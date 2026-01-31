# Kent's AI Business Partner

> **Voice-controlled AI assistant for trading business management, personal productivity, and VPS administration**

Talk to your AI partner like you'd talk to a colleague. PersonaPlex handles the conversation, Moltbot handles the execution, and WhatsApp keeps you in the loop when decisions are needed.

---

## What This Is

Kent runs a one-man trading business—managing prop firm accounts, MT5 Expert Advisors, Python trading servers, and agentic AI experiments. This system provides an AI partner that:

- **Monitors trading performance** across multiple EAs and prop firm accounts
- **Helps with organization** - structuring data, cleaning up Notion, building maintainable systems
- **Tracks ideas and follow-through** - remembers what Kent wants to do and helps get it done
- **Manages VPS infrastructure** - server health, Docker containers, service management
- **Works while Kent sleeps** - proactively doing useful work and creating PRs for review
- **Creates PRs autonomously** - uses Claude Code and Gemini CLI for self-improvement
- **Scheduled automation** - cron jobs for trading summaries and health monitoring

---

## Quick Start

1. **Deploy to SaladCloud** (see [DEPLOYMENT.md](./DEPLOYMENT.md) for step-by-step guide)
2. **Connect WhatsApp** for notifications
3. **Start talking** - describe what you need

> **New:** Use `/salad deploy v15` in Claude Code to build and deploy in one command!

---

## What Moltbot Helps With

### Trading Business

| Task | How to Ask |
|------|------------|
| Check EA performance | "How are my EAs doing today?" |
| Review prop firm accounts | "Show me account status for all my prop firms" |
| Flag concerning strategies | "Which strategies are underperforming?" |
| Daily performance summary | "Give me a morning trading update" |

### Organization & Productivity

| Task | How to Ask |
|------|------------|
| Capture an idea | "I want to build a dashboard for EA performance" |
| Review pending ideas | "What ideas have I mentioned recently?" |
| Structure scattered data | "Help me organize my strategy notes" |
| Prioritize tasks | "What should I focus on today?" |

### VPS Administration

| Task | How to Ask |
|------|------------|
| Check server health | "How's the server doing?" |
| Monitor containers | "Show me Docker containers" |
| Check disk/memory | "Check disk space and memory" |
| Service management | "Restart the trading server" |

### Data Access

| Service | How It Works | Setup |
|---------|--------------|-------|
| TradesViz | Browser automation (auto-login) | Set `TRADESVIZ_USERNAME` and `TRADESVIZ_PASSWORD` |
| Notion | MCP server (OAuth) | Run `moltbot mcp auth notion` once after deployment |

### Autonomous Development (GitHub PRs)

| Task | How to Ask |
|------|------------|
| Fix a bug | "Fix the timeout bug in my trading server" |
| Self-improvement | "Add [capability] to yourself" |
| Code review | "Review [repo] for security issues" |
| Create PR | "Create a PR to fix [issue]" |

### Scheduled Automation (Cron Jobs)

| Job | Schedule | Description |
|-----|----------|-------------|
| Self-Reflection | Every hour | Reviews actions, generates ideas, updates IDEAS.md |
| Afternoon Summary | 3pm Tbilisi | Trading status, work completed, **top 3 actionable ideas** |
| Health Monitor | Every 4 hours | VPS health, trading alerts if issues found |

---

## New Features

### AI Coding Tools

Moltbot has access to two AI coding assistants for autonomous development:

| Tool | Best For | Command |
|------|----------|---------|
| **Claude Code** | Complex refactoring, multi-file edits, security reviews | `claude --print "..."` |
| **Gemini CLI** | Quick fixes, analysis, commit messages | `gemini -p "..." --yolo` |

### GitHub PR Workflow

Moltbot can create PRs against repos you grant access to:

```
Kent: "Fix the timeout bug in my trading server"
  ↓
Moltbot:
  1. Clones repo (git clone)
  2. Creates branch (moltbot/fix-timeout)
  3. Uses Claude Code to implement fix
  4. Commits and pushes
  5. Creates PR via gh CLI
  6. Notifies Kent via WhatsApp with PR link
  ↓
Kent: Reviews and merges PR
```

**Golden Rules:**
- Never pushes to main - always creates PRs
- Never force pushes - preserves history
- Creates small, focused changes

---

## Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                         Your Voice Command                            │
│                    "Check on my trading EAs"                          │
└───────────────────────────────┬──────────────────────────────────────┘
                                ▼
┌──────────────────────────────────────────────────────────────────────┐
│  🌐 nginx Reverse Proxy (Port 8998) - Single Entry Point             │
│  Routes: /* → PersonaPlex | /api/* → Orchestrator | /health          │
└───────────────────────────────┬──────────────────────────────────────┘
                                ▼
┌──────────────────────────────────────────────────────────────────────┐
│  🎤 PersonaPlex (Internal :8999)                                     │
│  Full-duplex voice AI conversation                                   │
│  • Listens and responds naturally                                    │
│  • Clarifies your intent                                             │
│  • Builds a transcript                                               │
└───────────────────────────────┬──────────────────────────────────────┘
                                │ [Execute] button pressed
                                ▼
┌──────────────────────────────────────────────────────────────────────┐
│  🧠 Orchestrator (Internal :5000)                                    │
│  • LLM extracts actionable tasks                                     │
│  • Safety validation                                                 │
│  • Routes to Moltbot                                                 │
└───────────────────────────────┬──────────────────────────────────────┘
                                ▼
┌──────────────────────────────────────────────────────────────────────┐
│  🤖 Moltbot (Internal :18789)                                        │
│  AI-powered execution                                                │
│  • Executes commands and tasks                                       │
│  • Pauses for clarification via WhatsApp                            │
│  • Remembers preferences                                             │
│  • Creates PRs (doesn't push live)                                   │
└───────────────────────────────┬──────────────────────────────────────┘
                                ▼
┌──────────────────────────────────────────────────────────────────────┐
│  📱 WhatsApp Notification                                            │
│  "Morning summary: 3 EAs profitable, 1 flagged for review..."        │
└──────────────────────────────────────────────────────────────────────┘
```

---

## Moltbot Configuration

The `moltbot/` folder contains the AI's personality, memory, and operating instructions:

| File | Purpose |
|------|---------|
| `SOUL.md` | Personality, tone, core mission |
| `AGENTS.md` | Operating rules and responsibilities |
| `USER.md` | Kent's profile, preferences, challenges |
| `MEMORY.md` | Learned knowledge, trading baselines, repo registry |
| `IDEAS.md` | Hourly idea log, scored for 3pm summary |
| `TOOLS.md` | Tool usage guide, AI coding tools |
| `skills/trading.md` | Trading monitoring, EA evaluation, prop firm rules |
| `skills/github.md` | PR workflow, self-improvement, AI tool usage |
| `skills/vps-admin.md` | VPS health checks, server management |
| `skills/notion.md` | Notion organization, page management |
| `skills/self-reflection.md` | Hourly introspection, idea generation process |

### Key Philosophy

From `SOUL.md`:

> Kent wakes up every morning thinking "wow, you got a lot done while I was sleeping."

The AI is configured to be:
- **Proactive** - Does work without being asked
- **Pragmatic** - Peer-to-peer, not assistant-to-boss
- **Organized** - Helps structure chaos into systems
- **Honest** - Flags problems early, speaks directly

---

## Deployment

### Prerequisites

| Item | Purpose | Where to Get It |
|------|---------|-----------------|
| 🤗 HuggingFace Token | PersonaPlex model access | [huggingface.co/settings/tokens](https://huggingface.co/settings/tokens) |
| 🔑 Anthropic API Key | Command extraction + Claude Code | [console.anthropic.com](https://console.anthropic.com) |
| 📱 WhatsApp Account | Notifications | Personal phone |
| 🥗 SaladCloud Account | GPU hosting | [portal.salad.com](https://portal.salad.com) |
| 🗄️ Supabase Account | Data persistence | [supabase.com](https://supabase.com) |
| 🐙 GitHub Bot Account | Autonomous PRs (optional) | Create dedicated account |
| 🔮 Gemini API Key | Gemini CLI (optional) | [aistudio.google.com/apikey](https://aistudio.google.com/apikey) |

### Step 1: Supabase Setup

```
Supabase Dashboard → Storage → New Bucket
├── Name: moltbot-workspace
└── Public: No (private)

Dashboard → Project Settings → Storage → S3 Access Keys → Generate
```

### Step 2: Build & Deploy

```bash
# Clone and build
git clone https://github.com/yourusername/kent_clawd_personaplex
cd kent_clawd_personaplex

docker buildx use salad-builder 2>/dev/null || docker buildx create --use --name salad-builder
docker buildx build --platform linux/amd64 -t yourusername/personaplex-admin:latest --push .
```

### Step 3: SaladCloud Configuration

| Setting | Value |
|---------|-------|
| **Image** | `yourusername/personaplex-admin:latest` |
| **GPU** | RTX 3090 / 4090 / A5000 (24GB VRAM) |
| **vCPU** | 4+ |
| **RAM** | 8GB+ |
| **Disk** | 100GB |
| **Container Gateway** | Port `8998` |
| **Startup Probe** | HTTP/1.X, Path `/health`, Port `8998` |
| **Liveness Probe** | HTTP/1.X, Path `/health`, Port `8998` |
| **Command** | None (uses Dockerfile default) |

### Step 4: Environment Variables

```
# Required
HF_TOKEN=hf_xxxxxxxxxxxxx
ANTHROPIC_API_KEY=sk-ant-xxxxxxxxxxxxx

# WhatsApp (optional)
WHATSAPP_PHONE=+15551234567
PERSONAPLEX_URL=https://your-domain.salad.cloud

# Supabase Persistence
SUPABASE_S3_ENDPOINT=https://[PROJECT].supabase.co/storage/v1/s3
SUPABASE_S3_ACCESS_KEY=your-access-key
SUPABASE_S3_SECRET_KEY=your-secret-key
SUPABASE_BUCKET=moltbot-workspace

# GitHub PR Capabilities (optional)
GITHUB_TOKEN=ghp_xxxxxxxxxxxxx
GITHUB_BOT_EMAIL=moltbot@yourdomain.com

# AI Coding Tools (optional)
GEMINI_API_KEY=AIzaSyXXXXXXXX
# CLAUDE_SETUP_TOKEN=xxx  # Optional - Claude Code uses ANTHROPIC_API_KEY by default

# Service Integrations (optional)
TRADESVIZ_USERNAME=your-username
TRADESVIZ_PASSWORD=your-password
# Notion - OAuth configured via MCP (no env vars needed)
# Run `moltbot mcp auth notion` after deployment
```

### Step 5: Connect WhatsApp

```bash
moltbot channels login  # Scan QR with phone
moltbot agent --message "Say hello" --deliver --channel whatsapp --to +15551234567
```

### Step 6: Configure Cron Jobs (Optional)

After deployment, add scheduled automation:

```bash
# Hourly self-reflection (generates ideas, updates IDEAS.md)
moltbot cron add \
  --name "Self-Reflection" \
  --cron "0 * * * *" \
  --session isolated \
  --message "Run hourly self-reflection per skills/self-reflection.md: 1) Review recent actions and their alignment with Kent's goals 2) Generate 1-3 actionable ideas to help Kent's trading business 3) Score ideas by impact, effort, urgency, alignment 4) Add ideas to moltbot/IDEAS.md with timestamps. Focus on data-driven, patient growth. No notification needed." \
  --model "sonnet"

# Afternoon summary at 3pm Tbilisi (includes top 3 ideas)
moltbot cron add \
  --name "Afternoon Summary" \
  --cron "0 15 * * *" \
  --session isolated \
  --message "Generate afternoon summary: 1) Trading status across all EAs 2) Work completed since last summary 3) Current priorities. IMPORTANT: Review moltbot/IDEAS.md and include TOP 3 highest-scoring ideas as 'Actionable Ideas' section. Mark included ideas as 'reviewed' in IDEAS.md." \
  --deliver --channel whatsapp --to "+YOURPHONE"

# Health monitor every 4 hours
moltbot cron add \
  --name "Health Monitor" \
  --cron "0 */4 * * *" \
  --session isolated \
  --message "Run health check. Only notify if issues found." \
  --model "sonnet"
```

### Step 7: Setup GitHub Bot (Optional)

For autonomous PR creation:

1. **Create GitHub bot account** (e.g., `moltbot-kent`)
2. **Generate PAT** with `repo` scope
3. **Add bot as collaborator** to repos Moltbot should access
4. **Set environment variables**: `GITHUB_TOKEN`, `GITHUB_BOT_EMAIL`
5. **Update MEMORY.md** with repo registry

---

## API Reference

All API endpoints are accessed via nginx reverse proxy on port 8998.

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check (direct) |
| `/api/process` | POST | Process single voice input |
| `/api/execute` | POST | Execute commands from transcript |
| `/api/execute/background` | POST | Start long-running execution |
| `/api/context/{session_id}` | GET | Get execution state |
| `/api/resume/{session_id}` | POST | Resume with answer |
| `/api/sessions` | GET | List Moltbot sessions |

---

## Project Structure

```
kent_clawd_personaplex/
├── README.md              ← You are here
├── Dockerfile             ← Container build
├── requirements.txt       ← Python dependencies
├── .env.example           ← Environment template
│
├── orchestrator/          ← FastAPI backend
│   ├── main.py           ← API endpoints
│   ├── config.py         ← Settings
│   ├── safety.py         ← Command validation
│   ├── llm.py            ← Task extraction
│   ├── notify.py         ← WhatsApp notifications
│   └── execution.py      ← State management
│
├── moltbot/               ← AI configuration
│   ├── AGENTS.md         ← Operating instructions
│   ├── SOUL.md           ← Personality & mission
│   ├── USER.md           ← Kent's profile
│   ├── MEMORY.md         ← Learned context
│   ├── TOOLS.md          ← Tool usage
│   └── skills/           ← Specialized skills
│
├── nginx/                 ← Reverse proxy config
│   └── nginx.conf        ← Routes traffic to services
│
├── scripts/               ← Startup & utilities
│   ├── start.sh          ← Container entrypoint
│   ├── workspace_sync.sh ← Supabase sync
│   └── build.sh          ← Docker build helper
│
└── tests/                 ← Test suite
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "Moltbot service unavailable" | Check container logs in SaladCloud |
| Health check failing | Verify nginx started, check `/health` endpoint |
| WhatsApp not receiving | Run `moltbot channels login` inside container |
| Voice not working | Check microphone, ensure HTTPS connection |
| Model loading slow | Normal - first load takes 2-5 minutes |
| Workspace not persisting | Verify Supabase credentials |
| API calls failing | Use `/api/` prefix (e.g., `/api/execute`) |

---

## License

MIT License - See LICENSE file for details.

---

<div align="center">

**Built with 🎤 [PersonaPlex](https://github.com/nvidia/personaplex) • 🤖 [Moltbot](https://github.com/moltbot/moltbot) • 🧠 [Claude](https://anthropic.com)**

</div>
