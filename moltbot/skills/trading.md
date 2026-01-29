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

---

## TradesViz Session Management

### Auto-Login

TradesViz credentials are stored securely in environment variables. The system:

1. Waits for Moltbot to be healthy on container start
2. Automatically attempts login using browser automation
3. Retries up to 3 times with exponential backoff if login fails
4. Logs results to `/var/log/tradesviz-login.log`

**Security:**
- Password passed via secure temp file (not visible in `ps aux`)
- Temp file deleted immediately after use
- Credentials never logged or exposed in responses

### Manual Re-Login

Trigger: "Re-login to TradesViz" or "TradesViz session expired"

Moltbot will:
1. Navigate to https://www.tradesviz.com/login/
2. Enter credentials from environment
3. Click Sign In
4. Verify dashboard loads
5. Report status

### Session Status

Check MEMORY.md -> Service Connections -> TradesViz for:
- Session status: [active/expired/unknown]
- Last login: [timestamp]
- Auto-login enabled: Yes (if credentials in env)
