#!/bin/bash
set -u

# Ensure npm global packages are in PATH
export PATH="/usr/local/bin:$PATH"

# Moltbot wrapper is created by Dockerfile (uses npx for Node 24+ compatibility)
MOLTBOT_BIN="/usr/local/bin/moltbot"
if [ ! -x "$MOLTBOT_BIN" ]; then
    echo "FATAL: moltbot wrapper not found at $MOLTBOT_BIN (Dockerfile build issue)"
    exit 1
fi
export MOLTBOT_BIN

# PID tracking for graceful shutdown
SYNC_PID=""
TRADESVIZ_LOGIN_PID=""

# Graceful shutdown handler - sync workspace before exit
shutdown() {
    echo "Shutting down gracefully..."
    if [ -n "${SYNC_PID:-}" ]; then kill $SYNC_PID 2>/dev/null; fi
    if [ -n "${TRADESVIZ_LOGIN_PID:-}" ]; then kill $TRADESVIZ_LOGIN_PID 2>/dev/null; fi
    if [ -n "${SUPABASE_S3_ENDPOINT:-}" ]; then
        echo "Syncing workspace to Supabase before shutdown..."
        ./workspace_sync.sh backup || echo "Final backup failed"
    fi
    kill $(jobs -p) 2>/dev/null
    exit 0
}
trap shutdown EXIT INT TERM

# ============================================
# Service Readiness Functions
# ============================================

# Wait for Moltbot to be healthy before running dependent tasks
wait_for_moltbot() {
    local max_attempts=120  # 10 minutes max wait
    local attempt=0
    echo "Waiting for Moltbot to be ready..."
    while [ $attempt -lt $max_attempts ]; do
        if curl -sf http://localhost:18789/health >/dev/null 2>&1; then
            echo "Moltbot is ready"
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 5
    done
    echo "ERROR: Timeout waiting for Moltbot after $((max_attempts * 5))s" >&2
    return 1
}

# Wait for orchestrator's deep health check (verifies PersonaPlex + Moltbot)
wait_for_deep_health() {
    local max_attempts=180  # 15 minutes max wait (model download can be slow)
    local attempt=0
    echo "Waiting for all services to be ready (deep health check)..."
    while [ $attempt -lt $max_attempts ]; do
        # Check orchestrator's deep health endpoint
        response=$(curl -sf http://localhost:5000/health/deep 2>/dev/null)
        if [ $? -eq 0 ]; then
            status=$(echo "$response" | jq -r '.status' 2>/dev/null)
            if [ "$status" = "ok" ]; then
                echo "All services ready: $response"
                return 0
            fi
            echo "Health check response: $response (attempt $attempt)"
        fi
        attempt=$((attempt + 1))
        sleep 5
    done
    echo "ERROR: Timeout waiting for deep health after $((max_attempts * 5))s" >&2
    return 1
}

# Validate required environment variables
if [ -z "${HF_TOKEN:-}" ]; then
    echo "ERROR: HF_TOKEN environment variable is required for PersonaPlex"
    exit 1
fi

# Setup Moltbot workspace
MOLTBOT_WORKSPACE="${MOLTBOT_WORKSPACE:-$HOME/clawd}"
export MOLTBOT_WORKSPACE

# Try to restore workspace from Supabase Storage (if configured)
if [ -n "${SUPABASE_S3_ENDPOINT:-}" ]; then
    echo "Supabase Storage configured, restoring workspace..."
    ./workspace_sync.sh restore || echo "Restore failed, will use fresh workspace"
fi

# Initialize workspace structure if needed
if [ ! -d "$MOLTBOT_WORKSPACE" ] || [ ! -f "$MOLTBOT_WORKSPACE/AGENTS.md" ]; then
    echo "Initializing Moltbot workspace at $MOLTBOT_WORKSPACE"
    mkdir -p "$MOLTBOT_WORKSPACE"
    mkdir -p "$MOLTBOT_WORKSPACE/memory"
    mkdir -p "$MOLTBOT_WORKSPACE/skills"

    # Copy bootstrap files from repo (only if not restored from backup)
    cp -n /app/moltbot/AGENTS.md "$MOLTBOT_WORKSPACE/" 2>/dev/null || true
    cp -n /app/moltbot/SOUL.md "$MOLTBOT_WORKSPACE/" 2>/dev/null || true
    cp -n /app/moltbot/TOOLS.md "$MOLTBOT_WORKSPACE/" 2>/dev/null || true
    cp -n /app/moltbot/USER.md "$MOLTBOT_WORKSPACE/" 2>/dev/null || true
    cp -n /app/moltbot/MEMORY.md "$MOLTBOT_WORKSPACE/" 2>/dev/null || true
    cp -n /app/moltbot/IDEAS.md "$MOLTBOT_WORKSPACE/" 2>/dev/null || true
    cp -n /app/moltbot/skills/*.md "$MOLTBOT_WORKSPACE/skills/" 2>/dev/null || true

    echo "Moltbot workspace initialized successfully"
else
    echo "Moltbot workspace restored from Supabase at $MOLTBOT_WORKSPACE"
fi

# Start background sync to Supabase (if configured)
if [ -n "${SUPABASE_S3_ENDPOINT:-}" ]; then
    echo "Starting background workspace sync..."
    ./workspace_sync.sh loop &
    SYNC_PID=$!
fi

# Setup Moltbot configuration (tools, browser, channels)
CLAWDBOT_CONFIG_DIR="$HOME/.clawdbot"
mkdir -p "$CLAWDBOT_CONFIG_DIR"
if [ ! -f "$CLAWDBOT_CONFIG_DIR/moltbot.json" ]; then
    echo "Initializing Moltbot configuration..."
    cp /app/moltbot/moltbot.json "$CLAWDBOT_CONFIG_DIR/moltbot.json"

    # Add WhatsApp phone to allowlist if configured (using jq for safe JSON manipulation)
    if [ -n "${WHATSAPP_PHONE:-}" ]; then
        echo "Adding $WHATSAPP_PHONE to WhatsApp allowlist..."
        jq --arg phone "$WHATSAPP_PHONE" '.channels.whatsapp.allowFrom = [$phone]' \
            "$CLAWDBOT_CONFIG_DIR/moltbot.json" > "$CLAWDBOT_CONFIG_DIR/moltbot.json.tmp" \
            && mv "$CLAWDBOT_CONFIG_DIR/moltbot.json.tmp" "$CLAWDBOT_CONFIG_DIR/moltbot.json"
    fi
    echo "Moltbot configuration initialized"
else
    echo "Moltbot configuration already exists at $CLAWDBOT_CONFIG_DIR"
fi

# ============================================
# GitHub CLI Configuration
# ============================================
if [ -n "${GITHUB_TOKEN:-}" ]; then
    echo "Configuring GitHub CLI..."
    echo "$GITHUB_TOKEN" | gh auth login --with-token
    gh auth setup-git

    # Configure git identity for bot
    git config --global user.name "Moltbot"
    git config --global user.email "${GITHUB_BOT_EMAIL:-moltbot@example.com}"
fi

# ============================================
# Claude Code CLI Configuration
# ============================================
# Claude Code can use either:
# 1. ANTHROPIC_API_KEY (already set for Moltbot)
# 2. Setup token (for Claude subscription users)
if [ -n "${CLAUDE_SETUP_TOKEN:-}" ]; then
    echo "Configuring Claude Code with setup token..."
    echo "$CLAUDE_SETUP_TOKEN" | claude auth login
else
    echo "Claude Code will use ANTHROPIC_API_KEY"
fi

# ============================================
# Gemini CLI Configuration
# ============================================
# Gemini CLI uses GEMINI_API_KEY environment variable
# No explicit setup needed - just ensure env var is set
if [ -n "${GEMINI_API_KEY:-}" ]; then
    echo "Gemini CLI configured with API key"
else
    echo "Warning: GEMINI_API_KEY not set - Gemini CLI won't work"
fi

# ============================================
# TradesViz Auto-Login (after Moltbot starts)
# ============================================
# Uses health check instead of fixed delay for reliability
# Background process is tracked for proper cleanup on shutdown
if [ -n "${TRADESVIZ_USERNAME:-}" ] && [ -n "${TRADESVIZ_PASSWORD:-}" ]; then
    echo "TradesViz credentials found, will attempt auto-login after Moltbot is ready..."
    (
        wait_for_moltbot && /app/scripts/tradesviz-login.sh
    ) >> /var/log/tradesviz-login.log 2>&1 &
    TRADESVIZ_LOGIN_PID=$!
    echo "TradesViz login scheduled (PID: $TRADESVIZ_LOGIN_PID)"
fi

# ============================================
# Scheduled Cron Jobs (after Moltbot starts)
# ============================================
# Configure automated tasks: self-reflection, afternoon summary, health monitor
setup_cron_jobs() {
    echo "Setting up scheduled cron jobs..."

    # Check if cron jobs already exist (avoid duplicates on restart)
    existing_crons=$($MOLTBOT_BIN cron list 2>/dev/null || echo "")

    # Hourly self-reflection (generates ideas, no notification)
    if ! echo "$existing_crons" | grep -q "Self-Reflection"; then
        echo "Adding Self-Reflection cron (hourly)..."
        $MOLTBOT_BIN cron add \
            --name "Self-Reflection" \
            --cron "0 * * * *" \
            --session isolated \
            --model "sonnet" \
            --message "Run hourly self-reflection per skills/self-reflection.md: 1) Review recent actions and their alignment with Kent's goals from USER.md and SOUL.md 2) Generate 1-3 actionable ideas to help Kent's trading business grow 3) Score each idea by impact, effort, urgency, alignment (max 50 points) 4) Add ideas to IDEAS.md with timestamps. Focus on data-driven, patient growth. No notification needed - just log ideas."
    fi

    # Afternoon summary at 3pm Tbilisi (includes top 3 ideas)
    if ! echo "$existing_crons" | grep -q "Afternoon Summary"; then
        if [ -n "${WHATSAPP_PHONE:-}" ]; then
            echo "Adding Afternoon Summary cron (3pm daily)..."
            $MOLTBOT_BIN cron add \
                --name "Afternoon Summary" \
                --cron "0 15 * * *" \
                --tz "Asia/Tbilisi" \
                --session isolated \
                --message "Generate afternoon summary for Kent: 1) Trading status across all EAs 2) Work completed since last summary 3) Current priorities. IMPORTANT: Review IDEAS.md and include the TOP 3 highest-scoring ideas as an 'Actionable Ideas' section. Mark included ideas as 'reviewed' in IDEAS.md." \
                --deliver --channel whatsapp --to "$WHATSAPP_PHONE"
        else
            echo "Skipping Afternoon Summary - WHATSAPP_PHONE not set"
        fi
    fi

    # Health monitor every 4 hours (only notifies if issues found)
    if ! echo "$existing_crons" | grep -q "Health Monitor"; then
        echo "Adding Health Monitor cron (every 4 hours)..."
        $MOLTBOT_BIN cron add \
            --name "Health Monitor" \
            --cron "0 */4 * * *" \
            --session isolated \
            --model "sonnet" \
            --message "Run health check on all systems. Only notify Kent via WhatsApp if issues are found that need attention."
    fi

    echo "Cron jobs configured successfully"
    $MOLTBOT_BIN cron list
}

# Run cron setup in background after Moltbot is ready
(
    wait_for_moltbot && setup_cron_jobs
) >> /var/log/cron-setup.log 2>&1 &
CRON_SETUP_PID=$!
echo "Cron job setup scheduled (PID: $CRON_SETUP_PID)"

# Create SSL directory for PersonaPlex
SSL_DIR=$(mktemp -d)
echo "Created SSL directory: $SSL_DIR"

# ============================================
# GPU Verification: Ensure we have sufficient VRAM
# ============================================
# Moshi requires 24GB VRAM minimum. Exit immediately if GPU is insufficient
# so Salad Cloud can retry on different hardware.
MIN_VRAM_GB="${MIN_VRAM_GB:-20}"  # 20GB minimum (allows some headroom)
echo "Checking GPU VRAM requirements..."
if command -v nvidia-smi &> /dev/null; then
    # Get total VRAM in MB, convert to GB
    VRAM_MB=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -1)
    if [ -n "$VRAM_MB" ]; then
        VRAM_GB=$((VRAM_MB / 1024))
        GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)
        echo "Detected GPU: $GPU_NAME with ${VRAM_GB}GB VRAM"
        if [ "$VRAM_GB" -lt "$MIN_VRAM_GB" ]; then
            echo "FATAL: GPU VRAM (${VRAM_GB}GB) is below minimum requirement (${MIN_VRAM_GB}GB)" >&2
            echo "Moshi requires 24GB+ VRAM. Exiting so orchestration can retry on different hardware." >&2
            exit 1
        fi
        echo "GPU VRAM check passed: ${VRAM_GB}GB >= ${MIN_VRAM_GB}GB minimum"
    else
        echo "Warning: Could not query GPU VRAM, proceeding anyway"
    fi
else
    echo "Warning: nvidia-smi not found, cannot verify GPU VRAM"
fi

# ============================================
# Memory Optimization: Create swap space
# ============================================
# The Moshi model requires significant memory during loading.
# Swap size matches GPU VRAM to support CPU offloading.
SWAP_SIZE_GB="${SWAP_SIZE_GB:-24}"
SWAP_FILE="/swapfile"
if [ ! -f "$SWAP_FILE" ]; then
    echo "Creating ${SWAP_SIZE_GB}GB swap file for model loading..."
    if dd if=/dev/zero of="$SWAP_FILE" bs=1G count="$SWAP_SIZE_GB" 2>/dev/null; then
        chmod 600 "$SWAP_FILE"
        mkswap "$SWAP_FILE" >/dev/null 2>&1
        swapon "$SWAP_FILE" 2>/dev/null && echo "Swap enabled: ${SWAP_SIZE_GB}GB" || echo "Warning: Could not enable swap (may need root)"
    else
        echo "Warning: Could not create swap file (disk space?)"
    fi
else
    echo "Swap file already exists"
    swapon "$SWAP_FILE" 2>/dev/null || true
fi

# Start PersonaPlex server on internal port 8999 (nginx proxies from 8998)
# --cpu-offload: Offloads model layers to CPU RAM when GPU VRAM is insufficient
# Capture output to log file for crash diagnostics
PERSONAPLEX_LOG="/var/log/personaplex.log"
echo "Starting PersonaPlex on port 8999 with CPU offload enabled..."
python -m moshi.server --ssl "$SSL_DIR" --port 8999 --cpu-offload >> "$PERSONAPLEX_LOG" 2>&1 &
PERSONAPLEX_PID=$!

# Start Moltbot gateway
echo "Starting Moltbot gateway..."
$MOLTBOT_BIN gateway --port 18789 &
MOLTBOT_PID=$!

# Start orchestrator (bind to 0.0.0.0 for explicit IPv4 + :: for IPv6)
echo "Starting orchestrator..."
uvicorn orchestrator.main:app --host "0.0.0.0" --port 5000 &
UVICORN_PID=$!

# Wait for orchestrator to be ready before checking deep health
echo "Waiting for orchestrator to start..."
for i in {1..30}; do
    if curl -sf http://localhost:5000/health >/dev/null 2>&1; then
        echo "Orchestrator is ready"
        break
    fi
    sleep 1
done

# Wait for deep health (PersonaPlex + Moltbot) before starting nginx
# This ensures nginx health checks will pass once it starts
echo "Waiting for backend services before starting nginx..."
wait_for_deep_health || {
    echo "WARNING: Deep health check not passing yet, starting nginx anyway"
    echo "Salad Cloud health probes will retry during start-period"
}

# Verify nginx config before starting
echo "Verifying nginx configuration..."
if ! nginx -t 2>/dev/null; then
    echo "ERROR: nginx configuration is invalid"
    nginx -t
    exit 1
fi

# Start nginx reverse proxy (entry point on port 8998)
echo "Starting nginx reverse proxy..."
if ! nginx; then
    echo "ERROR: nginx failed to start"
    exit 1
fi

# Verify nginx is running
sleep 1
if ! pgrep -x nginx > /dev/null; then
    echo "ERROR: nginx is not running after startup"
    exit 1
fi

echo "All services started. Monitoring..."
# Log container version for Axiom tracking
echo "[INFO] Container version: ${CONTAINER_VERSION:-unknown}" >&2
echo "  - nginx (reverse proxy): port 8998"
echo "  - PersonaPlex: port 8999 (internal)"
echo "  - Orchestrator: port 5000 (internal)"
echo "  - Moltbot gateway: port 18789 (internal)"

# ============================================
# Circuit Breaker: Exit after repeated failures
# ============================================
# If PersonaPlex crashes repeatedly, exit the container so Salad Cloud
# can retry on different hardware instead of looping forever.
MAX_PERSONAPLEX_FAILURES="${MAX_PERSONAPLEX_FAILURES:-3}"
PERSONAPLEX_FAILURE_COUNT=0
LAST_FAILURE_TIME=0
FAILURE_WINDOW_SECONDS=300  # Reset counter if no crash in 5 minutes

# Monitor: if nginx or orchestrator dies, exit so the container restarts
while true; do
    if ! pgrep -x nginx > /dev/null; then
        echo "nginx died, shutting down container."
        exit 1
    fi
    if ! kill -0 $UVICORN_PID 2>/dev/null; then
        echo "Orchestrator exited, shutting down container."
        exit 1
    fi
    if ! kill -0 $PERSONAPLEX_PID 2>/dev/null; then
        CURRENT_TIME=$(date +%s)
        echo "PersonaPlex died, capturing crash logs..."
        echo "=== CRASH DETECTED at $(date -u +%Y-%m-%dT%H:%M:%SZ) ===" >> "$PERSONAPLEX_LOG"

        # Show last 50 lines of log to stderr (goes to Salad Cloud logs)
        echo "--- Last 50 lines before crash ---" >&2
        tail -50 "$PERSONAPLEX_LOG" >&2
        echo "--- End crash log ---" >&2

        # Check for common crash signatures
        CRASH_REASON="unknown"
        if grep -q "CUDA out of memory" "$PERSONAPLEX_LOG" 2>/dev/null; then
            CRASH_REASON="CUDA_OOM"
            echo "[CRASH REASON] CUDA out of memory - GPU VRAM insufficient" >&2
        elif grep -q "RuntimeError" "$PERSONAPLEX_LOG" 2>/dev/null; then
            CRASH_REASON="RuntimeError"
            echo "[CRASH REASON] RuntimeError - check last lines above" >&2
        elif grep -q "Segmentation fault" "$PERSONAPLEX_LOG" 2>/dev/null; then
            CRASH_REASON="Segfault"
            echo "[CRASH REASON] Segmentation fault - memory corruption" >&2
        fi

        # Circuit breaker: track failures and exit if too many
        TIME_SINCE_LAST=$((CURRENT_TIME - LAST_FAILURE_TIME))
        if [ "$TIME_SINCE_LAST" -gt "$FAILURE_WINDOW_SECONDS" ]; then
            # Reset counter if it's been a while since last failure
            PERSONAPLEX_FAILURE_COUNT=1
            echo "[CIRCUIT BREAKER] First failure in window, counter reset to 1"
        else
            PERSONAPLEX_FAILURE_COUNT=$((PERSONAPLEX_FAILURE_COUNT + 1))
            echo "[CIRCUIT BREAKER] Failure $PERSONAPLEX_FAILURE_COUNT of $MAX_PERSONAPLEX_FAILURES in ${FAILURE_WINDOW_SECONDS}s window"
        fi
        LAST_FAILURE_TIME=$CURRENT_TIME

        # Exit container if too many failures (let Salad Cloud retry on different hardware)
        if [ "$PERSONAPLEX_FAILURE_COUNT" -ge "$MAX_PERSONAPLEX_FAILURES" ]; then
            echo "FATAL: PersonaPlex crashed $PERSONAPLEX_FAILURE_COUNT times in ${FAILURE_WINDOW_SECONDS}s" >&2
            echo "Last crash reason: $CRASH_REASON" >&2
            echo "Exiting container so orchestration can retry on different hardware." >&2
            exit 1
        fi

        echo "PersonaPlex restarting (attempt $((PERSONAPLEX_FAILURE_COUNT + 1)))..."
        python -m moshi.server --ssl "$SSL_DIR" --port 8999 --cpu-offload >> "$PERSONAPLEX_LOG" 2>&1 &
        PERSONAPLEX_PID=$!
    fi
    if ! kill -0 $MOLTBOT_PID 2>/dev/null; then
        echo "Moltbot died, restarting..."
        $MOLTBOT_BIN gateway --port 18789 &
        MOLTBOT_PID=$!
    fi
    sleep 5
done
