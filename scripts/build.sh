#!/bin/bash
# Build and push Docker image via GitHub Actions (native AMD64)
# Usage: ./scripts/build.sh [docker-username] [image-tag]
#
# This script triggers a GitHub Actions workflow for native AMD64 builds,
# avoiding slow QEMU emulation on Apple Silicon Macs.

set -e

DOCKER_USER="${1:-nestedcallbacks}"
IMAGE_TAG="${2:-latest}"
IMAGE_NAME="personaplex-admin"
FULL_IMAGE="${DOCKER_USER}/${IMAGE_NAME}:${IMAGE_TAG}"
REPO="kent_clawd_personaplex"

echo "============================================"
echo "Building via GitHub Actions (native AMD64)"
echo "Image: ${FULL_IMAGE}"
echo "============================================"

# Check if gh CLI is authenticated
if ! gh auth status >/dev/null 2>&1; then
    echo "Error: GitHub CLI not authenticated"
    echo "Run: gh auth login"
    exit 1
fi

# Check for required secrets
echo "Checking GitHub secrets..."
SECRETS=$(gh secret list 2>/dev/null || echo "")
MISSING_SECRETS=""

if ! echo "$SECRETS" | grep -q "DOCKER_USERNAME"; then
    MISSING_SECRETS="${MISSING_SECRETS}  - DOCKER_USERNAME\n"
fi
if ! echo "$SECRETS" | grep -q "DOCKER_PASSWORD"; then
    MISSING_SECRETS="${MISSING_SECRETS}  - DOCKER_PASSWORD\n"
fi

if [ -n "$MISSING_SECRETS" ]; then
    echo ""
    echo "Missing required GitHub secrets:"
    echo -e "$MISSING_SECRETS"
    echo "Set them with:"
    echo "  gh secret set DOCKER_USERNAME"
    echo "  gh secret set DOCKER_PASSWORD"
    echo ""
    exit 1
fi

# Commit and push any pending changes first
if ! git diff --quiet HEAD 2>/dev/null; then
    echo ""
    echo "You have uncommitted changes. Commit them first:"
    echo "  git add -A && git commit -m 'your message'"
    echo ""
    exit 1
fi

# Push to ensure GitHub has latest code
echo "Pushing latest code to GitHub..."
git push origin main 2>/dev/null || git push origin HEAD 2>/dev/null || true

# Trigger the workflow
echo "Triggering GitHub Actions build..."
gh workflow run build.yml -f image_tag="${IMAGE_TAG}"

echo ""
echo "Build triggered! Monitor progress:"
echo "  gh run watch"
echo ""
echo "Or view in browser:"
echo "  gh run list --workflow=build.yml"
echo ""

# Wait a moment for the run to be created
sleep 3

# Get the latest run ID and watch it
RUN_ID=$(gh run list --workflow=build.yml --limit 1 --json databaseId -q '.[0].databaseId' 2>/dev/null || echo "")

if [ -n "$RUN_ID" ]; then
    echo "Watching run #${RUN_ID}..."
    echo "(Press Ctrl+C to stop watching - build will continue)"
    echo ""
    gh run watch "$RUN_ID"

    # Check if successful
    STATUS=$(gh run view "$RUN_ID" --json conclusion -q '.conclusion' 2>/dev/null || echo "")
    if [ "$STATUS" = "success" ]; then
        echo ""
        echo "============================================"
        echo "Build complete!"
        echo "Image pushed: ${FULL_IMAGE}"
        echo ""
        echo "Deploy to SaladCloud:"
        echo "  1. Go to https://portal.salad.com"
        echo "  2. Update container image to: ${FULL_IMAGE}"
        echo "============================================"
    fi
else
    echo "Could not find run ID. Check manually:"
    echo "  gh run list --workflow=build.yml"
fi
