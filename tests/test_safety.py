from orchestrator.safety import validate_command


def test_allowed_command():
    r = validate_command("ls -la")
    assert r["allowed"] and not r["needs_confirmation"]


def test_blocked_character():
    r = validate_command("ls; rm -rf /")
    assert not r["allowed"]
    assert "Blocked character" in r["reason"]


def test_unknown_command():
    r = validate_command("rm -rf /")
    assert not r["allowed"]
    assert "Unknown command" in r["reason"]


def test_destructive_needs_confirmation():
    r = validate_command("docker stop abc")
    assert r["allowed"] and r["needs_confirmation"]


def test_disallowed_flag():
    r = validate_command("ls --color")
    assert not r["allowed"]


def test_blocked_equals_sign():
    r = validate_command("ls --color=always")
    assert not r["allowed"]
    assert "Blocked character" in r["reason"]


def test_pipe_injection():
    r = validate_command("ls | cat /etc/passwd")
    assert not r["allowed"]


def test_subcommand_not_allowed():
    r = validate_command("systemctl enable nginx")
    assert not r["allowed"]
