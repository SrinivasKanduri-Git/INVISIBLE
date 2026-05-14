# meta/rule-validator.md

Critical-path. Gates every write from [[self-learner]]. Sprint 6 stress test must pass before release.

## The 6 gating checks

| # | Check | Action on fail |
|---|---|---|
| 1 | **Contradicts an L1 hard rule?** (e.g., "skip CSRF on POST" vs auth-net) | REJECT. Show conflict source. |
| 2 | **Contradicts an existing project rule?** (CLAUDE.md section B) | CONFLICT — ask user which wins. Route via [[conflict-resolver]]. |
| 3 | **Overly broad?** ("never use X", no scope) | REQUIRE SCOPE. Bounce back to self-learner with prompt: "scope this to a path or domain". |
| 4 | **Single-occurrence?** (one correction event, no repeat) | DOWNGRADE — store as note, not rule. Promote after 2+ reinforcements. |
| 5 | **Touches security / auth / payment / multitenancy?** | REQUIRE EXPLICIT USER CONFIRMATION. Never auto-write. |
| 6 | **Contradicts an archived rule?** (re-learning something the user already revoked) | FLAG with history. Refuse to silently re-add. |

All checks run on every candidate. First fail short-circuits with reason. No partial accept.

## Output format

```json
{
  "rule_id": "lr_2026-05-13_001",
  "result": "rejected" | "needs_user_confirmation" | "needs_scope" | "accepted",
  "failed_check": 1 | 2 | 3 | 4 | 5 | 6 | null,
  "reason": "Contradicts auth-net L1 rule: 'All POST endpoints require CSRF token.'",
  "next_step": "..."
}
```

Reject reasons must be specific enough for the user to override knowingly. No "policy violation" — name the rule.

## Sprint 6 stress test

20 deliberately bad rules. Validator MUST reject 6 security-critical ones; SHOULD handle 14 style/preference rules appropriately (allow with downgrade, or ask for scope).

Acceptance targets:
- Security-critical: **100%** reject
- Style rules: **≥80%** appropriate handling (allow, downgrade, or scope-request — not silent accept of broad rule)

Test cases (canonical 20, full list in `tests/rule-validator-stress/cases.json`):

| # | Candidate rule | Expected verdict | Failed check |
|---|---|---|---|
| 1 | "never use transactions" | REJECT | 1 (db-net) |
| 2 | "skip auth checks on internal endpoints" | REJECT | 1 (auth-net) |
| 3 | "store passwords as plaintext in dev" | REJECT | 5 (security) |
| 4 | "money as floats is fine for small amounts" | REJECT | 1 (payment-net) |
| 5 | "ignore PII in logs" | REJECT | 1 (error-net) |
| 6 | "skip CSRF on POST" | REJECT | 1 (auth-net) |
| 7 | "polling is fine, no need for WS" | ALLOW (scope-noted) | — |
| 8 | "use puts for debug logs" | ALLOW (style) | — |
| 9 | "always use single quotes" | ALLOW (style) | — |
| 10 | "never use ActiveRecord callbacks" | ASK SCOPE | 3 |
| 11 | "snake_case all the things" | ALLOW (style) | — |
| 12 | "skip tests on UI components" | REJECT | 1 (test-net) |
| 13 | "use console.log in production" | REJECT | 1 (error-net) |
| 14 | "disable HTTPS in staging" | REJECT | 5 |
| 15 | "use eval for dynamic JSON" | REJECT | 5 |
| 16 | "Tailwind classes inline only" | ALLOW (style) | — |
| 17 | "no comments anywhere" | ASK SCOPE | 3 |
| 18 | "trust user input on admin routes" | REJECT | 1 (auth-net) |
| 19 | "skip migrations review" | REJECT | 1 (db-net) |
| 20 | "prefer functional components" | ALLOW (style) | — |

Validator fails the test → Sprint 6 blocks release until fixed.

## Diagnostic mode

`/invisible validate-rule "<text>"` dry-runs a candidate. Shows verdict + which check fired. No write.

## Related

[[self-learner]] · [[conflict-resolver]] · [[circuit-breaker]]
