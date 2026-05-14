# INVISIBLE vs spec-kit — comparison harness

Sprint 6 deliverable per plan §6 + §12. Run both skillsets on the same input. Measure prod-readiness delta. Publish in README §6 (vs spec-kit row).

## Premise

- **spec-kit**: structured specification approach (https://github.com/github/spec-kit).
- **INVISIBLE**: 3-layer autoload skillset (this repo).
- Both target AI coding agents.
- Complementary in design (per [[interop]] doc) but produce different output on same input — that delta is what we report.

## What to compare

Pick **3 representative inputs** (lock before measurement):

| Input | Why |
|---|---|
| Vague feature brief (1 paragraph) | Tests spec generation + safeguard pre-loading |
| Auth-touching ticket | Tests security depth |
| Multi-tenant CRUD ticket | Tests cluster-skill activation |

Same input → both pipelines → measure outputs.

## Metrics

| Metric | INVISIBLE | spec-kit | Delta |
|---|---|---|---|
| Output length (tokens) | <N> | <N> | — |
| Time to produce | <s> | <s> | — |
| Silent-killer issues identified pre-build | <count> | <count> | — |
| Security checks listed | <count> | <count> | — |
| Test-plan completeness (rubric below) | <0–5> | <0–5> | — |
| Edge cases enumerated | <count> | <count> | — |
| Stack-aware specifics | <count> | <count> | — |
| Open questions surfaced | <count> | <count> | — |

### Test-plan completeness rubric (0–5)
- 0 = no test plan
- 1 = "write tests" mentioned
- 2 = unit / integration distinction
- 3 = critical paths + edge cases enumerated
- 4 = + auth boundary tests (cross-tenant, missing-perm) explicit
- 5 = + error envelope, rollback path, real-DB integration constraint

### Silent-killer count
Manually score each output: did it mention each of these where applicable?
- Auth check on new endpoint
- CSRF on cookie-auth POST
- Idempotency for payment / external side-effect
- Rate limit on auth endpoints
- Webhook signature verification
- Money as integer minor units
- Multi-tenant scope in WHERE clauses
- N+1 prevention (DataLoader / select_related / includes)
- Cache invalidation strategy
- Background job retry + DLQ
- Error envelope consistency
- PII scrubbing in logs

Each present = +1.

## Output format

```
tests/vs-spec-kit/
  methodology.md       ← this file
  inputs/
    input-1-brief.md
    input-2-auth.md
    input-3-multitenant.md
  results/
    input-1/
      invisible.md     ← raw INVISIBLE output
      spec-kit.md      ← raw spec-kit output
      scored.md        ← rubric scoring
    input-2/
      ...
    input-3/
      ...
  comparison-summary.md  ← cross-input averages, for README
```

## Honesty rules

1. **Same input, character-for-character.** No prompt-engineering one over the other.
2. **spec-kit version pinned** at the time of test (record sha / release).
3. **INVISIBLE version pinned** to VERSION at test time.
4. **Scoring is rubric-driven**, not by gut. Each scorer independent then reconciled.
5. **Both tools' best modes used.** Run INVISIBLE with appropriate L3 opt-in (full-spec-rewriter for input #1, security-auditor for input #2, prod-readiness-audit for input #3). Run spec-kit with its full pipeline.
6. **Failures published.** If INVISIBLE loses on a metric, that goes in the README.
7. **Not a smear of spec-kit.** Goal is honest delta, not marketing.

## What the README gets

Single paragraph + small table:

```
Vs spec-kit on the same 3 inputs (locked, public):
| Metric (averaged) | INVISIBLE | spec-kit |
|---|---|---|
| Silent-killers identified | <X>/12 | <Y>/12 |
| Test-plan rubric | <X>/5 | <Y>/5 |
| Output tokens | <X> | <Y> |

INVISIBLE optimizes for pre-build safeguard load; spec-kit optimizes for structured spec generation.
Use both if you want both. (See [[interop]].)
```

No "we won" / "we lost" framing. Just numbers.

## Reproducibility

Anyone should be able to:
1. `git checkout` this repo at vN.
2. `git checkout spec-kit` at the pinned sha.
3. Feed `inputs/input-*.md` to each.
4. Get within ±10% of our reported numbers.

If results don't reproduce → bug in our methodology.

## Future cadence

Per [[interop]] (quarterly review): re-run this comparison every quarter. Update README numbers. Note tool drift.
