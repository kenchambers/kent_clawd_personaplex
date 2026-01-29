#!/bin/bash
# Workspace sync to Supabase Storage (S3-compatible)
# Syncs Moltbot workspace to/from Supabase for persistence across SaladCloud node reallocations

set -e

WORKSPACE="${MOLTBOT_WORKSPACE:-$HOME/clawd}"
BUCKET="${SUPABASE_BUCKET:-moltbot-workspace}"
SYNC_INTERVAL="${SYNC_INTERVAL:-300}"  # 5 minutes default

# Supabase Storage S3 endpoint format:
# https://<project-ref>.supabase.co/storage/v1/s3
S3_ENDPOINT="${SUPABASE_S3_ENDPOINT}"
S3_ACCESS_KEY="${SUPABASE_S3_ACCESS_KEY}"
S3_SECRET_KEY="${SUPABASE_S3_SECRET_KEY}"

# Check required env vars
if [ -z "$S3_ENDPOINT" ] || [ -z "$S3_ACCESS_KEY" ] || [ -z "$S3_SECRET_KEY" ]; then
    echo "WARNING: Supabase S3 credentials not set. Workspace sync disabled."
    echo "Set SUPABASE_S3_ENDPOINT, SUPABASE_S3_ACCESS_KEY, SUPABASE_S3_SECRET_KEY"
    exit 0
fi

# Configure rclone for Supabase S3
configure_rclone() {
    mkdir -p ~/.config/rclone
    cat > ~/.config/rclone/rclone.conf << EOF
[supabase]
type = s3
provider = Other
endpoint = ${S3_ENDPOINT}
access_key_id = ${S3_ACCESS_KEY}
secret_access_key = ${S3_SECRET_KEY}
acl = private
EOF
    echo "Rclone configured for Supabase Storage"
}

# Download workspace from Supabase (run on startup)
restore_workspace() {
    echo "Restoring workspace from Supabase..."

    # Create workspace directory
    mkdir -p "$WORKSPACE"
    mkdir -p "$WORKSPACE/memory"
    mkdir -p "$WORKSPACE/skills"

    # Sync from Supabase (won't fail if bucket is empty)
    if rclone lsd "supabase:${BUCKET}" 2>/dev/null; then
        rclone sync "supabase:${BUCKET}/" "$WORKSPACE/" --verbose
        echo "Workspace restored from Supabase"
    else
        echo "No existing backup found, starting fresh"
    fi
}

# Upload workspace to Supabase
backup_workspace() {
    echo "Backing up workspace to Supabase..."
    rclone sync "$WORKSPACE/" "supabase:${BUCKET}/" \
        --exclude "*.tmp" \
        --exclude "__pycache__/**" \
        --verbose
    echo "Workspace backed up at $(date)"
}

# Continuous sync loop (run in background)
sync_loop() {
    echo "Starting continuous sync every ${SYNC_INTERVAL}s..."
    while true; do
        sleep "$SYNC_INTERVAL"
        backup_workspace || echo "Backup failed, will retry..."
    done
}

# Main
case "${1:-}" in
    configure)
        configure_rclone
        ;;
    restore)
        configure_rclone
        restore_workspace
        ;;
    backup)
        configure_rclone
        backup_workspace
        ;;
    loop)
        configure_rclone
        sync_loop
        ;;
    *)
        echo "Usage: $0 {configure|restore|backup|loop}"
        echo ""
        echo "Commands:"
        echo "  configure - Setup rclone for Supabase"
        echo "  restore   - Download workspace from Supabase (run on startup)"
        echo "  backup    - Upload workspace to Supabase (run manually or on shutdown)"
        echo "  loop      - Continuous backup every SYNC_INTERVAL seconds"
        exit 1
        ;;
esac
