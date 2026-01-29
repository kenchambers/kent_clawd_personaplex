import pytest
import pytest_asyncio
import asyncio
import time
from unittest.mock import AsyncMock, MagicMock, patch, call
from httpx import AsyncClient, ASGITransport
from orchestrator.main import (
    app,
    is_confirmation,
    _pending,
    _pending_lock,
    CONFIRMATION_KEYWORDS,
)


@pytest.fixture(autouse=True)
def clear_pending():
    """Clear pending commands before each test."""
    _pending.clear()
    yield
    _pending.clear()


@pytest_asyncio.fixture
async def async_client():
    """Create async test client for FastAPI app."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


class TestHealth:
    @pytest.mark.asyncio
    async def test_health_returns_ok(self, async_client):
        """Test /health endpoint returns ok status."""
        response = await async_client.get("/health")
        assert response.status_code == 200
        assert response.json() == {"status": "ok"}


class TestConfirmationDetection:
    def test_confirm_keyword_matches(self):
        """Test that 'confirm' keyword is detected."""
        assert is_confirmation("confirm")
        assert is_confirmation("Please confirm")
        assert is_confirmation("Confirm the command")

    def test_yes_keyword_matches(self):
        """Test that 'yes' keyword is detected."""
        assert is_confirmation("yes")
        assert is_confirmation("Yes please")

    def test_go_keyword_matches(self):
        """Test that 'go' keyword is detected."""
        assert is_confirmation("go")
        assert is_confirmation("Let's go")

    def test_execute_keyword_matches(self):
        """Test that 'execute' keyword is detected."""
        assert is_confirmation("execute")
        assert is_confirmation("Please execute")

    def test_proceed_keyword_matches(self):
        """Test that 'proceed' keyword is detected."""
        assert is_confirmation("proceed")
        assert is_confirmation("Let's proceed")

    def test_ok_keyword_matches(self):
        """Test that 'ok' keyword is detected."""
        assert is_confirmation("ok")
        assert is_confirmation("That's ok")

    def test_yep_keyword_matches(self):
        """Test that 'yep' keyword is detected."""
        assert is_confirmation("yep")
        assert is_confirmation("Yep, do it")

    def test_substring_does_not_match(self):
        """Test that substring matches don't count."""
        assert not is_confirmation("confirm_later")
        assert not is_confirmation("confirmation")
        assert not is_confirmation("unconfirmed")

    def test_punctuation_stripped(self):
        """Test that punctuation is properly stripped."""
        assert is_confirmation("confirm.")
        assert is_confirmation("yes!")
        assert is_confirmation("go,")
        assert is_confirmation("execute?")
        assert is_confirmation("proceed;")
        assert is_confirmation("ok:")

    def test_case_insensitive(self):
        """Test case-insensitive matching."""
        assert is_confirmation("CONFIRM")
        assert is_confirmation("Yes")
        assert is_confirmation("GO")
        assert is_confirmation("Execute")

    def test_multiple_words(self):
        """Test detection in multiple-word transcripts."""
        assert is_confirmation("yes I want to run that command")
        assert is_confirmation("please execute this operation")
        assert is_confirmation("I say ok to proceed")

    def test_no_match(self):
        """Test transcripts without confirmation keywords."""
        assert not is_confirmation("run the command")
        assert not is_confirmation("perform this later")
        assert not is_confirmation("maybe tomorrow")


class TestProcessEndpoint:
    @pytest.mark.asyncio
    async def test_process_extracts_and_executes_command(self, async_client):
        """Test /process endpoint extracts and executes a safe command."""
        with patch("orchestrator.main.llm.extract_command") as mock_extract, \
             patch("orchestrator.main.run_moltbot", new_callable=AsyncMock) as mock_run:

            mock_extract.return_value = {"command": "ls -la"}
            mock_run.return_value = "file1\nfile2"

            response = await async_client.post("/process", json={
                "transcript": "list the files",
                "session_id": "session1"
            })

            assert response.status_code == 200
            assert response.json() == {"response": "file1\nfile2"}
            mock_extract.assert_called_once()
            mock_run.assert_called_once_with("ls -la")

    @pytest.mark.asyncio
    async def test_process_blocks_unsafe_command(self, async_client):
        """Test /process endpoint blocks unsafe commands."""
        with patch("orchestrator.main.llm.extract_command") as mock_extract:
            mock_extract.return_value = {"command": "rm -rf /"}

            response = await async_client.post("/process", json={
                "transcript": "delete everything",
                "session_id": "session1"
            })

            assert response.status_code == 200
            result = response.json()
            assert "Blocked" in result["response"]

    @pytest.mark.asyncio
    async def test_process_returns_no_command_detected(self, async_client):
        """Test /process returns appropriate message when no command detected."""
        with patch("orchestrator.main.llm.extract_command") as mock_extract:
            mock_extract.return_value = {"command": None}

            response = await async_client.post("/process", json={
                "transcript": "hello there"
            })

            assert response.status_code == 200
            assert "didn't detect a server command" in response.json()["response"]

    @pytest.mark.asyncio
    async def test_destructive_command_requires_confirmation(self, async_client):
        """Test that destructive commands require confirmation."""
        with patch("orchestrator.main.llm.extract_command") as mock_extract:
            mock_extract.return_value = {"command": "docker stop abc"}

            response = await async_client.post("/process", json={
                "transcript": "stop the docker container",
                "session_id": "session1"
            })

            assert response.status_code == 200
            result = response.json()
            assert result["response"] == "This will run: docker stop abc. Say 'confirm' to proceed."
            assert result["pending_command"] == "docker stop abc"
            assert "session1" in _pending

    @pytest.mark.asyncio
    async def test_confirmation_executes_pending(self, async_client):
        """Test that confirmation executes pending command."""
        _pending["session1"] = {
            "command": "docker stop abc",
            "expires": time.time() + 120
        }

        with patch("orchestrator.main.run_moltbot", new_callable=AsyncMock) as mock_run:

            mock_run.return_value = "Container stopped"

            response = await async_client.post("/process", json={
                "transcript": "confirm",
                "session_id": "session1"
            })

            assert response.status_code == 200
            assert response.json() == {"response": "Container stopped"}
            mock_run.assert_called_once_with("docker stop abc")
            assert "session1" not in _pending

    @pytest.mark.asyncio
    async def test_expired_pending_not_executed(self, async_client):
        """Test that expired pending commands are not executed."""
        _pending["session1"] = {
            "command": "docker stop abc",
            "expires": time.time() - 60  # Expired
        }

        with patch("orchestrator.main.llm.extract_command") as mock_extract:
            mock_extract.return_value = {"command": "ls"}

            response = await async_client.post("/process", json={
                "transcript": "confirm",
                "session_id": "session1"
            })

            assert response.status_code == 200
            # Should have processed as new request, not confirmed
            assert "session1" not in _pending

    @pytest.mark.asyncio
    async def test_concurrent_confirmation_no_keyerror(self, async_client):
        """Test that concurrent confirmations don't cause KeyError with lock."""
        _pending["session1"] = {
            "command": "docker stop abc",
            "expires": time.time() + 120
        }

        async def confirm_request():
            with patch("orchestrator.main.run_moltbot", new_callable=AsyncMock) as mock_run:
                mock_run.return_value = "Stopped"
                response = await async_client.post("/process", json={
                    "transcript": "confirm",
                    "session_id": "session1"
                })
                return response.status_code

        # Simulate concurrent requests to same session
        results = await asyncio.gather(
            confirm_request(),
            confirm_request(),
            return_exceptions=True
        )

        # Both should complete without KeyError
        assert all(r != KeyError for r in results)

    @pytest.mark.asyncio
    async def test_large_output_truncated(self, async_client):
        """Test that large output is truncated at 100KB."""
        large_output = "x" * (150_000)  # 150KB output

        with patch("orchestrator.main.llm.extract_command") as mock_extract:

            mock_extract.return_value = {"command": "ls"}

            # Create a custom mock for subprocess that returns large output
            async def mock_create_subprocess(*args, **kwargs):
                mock_proc = AsyncMock()
                mock_proc.communicate.return_value = (large_output.encode(), b"")
                mock_proc.returncode = 0
                return mock_proc

            with patch("asyncio.create_subprocess_exec", side_effect=mock_create_subprocess):
                response = await async_client.post("/process", json={
                    "transcript": "list files"
                })

            result = response.json()["response"]
            assert len(result) < 150_000
            assert "truncated" in result
            assert "150000" in result  # Should show original size

    @pytest.mark.asyncio
    async def test_normal_output_not_truncated(self, async_client):
        """Test that normal output under 100KB is not truncated."""
        normal_output = "file" * 1000  # ~4KB

        with patch("orchestrator.main.llm.extract_command") as mock_extract, \
             patch("orchestrator.main.run_moltbot", new_callable=AsyncMock) as mock_run:

            mock_extract.return_value = {"command": "ls"}
            mock_run.return_value = normal_output

            response = await async_client.post("/process", json={
                "transcript": "list files"
            })

            result = response.json()["response"]
            assert result == normal_output
            assert "truncated" not in result


class TestExecuteEndpoint:
    @pytest.mark.asyncio
    async def test_execute_extracts_multiple_commands(self, async_client):
        """Test /execute endpoint extracts and executes multiple commands."""
        with patch("orchestrator.main.llm.extract_commands_from_conversation", new_callable=AsyncMock) as mock_extract, \
             patch("orchestrator.main.run_moltbot", new_callable=AsyncMock) as mock_run:

            mock_extract.return_value = {"commands": ["ls -la", "ps aux"]}
            mock_run.side_effect = ["files", "processes"]

            response = await async_client.post("/execute", json={
                "transcript": ["list files", "show processes"],
                "session_id": "session1"
            })

            assert response.status_code == 200
            result = response.json()
            assert len(result["results"]) == 2
            assert result["results"][0]["status"] == "executed"
            assert result["results"][1]["status"] == "executed"

    @pytest.mark.asyncio
    async def test_execute_blocks_unsafe_in_batch(self, async_client):
        """Test /execute endpoint blocks unsafe commands in batch."""
        with patch("orchestrator.main.llm.extract_commands_from_conversation", new_callable=AsyncMock) as mock_extract:
            mock_extract.return_value = {"commands": ["ls", "rm -rf /"]}

            response = await async_client.post("/execute", json={
                "transcript": ["list files", "delete everything"]
            })

            assert response.status_code == 200
            result = response.json()
            assert len(result["results"]) == 2
            assert result["results"][0]["status"] == "executed"
            assert result["results"][1]["status"] == "blocked"

    @pytest.mark.asyncio
    async def test_execute_empty_transcript(self, async_client):
        """Test /execute with empty transcript returns empty results."""
        with patch("orchestrator.main.llm.extract_commands_from_conversation", new_callable=AsyncMock) as mock_extract:
            mock_extract.return_value = {"commands": []}

            response = await async_client.post("/execute", json={
                "transcript": []
            })

            assert response.status_code == 200
            assert response.json() == {"results": []}

    @pytest.mark.asyncio
    async def test_execute_pending_confirmation(self, async_client):
        """Test /execute handles destructive commands with pending confirmation."""
        with patch("orchestrator.main.llm.extract_commands_from_conversation", new_callable=AsyncMock) as mock_extract:
            mock_extract.return_value = {"commands": ["docker stop abc"]}

            response = await async_client.post("/execute", json={
                "transcript": ["stop the container"],
                "session_id": "session1"
            })

            assert response.status_code == 200
            result = response.json()
            assert result["results"][0]["status"] == "pending_confirmation"
            assert "session1" in _pending

    @pytest.mark.asyncio
    async def test_execute_needs_confirmation_no_session(self, async_client):
        """Test /execute without session_id for destructive commands."""
        with patch("orchestrator.main.llm.extract_commands_from_conversation", new_callable=AsyncMock) as mock_extract:
            mock_extract.return_value = {"commands": ["docker stop abc"]}

            response = await async_client.post("/execute", json={
                "transcript": ["stop the container"]
            })

            assert response.status_code == 200
            result = response.json()
            assert result["results"][0]["status"] == "needs_confirmation"
