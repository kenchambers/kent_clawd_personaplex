# Curated Memory

## System Configuration

- Primary admin server: this container
- Notification channel: WhatsApp
- PersonaPlex voice interface on port 8998
- Orchestrator API on port 5000

## Kent's Trading Infrastructure

### MT5 Setup
- Multiple VPS servers running MT5 instances
- Each VPS hosts one or more Expert Advisors
- Prop firm accounts across different firms (track which EA → which account → which firm)
- Key metrics to monitor: win rate, drawdown, profit factor, max consecutive losses

### Python Trading Servers
- Manual trading algo servers on VPS
- Require uptime monitoring and log analysis
- May need periodic restarts or config updates

## Organization Systems (Work in Progress)

### Notion
- Currently disorganized - needs restructuring
- Goal: Create systems Kent can maintain easily
- Priority: Trading performance tracking, project management, idea capture

### Data Structure Needs
- EA performance history (per strategy, per account)
- Prop firm account status and rules
- Project ideas and implementation status
- GitHub repos and their purposes

## Learned Preferences

- Kent prefers `docker ps --format "table {{.Names}}\t{{.Status}}"` for container listing
- When asked about "the database", default to production PostgreSQL
- Backup operations should always be confirmed first
- Prefers concise summaries over raw output
- Likes tables and structured data over prose

## Common Issues & Solutions

- If PersonaPlex crashes, restart with: `python -m moshi.server --ssl "$SSL_DIR"`
- If disk >90%, first check docker: `docker system df` and `docker system prune`

## Ideas Kent Has Mentioned

*(This section gets updated as Kent mentions things he wants to do)*

## Pending Follow-Ups

*(Track items that need Kent's attention or decision)*

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

## Service Connections

### TradesViz
- Auth method: Username/password (browser automation)
- Session status: [active/expired/unknown]
- Last login: [timestamp]
- Auto-login enabled: Yes (if credentials in env)
- Log file: /var/log/tradesviz-login.log

### Notion
- Auth method: MCP OAuth
- Connection status: [connected/disconnected]
- Workspace: [workspace name]
- Last verified: [timestamp]
- MCP Server: https://mcp.notion.com/mcp

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
