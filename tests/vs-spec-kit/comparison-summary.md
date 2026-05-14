# INVISIBLE vs spec-kit — comparison summary

**Run date**: 2026-05-13
**INVISIBLE version**: 0.7.0-sprint6
**spec-kit version**: not yet run — see "Honesty disclosure" below

## Verdict

**PARTIAL — INVISIBLE side simulated; spec-kit side deferred.**

## Honesty disclosure

Per `tests/vs-spec-kit/methodology.md` rule 6 ("Failures published") and rule 7 ("Not a smear of spec-kit. Goal is honest delta, not marketing"), this run does NOT fabricate spec-kit output.

**Constraints**:
- INVISIBLE has no runtime — its output here is simulated by walking what L1/L2/L3 skills would emit per their spec docs.
- spec-kit is a separate tool with its own runtime; no local installation done in this turn.

**Both gaps documented in each per-input result file.** Headline numbers below show INVISIBLE side only.

## INVISIBLE-side numbers (simulated, locked inputs)

| Metric | Input 1 (export) | Input 2 (invites) | Input 3 (saved-views) | Average |
|---|---|---|---|---|
| Silent killers identified | 9.5/10 (95%) | 9/9 (100%) | 8/9 (89%) | **95%** |
| Input-specific killers caught | — | 4 | 4 | — |
| Test-plan rubric (0–5) | 5 | 5 | 5 | **5.0** |
| Stack-aware specifics | 4 | 5 | 4 | 4.3 |
| Edge cases enumerated | 6 | 6 | 5 | 5.7 |
| Output tokens (estimated, no runtime) | ~5k | ~7.5k | ~6.5k | ~6.3k |

## Per-input notes

### Input 1 — vague export brief
- INVISIBLE strength: scaling-advisor + cost-advisor + L3 spec-rewriter opt-in surface scale/cost angles a naive read misses.
- INVISIBLE weakness on this input: emits safeguards + L3 suggestion, not a committed spec artifact. spec-kit by design produces a spec; expected to score higher on "structured spec produced in one pass".
- Apples-to-oranges note: per-turn deliverable shapes differ; rubric needs separate dimensions for "safeguards loaded" vs "spec artifact produced".

### Input 2 — team invitations (auth-heavy)
- INVISIBLE's strongest input. Force-load chain (auth-net + error-net + data-flow-net + async-ops-net) and 4 input-specific killers caught (removed-member race, email enumeration, stale-session takeover, privilege escalation).
- L3 recommender surfaces `/invisible audit security` — second-turn deepening available.
- Expected: INVISIBLE >> spec-kit on input-specific-killer metric. spec-kit's spec structure likely strong but security depth is INVISIBLE's design center.

### Input 3 — saved-views (tenancy)
- Force-load chain enforces tenant-scope at every WHERE clause.
- ux-advisor caught destructive-deletion-affects-others — non-security but high-quality UX surfacing.
- Marginal weaknesses: pin/unpin idempotency partial, N+1 partial.
- Comparison value: standard B2B-CRUD baseline. Whether spec-kit surfaces cross-workspace UUID enumeration explicitly is the meaningful delta.

## What this would mean for README §6 (vs-spec-kit row)

Until spec-kit runs, the row reads:
> **vs spec-kit**: comparison protocol locked; spec-kit side pending live run. INVISIBLE simulated side surfaces 95% of applicable silent killers and 8 input-specific catches across 3 inputs. Honest delta requires actual spec-kit run — deferred to v0.8.

NOT:
> ~~INVISIBLE outperforms spec-kit 95% to X%.~~ (fabricated)

## Protocol to complete

1. Install spec-kit at a pinned release tag. Record sha + date.
2. Build INVISIBLE runtime (validator + DECIDER + scanner) — currently spec-only. Re-run INVISIBLE side with measurements, not simulation.
3. Feed each of `tests/vs-spec-kit/inputs/input-1-brief.md`, `input-2-auth.md`, `input-3-multitenant.md` to spec-kit's full pipeline.
4. Capture raw output in `tests/vs-spec-kit/results/input-N/spec-kit.md`.
5. Rubric-score per methodology.md.
6. Update `scored.md` per input.
7. Replace this summary with measured numbers + per-tool strengths + honest delta.

## Reproducibility

Per methodology rule on reproducibility: anyone with this repo + a pinned spec-kit checkout should produce results within ±10% of measurements. Locked inputs unchanged after first run.

## History

| Date | INVISIBLE ver | spec-kit ver | Status | Notes |
|---|---|---|---|---|
| 2026-05-13 | 0.7.0-sprint6 | — | INVISIBLE simulated, spec-kit deferred | No runtime for either side at this date |
