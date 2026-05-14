# DECIDER miss-log format

Sprint 6 tuning input. Every observed DECIDER misfire recorded here; each row drives a candidate tuning action.

## Storage

- Live: `~/.claude/invisible/<project-hash>/decider.log` (per [[DECIDER]] §4)
- Aggregated for tuning: `tests/decider-tuning/misses-<round>.json`
- Per-round tuning diff: `tests/decider-tuning/tuning-round-<n>.md`

## Per-miss record (JSON)

```json
{
  "turn_id": "2026-05-13T14:22:01Z",
  "project_hash": "a3f7e1",
  "stack": "rails-sidekiq-postgres",
  "input_summary": "user pasted controller code with new Stripe.charge call",
  "decider_output": {
    "loaded": ["api-net", "code-scanner"],
    "scores": {"api-net": 4.5, "code-scanner": 5.0, "payment-net": 2.8, "auth-net": 1.5, "integration-net": 3.2},
    "dropped_for_cap": [],
    "considered": ["payment-net (2.8)"]
  },
  "should_have_loaded": ["payment-net", "auth-net"],
  "miss_class": "under-threshold" | "wrong-tiebreak" | "missing-signal" | "force-load-not-fired" | "over-load",
  "missing_signal": "Stripe.charge call should weight payment-net to 4+",
  "tuning_proposal": "Add 'Stripe.charge' / '.charges.create' to payment-net libs trigger list",
  "evidence_pr_link": "<optional>",
  "noticed_by": "manual review | user correction | post-run audit"
}
```

## Miss classes

| Class | Definition | Tuning lever |
|---|---|---|
| `under-threshold` | Skill scored 2.0–2.99, should have crossed 3.0 | Add signal to skill triggers, OR raise weight of an existing signal class |
| `wrong-tiebreak` | Multiple ≥3.0 candidates; wrong one dropped at cap | Re-rank tier (security > user-facing > infra) or per-skill priority |
| `missing-signal` | Domain not detected at all (score 0) | Add new signal (keyword/lib/path) to skill trigger list |
| `force-load-not-fired` | Force-load rule didn't trigger when its parent skill did | Inspect `force_loads:` frontmatter; may need cross-rule entry |
| `over-load` | Skill loaded but turn didn't need it (token waste) | Down-weight a noisy signal, OR raise threshold for that skill |

## Aggregation per round

After dogfood pass:

```
misses-round-1.json
├── total_misses: N
├── by_class: { under-threshold: X, wrong-tiebreak: Y, ... }
├── by_skill: { payment-net: 4, async-ops-net: 2, ... }
├── top_proposals (deduped, ranked by miss count):
│   1. "Add Stripe.charge to payment-net libs trigger" — affects 4 misses
│   2. "Force-load multitenancy when 'workspace' keyword present in db-net candidate" — 3 misses
│   3. ...
```

## Tuning-round diff (`tuning-round-<n>.md`)

Per round, write a diff showing what changed:

```markdown
# DECIDER tuning — round 1

## Before
- payment-net `libs:` did not include `stripe-ruby` token literal `.charges.create`
- async-ops-net signal weight for "cron" was 1.0

## After
- payment-net libs: added `["stripe.charges.create", "Stripe::Charge.create", "stripe.PaymentIntent.create"]`
- async-ops-net "cron" weight raised 1.0 → 1.5 (verb tier with high specificity)

## Affected misses
- 4 under-threshold misses on payment-net → expected to clear
- 2 missing-signal misses on async-ops-net cron → expected to clear

## Validation plan
Re-run dogfood on same 3 repos. Compare miss counts.
```

## Stop conditions for tuning

- Aggregate misses ≤2 per repo, OR
- 2 full rounds completed with diminishing returns (<30% reduction round-over-round), OR
- Token-budget overrun (loading 4/4 skills on >40% of turns) — symptom of over-tuning.

Document stop-condition + final state in `tuning-final.md`.

## Anti-overfit rules

1. **Don't add signals visible only on the 3 dogfood repos** — could overfit. Add only when signal generalizes.
2. **Don't tune past the cap budget.** Solving "missed X" by loading 5 skills/turn violates plan §4 (≤4 skills/turn).
3. **Tune triggers, not thresholds, by default.** Threshold changes affect all skills; trigger changes are surgical.
4. **Test the change.** If a tuning proposal helps round-1 misses but breaks round-2 (false-positives surge), revert.
5. **Document every diff.** Future regression diagnosis depends on this audit trail.

## Cross-references

- [[DECIDER]] — routing logic
- [[circuit-breaker]] — auto-disable if misfire rate spikes post-tune
- `tests/dogfood/methodology.md` — feeds this with miss observations
- `skill_build_plan.md` §6 — Sprint 6 tuning expectation
