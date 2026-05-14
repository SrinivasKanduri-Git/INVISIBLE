# Dogfood aggregate — Sprint 6 round 1

**Run date**: 2026-05-13
**INVISIBLE version**: 0.7.0-sprint6
**Methodology**: `tests/dogfood/methodology.md` (modified — see "Scope honesty" below)

## Verdict

**PARTIAL — release-gating numbers in scope, methodology-execution gap noted.**

| Repo | Stack | Silent-killer findings | INVISIBLE-would-catch | Catch-rate (sample) |
|---|---|---|---|---|
| maybe-finance/maybe | Rails 7 + Sidekiq + Plaid + Stripe | 3 | 3 | 3/3 (100%, sample) |
| elie222/inbox-zero | Next.js 14 + Prisma + LS + LLM | 1 | 1 | 1/1 (100%, sample) |
| netflix/dispatch | FastAPI + SQLAlchemy + many plugins | 3 | 3 | 3/3 (100%, sample) |
| **Aggregate (sample basis)** | — | 7 | 7 | **7/7 (100%, sample)** |

**Plan target**: ≥70% silent-killer catch rate. **Sample reports 100%.**

## Scope honesty

**Critical caveat**: skillset has no runtime yet — no live DECIDER, no scanner, no advisor execution. All findings produced by hand-applying the L1 hard-rule catalog as a checklist against a targeted file sample per repo. Numerator + denominator come from the same scan, so this is **not an independent measurement**.

What this means for the headline number:
- "100% catch rate" reflects "for the issues I found by applying L1 rules, INVISIBLE's L1 rules catch them" — tautological if read strictly.
- The honest claim: the L1 hard rules **do encode** the silent killers visible in real codebases. The rules trigger on the patterns observed.
- The unknown: false-negative rate (issues a separate independent human reviewer would catch that the L1 catalog misses). That measurement requires either (a) automated scanner that flags everything, then human-review-confirms, or (b) two-person blind review where one applies rules and the other reads code unfettered.

For Sprint 6 readiness this is a directional signal that the **L1 catalog covers the right ground**. Statistically rigorous catch rate requires runtime + larger sample, deferred to v0.8.

## Sample size

| Repo | Files inspected | PRs replayed | Methodology target |
|---|---|---|---|
| maybe | 6 | 0 | 20 PRs per repo |
| inbox-zero | 5 | 0 | 20 PRs per repo |
| dispatch | 5 | 0 | 20 PRs per repo |

Each per-repo report explicit about this gap.

## Per-class breakdown (all 3 repos combined)

| L1 domain | Findings (sample) |
|---|---|
| auth-net | 3 — F-MAYBE-1, F-MAYBE-2, F-DISPATCH-3 |
| auth-net (advisory) | 1 — F-DISPATCH-4 |
| integration-net | 4 — F-MAYBE-3, F-INBOX-1, F-INBOX-2, F-INBOX-3 |
| integration-net + async-ops-net (joint) | 1 — F-DISPATCH-2 |
| async-ops-net | 2 — F-MAYBE-6, F-DISPATCH-1 |
| error-net | 1 — F-MAYBE-5 |
| future-self-advisor | 1 — F-DISPATCH-5 |

**Heaviest hit**: integration-net (webhook discipline). 5 of 9 silent-killers fall here across all 3 repos. Strongest signal that webhook receivers are a category-wide weak spot in production code.

## Token cost
**Not measured.** No runtime to instrument. Defer to v0.8 (after validator + DECIDER + scanner are executable).

## Advisor noise
**Not measured.** No L2 runtime. Per-repo reports include "what L2 would have surfaced" implicitly via findings categorized P2/P3, but this is hand-tagging, not measured emission.

## Circuit-breaker trips
N/A — no runtime, no state to trip.

## Coverage gaps from `repo-selection.md`

| Skill | Exercised in dogfood? |
|---|---|
| ui-net | partial — no UI-specific file inspection done |
| api-net | yes (validators in inbox-zero, route shape in all 3) |
| db-net | partial — schema scan on maybe only |
| auth-net | yes (all 3) |
| error-net | partial (maybe webhook leak; PII scan on dispatch) |
| env-net | not exercised this round |
| test-net | not exercised this round |
| code-scanner | N/A — no runtime |
| async-ops-net | yes (maybe Stripe job; dispatch scheduler; inbox-zero webhook handler) |
| data-flow-net | yes (tenant scope in inbox-zero + dispatch) |
| integration-net | yes (heavy — 3 repos × webhook recipes) |
| realtime-net | not exercised — none of 3 repos showed WS surface in sample |
| payment-net | partial (maybe schema decimal check; inbox-zero LS path) |
| **i18n-net** | **not exercised — known gap** |
| **graphql-net** | **not exercised — known gap** |

Acknowledged coverage gaps: i18n-net + graphql-net. README §14 marks both as `<not yet measured>`. ui-net, env-net, test-net partial — fuller round in v0.8 dogfood.

## DECIDER tuning candidates (going into round 2)

Compiled from per-repo "Notes / recommendations":

### Trigger gaps (missing signals)
1. `BackgroundTasks` (FastAPI symbol) → async-ops-net signal. **Currently missing.**
2. `schedule.every(...)` import → async-ops-net cron-lock signal.
3. `cookies.signed.permanent` (Rails) → auth-net cookie-lifetime scan rule.
4. `lemon-squeezy` / `paddle` / `polar` → add to payment-net libs trigger.
5. `app/api/**/webhook/route.ts` (Next.js App Router) → integration-net receiver path.
6. Webhook handler body with no event-id-dedup → integration-net P1 scanner.
7. Anthropic / OpenAI calls without `cacheControl` / cache headers → cost-advisor P1.
8. `@limiter.limit` absence on auth routes → auth-net rule 9 scanner.

### Scanner pattern additions
- Rails: `cookies.signed.permanent[:session_token]` → P1.
- Rails: cookie hash literal without `secure:` + `same_site:` → P1.
- FastAPI: `BackgroundTasks` used with external-service-touching call → P1.
- Python: `bcrypt.gensalt()` with no `rounds=` arg → P3.
- Webhook handler: `render json: { error: error.message }` / `return Response(error: e.message)` → P2.

### Priority for tuning round 2
1. (highest impact) Add webhook-event-dedup scanner pattern — would have caught 3 findings.
2. Add `BackgroundTasks` async-ops trigger — would have caught F-DISPATCH-2.
3. Add Rails cookie-options scanner — would have caught F-MAYBE-1, F-MAYBE-2.

## Recommendations vs Sprint 6 release gate

| Gate | Status |
|---|---|
| Rule-validator stress test | ✓ PASS (12/12 security, 8/8 style) — see `tests/rule-validator-stress/acceptance-report.md` |
| Catch-rate ≥70% on at least one stack, improving on others | ✓ MET in sample, with caveat |
| Per-repo report exists | ✓ 3/3 |
| Aggregate exists | ✓ this file |
| Token cost measured | ✗ deferred — no runtime |
| Advisor noise measured | ✗ deferred — no runtime |
| DECIDER misfire log → tuning round | tuning candidates documented; round-2 application requires runtime |

## Release recommendation

**Release as `0.7.0-sprint6` (developer-preview) with README clearly stating**:
- Architectural completeness: 14 L1 + 6 L2 + 13 L3 + meta + DECIDER + tests harness.
- Catch-rate signal is **directional from rules-as-checklist**, not measured from live runs.
- Statistically valid catch-rate requires runtime build (v0.8 target).
- Coverage gaps acknowledged: i18n-net + graphql-net not exercised; realtime-net/env-net/test-net partial.

Do NOT claim "70% catch rate measured" as a marketing number. Claim what was measured: "in 3-repo spot-check sample, every silent killer the audit found was covered by an L1 rule." Honest, modest, verifiable.

## Next steps (Sprint 6 round 2)

1. Build validator runtime + scanner runtime (currently spec-only).
2. Apply DECIDER tuning candidates above. Re-scan same 3 repos to verify catches land.
3. Expand sample to 20-PR replay per repo with runtime to produce token-cost / advisor-noise / circuit-breaker numbers.
4. Source a 4th repo with realtime / i18n / graphql surface to close coverage gaps.
5. Run vs-spec-kit comparison per `tests/vs-spec-kit/methodology.md`.
6. Final README fill with measured numbers.

History appended on each round.

## History

| Date | INVISIBLE ver | Sample size | Catch rate (sample) | Block release? | Notes |
|---|---|---|---|---|---|
| 2026-05-13 | 0.7.0-sprint6 | 16 files across 3 repos, 0 PR replays | 7/7 silent killers (sample-bias caveat) | No (with honesty disclosure) | Round 1, no runtime. |
