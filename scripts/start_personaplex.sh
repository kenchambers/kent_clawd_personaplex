#!/bin/bash
set -e

# Fetch dynamic prompt from orchestrator
# This script can be called with an optional session_id parameter
SESSION_ID="${1:-}"

ORCHESTRATOR_URL="${ORCHESTRATOR_URL:-http://localhost:5000}"
PROMPT_ENDPOINT="$ORCHESTRATOR_URL/personaplex/prompt"

if [ -n "$SESSION_ID" ]; then
    PROMPT_ENDPOINT="$PROMPT_ENDPOINT?session_id=$SESSION_ID"
fi

echo "Fetching PersonaPlex prompt from $PROMPT_ENDPOINT"
PROMPT_RESPONSE=$(curl -s "$PROMPT_ENDPOINT")
TEXT_PROMPT=$(echo "$PROMPT_RESPONSE" | jq -r '.text_prompt')
VOICE_PROMPT=$(echo "$PROMPT_RESPONSE" | jq -r '.voice_prompt')

echo "Text prompt: $TEXT_PROMPT"
echo "Voice prompt: $VOICE_PROMPT"

# Generate SSL certs
SSL_DIR=$(mktemp -d)
echo "Created SSL directory: $SSL_DIR"

# Launch PersonaPlex with configured prompts
echo "Starting PersonaPlex server with dynamic prompts..."
python -m moshi.server \
    --ssl "$SSL_DIR" \
    --voice-prompt "${VOICE_PROMPT}.pt" \
    --text-prompt "$TEXT_PROMPT"
