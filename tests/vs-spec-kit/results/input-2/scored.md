# Scored — Input 2 (team invitations)

**INVISIBLE source**: `tests/vs-spec-kit/results/input-2/invisible.md` (simulated).
**spec-kit source**: not yet run.

## Per-metric scoring

| Metric | INVISIBLE | spec-kit | Delta |
|---|---|---|---|
| Output length (tokens, estimated) | ~7,500 | — | — |
| Time to produce | single turn | — | — |
| Silent-killer items mentioned (of 9 applicable) | 9 / 9 (100%) | — | — |
| Input-specific silent killers caught | 4 (removed-member race, email enumeration, stale-session takeover, privilege escalation) | — | — |
| Security-specific checks | 18+ explicit | — | — |
| Test-plan rubric (0–5) | **5** | — | — |
| Edge cases enumerated | 6 | — | — |
| Stack-aware specifics | 5 (Rails+Devise specifics) | — | — |
| Open questions surfaced | 0 explicit — feature relatively concrete | — | — |

## Notes

- This is INVISIBLE's strongest input — auth-heavy + tenant-touching + token-bearing-email. The skill set explicitly targets this class of feature.
- Removed-member race: brief specifically asks; INVISIBLE caught with concrete fix (unique partial index + transaction + `SELECT FOR UPDATE`).
- INVISIBLE L3 recommender surfaces `/invisible audit security` — the audit pass would add more depth in a second turn (threat model, OWASP walk).
- Likely INVISIBLE >> spec-kit on input-2 metric "input-specific silent killers". spec-kit's strength is in spec structure; auth/tenancy depth is INVISIBLE's design center.

Reconcile after spec-kit run.
