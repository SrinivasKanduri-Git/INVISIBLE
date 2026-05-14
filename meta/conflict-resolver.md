# meta/conflict-resolver.md

Resolves contradictions between rule sources. Called by [[DECIDER]] (skill conflicts), [[self-learner]] (new rule vs existing), and [[rule-validator]] (check #2).

## Source precedence

Highest wins on direct contradiction. Lower-precedence sources may still narrow scope.

1. **User-issued in current turn** ("for this file, do X") — wins over everything below for the current turn only.
2. **CLAUDE.md section B** — project hard rules. Persist.
3. **CLAUDE.md section C** — accepted exceptions (narrow waivers).
4. **L1 hard rules** (skill SKILL.md, `hard_rules:` section).
5. **CLAUDE.md section D** — established patterns.
6. **Learned rules** (`learned-rules.json`).
7. **L1 default rules** (skill SKILL.md, `defaults:` section).
8. **Stack-adapter overrides** — lowest, contextual.

Rule of thumb: a higher rank can *waive* or *override* a lower one. A lower rank cannot override a higher one — only request a CLAUDE.md update.

## Conflict types

| Type | Example | Handling |
|---|---|---|
| **Direct contradiction** | Skill says "require CSRF on POST", project says "skip CSRF on internal /api/health" | Project wins → check 5 (security touch) → require explicit user confirmation if not already present |
| **Scope overlap** | Two learned rules apply same path, different bodies | Newer wins; older archived with conflict note |
| **Cross-skill** | auth-net and api-net both opine on error envelope shape | Tie → security skill (auth-net) wins |
| **Temporal** | Rule expired (CLAUDE.md section C waiver past date) | Treat as non-existent; flag to user |
| **Force-load vs disable** | User disabled auth-net in CLAUDE.md section E, but payment-net force-loads it | Force-load wins. Surface P1 explaining why. |

## Resolution flow

```
conflict detected
  ↓
classify type (above table)
  ↓
apply precedence
  ↓
single winner? → use it, log to conflict.log
  ↓
no clear winner? → ASK USER, present both rules + source + suggested merge
  ↓
user picks → write decision to CLAUDE.md section C (waiver) or section B (new rule)
```

User-facing prompt format:

> *Conflict in `app/api/admin/`:*
> *  A. auth-net rule: "All /api/admin/ endpoints require admin role check at controller level."*
> *  B. learned rule (lr_2026-05-13_007): "Skip role check on /api/admin/health."*
>
> *Which wins? `A`, `B`, or `merge: <your text>`.*

## Force-load conflict precedence

Force-load rules from [[DECIDER]] §7 are non-negotiable hard guarantees. They cannot be disabled by CLAUDE.md section E. If user wants to truly disable a force-loaded skill, they must disable the *triggering* skill (e.g., disable payment-net to free auth-net from being auto-loaded by it).

## Logging

Every resolution writes to `~/.claude/invisible/<hash>/conflict.log`:

```json
{"at": "...", "type": "direct", "winner": "section_B", "loser": "skill_default", "rule": "...", "user_confirmed": true}
```

[[circuit-breaker]] watches conflict rate. >5 conflicts in one turn → degraded mode.

## Related

[[rule-validator]] · [[self-learner]] · [[DECIDER]] · [[circuit-breaker]]
