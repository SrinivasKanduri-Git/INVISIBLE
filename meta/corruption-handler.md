# meta/corruption-handler.md

Detects and recovers from corrupted INVISIBLE state. Never loses user-owned data silently.

## What it watches

Per project (`~/.claude/invisible/<hash>/`):

| Artifact | Corruption signal |
|---|---|
| `preferences.json` | fails [[preferences.schema.json]] validation |
| `discovered-patterns.json` | invalid JSON OR pattern value is non-string/non-list |
| `decider.log` | unreadable / oversized (>10 MB) |
| `accepted-exceptions.json` | duplicate scope+rule entries |
| `circuit-breaker.state` | trip counter is negative or non-integer |

Per install (`~/.claude/skills/invisible/`):

| Artifact | Corruption signal |
|---|---|
| Skill SKILL.md | YAML frontmatter parse fail |
| Routing table in DECIDER.md | rows >35 OR malformed |
| `interop.md` version pins | YAML parse fail |

## Detection cadence

- On every load (cheap fields only — JSON parse, line count).
- Deep validate (schema check) on session start.
- Re-validate when [[self-learner]] writes.

## Recovery flow

1. **Quarantine** — rename corrupt file to `<name>.corrupt.<timestamp>`. Never delete.
2. **Restore** — copy default from `~/.claude/skills/invisible/defaults/<name>`. If no default exists, emit empty-but-valid stub.
3. **Notify** — emit P1 advisor note (P1 exempt from advisor cap):
   > *"INVISIBLE quarantined `<file>` (reason: <signal>). Restored from default. Quarantined copy at `<path>`. Inspect when convenient."*
4. **Log** — append to `~/.claude/invisible/<hash>/corruption.log`.

## What it never does

- Auto-delete quarantined files (user must clean up — they may be salvageable).
- Restore over a *non-corrupt* user file.
- Disable INVISIBLE wholesale on a single artifact failure — degrade gracefully.

## Cascading corruption

If 3+ artifacts in one project quarantine within 7 days → assume systemic issue. Surface P1:

> *"INVISIBLE quarantined 3+ files in 7 days. Likely cause: disk/sync issue or version mismatch. Run `/invisible doctor`."*

[[circuit-breaker]] trips on cascading corruption.

## Related

[[circuit-breaker]] · [[self-learner]] · [[rule-validator]]
