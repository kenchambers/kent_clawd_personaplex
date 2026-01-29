import os

# Moltbot Configuration
MOLTBOT_WORKSPACE = os.getenv("MOLTBOT_WORKSPACE", "~/clawd")

# PersonaPlex Voice Configuration
# Options: NATF0-3 (natural female), NATM0-3 (natural male), VARF0-4, VARM0-4 (variety)
PERSONAPLEX_VOICE = os.getenv("PERSONAPLEX_VOICE", "NATM1")

# LLM Configuration
LLM_API_KEY = os.getenv("ANTHROPIC_API_KEY")
LLM_MODEL = os.getenv("ANTHROPIC_MODEL", "claude-sonnet-4-20250514")

COMMAND_SCHEMAS = {
    "ls": {"allowed_flags": ["-l", "-a", "-h", "-la", "-lah"]},
    "df": {"allowed_flags": ["-h"]},
    "free": {"allowed_flags": ["-h", "-m", "-g"]},
    "top": {"allowed_flags": ["-b", "-n"]},
    "ps": {"allowed_flags": ["aux", "-ef", "-e"]},
    "systemctl": {
        "allowed_subcommands": ["status"],
        "destructive_subcommands": ["restart", "stop", "start"],
    },
    "docker": {
        "allowed_subcommands": ["ps", "images", "stats", "logs"],
        "destructive_subcommands": ["rm", "stop", "kill"],
    },
}

ALLOWED_CHARS = set(
    "abcdefghijklmnopqrstuvwxyz"
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    "0123456789"
    "-._/ "
)

PENDING_COMMAND_TTL_SECONDS = 120

# Two-Way Communication Settings
WHATSAPP_PHONE = os.getenv("WHATSAPP_PHONE")
PERSONAPLEX_URL = os.getenv("PERSONAPLEX_URL", "https://your-deployment.salad.cloud:8998")
NOTIFY_ON_COMPLETE = os.getenv("NOTIFY_ON_COMPLETE", "true").lower() == "true"
NOTIFY_ON_QUESTION = os.getenv("NOTIFY_ON_QUESTION", "true").lower() == "true"
EXECUTION_TIMEOUT_MINUTES = max(1, int(os.getenv("EXECUTION_TIMEOUT_MINUTES", "60")))
