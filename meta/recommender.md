# meta/recommender.md

Surfaces L3 suggestions (≤1/turn) and P3 advisor notes for "considered but not loaded" skills. Quiet by design.

## What it can surface

1. **L3 opportunity** — current turn matches an L3 skill's trigger. Max 1/turn.
2. **Considered L1** — a skill scored 2.0–2.99 (under DECIDER threshold). May still be worth a note.
3. **Interop hint** — unknown skillset detected (see [[interop]]).
4. **Pattern hint** — agent is about to write code in a domain where the user has no [[CLAUDE_TEMPLATE]] section D pattern — gentle nudge to record.

## Surfacing rules

- ≤1 L3 suggestion per turn (hard cap).
- ≤2 P3 considered-L1 notes per turn.
- Never surface a recommendation the user dismissed in the last 5 turns (anti-spam).
- Suppress entirely if [[circuit-breaker]] is in `degraded` state.
- Always include a one-key dismissal: *"Reply `skip` to mute this for 24h."*

## L3 scoring

L3 candidates are scored like L1 but with stricter threshold (≥4.0). Reason: L3 work is heavy (full audit, spec rewrite); false positives are expensive in tokens and attention.

| L3 skill | Min score | Typical triggers |
|---|---|---|
| deep-codebase-mapper | 5.0 | "onboard me to this repo", new contributor |
| full-spec-rewriter | 5.0 | "rewrite the spec", incomplete brief |
| prod-readiness-audit | 4.5 | "ship", "production", "go-live" + ≥1 risk signal |
| prd-writer | 4.0 | "PRD", "product spec", "requirements doc" |
| security-auditor | 4.5 | "security review", auth+payment touched in same turn |

(Other 8 in Sprint 5b — same scoring model.)

## Suggestion format

```
[INVISIBLE · L3 opt-in] Consider running `/invisible audit prod-readiness` — your turn touched auth + payment + a new endpoint. Reply `skip` to mute 24h.
```

One line. Skill name, why, dismissal.

## Acceptance telemetry

- User runs the suggested L3 → +1 hit
- User says `skip` → +1 dismiss
- User runs L3 unprompted within 3 turns of suggestion → counted as hit (delayed acceptance)

Hit rate <15% over 30 days → recommender enters quiet mode for that project (only surface very-high-score L3 ≥6.0).

## Related

[[interop]] · [[circuit-breaker]] · [[pattern-scan-budget]]
