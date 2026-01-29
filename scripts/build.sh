#!/bin/bash
# Build and push Docker image for SaladCloud (AMD64 architecture)
# Usage: ./scripts/build.sh [docker-username] [image-tag]

set -e

DOCKER_USER="${1:-yourusername}"
IMAGE_TAG="${2:-latest}"
IMAGE_NAME="personaplex-admin"
FULL_IMAGE="${DOCKER_USER}/${IMAGE_NAME}:${IMAGE_TAG}"

echo "============================================"
echo "Building for SaladCloud (AMD64 architecture)"
echo "Image: ${FULL_IMAGE}"
echo "============================================"

# Check if buildx builder exists, create if not
if ! docker buildx inspect salad-builder >/dev/null 2>&1; then
    echo "Creating multi-platform builder..."
    docker buildx create --driver-opt network=host --use --name salad-builder
fi

# Use the builder
docker buildx use salad-builder

# Build and push for AMD64
echo "Building and pushing image..."
docker buildx build \
    --platform linux/amd64 \
    -t "${FULL_IMAGE}" \
    --push \
    .

echo "============================================"
echo "Build complete!"
echo "Image pushed: ${FULL_IMAGE}"
echo ""
echo "Next steps:"
echo "1. Go to https://portal.salad.com"
echo "2. Create a new Container Group"
echo "3. Set Image Source to: ${FULL_IMAGE}"
echo "4. Configure environment variables:"
echo "   - HF_TOKEN (required)"
echo "   - ANTHROPIC_API_KEY (required)"
echo "5. Select GPU (RTX 3080+ recommended)"
echo "6. Enable Container Gateway for ports 5000 and 8998"
echo "============================================"
