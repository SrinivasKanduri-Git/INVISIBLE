---
name: ux-advisor
description: Silent advisor on user-facing UX gaps — loading states, error recovery, empty states, optimistic-vs-pessimistic UI, undo paths, perceived performance, destructive-action confirmation. Distinct from ui-net (which enforces baseline a11y/error/loading); ux-advisor catches the "works but feels bad" layer.
layer: 2
enabled_default: true
caps:
  body_lines: 150
  notes_per_turn: 5
triggers:
  signals: ["form submit", "delete/destroy", "save", "fetch on mount", "navigation", "modal open", "list filter", "search", "upload"]
  load_when: ui-net loaded OR output touches UI files (.tsx/.jsx/.vue/.svelte/.erb templates with user-facing flow)
suppress_when:
  - ui-net already raised same finding as P1
  - explicit `// ux-ok: <reason>` or test confirms accepted behavior
---

# ux-advisor

Watches the experience layer ui-net doesn't cover. ui-net says "must have loading + error + empty states"; ux-advisor says "loading is a 2-second spinner with no skeleton — users will think it froze."

## What it watches

| Signal | Concern |
|---|---|
| Mutation with no optimistic update on hot path | Feels slow even when fast |
| Form submit with no in-flight disable | Double-submit risk + uncertainty |
| Destructive action with no confirm + no undo | Permanent regret path |
| Empty state = "no data" with no call-to-action | Dead end |
| Search/filter with no debounce | Flicker + wasted backend cost |
| Loading >300ms with bare spinner | Skeleton beats spinner past 200ms |
| Multi-step form with no save-and-resume | Lost progress on tab close |
| Async result with no progress indication >2s | User assumes broken |
| Error toast that disappears in 3s on a 5-second-read message | Unreadable |
| Modal that traps focus but no Esc-to-close | Discoverability gap |
| Date input as free text, no picker | Format ambiguity |
| Mobile tap target <44×44px | Mis-tap rate |
| Disabled button with no reason tooltip | "Why?" mystery |

## Note format

```
[ux-advisor] PX: <element> <gap>. <user consequence>. Suggest: <pattern>.
```

## Severity

| Tier | When |
|---|---|
| **P1** | Destructive action with no confirm + no undo. Lost-data scenario. |
| **P2** | Friction that drives drop-off (no optimistic update on common action, no debounce on search). |
| **P3** | Polish (skeleton vs spinner, toast duration, tooltip on disabled control). |

## Examples

```
[ux-advisor] P1: `deleteProject` mutation has no confirm dialog or undo window. Misclick = data loss. Suggest: confirm modal with project name re-type OR 10s undo toast.

[ux-advisor] P2: Search input fires query on every keystroke (~500 keys × 100ms backend). Suggest: debounce 300ms + show "searching..." inline.

[ux-advisor] P2: Like button waits for server roundtrip (~400ms). High-frequency action — feels broken. Suggest: optimistic increment, rollback on error.

[ux-advisor] P3: Loading spinner replaces entire card on refresh. Skeleton preserving layout reduces perceived delay. Suggest: skeleton matching card grid for >200ms loads.

[ux-advisor] P2: Multi-step onboarding (5 steps) has no progress save. Tab close at step 3 = restart. Suggest: persist step state per user (localStorage min, server preferred).
```

## Optimistic update heuristic

Apply optimistic UI when:
- Failure is rare (<1%)
- Rollback is cheap (single value flip)
- User action is high-frequency (like, follow, mark-read)

Don't apply optimistic UI when:
- Failure has user consequences (payment, send-message-to-other-party)
- State is complex (rollback would corrupt local view)
- Action is rare + critical (delete account)

## Empty state pattern

Bad: "No items."
Good: "No projects yet. Create one to get started → [+ New project]"

Empty states are onboarding surface. Every list view should have a useful empty state.

## Destructive-action pattern

Levels of friction matched to severity:
- **Reversible (24h trash bin)**: no confirm, show undo toast
- **Hard delete, small scope**: confirm with "Delete" button
- **Hard delete, large scope (cascading)**: type-the-name confirm + summary of what cascades
- **Irreversible cross-user effect (cancel sub, transfer ownership)**: type-the-name + email confirmation

## Error message rule

- Be specific: "Card declined: insufficient funds" not "Payment failed".
- Be actionable: tell user what to do next.
- Never blame user with vague words ("invalid input" — say which field).
- Preserve user input on error. Don't clear the form.

## Anti-noise rules

1. ui-net handles required baseline (loading present? error present?); ux-advisor handles quality (is it good?).
2. No taste-level "I'd use a different color" / "button should be rounded" — that's design, not UX.
3. Max 5 notes/turn (P1 exempt). P3 drops first when over budget.
4. Suppress on `// ux-ok: by design, per spec` annotation.

## Plan-time use

Most useful in early UI plans — "this list view needs a skeleton state, optimistic toggle, debounced search, empty state with CTA, 44px tap targets on mobile" set up before code lands cheaper than retrofit.

## CLAUDE.md hooks

Reads section A: `target_platforms` (mobile sensitivity), `design_system`, `i18n_required`.
Reads section B: project UX rules (e.g., "all destructive ops use trash + 24h restore").
Reads section C: accepted exceptions (e.g., "admin tools skip confirmation, audited").

## Related

[[ui-net]] · [[api-net]] · [[i18n-net]] · [[error-net]] · [[scaling-advisor]] · [[architecture-advisor]]
