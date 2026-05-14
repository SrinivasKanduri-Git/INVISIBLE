# meta/circuit-breaker.md

Detects when INVISIBLE itself is misbehaving. Target trip rate: <10% of projects in steady state (plan §14). When tripped, INVISIBLE degrades loudly rather than silently misfiring.

## States

| State | Behavior |
|---|---|
| `armed` | Normal operation. All layers active. |
| `degraded` | L1 still active, L2 advisor notes suppressed below P2, L3 suggestions muted. [[self-learner]] paused. |
| `tripped` | Only L1 hard rules + code-scanner active. No advisor notes. No learning. User shown loud P1 banner each turn until reset. |

## Trip conditions

| Signal | Threshold | Action |
|---|---|---|
| DECIDER misfire (user says "wrong skill") | 3 in 10 turns | → `degraded` |
| Same advisor note ignored | 5 turns in a row | suppress that note for 24h |
| Rule-validator rejection rate | >50% over 20 candidates | → `degraded` (self-learner is over-proposing) |
| Cascading corruption (see [[corruption-handler]]) | 3 quarantines / 7 days | → `tripped` |
| Conflict-resolver invoked | >5 times in one turn | → `degraded` (sign of broken project config) |
| User runs `/invisible stop` | immediate | → `tripped` |
| Pattern-scan over-budget | 3 turns in a row | → `degraded`, scope review prompted |
| Force-load loop (skill A force-loads B, B force-loads A) | detected | → `tripped` (config bug, halt) |

## Recovery

| State transition | How |
|---|---|
| `tripped` → `degraded` | User runs `/invisible doctor` and passes self-test |
| `degraded` → `armed` | 20 turns clean (no new trip signals) OR user runs `/invisible reset breaker` |
| `armed` ← any | only via doctor or user-issued reset |

Auto-recovery never crosses `tripped` boundary without user action. Reason: tripped means INVISIBLE doesn't trust itself.

## State file

`~/.claude/invisible/<hash>/circuit-breaker.state`

```json
{
  "state": "armed",
  "since": "2026-05-13T14:22:00Z",
  "trip_history": [
    {"at": "2026-05-10T09:11:00Z", "from": "armed", "to": "degraded", "reason": "decider_misfire_x3"}
  ],
  "metrics_window_24h": {
    "decider_misfires": 0,
    "rule_validator_rejects": 2,
    "rule_validator_total": 14
  }
}
```

## What gets shown to the user

Armed: nothing.
Degraded (once, on entry): one P2 note:
> *"INVISIBLE entered degraded mode (reason: <X>). Advisor notes muted below P2. Self-learner paused. Run `/invisible doctor` when convenient."*
Tripped (every turn until reset): P1 banner:
> *"⚠ INVISIBLE is tripped (reason: <X>). Only hard safeguards active. Run `/invisible doctor` to recover."*

## CLI

- `/invisible doctor` — self-test + diagnose + propose fixes
- `/invisible reset breaker` — force back to `armed` (logged)
- `/invisible breaker status` — show state + recent trip history

## Related

[[corruption-handler]] · [[rule-validator]] · [[self-learner]] · [[recommender]]
