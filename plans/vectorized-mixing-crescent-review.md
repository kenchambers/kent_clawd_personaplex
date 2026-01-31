# Plan Review Report: Moltbot Gateway Direct Integration

**Plan:** `vectorized-mixing-crescent.md`
**Date:** 2026-01-29
**Status:** NEEDS REVISION

---

## Summary

Replace subprocess CLI calls with HTTP API integration to Moltbot Gateway for unified sessions and cross-channel communication.

**Files Touched:**
- `orchestrator/gateway.py` (NEW)
- `orchestrator/config.py` (MODIFY)
- `orchestrator/main.py` (MODIFY)
- `orchestrator/notify.py` (MODIFY)
- `orchestrator/llm.py` (MODIFY)
- `moltbot/moltbot.json` (MODIFY)
- `moltbot/TOOLS.md` (MODIFY)

---

## Breaking Changes Analysis

### CRITICAL

| Issue | Location | Impact |
|-------|----------|--------|
| **notify.py sync→async conversion** | `notify.py:6-45`, `main.py:414,443` | Callers don't use `await` - notifications silently fail |
| **NEED_INPUT_PATTERN regex** | `llm.py:137-140` | New `channel=` format won't match - NEED_INPUT signals ignored |

### HIGH

| Issue | Location | Impact |
|-------|----------|--------|
| **parse_moltbot_output return type** | `llm.py:158-170` | New `channel` key; regex group indices shift |
| **run_moltbot signature change** | `main.py:328-352` | 3 call sites lack `session_id` |
| **Test suite breakage** | `tests/test_main.py` | 5 tests mock `run_moltbot` - need gateway mocks |

### MEDIUM

| Issue | Location | Impact |
|-------|----------|--------|
| Template format change | `llm.py:118-135` | In-flight sessions using old format will fail |
| Missing env vars | `config.py` | Deployment without GATEWAY_URL/TOKEN fails |

---

## Over-Engineering Concerns

| Item | Issue | Simpler Alternative |
|------|-------|---------------------|
| **GatewayClient class** | Unnecessary abstraction | Use module-level async functions |
| **SSE streaming** | No current consumer | Omit - add when needed |
| **Channel selection** | Premature multi-channel abstraction | Keep WhatsApp-only |
| **`/personaplex/context` endpoint** | Duplicates existing endpoints | Use `/personaplex/prompt`, `/context/{session_id}` |
| **Identity links** | Vaguely specified | Clarify requirement first |

---

## Logic Validation Issues

### CRITICAL Architectural Flaws

| Issue | Description | Confidence |
|-------|-------------|------------|
| **Session ID flaw** | Using `WHATSAPP_PHONE` as session key breaks concurrent sessions | HIGH |
| **Incomplete async migration** | No call-site updates specified | HIGH |
| **Missing gateway.py spec** | No retry logic, error handling, response format | HIGH |
| **NEED_INPUT channel unclear** | Incompatible with Moltbot subprocess output | HIGH |

### Unanswered Questions

1. What happens when Gateway is unreachable?
2. Response format - JSON or plain text?
3. Retry strategy? Exponential backoff?
4. Why 300s timeout specifically?

---

## Overall Assessment

| Metric | Value |
|--------|-------|
| **Status** | **NEEDS REVISION** |
| **Critical Issues** | 4 |
| **High Issues** | 3 |
| **Medium Issues** | 2 |
| **Over-Engineering Concerns** | 5 |

---

## Required Changes Before Implementation

### 1. Fix Session ID Architecture

**Problem:** "Session key uses WHATSAPP_PHONE" breaks concurrent sessions.

**Solution:** Keep UUID-based `session_id`. Phone number is only for notification targeting.

### 2. Complete Async Migration Plan

**Problem:** "Make notify.py async" without call-site updates.

**Solution:** Add explicit changes:
```python
# main.py:414 - MUST add await
await notify.send_question_notification(...)

# main.py:443 - MUST add await
await notify.send_completion_notification(...)
```

### 3. Define gateway.py Specification

**Required Details:**
- HTTP endpoint URL
- Request/response JSON schema
- Timeout strategy per operation type
- Retry logic with max attempts
- Error messages for each failure mode
- Connection pooling strategy

### 4. Clarify NEED_INPUT Channel Integration

**Options:**
- **Option A:** Remove channel requirement (simplest)
- **Option B:** Include channel in template context, not signal format
- **Option C:** Track channel in ExecutionContext separately

**Recommendation:** Option B or C. Don't modify NEED_INPUT signal format.

### 5. Update NEED_INPUT_PATTERN Regex

Make channel optional for backward compatibility:
```python
NEED_INPUT_PATTERN = re.compile(
    r'<<<NEED_INPUT(?:\s+channel=(\w+))?>>>\s*(.+?)\s*<<<CONTEXT>>>\s*(.+?)\s*<<<END_INPUT>>>',
    re.DOTALL,
)
```

---

## Recommendation

**Do not implement as-is.**

The current subprocess approach is simpler, more debuggable, and sufficient for stated goals. HTTP gateway only makes sense for:
- Streaming responses
- Connection pooling for 100+ concurrent commands
- Load balancing across multiple Moltbot instances

None of these are stated requirements.

**If proceeding:** Fix the 4 critical issues first, then implement as 2-3 smaller PRs rather than one large change.

---

## Files Referenced

- `orchestrator/main.py` (520 lines)
- `orchestrator/notify.py` (45 lines)
- `orchestrator/llm.py` (171 lines)
- `orchestrator/config.py` (45 lines)
- `orchestrator/execution.py` (31 lines)
- `tests/test_main.py` (372 lines)
