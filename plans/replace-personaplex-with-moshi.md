---
name: Replace PersonaPlex with Moshi
overview: Replace NVIDIA PersonaPlex with kyutai-labs/moshi as the voice server. This involves updating the Dockerfile, start scripts, configuration, and all references throughout the codebase while maintaining the same architecture and low-latency voice capabilities.
todos:
  - id: remove-personaplex
    content: Update Dockerfile to use kyutai-labs/moshi instead of nvidia/personaplex
    status: pending
  - id: update-config
    content: Update orchestrator/config.py with MOSHI_VOICE, MOSHI_HF_REPO variables
    status: pending
  - id: update-start-script
    content: Update scripts/start.sh - rename variables and add --hf-repo flag
    status: pending
  - id: update-orchestrator
    content: Update orchestrator/main.py - rename endpoints and simplify prompt logic
    status: pending
  - id: update-nginx
    content: Update nginx/nginx.conf - rename upstream from personaplex to moshi
    status: pending
  - id: update-env
    content: Update .env.example with new variable names
    status: pending
  - id: update-notify
    content: Update orchestrator/notify.py to use MOSHI_URL
    status: pending
  - id: cleanup-scripts
    content: Delete or rename scripts/start_personaplex.sh
    status: pending
  - id: update-docs
    content: Update README.md, DEPLOYMENT.md, and moltbot docs with Moshi references
    status: pending
isProject: false
---

# Replace PersonaPlex with Moshi

## Background

PersonaPlex is NVIDIA's extension of Moshi that adds persona control. The original kyutai-labs/moshi provides the same core full-duplex voice capabilities with:

- Theoretical latency: 160ms (80ms frame size + 80ms acoustic delay)
- Practical latency: ~200ms on L4 GPU
- 24GB VRAM requirement (PyTorch version)

## Key Differences

| Aspect        | PersonaPlex                | Moshi (kyutai-labs)                                            |
| ------------- | -------------------------- | -------------------------------------------------------------- |
| Model         | `nvidia/personaplex-7b-v1` | `kyutai/moshiko-pytorch-bf16` or `kyutai/moshika-pytorch-bf16` |
| Voice Control | `--voice-prompt NATM1.pt`  | `--hf-repo kyutai/moshiko-*` (male) or `moshika-*` (female)    |
| Text Prompt   | `--text-prompt "..."`      | Not supported - Moshi uses fixed personalities                 |
| License       | NVIDIA Open Model          | CC-BY 4.0                                                      |

## Infrastructure Requirements for Low Latency

Current setup is already optimized:

- GPU: RTX 3090/4090/A5000 (24GB VRAM) - required
- `--cpu-offload` flag for memory pressure - keep
- WebSocket streaming via nginx - keep
- Self-signed SSL for internal HTTPS - keep

No infrastructure changes needed - Moshi uses identical server architecture.

## Changes Required

### 1. Dockerfile Updates ([Dockerfile](../Dockerfile))

Replace PersonaPlex clone with Moshi:

```dockerfile
# Before (lines 58-68)
RUN git clone --depth 1 https://github.com/nvidia/personaplex.git /opt/personaplex \
    && cd /opt/personaplex && pip install --no-cache-dir moshi/. \
    && rm -rf /opt/personaplex/.git
WORKDIR /opt/personaplex/client

# After
RUN pip install moshi
# OR for bleeding edge:
RUN pip install -U -e "git+https://git@github.com/kyutai-labs/moshi#egg=moshi&subdirectory=moshi"
```

For the web client, clone and build separately:

```dockerfile
RUN git clone --depth 1 https://github.com/kyutai-labs/moshi.git /opt/moshi \
    && rm -rf /opt/moshi/.git
WORKDIR /opt/moshi/client
RUN npm install && npx vite build && npm cache clean --force
```

### 2. Configuration Updates ([orchestrator/config.py](../orchestrator/config.py))

Replace voice configuration with model selection:

```python
# Before
PERSONAPLEX_VOICE = os.getenv("PERSONAPLEX_VOICE", "NATM1")

# After
MOSHI_VOICE = os.getenv("MOSHI_VOICE", "moshiko")  # "moshiko" (male) or "moshika" (female)
MOSHI_QUANTIZATION = os.getenv("MOSHI_QUANTIZATION", "bf16")  # "bf16" or "q8"
MOSHI_HF_REPO = f"kyutai/{MOSHI_VOICE}-pytorch-{MOSHI_QUANTIZATION}"
```

Rename:

- `PERSONAPLEX_URL` -> `MOSHI_URL`

### 3. Start Script Updates ([scripts/start.sh](../scripts/start.sh))

Update server launch command:

```bash
# Before (line 284)
python -m moshi.server --ssl "$SSL_DIR" --port 8999 --cpu-offload

# After
python -m moshi.server --ssl "$SSL_DIR" --port 8999 --cpu-offload \
    --hf-repo "${MOSHI_HF_REPO:-kyutai/moshiko-pytorch-bf16}"
```

Rename all variables:

- `PERSONAPLEX_PID` -> `MOSHI_PID`
- `PERSONAPLEX_LOG` -> `MOSHI_LOG`
- `PERSONAPLEX_FAILURE_COUNT` -> `MOSHI_FAILURE_COUNT`
- `MAX_PERSONAPLEX_FAILURES` -> `MAX_MOSHI_FAILURES`

### 4. Orchestrator Updates ([orchestrator/main.py](../orchestrator/main.py))

Rename endpoints and update prompts:

```python
# Before
@app.get("/personaplex/prompt")
async def get_personaplex_prompt(...)

# After
@app.get("/moshi/prompt")
async def get_moshi_prompt(...)
```

Note: Moshi doesn't support dynamic text prompts like PersonaPlex. The prompt endpoints may need to be simplified or removed, with context passed differently.

### 5. Environment Variable Updates ([.env.example](../.env.example))

```bash
# Before
HF_TOKEN=  # For nvidia/personaplex-7b-v1
PERSONAPLEX_VOICE=NATM1
PERSONAPLEX_URL=https://your-deployment.salad.cloud

# After
HF_TOKEN=  # For kyutai/moshi models (CC-BY 4.0, may not need acceptance)
MOSHI_VOICE=moshiko  # "moshiko" (male) or "moshika" (female)
MOSHI_QUANTIZATION=bf16  # "bf16" or "q8"
MOSHI_URL=https://your-deployment.salad.cloud
```

### 6. nginx.conf Updates ([nginx/nginx.conf](../nginx/nginx.conf))

Rename upstream:

```nginx
# Before
upstream personaplex {
    server 127.0.0.1:8999;
}

# After
upstream moshi {
    server 127.0.0.1:8999;
}
```

Update proxy_pass accordingly.

### 7. Documentation Updates

Files to update:

- [README.md](../README.md) - Replace all PersonaPlex references
- [DEPLOYMENT.md](../DEPLOYMENT.md) - Update deployment instructions
- [moltbot/MEMORY.md](../moltbot/MEMORY.md) - Update service references
- [moltbot/TOOLS.md](../moltbot/TOOLS.md) - Update self-reference

### 8. Script Renaming

- `scripts/start_personaplex.sh` -> `scripts/start_moshi.sh` (or delete if unused)

### 9. Remove PersonaPlex-Specific Features

The dynamic prompt endpoints (`/personaplex/prompt`, `/personaplex/prompt/question`) leverage PersonaPlex's text-prompt feature. Since Moshi doesn't support this:

Option A: Remove these endpoints (simpler)
Option B: Keep them for potential future use but mark as no-op

## Files to Modify

| File                           | Changes                                                         |
| ------------------------------ | --------------------------------------------------------------- |
| `Dockerfile`                   | Replace PersonaPlex clone with Moshi pip install + client build |
| `scripts/start.sh`             | Rename variables, update server command with `--hf-repo`        |
| `scripts/start_personaplex.sh` | Delete or rename                                                |
| `orchestrator/config.py`       | Replace voice config with model selection                       |
| `orchestrator/main.py`         | Rename endpoints, update/simplify prompt logic                  |
| `orchestrator/notify.py`       | Update URL variable reference                                   |
| `nginx/nginx.conf`             | Rename upstream                                                 |
| `.env.example`                 | Update variable names and docs                                  |
| `README.md`                    | Full documentation update                                       |
| `DEPLOYMENT.md`                | Update deployment instructions                                  |
| `moltbot/MEMORY.md`            | Update service references                                       |
| `moltbot/TOOLS.md`             | Update repo references                                          |
| `plans/*.md`                   | Update any PersonaPlex references                               |
| `scripts/build.sh`             | Optionally rename image                                         |

## Testing Checklist

- [ ] Voice server starts on port 8999
- [ ] WebSocket connection works from browser
- [ ] nginx proxy routes correctly
- [ ] Orchestrator health check passes
- [ ] WhatsApp notification links work with new URL variable
- [ ] Voice quality and latency acceptable
