import shlex
from .config import ALLOWED_CHARS, COMMAND_SCHEMAS


def validate_command(cmd: str) -> dict:
    """Parse and validate command against schemas."""
    for char in cmd:
        if char not in ALLOWED_CHARS:
            return {"allowed": False, "needs_confirmation": False, "reason": f"Blocked character: {char!r}"}

    try:
        tokens = shlex.split(cmd)
    except ValueError as e:
        return {"allowed": False, "needs_confirmation": False, "reason": f"Parse error: {e}"}

    if not tokens:
        return {"allowed": False, "needs_confirmation": False, "reason": "Empty command"}

    base_cmd = tokens[0]
    if base_cmd not in COMMAND_SCHEMAS:
        return {"allowed": False, "needs_confirmation": False, "reason": f"Unknown command: {base_cmd}"}

    schema = COMMAND_SCHEMAS[base_cmd]
    args = tokens[1:]

    # Check for destructive subcommands
    destructive = schema.get("destructive_subcommands", [])
    for arg in args:
        if arg in destructive:
            return {"allowed": True, "needs_confirmation": True, "reason": f"Destructive subcommand: {arg}"}

    # Validate subcommands if schema defines them
    allowed_subs = schema.get("allowed_subcommands")
    if allowed_subs is not None and args:
        if args[0] not in allowed_subs and args[0] not in destructive:
            return {"allowed": False, "needs_confirmation": False, "reason": f"Subcommand not allowed: {args[0]}"}

    # Validate flags if schema defines them
    allowed_flags = schema.get("allowed_flags")
    if allowed_flags is not None:
        for arg in args:
            if arg.startswith("-") and arg not in allowed_flags:
                return {"allowed": False, "needs_confirmation": False, "reason": f"Flag not allowed: {arg}"}

    return {"allowed": True, "needs_confirmation": False, "reason": "OK"}
