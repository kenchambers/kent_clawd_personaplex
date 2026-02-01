# Plan: Salad Cloud Deployment Skills (Revised)

**Status:** READY TO IMPLEMENT
**Revised:** 2026-01-30
**Previous Issues:** All critical issues from review have been addressed

---

## Overview

Create a unified `/salad` Claude Code skill for managing Salad Cloud deployments with bash/curl (matching codebase patterns).

**Key changes from original plan:**
- Single skill with subcommands instead of two separate skills
- Bash/curl instead of Python scripts
- Fixed version pipeline (ARG/ENV chain)
- Documented Salad Cloud API with working curl examples

---

## Salad Cloud API Documentation

### Base URL
```
https://api.salad.com/api/public
```

### Authentication
- **Header:** `Salad-Api-Key: <your-api-key>`
- **Obtain from:** [Salad Portal](https://portal.salad.com) > Profile > API Keys
- **Rate limit:** 240 requests/minute

### Container Group Endpoints

#### Get Container Group
```bash
curl -X GET \
  "https://api.salad.com/api/public/organizations/${SALAD_ORG}/projects/${SALAD_PROJECT}/containers/${SALAD_CONTAINER_GROUP}" \
  -H "Salad-Api-Key: ${SALAD_API_KEY}" \
  -H "Accept: application/json"
```

**Response fields:** `id`, `name`, `display_name`, `container.image`, `current_state.status`, `replicas`, `pending_change`

#### Update Container Group (Image)
```bash
curl -X PATCH \
  "https://api.salad.com/api/public/organizations/${SALAD_ORG}/projects/${SALAD_PROJECT}/containers/${SALAD_CONTAINER_GROUP}" \
  -H "Salad-Api-Key: ${SALAD_API_KEY}" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d "{\"container\": {\"image\": \"${DOCKER_USERNAME}/${DOCKER_IMAGE_NAME}:${VERSION}\"}}"
```

**Note:** When image changes, Salad automatically pulls new image and restarts replicas.

#### Start Container Group
```bash
curl -X POST \
  "https://api.salad.com/api/public/organizations/${SALAD_ORG}/projects/${SALAD_PROJECT}/containers/${SALAD_CONTAINER_GROUP}/start" \
  -H "Salad-Api-Key: ${SALAD_API_KEY}"
```

#### Stop Container Group
```bash
curl -X POST \
  "https://api.salad.com/api/public/organizations/${SALAD_ORG}/projects/${SALAD_PROJECT}/containers/${SALAD_CONTAINER_GROUP}/stop" \
  -H "Salad-Api-Key: ${SALAD_API_KEY}"
```

### Status Values
- `preparing` - Image being pulled
- `stopped` - Not running
- `deploying` - Starting up
- `running` - Healthy
- `failed` - Error state

---

## File Changes Required

### 1. Dockerfile - Add Version Tracking

**Location:** Line 5 (after TZ env var)

```dockerfile
# Container version tracking (passed from build.sh via --build-arg)
ARG CONTAINER_VERSION=unknown
ENV CONTAINER_VERSION=${CONTAINER_VERSION}
```

**Full context (lines 1-7):**
```dockerfile
FROM --platform=linux/amd64 nvidia/cuda:12.4.1-runtime-ubuntu22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Tbilisi

# Container version tracking (passed from build.sh via --build-arg)
ARG CONTAINER_VERSION=unknown
ENV CONTAINER_VERSION=${CONTAINER_VERSION}
```

### 2. scripts/build.sh - Pass Version to Docker

**Change:** Add `--build-arg` flag to docker buildx command (lines 28-32)

**Before:**
```bash
docker buildx build \
    --platform linux/amd64 \
    -t "${FULL_IMAGE}" \
    --push \
    .
```

**After:**
```bash
docker buildx build \
    --platform linux/amd64 \
    --build-arg CONTAINER_VERSION="${IMAGE_TAG}" \
    -t "${FULL_IMAGE}" \
    --push \
    .
```

### 3. scripts/start.sh - Log Version at Startup

**Location:** After line 268 (after "All services started")

**Add:**
```bash
# Log container version for Axiom tracking
echo "[INFO] Container version: ${CONTAINER_VERSION:-unknown}" >&2
```

---

## Skill Implementation

### Location
```
~/.claude/skills/salad/SKILL.md
```

### SKILL.md Content

```markdown
---
name: salad
description: Manage Salad Cloud container deployments - deploy, status, logs
argument-hint: <command> [args] (deploy v14, status, logs v14, stop)
---

# Salad Cloud Deployment Skill

Manage the PersonaPlex container deployment on Salad Cloud.

## Commands

### Deploy New Version
```
/salad deploy <version>
```

Example: `/salad deploy v14`

**Workflow:**
1. Build Docker image with version tag
2. Push to Docker Hub
3. Verify image is available
4. Update Salad Cloud container group
5. Wait for deployment to complete
6. Report status

### Check Status
```
/salad status
```

Shows current container group state, image version, and replica count.

### Query Logs
```
/salad logs [version]
```

Query Axiom logs for the specified version (or current if omitted).

### Stop Deployment
```
/salad stop
```

Stop the container group (use before maintenance).

---

## Environment Variables

Required in project `.env`:
- `SALAD_API_KEY` - From Salad Portal > Profile > API Keys
- `SALAD_ORG` - Organization name (chambers-arithmos)
- `SALAD_PROJECT` - Project name (default)
- `SALAD_CONTAINER_GROUP` - Container group name (kent-controller)
- `DOCKER_USERNAME` - Docker Hub username (nestedcallbacks)
- `DOCKER_IMAGE_NAME` - Image name (personaplex-admin)
- `AXIOM_API_KEY` - For log queries
- `AXIOM_DATASET_NAME` - Dataset name (kent-clawd-salad-cloud-logs)

---

## Implementation Details

### Deploy Command

```bash
#!/bin/bash
set -e

VERSION="${1:?Usage: /salad deploy <version>}"
source .env

FULL_IMAGE="${DOCKER_USERNAME}/${DOCKER_IMAGE_NAME}:${VERSION}"
SALAD_API="https://api.salad.com/api/public/organizations/${SALAD_ORG}/projects/${SALAD_PROJECT}/containers/${SALAD_CONTAINER_GROUP}"

echo "=== Building ${FULL_IMAGE} ==="
./scripts/build.sh "${DOCKER_USERNAME}" "${VERSION}"

echo "=== Verifying image push ==="
for i in {1..6}; do
    if docker pull "${FULL_IMAGE}" >/dev/null 2>&1; then
        echo "Image verified in Docker Hub"
        break
    fi
    echo "Waiting for image to be available... (attempt $i/6)"
    sleep 10
done

echo "=== Updating Salad Cloud ==="
RESPONSE=$(curl -sf -X PATCH "${SALAD_API}" \
    -H "Salad-Api-Key: ${SALAD_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "{\"container\": {\"image\": \"${FULL_IMAGE}\"}}")

echo "Update response: ${RESPONSE}"

echo "=== Waiting for deployment ==="
for i in {1..60}; do
    STATUS=$(curl -sf "${SALAD_API}" \
        -H "Salad-Api-Key: ${SALAD_API_KEY}" | jq -r '.current_state.status // "unknown"')

    echo "Status: ${STATUS} (${i}/60)"

    if [ "${STATUS}" = "running" ]; then
        echo "=== Deployment successful! ==="
        echo "Version ${VERSION} is now running"
        exit 0
    fi

    if [ "${STATUS}" = "failed" ]; then
        echo "ERROR: Deployment failed"
        exit 1
    fi

    sleep 10
done

echo "WARNING: Deployment still in progress after 10 minutes"
echo "Check Salad Portal for status"
```

### Status Command

```bash
#!/bin/bash
source .env

SALAD_API="https://api.salad.com/api/public/organizations/${SALAD_ORG}/projects/${SALAD_PROJECT}/containers/${SALAD_CONTAINER_GROUP}"

RESPONSE=$(curl -sf "${SALAD_API}" \
    -H "Salad-Api-Key: ${SALAD_API_KEY}" \
    -H "Accept: application/json")

echo "=== Salad Cloud Status ==="
echo "${RESPONSE}" | jq '{
    name: .name,
    status: .current_state.status,
    image: .container.image,
    replicas: .replicas,
    pending_change: .pending_change
}'
```

### Logs Command

```bash
#!/bin/bash
source .env

VERSION="${1:-}"

# Build Axiom query
if [ -n "${VERSION}" ]; then
    QUERY="CONTAINER_VERSION == '${VERSION}'"
else
    QUERY=""
fi

# Query Axiom API
# Query Salad Cloud native logs API (not Axiom)
curl -s -X POST "https://api.salad.com/api/public/organizations/${SALAD_ORG}/log-entries" \
    -H "Salad-Api-Key: ${SALAD_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "{
        \"start_time\": \"$(date -u -v-1H +%Y-%m-%dT%H:%M:%SZ)\",
        \"end_time\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
        \"query\": \"${QUERY}\",
        \"page_size\": 100,
        \"sort_order\": \"desc\"
    }" | jq -r '.items[] | "\(.time) [\(.severity)] \(.json_log.message // .text_log // "no message")"'
```

---

## Files to Create

| File | Purpose |
|------|---------|
| `~/.claude/skills/salad/SKILL.md` | Unified deployment skill |

## Files to Modify

| File | Change |
|------|--------|
| `Dockerfile` | Add ARG/ENV for CONTAINER_VERSION (line 6-7) |
| `scripts/build.sh` | Add --build-arg CONTAINER_VERSION (line 29) |
| `scripts/start.sh` | Add version logging (after line 268) |

---

## Implementation Checklist

- [ ] Modify Dockerfile to accept CONTAINER_VERSION build arg
- [ ] Modify build.sh to pass --build-arg CONTAINER_VERSION
- [ ] Modify start.sh to log CONTAINER_VERSION at startup
- [ ] Create ~/.claude/skills/salad/SKILL.md
- [ ] Test deploy command with v14
- [ ] Verify version appears in Axiom logs

---

## Usage Examples

### Deploy new version
```
/salad deploy v14
```

### Check deployment status
```
/salad status
```

### View recent logs
```
/salad logs
```

### View logs for specific version
```
/salad logs v14
```

### Stop deployment
```
/salad stop
```

---

## Sources

- [Salad Cloud API Usage](https://docs.salad.com/reference/api-usage)
- [Container Groups API](https://docs.salad.com/reference/saladcloud-api/container-groups/list-container-groups)
- [Quickstart API Tutorial](https://docs.salad.com/container-engine/tutorials/quickstart-api)
- [SCE Deploy GitHub Action](https://github.com/SaladTechnologies/sce-deploy)
