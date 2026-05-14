---
name: code-scanner
description: Always-on output filter. Runs after agent writes code. Triggers when output ≥30 LOC OR any auth/payment/data-mutation touch. Surfaces P1/P2/P3 findings via [[error-net]] envelope-like notes. Loaded by [[DECIDER]] force-load on db-net migration signal.
layer: 1
enabled_default: true
caps:
  body_lines: 300
triggers:
  always_on_filter: true
  loc_threshold: 30
  sensitive_path_force: [auth, payment, billing, sessions, tokens, users, permissions, policies]
force_loads: []
---

# code-scanner

The cross-cutting filter. Other L1 skills declare what to flag; code-scanner is *where* the flagging happens — at the moment the agent emits code.

## When it runs

- Output (single tool call OR a batched series in one turn) contains ≥30 lines of code, OR
- Output touches a sensitive-path token (file path containing `auth/`, `payment/`, `billing/`, `sessions/`, `tokens/`, `users/`, `permissions/`, `policies/`, `migrate/`, `migrations/`), OR
- Output performs a data mutation (file write, migration, destructive shell, schema change) regardless of LOC.

DB migration signal force-loads code-scanner regardless of LOC threshold (per [[DECIDER]] §7).

## Severity tiers

| Tier | Meaning | Surface behavior |
|---|---|---|
| **P1** | Will break safety, security, or core domain invariant | Emit before code is presented; recommend hold-and-fix |
| **P2** | Will cause incorrect or fragile behavior | Emit alongside code; auto-fixable patterns offered as edit |
| **P3** | Style / smell / future-self problem | Emit summarized at end; user opts-in to view detail |

[[circuit-breaker]] watches P1 noise rate. >50% P1 false-positives over 20 turns → degrade scanner sensitivity.

## What code-scanner specifically owns

Each L1 skill declares its own flag list in its SKILL.md `What scanner flags` section. code-scanner is the **executor** — it loads active skill flag lists, applies them to current output, and produces findings.

Plus, code-scanner has its own cross-cutting flags that no domain skill owns:

| Flag | Tier |
|---|---|
| `TODO` / `FIXME` / `XXX` in newly-emitted code | P3 |
| Dead `import` / unused declaration (lint surrogate) | P3 |
| Stub returning `null` / hardcoded value where domain function should compute | P2 |
| `// @ts-ignore` / `# type: ignore` without comment explaining why | P2 |
| Function ≥80 lines, ≥4 levels deep nesting | P3 (refactor advisor) |
| File ≥500 lines added in single change | P3 (split advisor) |
| Hardcoded URL, IP, or magic constant matching env-shape pattern | P2 (extract to config) |
| Commented-out code blocks ≥5 lines | P3 (delete; git keeps history) |
| Mass renames touching ≥10 files with no shared rationale visible | P2 (split into reviewable chunks) |

## Finding format

Each finding is one line, machine-parseable, human-readable. Format follows [[caveman]] review style — fragment OK, severity-tagged:

```
path/to/file.ts:42  P1 auth-net: localStorage.setItem('token', ...) — XSS leak vector. Move to httpOnly cookie.
path/to/file.ts:78  P2 error-net: catch (e) { res.send(e.message) } — exception leak to client. Sanitize via central handler.
path/to/migration.sql:12  P1 db-net: DROP COLUMN with no deprecation cycle on prod table. Split: rename → null-tolerate → drop (3 deploys).
```

Path, line, tier, owning-skill, problem, fix. No praise, no scope-creep.

## Output ordering

1. P1 findings first, grouped by skill.
2. P2 findings second.
3. P3 summary (count + offer to expand).

If P1 findings present, code-scanner asks: *"P1 findings above. Hold and fix before presenting code? (Recommended.)"* Agent's call whether to defer — default is fix-then-present.

## Auto-fix offers

For mechanical, unambiguous fixes (P2 patterns mostly), code-scanner offers an inline edit. Examples:
- Replace `localStorage.setItem('token', ...)` → cookie call (when project has a cookie helper).
- Wrap `fetch()` in try/catch when project has a fetch wrapper.
- Add missing `key={item.id}` on simple list renders.

Never auto-fixes:
- Authorization logic (manual review required).
- Money / amount math.
- Migration `down` bodies (requires intent).
- Anything in CLAUDE.md section C (accepted exceptions).

## False-positive handling

User dismisses a finding: code-scanner records `{flag_id, file_path, line_range, dismissed_at}` to `~/.claude/invisible/<hash>/scanner-dismissals.json`. Identical re-occurrence within 30 days of dismissal is suppressed (rate-limit-the-nag).

Repeated dismissal across files → [[self-learner]] proposes a project-wide exception in CLAUDE.md section C (still routes through [[rule-validator]] for security flags).

## Token discipline

Code-scanner's *own* output budget per turn: ≤500 tokens. If findings would exceed, summarize:

> *Code-scanner: 7 findings (2 P1, 3 P2, 2 P3). Showing P1 only. Run `/invisible scanner expand` for full.*

P1 findings always shown in full. P2 truncated to one-line each. P3 collapsed to count + topic list.

## How it composes with other skills

- Each active L1 skill contributes flag definitions (`What scanner flags` sections).
- Code-scanner loads those definitions, runs once over output, dedupes, emits.
- If 2 skills flag the same line for the same issue, code-scanner shows the most-specific source (auth-net wins over generic env-net for an auth-secret flag).
- Skills not loaded this turn do not contribute flags (no spurious "you should have loaded X" findings).

## Stack overrides

Scanner adapts pattern matchers per stack:

- **Rails**: regex respects `do |x|`/`end` block boundaries.
- **Python**: indentation-aware function/class boundary detection.
- **TypeScript**: respects JSX, type-only imports, decorators.
- **Elixir**: pipe-chain awareness for "function ≥80 lines" rule (counts logical function, not character lines).

## What it does not do

- Run external linters / type checkers (the project's CI does that).
- Modify code on disk without user confirmation.
- Block tool calls — it advises, agent decides.
- Replace [[security-auditor]] (L3) — code-scanner is per-turn shallow; security-auditor is deep.

## Force-load relationships

- Force-loaded by [[db-net]] on migration signal regardless of LOC.
- Force-loaded by [[DECIDER]] on any output ≥30 LOC OR sensitive-path touch.
- Does not force-load other skills.

## CLAUDE.md hooks

Reads section C: accepted exceptions — scanner skips matching findings.
Reads section B: project rules — added to flag set.

## Related

[[error-net]] · [[auth-net]] · [[db-net]] · [[self-learner]] · [[circuit-breaker]] · [[rule-validator]]
