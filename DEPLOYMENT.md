# Deployment Guide

Step-by-step instructions for building and deploying PersonaPlex to Salad Cloud.

---

## Prerequisites

Before you begin, ensure you have:

- [ ] Docker Desktop installed and running
- [ ] Docker Hub account (for pushing images)
- [ ] Salad Cloud account with API key
- [ ] `.env` file configured (see [Environment Setup](#environment-setup))

---

## Environment Setup

Create a `.env` file in the project root with your credentials:

```bash
# Docker Hub
DOCKER_USERNAME=your-dockerhub-username
DOCKER_IMAGE_NAME=personaplex-admin

# Salad Cloud API
SALAD_API_KEY=your-salad-api-key
SALAD_ORG=your-organization-name
SALAD_PROJECT=default
SALAD_CONTAINER_GROUP=your-container-group-name

# Axiom Logging (optional)
AXIOM_API_KEY=your-axiom-api-key
AXIOM_DATASET_NAME=your-dataset-name

# Required for container runtime
HF_TOKEN=hf_xxxxxxxxxxxxx
ANTHROPIC_API_KEY=sk-ant-xxxxxxxxxxxxx
```

### Where to Get Credentials

| Credential | Where to Find It |
|------------|------------------|
| `DOCKER_USERNAME` | Your Docker Hub username |
| `SALAD_API_KEY` | [Salad Portal](https://portal.salad.com) > Profile > API Keys |
| `SALAD_ORG` | [Salad Portal](https://portal.salad.com) > Organization name in URL |
| `SALAD_PROJECT` | Usually `default` unless you created a custom project |
| `SALAD_CONTAINER_GROUP` | Name of your container group in Salad Portal |
| `AXIOM_API_KEY` | [Axiom Dashboard](https://app.axiom.co) > Settings > API Tokens |

---

## Method 1: Using the `/salad` Skill (Recommended)

The `/salad` Claude Code skill provides an automated deployment workflow.

### Deploy a New Version

```
/salad deploy v15
```

This command will:
1. Build the Docker image with version tag `v15`
2. Push to Docker Hub as `{DOCKER_USERNAME}/{DOCKER_IMAGE_NAME}:v15`
3. Verify the image is available in Docker Hub
4. Update the Salad Cloud container group to use the new image
5. Wait for deployment to complete (up to 10 minutes)
6. Report success or failure

**Example output:**
```
=== Building nestedcallbacks/personaplex-admin:v15 ===
Building for SaladCloud (AMD64 architecture)...
Build complete!

=== Verifying image push ===
Image verified in Docker Hub

=== Updating Salad Cloud ===
Update response: {"id":"...", "name":"kent-controller", ...}

=== Waiting for deployment ===
Status: deploying (1/60)
Status: deploying (2/60)
Status: running (3/60)

=== Deployment successful! ===
Version v15 is now running
```

### Check Current Status

```
/salad status
```

Returns the current state of your container group:
```json
{
  "name": "kent-controller",
  "status": "running",
  "image": "nestedcallbacks/personaplex-admin:v14",
  "replicas": 1,
  "pending_change": null
}
```

### View Container Logs

```
/salad logs
```

Or for a specific version:
```
/salad logs v15
```

Queries Axiom for recent logs from your container.

### Stop the Container Group

```
/salad stop
```

Stops the container group (useful before maintenance or to save costs).

---

## Method 2: Manual Deployment

### Step 1: Build the Docker Image

Run the build script from the project root:

```bash
./scripts/build.sh <docker-username> <version-tag>
```

**Example:**
```bash
./scripts/build.sh nestedcallbacks v15
```

This will:
1. Create/use a Docker buildx builder for AMD64 architecture
2. Build the image with the version baked in via `CONTAINER_VERSION` env var
3. Push directly to Docker Hub

**What happens during build:**
```
============================================
Building for SaladCloud (AMD64 architecture)
Image: nestedcallbacks/personaplex-admin:v15
============================================
Building and pushing image...
[+] Building 245.3s (25/25) FINISHED
============================================
Build complete!
Image pushed: nestedcallbacks/personaplex-admin:v15
```

### Step 2: Update Salad Cloud

After the image is pushed, update your container group via the Salad Cloud API:

```bash
source .env

curl -X PATCH \
  "https://api.salad.com/api/public/organizations/${SALAD_ORG}/projects/${SALAD_PROJECT}/containers/${SALAD_CONTAINER_GROUP}" \
  -H "Salad-Api-Key: ${SALAD_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "{\"container\": {\"image\": \"${DOCKER_USERNAME}/${DOCKER_IMAGE_NAME}:v15\"}}"
```

### Step 3: Monitor Deployment

Check the status until it shows `running`:

```bash
source .env

curl -s "https://api.salad.com/api/public/organizations/${SALAD_ORG}/projects/${SALAD_PROJECT}/containers/${SALAD_CONTAINER_GROUP}" \
  -H "Salad-Api-Key: ${SALAD_API_KEY}" | jq '.current_state.status'
```

**Status values:**
| Status | Meaning |
|--------|---------|
| `preparing` | Image being pulled to nodes |
| `deploying` | Container starting up |
| `running` | Container healthy and serving traffic |
| `stopped` | Container group is stopped |
| `failed` | Error state - check logs |

---

## Version Tracking

Each build includes the version tag baked into the container as `CONTAINER_VERSION`. This appears in:

1. **Container logs** at startup:
   ```
   [INFO] Container version: v15
   ```

2. **Axiom queries** (if configured):
   ```
   CONTAINER_VERSION == 'v15'
   ```

This allows you to:
- Filter logs by version
- Identify which version is running in production
- Track deployments over time

---

## Salad Cloud Portal Setup

If you haven't created a container group yet:

### 1. Create Container Group

Go to [Salad Portal](https://portal.salad.com) > Container Groups > Create

### 2. Configure Settings

| Setting | Value |
|---------|-------|
| **Name** | `kent-controller` (or your preferred name) |
| **Image** | `{DOCKER_USERNAME}/personaplex-admin:v15` |
| **GPU** | RTX 3090 / 4090 / A5000 (24GB VRAM recommended) |
| **vCPU** | 4+ |
| **RAM** | 8GB+ |
| **Disk** | 100GB |

### 3. Enable Container Gateway

| Setting | Value |
|---------|-------|
| **Port** | `8998` |
| **Protocol** | HTTP |

### 4. Configure Probes

**Startup Probe:**
- Protocol: HTTP/1.X
- Path: `/health`
- Port: `8998`
- Initial delay: 300s (model download takes time)

**Liveness Probe:**
- Protocol: HTTP/1.X
- Path: `/health`
- Port: `8998`
- Interval: 30s

### 5. Set Environment Variables

Add all required environment variables from your `.env` file in the Salad Portal.

---

## Troubleshooting

### Build Fails

**"Cannot connect to Docker daemon"**
```bash
# Ensure Docker Desktop is running
open -a Docker
```

**"unauthorized: authentication required"**
```bash
# Login to Docker Hub
docker login
```

### Deployment Stuck in "preparing"

The image is being pulled to Salad nodes. Large images (10GB+) can take 5-10 minutes.

### Container Fails Health Check

1. Check startup probe initial delay (should be 300s for model download)
2. Verify environment variables are set correctly
3. Check container logs in Salad Portal

### API Returns 401/403

```bash
# Verify your API key is correct
echo $SALAD_API_KEY

# Test API access
curl -s "https://api.salad.com/api/public/organizations/${SALAD_ORG}/projects" \
  -H "Salad-Api-Key: ${SALAD_API_KEY}" | jq .
```

### Version Not Showing in Logs

Ensure you're using the build script which passes `--build-arg CONTAINER_VERSION`. Manual `docker build` commands won't include the version.

---

## Quick Reference

### Common Commands

```bash
# Build and push new version
./scripts/build.sh nestedcallbacks v15

# Check Salad status
/salad status

# Deploy with skill (builds + updates Salad)
/salad deploy v15

# View logs
/salad logs v15

# Stop container group
/salad stop
```

### API Endpoints

| Action | Endpoint |
|--------|----------|
| Get status | `GET /organizations/{org}/projects/{project}/containers/{group}` |
| Update image | `PATCH /organizations/{org}/projects/{project}/containers/{group}` |
| Start | `POST .../containers/{group}/start` |
| Stop | `POST .../containers/{group}/stop` |

Base URL: `https://api.salad.com/api/public`

---

## See Also

- [Salad Cloud API Docs](https://docs.salad.com/reference/api-usage)
- [Container Groups API](https://docs.salad.com/reference/saladcloud-api/container-groups)
- [Main README](./README.md)
