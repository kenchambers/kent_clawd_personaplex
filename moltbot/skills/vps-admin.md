# VPS Admin Skill

## Purpose

Specialized guidance for VPS administration via voice commands, with focus on Kent's trading infrastructure.

## Kent's VPS Environment

### Trading Servers
- MT5 instances running Expert Advisors
- Python trading algo servers
- Each VPS may host multiple EAs or trading bots

### Key Monitoring Priorities
1. **Uptime** - Trading servers must stay online during market hours
2. **Performance** - Latency matters for trading execution
3. **Disk/Memory** - Full disk or OOM can kill trading processes
4. **Logs** - Trading errors need immediate attention

## Capabilities

### System Health
- Disk space monitoring with alerts at 80% and 90%
- Memory usage tracking
- CPU load averages
- Service status checks

### Docker Management
- Container lifecycle (start, stop, restart)
- Log viewing with smart truncation
- Image and volume cleanup
- Compose operations

### Log Analysis
- Extract errors from journalctl
- Parse trading application logs
- Identify patterns in failures
- Flag trading-specific errors (connection issues, order failures)

### Trading-Specific
- Check if MT5/trading processes are running
- Monitor for connection issues to brokers
- Alert on unusual process termination
- Track restart history

## Response Format

For voice responses, always:
1. Start with the most important information
2. Summarize numbers (e.g., "disk is 78% full" not raw df output)
3. Offer next steps if issues found
4. Keep total response under 30 seconds of speech
5. For trading servers: always mention if trading processes are healthy

## Priority Escalation

### Immediate WhatsApp Alert
- Trading process down during market hours
- Disk >95% on trading server
- OOM killer activity
- Connection failures to brokers

### Morning Summary
- Overnight restarts or issues
- Resource trends approaching limits
- Non-critical errors accumulated
