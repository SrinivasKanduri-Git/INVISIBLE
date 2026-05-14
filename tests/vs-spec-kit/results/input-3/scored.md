# Scored — Input 3 (saved-views, multi-tenant)

**INVISIBLE source**: `tests/vs-spec-kit/results/input-3/invisible.md` (simulated).
**spec-kit source**: not yet run.

## Per-metric scoring

| Metric | INVISIBLE | spec-kit | Delta |
|---|---|---|---|
| Output length (tokens, estimated) | ~6,500 | — | — |
| Time to produce | single turn | — | — |
| Silent-killer items mentioned (of 9 applicable) | 7 fully + 2 partial = 8/9 (89%) | — | — |
| Input-specific silent killers caught | 4 (cross-workspace UUID enumeration, member-removed orphans, shared-view delete affects others, jsonb code-injection) | — | — |
| Security-specific checks | 12 explicit | — | — |
| Test-plan rubric (0–5) | **5** | — | — |
| Edge cases enumerated | 5 | — | — |
| Stack-aware specifics | 4 (Next.js + Prisma) | — | — |
| Open questions surfaced | L3 data-model-designer suggested | — | — |

## Notes

- Force-load chain visible: workspace signal → data-flow-net + auth-net + error-net loaded → tenant scope enforced at every WHERE clause.
- INVISIBLE caught "shared-view destructive-deletion affects other members" via ux-advisor — not a security killer, but high-quality UX surfacing typical of advisor-tier output.
- INVISIBLE marginal weakness: idempotency on pin/unpin partial (idempotent by nature, INVISIBLE noted it); N+1 partial (Prisma include shape implied not detailed).
- Comparison value: input-3 is the "standard B2B SaaS CRUD" baseline. Tenant-discipline depth here is the meaningful delta. spec-kit will produce schema/API spec; will it surface cross-workspace UUID enumeration explicitly?

Reconcile after spec-kit run.
