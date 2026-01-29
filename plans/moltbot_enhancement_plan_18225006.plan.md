---
name: Moltbot Enhancement Plan (Revised)
overview: Simplified enhancement with 2 skills, 2 cron jobs, Tbilisi timezone, GitHub PR capabilities, Claude Code + Gemini CLI for autonomous development.
todos:
  - id: update-dockerfile
    content: Update Dockerfile with timezone, Claude Code CLI, and Gemini CLI
    status: pending
  - id: update-start-sh
    content: Update start.sh with GitHub and AI tool authentication
    status: pending
  - id: update-moltbot-json
    content: Update moltbot.json with cron configuration (keep headless true)
    status: pending
  - id: create-trading-skill
    content: Create moltbot/skills/trading.md (consolidated skill)
    status: pending
  - id: create-github-skill
    content: Create moltbot/skills/github.md for PR workflow with AI tools
    status: pending
  - id: update-memory-md
    content: Update MEMORY.md with trading baselines, prop firm rules, and repo registry
    status: pending
  - id: update-tools-md
    content: Update TOOLS.md with cron, GitHub, and AI coding tool documentation
    status: pending
  - id: setup-github-bot-account
    content: Create dedicated GitHub account for Moltbot with gh CLI auth
    status: pending
isProject: false
---

# Moltbot Enhancement Plan (Revised)

Based on code review feedback, this plan is **simplified** from the original:
- **5 skills → 2 skills** (`trading.md` + `github.md`)
- **4 cron jobs → 2 cron jobs** (afternoon summary + health monitor)
- **Timezone: Asia/Tbilisi** (3pm summary = your morning)
- **Keep `headless: true`** (works in containers)
- **GitHub PR capabilities** (create PRs, self-improvement)
- **AI Coding Tools** (Claude Code CLI + Gemini CLI for autonomous development)
- **Future capabilities documented** (not overloading context now)

## Goals Alignment (from SOUL.md)

This plan directly supports Kent's stated goals:
1. **"Wow, you got a lot done while I was sleeping"** → Afternoon summary at 3pm Tbilisi
2. **Monitor trading business** → Trading skill with baselines
3. **Help identify which strategies to promote or kill** → Performance comparison guidance
4. **Be proactive about potential issues** → Health monitoring + alerts

## Phase 1: Infrastructure Updates

### 1.1 Update Dockerfile

**File:** `Dockerfile`

#### Timezone (line 5)

Change:
```dockerfile
ENV TZ=UTC
```

To:
```dockerfile
ENV TZ=Asia/Tbilisi
```

#### Install AI Coding Tools (after line 28, after Moltbot install)

Add Claude Code CLI and Gemini CLI:

```dockerfile
# Install AI coding assistants for autonomous development
RUN npm install -g @anthropic-ai/claude-code @google/gemini-cli && npm cache clean --force
```

#### Full Dockerfile Changes Summary

```dockerfile
# Line 5: Change timezone
ENV TZ=Asia/Tbilisi

# After line 28 (after Moltbot install), add:
# Install AI coding assistants for autonomous development
RUN npm install -g @anthropic-ai/claude-code @google/gemini-cli && npm cache clean --force
```

This gives Moltbot access to:
- **Claude Code CLI** (`claude`) - Anthropic's AI coding assistant
- **Gemini CLI** (`gemini`) - Google's AI coding assistant

Both can be run in headless mode for automated development work.

### 1.2 Update moltbot.json

**File:** `moltbot/moltbot.json`

```json
{
  "tools": {
    "profile": "full"
  },
  "browser": {
    "enabled": true,
    "headless": true,
    "noSandbox": true,
    "executablePath": "/usr/bin/chromium-browser"
  },
  "channels": {
    "whatsapp": {
      "dmPolicy": "allowlist",
      "allowFrom": []
    }
  },
  "cron": {
    "enabled": true
  }
}
```

**Key decisions:**
- `headless: true` - Required for containerized deployment (no display server)
- `cron.enabled: true` - Enable scheduled automation
- **NOT adding** subagent config (infrastructure doesn't exist yet)
- **NOT adding** thinking defaults (framework-level setting)

### 1.3 GitHub Bot Account Setup

Per [Moltbot FAQ](https://docs.molt.bot/help/faq#should-my-bot-have-its-own-email-github-account-or-phone-number), a dedicated bot account provides:
- **Clear audit trail** - Know which changes were bot-generated
- **Isolated permissions** - Bot can't accidentally use your personal credentials
- **Transparency** - Collaborators can identify bot contributions

#### One-Time Setup Steps

1. **Create dedicated GitHub account** (e.g., `moltbot-kent` or `kent-trading-bot`)
   - Use a dedicated email (e.g., `moltbot@yourdomain.com` or a Gmail alias)
   - Enable 2FA for security

2. **Generate Personal Access Token (PAT)**
   - Go to: Settings → Developer settings → Personal access tokens → Fine-grained tokens
   - Create token with these permissions:
     - `repo` - Full control of private repositories
     - `workflow` - Update GitHub Action workflows (if needed)
   - Set expiration (90 days recommended, rotate periodically)

3. **Add bot as collaborator to repos**
   - For each repo Moltbot should access:
     - Go to repo → Settings → Collaborators
     - Add the bot account with "Write" or "Maintain" role

4. **Configure tools in container**

   Add to `scripts/start.sh` (after line 76):
   ```bash
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
   ```

5. **Add environment variables to SaladCloud**
   ```bash
   # GitHub
   GITHUB_TOKEN=ghp_xxxxxxxxxxxx
   GITHUB_BOT_EMAIL=moltbot@yourdomain.com

   # Claude Code (uses existing ANTHROPIC_API_KEY, or setup token)
   # CLAUDE_SETUP_TOKEN=xxx  # Optional, if using Claude subscription

   # Gemini CLI
   GEMINI_API_KEY=AIzaSyXXXXXXXX
   ```

#### Repos Moltbot Should Access

Track in MEMORY.md (see Phase 3):

| Repo | Purpose | Access Level |
|------|---------|--------------|
| `kent_clawd_personaplex` | **Self-improvement** - Moltbot's own code, propose capability expansions | Write |
| `[trading-server-repo]` | Trading algo servers - bug fixes, improvements | Write |
| `[ea-repo]` | Expert Advisor code - optimizations, analysis | Write |

## Phase 2: Create Skills

### 2.1 Create `moltbot/skills/trading.md`

### 2.1 Create `moltbot/skills/trading.md`

This **single consolidated skill** replaces the proposed 5 separate skills:

```markdown
# Trading Business Skill

## Purpose

Comprehensive support for Kent's prop firm trading business. Covers EA monitoring, performance analysis, TradesViz data extraction, and strategic decision-making.

## Core Capabilities

### 1. Performance Monitoring

Track and compare EA performance against baselines stored in MEMORY.md.

**Key Metrics:**
- Win rate (compare to baseline)
- Daily/total drawdown (compare to prop firm limits)
- Consecutive losses (alert threshold: 3+)
- Profit factor

**Alert Thresholds:**
- Approaching prop firm limit (80% of max): WARN
- Exceeding prop firm limit: CRITICAL ALERT
- Win rate 10%+ below baseline: WARN
- 3+ consecutive losses on any EA: WARN

### 2. TradesViz Integration

Navigate TradesViz to extract trading performance data.

**Capabilities:**
- Dashboard summary extraction
- Trade history export
- Performance chart screenshots
- Journal entry reading

**When TradesViz Unavailable:**
1. Detect login page or timeout (10 second limit)
2. Fall back to cached data if <6 hours old
3. Notify Kent: "TradesViz unavailable, using cached data from [time]"
4. If no cache: "TradesViz unavailable, manual check needed"

### 3. Strategy Evaluation

Help Kent decide which EAs to promote or retire.

**Decision Framework:**
1. Is win rate acceptable for this strategy type?
2. Is drawdown within prop firm limits?
3. Is recent performance consistent with backtest?
4. What's the trend? (improving/declining/stable)

**Output Format:**
- Traffic light status (green/yellow/red)
- Key metrics in bullet points
- Clear recommendation with reasoning

### 4. Prop Firm Rules

Each prop firm has different rules. Check MEMORY.md for per-account limits.

**Common Limits to Track:**
- Max daily drawdown (varies by firm: 3-5%)
- Max total drawdown (varies by firm: 8-12%)
- Minimum trading days
- Profit targets for payouts

## Response Format

Keep it concise for WhatsApp:
- Lead with status emoji
- Bullet points, not prose
- Specific numbers with comparison to limits
- Clear next action if needed

## Future Capabilities (Not Active Yet)

These capabilities are documented for future activation when Kent is ready:

### Trading Mentor Mode
- Analyze losing trades to identify patterns
- Suggest learning resources based on weaknesses
- Track improvement over time
- Celebrate milestones

### TradesViz Configuration Helper
- Guide Kent through optimal dashboard setup
- Suggest useful reports and alerts
- Help configure journal templates
```

### 2.2 Create `moltbot/skills/github.md`

GitHub PR workflow skill for autonomous code contributions:

```markdown
# GitHub Development Skill

## Purpose

Create pull requests against Kent's repositories. Moltbot can propose improvements, fix bugs, and expand its own capabilities—all through PRs that Kent reviews before merging.

## Core Principles

From SOUL.md:
> "Just create PRs for me to review, don't push anything live. I'll test and commit"

**Golden Rules:**
1. **Never push to main/master** - Always create branches and PRs
2. **Never force push** - Preserve history
3. **Clear PR descriptions** - Explain what and why
4. **Small, focused changes** - One concern per PR

## Accessible Repositories

Check MEMORY.md for the current repo registry. Each repo has a defined purpose:

- **Self-improvement repos** - Moltbot can propose enhancements to its own code
- **Trading repos** - Bug fixes, optimizations, analysis tools
- **Infrastructure repos** - Deployment, monitoring improvements

## PR Workflow

### 1. Before Making Changes

```bash
# Ensure we're on latest main
cd /path/to/repo
git fetch origin
git checkout main
git pull origin main

# Create feature branch
git checkout -b moltbot/[descriptive-name]
```

### 2. Making Changes with AI Coding Tools

Moltbot can use **Claude Code** or **Gemini CLI** to implement changes:

#### Option A: Claude Code (Recommended for complex changes)
```bash
cd /path/to/repo

# Let Claude Code implement the fix
claude --print "Fix the bug in main.py where the API timeout isn't handled properly. Create proper error handling with retry logic."

# Or for broader work
claude --print "Review this codebase and fix any security vulnerabilities you find"
```

#### Option B: Gemini CLI (Good for quick fixes)
```bash
cd /path/to/repo

# Headless mode with auto-approve for safe operations
gemini -p "Fix the type error in utils.py" --yolo

# Get structured output for verification
gemini -p "Add input validation to the create_order function" --output-format json
```

#### Option C: Combined Approach
```bash
# Use Gemini for analysis
gemini -p "Analyze this codebase and list the top 5 bugs" --output-format json > analysis.json

# Use Claude for implementation
claude --print "Fix the bugs identified in analysis.json"
```

### 3. Choosing the Right Tool

| Task | Best Tool | Why |
|------|-----------|-----|
| Complex refactoring | Claude Code | Better context handling |
| Quick bug fixes | Gemini CLI | Faster, `--yolo` mode |
| Code review | Either | Both work well |
| Large codebase changes | Claude Code | Handles many files better |
| Generate commit messages | Gemini CLI | Fast, JSON output |

### 4. Creating the PR

```bash
# Stage and commit
git add -A
git commit -m "feat: [clear description]

[Longer explanation if needed]

🤖 Generated by Moltbot"

# Push branch
git push -u origin moltbot/[branch-name]

# Create PR
gh pr create \
  --title "[type]: [description]" \
  --body "## Summary
- [bullet points of changes]

## Motivation
[why this change helps Kent's trading business]

## Testing
[how to verify this works]

🤖 Generated by Moltbot" \
  --base main
```

### 4. Notify Kent

After creating PR, send WhatsApp notification:
```
New PR ready for review:
[repo]: [title]
[link]

Changes: [1-2 sentence summary]
```

## Self-Improvement Mode

For `kent_clawd_personaplex` (this repo), Moltbot can:

1. **Propose capability expansions** - New skills, enhanced monitoring
2. **Fix issues discovered** - Bugs found during operation
3. **Update documentation** - Keep MEMORY.md, TOOLS.md current
4. **Optimize configurations** - Improve cron schedules, alerts

**Trigger:** "Improve yourself" or "Add [capability] to your skills"

## Trading Server PRs

For trading repos, Moltbot can:

1. **Fix bugs** - Issues discovered in logs or monitoring
2. **Add logging** - Better observability
3. **Optimize performance** - Identified bottlenecks
4. **Update dependencies** - Security patches

**Trigger:** "Fix the issue in [repo]" or "Improve [repo]"

## Safety Checks

Before any PR:
- [ ] Changes are on a branch, not main
- [ ] Commit message is clear
- [ ] PR description explains the change
- [ ] No secrets/credentials in code
- [ ] Changes are minimal and focused
```

## Phase 3: Initialize MEMORY.md Baselines

### 3.1 Update `moltbot/MEMORY.md`

Add these sections to the existing file:

```markdown
## Trading Baselines

_(Update these as you establish actual performance data)_

### EA Performance Baselines

| EA Name | Account | Prop Firm | Baseline Win Rate | Baseline Profit Factor | Notes |
|---------|---------|-----------|-------------------|------------------------|-------|
| [EA1] | [Account] | [Firm] | TBD | TBD | Add after 50+ trades |
| [EA2] | [Account] | [Firm] | TBD | TBD | Add after 50+ trades |

### Prop Firm Rules

| Firm | Max Daily DD | Max Total DD | Min Trading Days | Profit Target | Notes |
|------|--------------|--------------|------------------|---------------|-------|
| FTMO | 5% | 10% | 4 | 10% | Challenge phase |
| FundedNext | 3% | 6% | 5 | 8% | Express model |
| TopStep | 4.5% | varies | 5 | varies | Futures |

_(Add your actual accounts and firms here)_

### Alert Configuration

- Win rate drop threshold: 10% below baseline
- Consecutive losses alert: 3
- Drawdown warning: 80% of firm limit
- Drawdown critical: 90% of firm limit

### TradesViz Cache

- Last successful fetch: [timestamp]
- Cache validity: 6 hours
- Session status: [active/expired]

## Browser Sessions

- GitHub: Logged in (session in clawd profile)
- Notion: Logged in (session in clawd profile)
- TradesViz: Logged in (session in clawd profile)

Last verified: [date]

## GitHub Repository Registry

Repos Moltbot has write access to. Update this list as repos are added.

### Self-Improvement (Moltbot's Own Code)

| Repo | Local Path | Purpose | Notes |
|------|------------|---------|-------|
| `kennethchambers/kent_clawd_personaplex` | `/app` | Moltbot deployment, skills, config | Can propose capability expansions |

### Trading Infrastructure

| Repo | Local Path | Purpose | Notes |
|------|------------|---------|-------|
| `[your-trading-server]` | TBD | Python trading algos | Add after granting access |
| `[your-ea-repo]` | TBD | MT5 Expert Advisors | Add after granting access |

### Other Projects

| Repo | Local Path | Purpose | Notes |
|------|------------|---------|-------|
| _(Add repos as you grant access)_ | | | |

## Pending PRs

Track PRs Moltbot has created that are awaiting review:

| Repo | PR # | Title | Created | Status |
|------|------|-------|---------|--------|
| _(Moltbot will update this)_ | | | | |
```

## Phase 4: Cron Job Setup

After deployment, run these commands:

### 4.1 Afternoon Summary (3pm Tbilisi = Your Morning)

```bash
moltbot cron add \
  --name "Afternoon Summary" \
  --cron "0 15 * * *" \
  --session isolated \
  --message "Generate afternoon summary using trading skill: overnight trading status (P/L, alerts), any work completed, pending decisions needing my input, suggested priorities. Keep it concise for WhatsApp." \
  --deliver \
  --channel whatsapp \
  --to "+YOURPHONE"
```

### 4.2 Health Monitor (Every 4 Hours)

```bash
moltbot cron add \
  --name "Health Monitor" \
  --cron "0 */4 * * *" \
  --session isolated \
  --message "Run health check: VPS servers, trading processes, check TradesViz for concerning patterns. Only notify via WhatsApp if issues found or approaching prop firm limits." \
  --model "sonnet"
```

**Why 4 hours instead of 15 minutes:**
- Trading metrics (win rate, profit factor) don't change meaningfully in 15 minutes
- Reduces noise and alert fatigue
- Still catches issues within reasonable timeframe
- Can always check on-demand

## Phase 5: Update Documentation

### 5.1 Update `moltbot/TOOLS.md`

Add this section:

```markdown
## cron

Scheduled automation:
- **Afternoon summary (3pm Tbilisi)**: Trading status, overnight work, priorities
- **Health monitor (every 4 hours)**: VPS health, trading alerts if issues found

Cron jobs run in isolated sessions. Results delivered via WhatsApp when configured.

## browser

For web automation on logged-in sites:
- TradesViz (trade data, analytics)
- GitHub (PRs, repos, issues)
- Notion (organization, notes)

Sessions persist in clawd Chrome profile. Re-login manually if cookies expire.

## exec (GitHub/Git)

Moltbot can create PRs against repos you grant access to:

**Capabilities:**
- Clone/pull repositories
- Create branches and commits
- Push changes and create PRs via `gh` CLI
- Never pushes to main—always creates PRs for review

**Workflow:**
1. Moltbot identifies an improvement or fix
2. Creates branch: `moltbot/[descriptive-name]`
3. Uses Claude Code or Gemini CLI to implement changes
4. Commits with clear message
5. Creates PR with summary
6. Notifies Kent via WhatsApp with PR link

**Repos with access:** See MEMORY.md → GitHub Repository Registry

**Self-improvement:** Moltbot can propose enhancements to its own code in `kent_clawd_personaplex`

## AI Coding Tools

Moltbot has access to AI coding assistants for autonomous development:

### Claude Code CLI
```bash
# Implement a fix
claude --print "Fix the bug in main.py"

# Review and improve code
claude --print "Review this file for security issues and fix them"
```

Best for: Complex changes, refactoring, multi-file edits

### Gemini CLI
```bash
# Quick fix with auto-approve
gemini -p "Add error handling to api.py" --yolo

# Get structured output
gemini -p "List all TODO comments" --output-format json
```

Best for: Quick fixes, analysis, generating commit messages

### When to Use Which

| Task | Tool |
|------|------|
| Complex refactoring | Claude Code |
| Quick bug fixes | Gemini CLI |
| Security review | Claude Code |
| Generate docs | Either |
| Commit messages | Gemini CLI |
```

## File Summary

| File | Action | Lines Changed |
|------|--------|---------------|
| `Dockerfile` | Add timezone + Claude Code + Gemini CLI | ~5 |
| `scripts/start.sh` | Add GitHub + Claude + Gemini auth setup | ~30 |
| `moltbot/moltbot.json` | Add cron section | ~3 |
| `moltbot/skills/trading.md` | Create | ~100 |
| `moltbot/skills/github.md` | Create (with AI tool guidance) | ~180 |
| `moltbot/MEMORY.md` | Add baselines + repo registry | ~60 |
| `moltbot/TOOLS.md` | Add cron/browser/exec/AI tools docs | ~60 |

**Total: 7 files, ~440 lines**

**Environment Variables Required (SaladCloud):**

```bash
# Core (already have)
HF_TOKEN=hf_xxxxx
ANTHROPIC_API_KEY=sk-ant-xxxxx
WHATSAPP_PHONE=+yourphone

# GitHub PR capabilities
GITHUB_TOKEN=ghp_xxxxx
GITHUB_BOT_EMAIL=moltbot@yourdomain.com

# AI Coding Tools
GEMINI_API_KEY=AIzaSyXXXXXXXX
# CLAUDE_SETUP_TOKEN=xxx  # Optional - Claude Code uses ANTHROPIC_API_KEY by default

# Persistence (optional)
SUPABASE_S3_ENDPOINT=...
SUPABASE_S3_ACCESS_KEY=...
SUPABASE_S3_SECRET_KEY=...
```

**One-time setup (not in codebase):**
- Create GitHub bot account
- Generate GitHub PAT token
- Add bot as collaborator to repos
- Get Gemini API key from [Google AI Studio](https://aistudio.google.com/apikey)

## Post-Implementation Steps

### One-Time GitHub Setup (Do First)

1. **Create GitHub bot account** - e.g., `moltbot-kent`
2. **Generate PAT** - Fine-grained token with `repo` scope
3. **Add bot to repos** - Grant collaborator access to repos Moltbot should modify
4. **Set env vars** - Add `GITHUB_TOKEN` and `GITHUB_BOT_EMAIL` to SaladCloud

### Deploy and Configure

5. **Deploy updated container** to SaladCloud
6. **Manual browser login** - Log into TradesViz, GitHub, Notion once
7. **Add cron jobs** - Run the two cron commands above
8. **Populate MEMORY.md** - Add actual:
   - EA names, accounts, prop firm rules
   - GitHub repos with access levels
9. **Test** - Ask Moltbot to:
   - Check trading status
   - Create a test PR against `kent_clawd_personaplex`

## Future Enhancement Path

These features are **documented but not active** to avoid context overload. Enable when ready:

### Level 2: Trading Mentor (When Ready)

Add to trading.md when Kent wants learning support:

```markdown
### Trading Mentor Mode

Help Kent learn from trading data and improve over time.

**Capabilities:**
- Analyze losing trades for patterns (time of day, market conditions, etc.)
- Track improvement metrics over weeks/months
- Suggest focus areas based on weaknesses
- Celebrate milestones and wins

**Trigger:** "Help me learn from my recent trades" or "What should I focus on?"

**Data Sources:**
- TradesViz trade history
- Journal entries
- Performance trends over time
```

### Level 3: TradesViz Setup Guide (When Ready)

Add when Kent wants help configuring TradesViz:

```markdown
### TradesViz Configuration Helper

Guide Kent through optimal TradesViz setup.

**Capabilities:**
- Walk through dashboard widget selection
- Configure useful alerts and reports
- Set up journal templates for trade review
- Optimize data import settings

**Trigger:** "Help me set up TradesViz better" or "What TradesViz features should I use?"
```

### Level 4: Prop Firm Strategy Optimizer (When Ready)

For advanced strategy allocation:

```markdown
### Strategy Optimizer

Help allocate EAs across prop firm accounts optimally.

**Capabilities:**
- Match EA risk profiles to firm rules
- Suggest account allocation based on performance
- Track which EAs work best on which firms
- Model scenarios for scaling decisions

**Trigger:** "Which EA should I run on [firm]?" or "Help me allocate my strategies"
```

## Summary

**This revision:**
- Reduces complexity by 60% (5 skills → 2, 4 crons → 2)
- Fixes critical issues (timezone, headless mode, baselines)
- **Adds GitHub PR capabilities** - Moltbot can propose changes via PRs
- **Self-improvement enabled** - Moltbot can enhance its own code
- **AI Coding Tools** - Claude Code + Gemini CLI for autonomous development
- Aligns with Kent's actual goals from SOUL.md
- Documents growth path without overloading context now

**Key capabilities after implementation:**

| Capability | Skill/Tool | Trigger |
|------------|------------|---------|
| Trading monitoring | `trading.md` | "Check trading status" |
| Strategy evaluation | `trading.md` | "Should I keep running [EA]?" |
| TradesViz data | `trading.md` | "What's my P/L today?" |
| Create PRs | `github.md` | "Fix [issue] in [repo]" |
| Self-improvement | `github.md` | "Add [capability] to yourself" |
| Clone & develop | Claude Code / Gemini | "Clone [repo] and fix the bugs" |
| Code review | Claude Code / Gemini | "Review [repo] for security issues" |
| Afternoon summary | Cron (3pm) | Automatic |
| Health monitoring | Cron (4hr) | Automatic |

**Development Workflow:**
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

**Key insight from SOUL.md:** Kent wants Moltbot to be proactive but not overwhelming. Start simple, prove value, then expand.
