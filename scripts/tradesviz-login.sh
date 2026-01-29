#!/bin/bash
# TradesViz automated login via Moltbot browser tool
# Run after container start to establish session
#
# SECURITY: Credentials passed via temp file, not command args
# This prevents exposure in `ps aux` or process inspection

set -eu

if [ -z "${TRADESVIZ_USERNAME:-}" ] || [ -z "${TRADESVIZ_PASSWORD:-}" ]; then
    echo "TradesViz credentials not set, skipping auto-login"
    exit 0
fi

# Configuration
MAX_RETRIES=3
RETRY_DELAY=10

# Create secure credential file (deleted on exit)
CRED_FILE=$(mktemp)
chmod 600 "$CRED_FILE"
trap 'rm -f "$CRED_FILE"' EXIT
echo "$TRADESVIZ_PASSWORD" > "$CRED_FILE"

echo "Attempting TradesViz login..."

for attempt in $(seq 1 $MAX_RETRIES); do
    echo "Login attempt $attempt/$MAX_RETRIES"

    # Use moltbot's browser tool to automate login
    # Password read from secure temp file, not command args
    if moltbot agent --message "
Use the browser tool to log into TradesViz:
1. Navigate to https://www.tradesviz.com/login/
2. Wait for page to load
3. Find the username input field and type: ${TRADESVIZ_USERNAME}
4. Read the password from file: $CRED_FILE
5. Find the password input field and type the password
6. Click the 'Sign In' button
7. Wait for redirect to dashboard
8. Verify login was successful by checking the page URL or content
9. Report success or failure

IMPORTANT: Do not log or display the password contents.
If login fails, report the error message shown on the page.
" --model opus; then
        echo "TradesViz login successful"
        exit 0
    fi

    if [ $attempt -lt $MAX_RETRIES ]; then
        DELAY=$((RETRY_DELAY * (2 ** (attempt - 1))))
        echo "Login failed, retrying in ${DELAY}s..."
        sleep $DELAY
    fi
done

echo "ERROR: TradesViz login failed after $MAX_RETRIES attempts" >&2
exit 1
