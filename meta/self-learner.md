# meta/self-learner.md

Observes user corrections, proposes rule writes. Never writes a rule without passing [[rule-validator]] and (for security-sensitive rules) explicit user confirmation.

## What counts as a correction signal

Strong (auto-propose):
- User edits agent's output, then says: "do X this way from now on", "always", "in this project never"
- User reverts an agent change with reason
- User reruns same prompt with explicit constraint added

Weak (note only, don't propose yet):
- Single edit without phrasing
- User accepts but tweaks formatting
- Disagreement over taste with no rule phrasing

## Pipeline

```
correction signal
    ↓
extract candidate rule (scope + rule body)
    ↓
[[rule-validator]] 6-check gate
    ↓ (if pass)
[[conflict-resolver]] check against project rules + skill defaults
    ↓ (if no conflict OR conflict resolved)
    ├─ security/auth/payment/multitenancy? → ASK USER first
    └─ otherwise → write to ~/.claude/invisible/<hash>/learned-rules.json
        + note in CLAUDE.md section B (if user opted into auto-edit)
```

## Rule shape

```json
{
  "id": "lr_2026-05-13_001",
  "scope": "app/services/billing/**",
  "rule": "Never call Stripe SDK directly; route through BillingGateway.",
  "why": "User reverted direct Stripe call on 2026-05-13, said 'always through BillingGateway for audit trail'.",
  "source_turn": 42,
  "validator_passed_at": "2026-05-13T14:22:00Z",
  "status": "active"
}
```

## Confidence tracking

Each learned rule gets a confidence score that grows when reinforced, shrinks when contradicted:

- Created: 0.6
- Reinforced (user says yes again): +0.15
- Contradicted: -0.3
- Below 0.2 → auto-archive (move to `archived-rules.json`, never auto-revive)

## Saving both wins and losses

From the global memory guidance: record from **failure AND success**. If user explicitly endorses a non-obvious approach the agent took (and skill defaults didn't mandate it), self-learner files that as a "validated judgment" rule too — not just corrections.

## What it never does

- Write rules contradicting L1 hard rules (rule-validator rejects).
- Write security-critical rules silently — always confirm.
- Promote single-occurrence patterns to project-wide rules (rule-validator check 4).
- Modify a *user-authored* rule in CLAUDE.md section B without explicit confirmation.

## CLI

- `/invisible learned list` — show active learned rules
- `/invisible learned archive <id>` — manual archive
- `/invisible learned forget <id>` — hard delete (also blocks re-learn from same signal for 30 days)

## Related

[[rule-validator]] · [[conflict-resolver]] · [[circuit-breaker]] · [[pattern-scan-budget]]
