# Scored — Input 1 (vague export brief)

**INVISIBLE source**: `tests/vs-spec-kit/results/input-1/invisible.md` (simulated).
**spec-kit source**: not yet run.

## Per-metric scoring

| Metric | INVISIBLE | spec-kit | Delta |
|---|---|---|---|
| Output length (tokens, estimated) | ~5,000 | — (not run) | — |
| Time to produce | ~single turn (simulated) | — | — |
| Silent-killer items mentioned (of 10 applicable) | 9.5 / 10 (95%) | — | — |
| Security-specific checks | 14+ explicit | — | — |
| Test-plan rubric (0–5) | **5** (unit + integration + boundary + e2e + load + real-DB constraint) | — | — |
| Edge cases enumerated | 6 | — | — |
| Stack-aware specifics | 4 (Rails, Next.js, Python, Postgres) | — | — |
| Open questions surfaced (via L3 spec-rewriter suggestion) | 12 implied via L3 opt-in | — | — |

## Notes

- INVISIBLE strength on this input: scaling-advisor + cost-advisor + L3 spec-rewriter opt-in surface the "100k records / export-cost / would-benefit-from-spec" angles that a naive read of the brief misses.
- INVISIBLE weakness: it surfaces *safeguards* but does not produce a *committed spec*. The L3 spec-rewriter suggestion is one extra opt-in step. spec-kit, by design, would produce a spec artifact directly.
- Apples-to-oranges nuance: INVISIBLE's per-turn output is safeguards + advisors + L3 suggestion; spec-kit's per-turn output is a structured spec artifact. Headline metric "silent killers identified" favors INVISIBLE; metric "fully-structured spec artifact produced in one pass" favors spec-kit.

Reconcile after spec-kit run.
