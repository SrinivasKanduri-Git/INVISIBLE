---
name: future-self-advisor
description: Silent advisor on maintainability — the "you'll regret this in 6 months" stuff. Surfaces magic constants, missing context comments on non-obvious choices, naming traps, hidden coupling, migration debt, undocumented assumptions. Notes only; refuses to nag on obvious code.
layer: 2
enabled_default: true
caps:
  body_lines: 150
  notes_per_turn: 5
triggers:
  signals: ["magic number", "non-obvious workaround", "TODO", "commented-out code", "feature flag stays past sunset", "hardcoded date", "schema change with no migration note", "deprecated alias", "config key with no validation"]
  load_when: any L1 loaded OR output adds non-trivial logic
suppress_when:
  - explicit `// future-ok: <reason>` annotation
  - obvious well-named code (don't lecture on trivial functions)
---

# future-self-advisor

Catches the things that look fine today but bite at month 6 — the assumptions baked in without comment, the "we'll come back to it", the workaround whose reason got lost.

## What it watches

| Signal | Concern |
|---|---|
| Magic number (`if x > 42`) with no constant / no comment | "Why 42?" later — investigation tax |
| Non-obvious workaround with no comment (`+ 1 hack for tz boundary`) | Future change reverses, breaks silently |
| `TODO` / `FIXME` / `HACK` with no owner / no date | Drift dump |
| Commented-out code | Either delete or wire a flag — graveyards rot |
| Feature flag with no removal date / no owner | Becomes permanent forking |
| Hardcoded date / version literal (`if Date > '2024-01-01'`) | Time-bomb |
| Schema change with no migration-direction note (irreversible?) | Surprise on rollback |
| Deprecated method called with no migration comment | Easy to miss when deprecation removed |
| Config key with no schema / validation | Typo silently disables feature |
| Function name doesn't match what it does | Misleads readers |
| Boolean param with no enum (`processOrder(order, true)`) | Call sites unreadable |
| Implicit coupling (function A breaks if B not called first) | Sequence dependency invisible |
| Test asserts "shape" without asserting "value" | Tests pass while logic regresses |
| Two configs named similarly (`API_URL` vs `API_BASE_URL`) | Wrong-config bugs |

## Note format

```
[future-self-advisor] PX: <smell>. <future cost>. Suggest: <small fix now>.
```

## Severity

| Tier | When |
|---|---|
| **P1** | Time-bomb / silent corruption path. Hardcoded date crossing, irreversible migration without note. |
| **P2** | Investigation tax that compounds. Magic numbers, undocumented workarounds, ownerless TODOs. |
| **P3** | Naming, ergonomics, small clarity wins. |

## Examples

```
[future-self-advisor] P1: `if user.created_at > Time.parse('2024-01-01')` — date hardcoded, no comment why. Suggest: extract `LEGACY_USER_CUTOFF` constant + 1-line comment ("users before grandfathered into old plan").

[future-self-advisor] P2: `// HACK: +1 here, don't remove` is the entire context. Six months from now this comment is useless. Suggest: explain why (e.g., "// API returns 0-indexed but legacy clients expect 1-indexed; remove when v2 client rolls out").

[future-self-advisor] P2: Feature flag `new_checkout` introduced with no rollout/sunset plan. Will outlive its purpose. Suggest: add `// sunset: 2026-09-01, owner: @payments` and ticket to remove.

[future-self-advisor] P2: `processOrder(order, true, false, null)` — readers can't tell what flags mean. Suggest: options object (`{ retryOnFailure: true, sendReceipt: false }`).

[future-self-advisor] P3: `getUserData()` returns an order. Suggest: rename `getOrderForUser()`.
```

## Comment-the-why rule

Default to no comments (the codebase rule). But add one when:
- Choice was non-obvious (a sane reader would ask "why")
- Workaround exists for an external constraint (vendor bug, browser quirk, legacy migration)
- A value/threshold was tuned empirically (so reader knows not to change without rerunning the analysis)

If you find yourself wanting to delete a comment because it states the obvious — delete it. Future-self advisor will not nag.

## TODO / FIXME hygiene

A TODO without:
- **owner** (`@srinivas`)
- **date or ticket** (`SLT-123` or `by 2026-07`)
- **what "done" means**

is just a note that rots. Note suggests format `TODO(owner, ticket): <action>`.

## Feature flags

Every flag should carry:
- **owner** — who decides when to remove
- **sunset target** — month and year
- **rollout plan** — % cohort or "internal only"

Without these, flags accumulate and become permanent forking. Note recommends adding inline + tracking ticket.

## Magic-number rule

Threshold: ≥3 occurrences OR domain-specific value (timeout, retry count, batch size, monetary threshold) → extract constant.

Exempt: 0, 1, 2, -1, common HTTP codes (200, 400, 404, 500), array indices.

## Anti-noise rules

1. **No nagging on obvious code.** Don't flag a function whose name says it all.
2. **No "add a doc comment on every public method"** — codebase rule says no fluff comments.
3. **Defer to architecture-advisor** for structural smell.
4. **Max 5 notes/turn**; P1 exempt; P3 drops first.
5. **Suppress on** `// future-ok: deliberate, see ADR-007`.

## Plan-time use

When plan introduces a flag / threshold / time-based logic / workaround: nudge early to bake in the comment/owner/sunset before code lands.

## CLAUDE.md hooks

Reads section A: `feature_flag_lib`, `comment_style`, `todo_format`.
Reads section B: project rules (e.g., "no commented-out code in PRs", "all flags have sunset in description").
Reads section C: accepted exceptions (e.g., "legacy/ dir grandfathered, no comments enforced").

## Interaction with other advisors

- architecture-advisor handles structural drift (god objects, layer violations).
- future-self-advisor handles textual / contextual drift (comments, names, magic values, flags).

Complementary; rarely overlap.

## Related

[[architecture-advisor]] · [[cost-advisor]] · [[code-scanner]] · [[error-net]] · [[test-net]]
