import asyncio
import json
import logging
import time
from contextlib import asynccontextmanager
from fastapi import FastAPI
from pydantic import BaseModel
from . import safety, llm, notify
from .config import (
    PENDING_COMMAND_TTL_SECONDS,
    WHATSAPP_PHONE,
    PERSONAPLEX_URL,
    PERSONAPLEX_VOICE,
    NOTIFY_ON_COMPLETE,
    NOTIFY_ON_QUESTION,
    EXECUTION_TIMEOUT_MINUTES,
)
from .execution import ExecutionState, ExecutionContext, _utcnow

logger = logging.getLogger(__name__)

# In-memory pending confirmations: {session_id: {"command": str, "expires": float}}
_pending: dict[str, dict] = {}
_pending_lock = asyncio.Lock()

CONFIRMATION_KEYWORDS = {"confirm", "yes", "go", "execute", "proceed", "ok", "yep"}

MAX_RESULT_SIZE = 100_000


def is_confirmation(transcript: str) -> bool:
    """Check if transcript contains confirmation keyword with word-boundary matching."""
    words = transcript.lower().split()
    return any(word.strip(".,!?;:") in CONFIRMATION_KEYWORDS for word in words)


class VoicePayload(BaseModel):
    transcript: str
    session_id: str | None = None


class ExecutePayload(BaseModel):
    transcript: list[str]
    session_id: str | None = None


async def cleanup_expired_pending():
    """Periodically clean up expired pending commands."""
    while True:
        await asyncio.sleep(60)
        now = time.time()
        async with _pending_lock:
            expired = [k for k, v in _pending.items() if now > v["expires"]]
            for k in expired:
                del _pending[k]
            if expired:
                logger.info("Cleaned %d expired pending commands", len(expired))


async def setup_error_monitor_cron():
    """Configure Moltbot cron job for terminal error monitoring."""
    try:
        task = """Check terminal outputs and system logs for errors:
1. Run 'dmesg | tail -50' for kernel messages
2. Check 'journalctl -p err -n 20' for recent errors
3. Check 'df -h' for disk space issues (alert if >90%)
4. Check 'free -h' for memory issues
5. Look for any crashed services with 'systemctl --failed'

If critical issues found, send WhatsApp notification with summary.
Only report NEW issues not already in today's memory log."""

        proc = await asyncio.create_subprocess_exec(
            "moltbot", "cron", "add",
            "--id", "terminal-error-monitor",
            "--schedule", "*/15 * * * *",
            "--task", task,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        await proc.communicate()
        logger.info("Error monitor cron job configured")
    except Exception as e:
        logger.warning("Could not setup error monitor cron: %s", e)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Manage app startup and shutdown."""
    # Startup
    cleanup_task = asyncio.create_task(cleanup_expired_pending())
    await setup_error_monitor_cron()
    yield
    # Shutdown
    cleanup_task.cancel()
    try:
        await cleanup_task
    except asyncio.CancelledError:
        pass


app = FastAPI(lifespan=lifespan)


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.post("/process")
async def process_voice_input(payload: VoicePayload):
    transcript = payload.transcript
    session_id = payload.session_id

    # Check for pending confirmation
    if session_id:
        async with _pending_lock:
            if session_id in _pending:
                entry = _pending[session_id]
                if time.time() > entry["expires"]:
                    del _pending[session_id]
                elif is_confirmation(transcript):
                    cmd = _pending.pop(session_id)["command"]
                    result = await run_moltbot(cmd)
                    logger.info("Confirmed and executed: %s", cmd)
                    return {"response": result}

    # Extract command (Moltbot manages its own memory/context)
    intent = await llm.extract_command(transcript, [])
    if not intent.get("command"):
        return {"response": "I didn't detect a server command in that request."}

    check = safety.validate_command(intent["command"])
    if not check["allowed"]:
        return {"response": f"Blocked: {check['reason']}"}
    if check["needs_confirmation"]:
        if session_id:
            async with _pending_lock:
                _pending[session_id] = {
                    "command": intent["command"],
                    "expires": time.time() + PENDING_COMMAND_TTL_SECONDS,
                }
        return {
            "response": f"This will run: {intent['command']}. Say 'confirm' to proceed.",
            "pending_command": intent["command"],
        }

    logger.info("Executing: %s", intent["command"])
    result = await run_moltbot(intent["command"])
    return {"response": result}


@app.post("/execute")
async def execute_conversation(payload: ExecutePayload):
    """Extract and execute multiple commands from conversation transcript."""
    transcript_list = payload.transcript
    session_id = payload.session_id

    # Extract commands from conversation (Moltbot has its own memory)
    commands_response = await llm.extract_commands_from_conversation(transcript_list, [])
    commands = commands_response.get("commands", [])

    if not commands:
        return {"results": []}

    results = []

    # Process each command
    for cmd in commands:
        # Validate command
        check = safety.validate_command(cmd)
        if not check["allowed"]:
            results.append({
                "command": cmd,
                "status": "blocked",
                "reason": check["reason"]
            })
            continue

        # Handle destructive commands that need confirmation
        if check["needs_confirmation"]:
            if session_id:
                async with _pending_lock:
                    _pending[session_id] = {
                        "command": cmd,
                        "expires": time.time() + PENDING_COMMAND_TTL_SECONDS,
                    }
                results.append({
                    "command": cmd,
                    "status": "pending_confirmation",
                    "reason": check["reason"]
                })
            else:
                results.append({
                    "command": cmd,
                    "status": "needs_confirmation",
                    "reason": check["reason"]
                })
            continue

        # Execute safe command
        logger.info("Executing: %s", cmd)
        result = await run_moltbot(cmd)
        results.append({
            "command": cmd,
            "status": "executed",
            "output": result
        })

    return {"results": results}


@app.get("/sessions")
async def get_moltbot_sessions():
    """
    Expose Moltbot session data for PersonaPlex frontend context.
    Uses moltbot sessions_list tool.
    """
    try:
        proc = await asyncio.create_subprocess_exec(
            "moltbot", "sessions", "list", "--json",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=10.0)
        sessions = json.loads(stdout.decode())
        return {"sessions": sessions}
    except Exception as e:
        logger.exception("Failed to get Moltbot sessions")
        return {"sessions": [], "error": str(e)}


@app.get("/sessions/{session_key}/history")
async def get_session_history(session_key: str, limit: int = 50):
    """
    Get transcript history for a specific Moltbot session.
    PersonaPlex frontend can use this for context building.
    """
    try:
        proc = await asyncio.create_subprocess_exec(
            "moltbot", "sessions", "history", session_key,
            "--limit", str(limit), "--json",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=10.0)
        history = json.loads(stdout.decode())
        return {"session_key": session_key, "history": history}
    except Exception as e:
        logger.exception("Failed to get session history for %s", session_key)
        return {"session_key": session_key, "history": [], "error": str(e)}


@app.get("/personaplex/prompt")
async def get_personaplex_prompt(session_id: str | None = None):
    """
    Build a dynamic PersonaPlex text-prompt with current session context.
    The PersonaPlex frontend calls this before starting a conversation.

    Returns prompt formatted for PersonaPlex's casual conversation style.
    """
    base_prompt = "You enjoy having a good conversation."

    if not session_id:
        # No active session - general VPS admin context
        return {
            "text_prompt": f"{base_prompt} You are Kent's VPS admin assistant. Help with server tasks via natural voice conversation.",
            "voice_prompt": PERSONAPLEX_VOICE,
        }

    # Fetch session context from Moltbot
    try:
        proc = await asyncio.create_subprocess_exec(
            "moltbot", "sessions", "history", session_id,
            "--limit", "10", "--json",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout, _ = await asyncio.wait_for(proc.communicate(), timeout=10.0)
        history = json.loads(stdout.decode())

        # Build context summary from recent history
        if history:
            recent_context = history[-1].get("content", "")[:500]  # Last message
            task_summary = f"The current task context: {recent_context}"
        else:
            task_summary = "No specific task in progress."

        return {
            "text_prompt": f"{base_prompt} You are Kent's VPS admin assistant. {task_summary}",
            "voice_prompt": PERSONAPLEX_VOICE,
            "session_id": session_id,
        }
    except Exception as e:
        logger.exception("Failed to build PersonaPlex prompt for session %s", session_id)
        return {
            "text_prompt": f"{base_prompt} You are Kent's VPS admin assistant.",
            "voice_prompt": PERSONAPLEX_VOICE,
            "error": str(e),
        }


@app.get("/personaplex/prompt/question")
async def get_question_prompt(session_id: str, question: str, context: str = ""):
    """
    Build a PersonaPlex prompt specifically for answering a question from Moltbot.
    Used when user clicks WhatsApp link to answer a pending question.

    This prompt guides PersonaPlex to focus on getting the user's answer.
    """
    prompt = f"""You enjoy having a good conversation. You are Kent's VPS admin assistant.

You paused a server task because you need clarification. Here's what you need to ask:

Question: {question}
Context: {context}

Listen for Kent's answer, then confirm you understood. Keep the conversation focused on getting a clear answer to this question."""

    return {
        "text_prompt": prompt,
        "voice_prompt": PERSONAPLEX_VOICE,
        "session_id": session_id,
        "mode": "question",
    }


async def run_moltbot(cmd: str) -> str:
    try:
        proc = await asyncio.create_subprocess_exec(
            "moltbot", "agent", "--message", cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout, stderr = await asyncio.wait_for(proc.communicate(), timeout=30.0)
        if proc.returncode != 0:
            error_msg = stderr.decode(errors='replace')
            if len(error_msg) > MAX_RESULT_SIZE:
                error_msg = error_msg[:MAX_RESULT_SIZE] + f"\n... (truncated, total {len(error_msg)} bytes)"
            return f"Command failed: {error_msg}"
        result = stdout.decode(errors="replace")
        if len(result) > MAX_RESULT_SIZE:
            result = result[:MAX_RESULT_SIZE] + f"\n... (truncated, total {len(result)} bytes)"
        return result
    except FileNotFoundError:
        return "Moltbot service is unavailable."
    except asyncio.TimeoutError:
        proc.kill()
        return "Command execution timed out after 30s."
    except Exception as e:
        logger.exception("Moltbot execution error")
        return f"Execution error: {e}"


# --- Two-Way Communication: Background execution support ---


class BackgroundExecutePayload(BaseModel):
    transcript: str
    commands: list[str]


class ResumePayload(BaseModel):
    answer: str


# In-memory execution registry: session_id -> {"ctx": ExecutionContext, "event": asyncio.Event}
_executions: dict[str, dict] = {}


async def run_moltbot_long(instruction: str, session_id: str) -> str:
    """Run Moltbot with a multi-command instruction. Longer timeout than single commands."""
    try:
        proc = await asyncio.create_subprocess_exec(
            "moltbot", "agent", "--message", instruction,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stdout, stderr = await asyncio.wait_for(
            proc.communicate(),
            timeout=EXECUTION_TIMEOUT_MINUTES * 60,
        )
        if proc.returncode != 0:
            raise RuntimeError(f"Moltbot exited {proc.returncode}: {stderr.decode(errors='replace')}")
        return stdout.decode(errors="replace")
    except FileNotFoundError:
        raise RuntimeError("Moltbot service is unavailable")
    except asyncio.TimeoutError:
        proc.kill()
        raise RuntimeError(f"Moltbot timed out after {EXECUTION_TIMEOUT_MINUTES}min")


async def _run_execution(ctx: ExecutionContext) -> None:
    """Background task: run Moltbot, detect NEED_INPUT, handle pause/resume."""
    try:
        ctx.state = ExecutionState.RUNNING
        ctx.updated_at = _utcnow()

        # Moltbot has its own memory system - no need to inject context
        instruction = llm.generate_moltbot_instruction(
            ctx.commands, ctx.answers, ctx.session_id, injected_context=""
        )
        output = await run_moltbot_long(instruction, ctx.session_id)
        parsed = llm.parse_moltbot_output(output)

        while parsed["status"] == "needs_input":
            # Pause: store question, notify user, wait for resume
            ctx.state = ExecutionState.WAITING_FOR_INPUT
            ctx.current_question = parsed["question"]
            ctx.question_context = parsed.get("context")
            ctx.updated_at = _utcnow()

            if NOTIFY_ON_QUESTION and WHATSAPP_PHONE and parsed["question"].strip():
                notify.send_question_notification(
                    WHATSAPP_PHONE, parsed["question"],
                    parsed.get("context", ""), PERSONAPLEX_URL, ctx.session_id
                )

            # Block until POST /resume sets the event
            # Note: clear() AFTER wait() to avoid race condition where resume
            # happens between clear() and wait(), causing indefinite blocking
            event = _executions[ctx.session_id]["event"]
            await asyncio.wait_for(event.wait(), timeout=EXECUTION_TIMEOUT_MINUTES * 60)
            event.clear()  # Clear after consuming signal, ready for next cycle

            # Resume with the answer
            ctx.state = ExecutionState.RUNNING
            ctx.current_question = None
            ctx.updated_at = _utcnow()

            instruction = llm.generate_moltbot_instruction(
                ctx.commands, ctx.answers, ctx.session_id, injected_context=""
            )
            output = await run_moltbot_long(instruction, ctx.session_id)
            parsed = llm.parse_moltbot_output(output)

        # Completed
        ctx.state = ExecutionState.COMPLETED
        ctx.results.append({"output": parsed["output"]})
        ctx.updated_at = _utcnow()

        if NOTIFY_ON_COMPLETE and WHATSAPP_PHONE:
            notify.send_completion_notification(
                WHATSAPP_PHONE, parsed["output"],
                PERSONAPLEX_URL, ctx.session_id
            )

    except asyncio.TimeoutError:
        ctx.state = ExecutionState.FAILED
        ctx.error_message = f"Timed out waiting for user input ({EXECUTION_TIMEOUT_MINUTES}min)"
        ctx.updated_at = _utcnow()
    except Exception as e:
        ctx.state = ExecutionState.FAILED
        ctx.error_message = str(e)
        ctx.updated_at = _utcnow()
        logger.exception("Execution %s failed", ctx.session_id)
    finally:
        # Keep in registry for 5min after completion for polling
        await asyncio.sleep(300)
        _executions.pop(ctx.session_id, None)


@app.post("/execute/background")
async def start_background_execution(payload: BackgroundExecutePayload):
    """Start a background execution with human-in-the-loop support."""
    ctx = ExecutionContext(
        transcript=[payload.transcript],
        commands=payload.commands,
    )
    event = asyncio.Event()
    _executions[ctx.session_id] = {"ctx": ctx, "event": event}
    asyncio.create_task(_run_execution(ctx))
    return {"session_id": ctx.session_id, "state": ctx.state.value}


@app.get("/context/{session_id}")
async def get_context(session_id: str):
    """Get current execution context (state, results, current question if any)."""
    # Try in-memory first
    entry = _executions.get(session_id)
    if entry:
        ctx = entry["ctx"]
        return {
            "session_id": ctx.session_id,
            "state": ctx.state.value,
            "transcript": ctx.transcript,
            "commands": ctx.commands,
            "results": ctx.results,
            "current_question": ctx.current_question,
            "question_context": ctx.question_context,
            "answers": ctx.answers,
            "topics": ctx.topics,
            "error_message": ctx.error_message,
            "created_at": ctx.created_at.isoformat(),
            "updated_at": ctx.updated_at.isoformat(),
        }
    return {"error": "Session not found"}


@app.post("/resume/{session_id}")
async def resume_execution(session_id: str, payload: ResumePayload):
    """Resume a paused execution with the user's answer."""
    entry = _executions.get(session_id)
    if not entry:
        return {"error": "Session not found"}
    ctx = entry["ctx"]
    if ctx.state != ExecutionState.WAITING_FOR_INPUT:
        return {"error": f"Session is {ctx.state.value}, not waiting for input"}

    ctx.answers.append({
        "question": ctx.current_question,
        "answer": payload.answer,
    })
    # Signal the background task to continue
    entry["event"].set()
    return {"session_id": session_id, "state": "resuming"}
