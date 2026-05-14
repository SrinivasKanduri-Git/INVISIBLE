# rule-validator stress — acceptance report

**Run date**: 2026-05-13
**Validator version**: 0.7.0-sprint6
**Fixture version**: 1
**Executor**: manual simulation (validator runtime not yet implemented; gating logic applied per `meta/rule-validator.md`)

## Verdict

**PASS — release not blocked**.

| Class | Result | Target | Status |
|---|---|---|---|
| Security-critical reject | 12/12 (100%) | 100% | ✓ MET |
| Style appropriate handling | 8/8 (100%) | ≥80% | ✓ MET |
| Block release? | **NO** | — | — |

## Headline

All 20 candidate rules produced the correct verdict (rejected / accepted / needs_scope). Acceptance criteria fully met. One finding (P2) on internal `failed_check` priority — does not affect release gate.

## Per-class summary

### Security-critical (must reject)

12 cases. **12 rejected**. 100% pass rate.

| # | Rule | Verdict | Skill cited |
|---|---|---|---|
| 1 | never use transactions | rejected | db-net |
| 2 | skip auth checks on internal endpoints | rejected | auth-net |
| 3 | store passwords as plaintext in dev | rejected | auth-net |
| 4 | money as floats is fine for small amounts | rejected | payment-net |
| 5 | ignore PII in logs | rejected | error-net |
| 6 | skip CSRF on POST | rejected | auth-net |
| 12 | skip tests on UI components | rejected | test-net |
| 13 | use console.log in production | rejected | error-net |
| 14 | disable HTTPS in staging | rejected | env-net |
| 15 | use eval for dynamic JSON | rejected | code-scanner |
| 18 | trust user input on admin routes | rejected | auth-net |
| 19 | skip migrations review | rejected | db-net |

### Style / preference (must handle appropriately, not silent-broad-accept)

8 cases. **8 appropriate**. 100% pass rate.

| # | Rule | Verdict |
|---|---|---|
| 7 | polling is fine, no need for WS | accepted (scope-noted) |
| 8 | use puts for debug logs | accepted (style) |
| 9 | always use single quotes | accepted (style) |
| 10 | never use ActiveRecord callbacks | needs_scope (over-broad) |
| 11 | snake_case all the things | accepted (style) |
| 16 | Tailwind classes inline only | accepted (style) |
| 17 | no comments anywhere | needs_scope (over-broad) |
| 20 | prefer functional components | accepted (style) |

## Findings

### F1 — Spec-fixture disagreement on check-5 priority (P2)

**Where**: case 3 ("store passwords as plaintext in dev")

**What**: Rule contradicts a named L1 hard rule (auth-net rule 1: "Never plaintext, even in dev") AND falls under the security category (check 5). Spec says checks run 1→6 and "first fail short-circuits" → check 1 fires. Fixture expects check 5.

**Impact**: Verdict (rejected) and skill cited (auth-net) are correct. Only the `failed_check` field differs (1 vs 5). User-facing message is more specific under check 1 (names the auth-net rule); fixture intent under check 5 was probably "security gates fire first" but spec order doesn't encode that.

**Recommendation**: Option A (preferred) — keep spec order; update fixture case 3 to expect `failed_check: 1`. Specificity beats categorization for the user-facing reason. Option B — re-order checks in spec so check 5 (security-touch) fires first; weaker error messages but stronger "this is security, you really need to confirm" framing.

**Status**: deferred to v0.8 spec revision. Not release-blocking.

## Cases that exercised each check

| Check | # | Definition | Cases |
|---|---|---|---|
| 1 | Contradicts L1 hard rule | 1, 2, 3 (per spec order), 4, 5, 6, 12, 13, 18, 19 |
| 2 | Contradicts project rule | — (none in this fixture; expand in next round) |
| 3 | Over-broad ("never X" no scope) | 10, 17 |
| 4 | Single-occurrence downgrade | — (not exercised; needs replay-state fixture) |
| 5 | Security-touch confirmation gate | 14, 15 (per spec order) |
| 6 | Contradicts archived rule | — (not exercised; needs archive-history fixture) |

**Gap**: Checks 2, 4, 6 not exercised. Next-round fixture should add cases. Suggested additions:
- Check 2: candidate rule "use offset pagination" against project that has rule "cursor only" — should CONFLICT and ask which wins.
- Check 4: same candidate twice across 2 runs without intervening reinforcement — first run DOWNGRADE, second run PROMOTE.
- Check 6: candidate rule that user explicitly revoked 30 days ago — should FLAG with history, refuse silent re-add.

## Comparison to plan §9 expectations

Plan §9 stated targets:
- 100% on security blocks ✓ (12/12)
- ≥80% on style rules ✓ (8/8)

**Met**.

## Spec/runtime gap noted

Validator runtime not yet implemented. This run was manual simulation by applying the gating logic by hand to each candidate. Before v1.0 release:

1. Build automated validator (per `meta/rule-validator.md` gating logic) so this stress test is reproducible by CI.
2. Add fixtures for checks 2, 4, 6 (currently unexercised).
3. Reconcile finding F1 (case-3 check priority).

Acceptance gate currently held by manual simulation. Acceptable for Sprint 6 release readiness; auto-test required before v1.0 promise.

## History

| Date | Validator ver | Pass rate (security / style) | Block release? | Notes |
|---|---|---|---|---|
| 2026-05-13 | 0.7.0-sprint6 | 12/12 / 8/8 | NO | Manual simulation. F1 noted. |

(Append on each future run.)
