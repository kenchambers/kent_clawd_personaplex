# Tools Usage Guide

## exec / system.run

Primary tool for command execution. Use for:
- System status checks (df, free, ps, top)
- Service management (systemctl)
- Docker operations
- File operations (ls, cat, head, tail)
- Running Python scripts for data analysis
- Git operations for PR creation

## memory_search / memory_get

Search past interactions and learned patterns. Use to:
- Recall Kent's preferences
- Find similar past commands
- Avoid asking questions already answered
- Track ideas Kent has mentioned
- Remember trading strategy decisions
- Recall prop firm account details

## message

For WhatsApp notifications:
- Questions requiring user input
- Task completion summaries
- Critical error alerts
- Trading performance alerts (unusual drawdown, losing streaks)
- Morning summaries of overnight work
- Ideas captured for follow-up

## cron

Scheduled tasks:
- Error monitoring every 15 minutes
- Daily health check summaries
- Morning trading performance report
- Weekly strategy review reminders

## sessions_*

For context management:
- sessions_list: See active sessions
- sessions_history: Get conversation history
- session_status: Check current state

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

## TradesViz (Browser)

Trading performance data extracted via browser automation.

**Capabilities:**
- Dashboard metrics extraction
- Trade history access
- Performance charts (screenshots)
- Journal reading/updating

**Session Management:**
- Auto-login on container start (if credentials provided)
- Session expires periodically (cookies)
- Re-login triggered automatically or manually
- Retry logic: 3 attempts with exponential backoff

**Trigger:** "Check TradesViz" or "What's my trading performance?"

**Logs:** /var/log/tradesviz-login.log

## Notion (MCP)

Organization and note-taking via Notion MCP server.

**Capabilities:**
- Search pages and databases
- Read and create content
- Update database entries
- Organize workspace structure

**Connection:** OAuth authenticated via MCP server (https://mcp.notion.com/mcp)

**Setup:** Run `moltbot mcp auth notion` once after deployment to complete OAuth flow.

**Trigger:** "Find in Notion..." or "Create a Notion page for..."

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

## Best Practices

### For Trading Tasks
- Always include context (which EA, which account, which prop firm)
- Store performance data in structured format for comparison
- Flag concerning metrics proactively

### For Organization Tasks
- Propose simple, maintainable systems
- Don't create complexity Kent won't maintain
- Update MEMORY.md with new learnings

### For VPS Tasks
- Confirm destructive operations
- Log important actions
- Summarize output, don't dump raw text
