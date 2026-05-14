---
name: runbook-generator
description: User-opt-in pass that generates an on-call runbook for a service / feature. Output is a single-page operator doc — what it does, common failures + diagnostic + fix, key dashboards, alert response, escalation, common manual ops. Optimized for "3am, paged, half-awake" usability. ≤1 active L3/turn.
layer: 3
group: _extended8
enabled_default: false
opt_in: true
cli: "/invisible runbook [--target <service|feature>] [--mode new|update]"
caps:
  body_lines: 400
recommender:
  min_score: 4.0
  triggers: ["runbook", "on-call doc", "ops doc", "playbook", "what to do when X fails", "incident response", "3am paged"]
---

# runbook-generator

Generates a runbook fit for a half-awake on-call. One page (logical, not literal). Scannable. Specific. No fluff.

## When to run

- New service / feature reaching production.
- Existing service has no runbook (most common).
- Recent incident exposed a gap — update runbook.
- Pre-launch [[prod-readiness-audit]] blocked on missing runbook.

## When NOT to run

- Internal tool with no on-call surface.
- Feature behind always-off flag with no production exposure.

## Output template

```markdown
# Runbook — <service / feature name>
INVISIBLE runbook-generator · v<n> · <date>

## At a glance
**What it does**: <1 sentence>
**Owner**: <team> · Slack: #<channel> · On-call: <rotation>
**Critical paths**: <list, in priority>
**SLO**: <availability + p95 latency>
**Status page component**: <name + link>

## Quick links
- Dashboard: <link>
- Logs: <link>
- Alerts: <link>
- Deploy pipeline: <link>
- Repo: <link>
- Architecture: <link to design doc>

## Alert response

### Alert: `<alert name>` (severity: page)
**What it means**: <one-line>
**First check (within 60s)**:
1. <quick check, copy-paste command or link>
2. <quick check>

**Common causes** (in order of likelihood):
- <cause> → <fix>
- <cause> → <fix>

**If unclear**: <escalation step>

### Alert: `<alert name>` (severity: ticket)
...

## Common failure modes

### Failure: <name>
**Symptom**: <what you see>
**Mechanism**: <what's going wrong>
**Detection**: <how to confirm — query / log / metric>
**Mitigate (do this first to stop bleeding)**:
- <action>
**Resolve (do this to actually fix)**:
- <action>
**Rollback**: <if mitigation made it worse>

### Failure: <name>
...

## Common manual operations

### Op: <name>
**When**: <reason to do this>
**How**:
```bash
<exact command>
```
**Verify**: <what to check after>
**Risk**: <what could go wrong>

### Op: <name>
...

## Diagnostics one-liners

```bash
# Recent errors in last 15min
<command>

# Top slow queries
<command>

# Active connections
<command>

# Background job backlog
<command>
```

## Dependencies

| Dependency | Type | Failure means | Their on-call |
|---|---|---|---|
| <name> | DB / cache / vendor | <what breaks> | <channel> |

## Capacity + limits
- Max RPS observed: <N>
- Connection pool sizes: <DB: X, cache: Y>
- Queue throughput: <jobs/sec>
- Rate limit triggers: <when seen, what action>

## Recent incidents (last 90d)
- <date> — <one-line> — postmortem: <link>
- <date> — <one-line> — postmortem: <link>

## Escalation
1. **First responder** — current on-call
2. **Service owner** — <name / team> if root cause unclear in 30min
3. **Architecture / platform** — <name / team> for cross-service incident
4. **Leadership** — <name / role> for customer-visible incident lasting >30min

## Known landmines
- <thing that bit us before — kept here to spare future on-call>
- <unintuitive behavior in normal operation>

## Maintenance procedures
- Deploy: <link or steps>
- Rollback: <flag-flip / re-deploy>
- Restart: <command, expected downtime>
- Restore from backup: <link, RPO/RTO>

## What this runbook does NOT cover
- <related but separate concern>
- <thing handled by another team's runbook>
```

## Inputs

| Source | Use |
|---|---|
| Existing service code | Detect endpoints, jobs, dependencies |
| `.invisible/maps/` | Architecture context |
| `.invisible/audits/` | Failure modes from prod-readiness-audit |
| Existing alerts config | Alert names → response sections |
| Postmortems (`docs/postmortems/`, Linear/Notion if linked) | Recent-incident section, known landmines |
| Dashboard URLs (config / CLAUDE.md) | Quick-link block |

## Inference rules

### Failure modes
Derived from:
- Code: try/catch sites + retry policies → "what we know fails"
- Dependencies: each external call → "what if it's down"
- Postmortems: incidents → "what failed historically"

### Common ops
Derived from:
- Maintenance scripts in `bin/` / `scripts/` / `Makefile`
- Manual SQL noted in past postmortems
- Documented rake tasks / management commands

### Alert sections
For each alert in alerts config:
- Generate response block.
- If alert name doesn't suggest mechanism, mark "needs human description".

### Escalation
Default chain if not specified: on-call → owning team lead → platform → leadership. User can override per service.

## Tone + style discipline

- **No filler.** Half-awake on-call doesn't need "in order to investigate, you might want to consider...".
- **Action verbs first.** "Check the dashboard. If error rate >5%, page DB team."
- **Copy-paste commands** beat prose descriptions.
- **No assumed knowledge.** Use full command paths. Specify env vars.
- **Verify steps** after every action. "Run X. You should see Y. If not, Z."
- **Time budgets** on diagnostic steps. "Within 60 seconds: check ...".

## Anti-patterns the generator refuses

- "Investigate the issue" / "Look at the logs" without specifics.
- Multi-paragraph background sections (move to architecture doc).
- Marketing about the service.
- Generic SRE advice not specific to this service.

## Update mode

When `--mode update`:
- Preserve human-edited sections (marked with `<!-- runbook-edit:human -->`).
- Refresh detected facts (dependencies, endpoints, dashboards).
- Append new incidents to "Recent incidents" section.
- Flag stale sections (e.g., "Quick link to dashboard returns 404" if checked).

## Validation

After generation:
- Every alert mentioned has a response section (or is flagged).
- Every dependency has an entry.
- Every quick-link is a non-placeholder URL.
- Length ≤2,000 words (anything more is too much for 3am).

If validation fails → emit report + suggest edits.

## Token budget

| Scope | Tokens |
|---|---|
| Small service / single feature | 8–20k |
| Medium service | 20–45k |
| Large service / system | 45–80k |

## Failure modes

- No alerts configured → emit runbook with "ALERTS SECTION TO BE WRITTEN" + suggest [[prod-readiness-audit]] first.
- No dashboards / observability → flag as P1 gap; produce runbook with TODO blocks for ops-data sections.
- Multiple subsystems collapsed into one service → recommend per-subsystem runbook + cross-link.

## Integration with other tools

- Inputs: [[deep-codebase-mapper]] (architecture), [[prod-readiness-audit]] (failure modes), [[security-auditor]] (incident playbook hooks).
- Output: `.invisible/runbooks/<service-slug>.md`.
- Pairs with [[architecture-designer]] (referenced in runbook quick-links).

## CLAUDE.md hooks

Reads section A (observability stack, alert system), B (escalation policy), F (incident history → known landmines section).
Writes runbook. Doesn't modify code.

## Related

[[prod-readiness-audit]] · [[deep-codebase-mapper]] · [[architecture-designer]] · [[trd-writer]] · [[error-net]] · [[env-net]]
