# CLAUDE.md (template — copy into project root)

This file is loaded into every Claude Code turn for this project. Keep it ≤500 lines. INVISIBLE reads sections A–F.

## A. Project identity

- **Name**:
- **Stack** (auto-detected by [[stack-adapter]]; override here if wrong):
- **Hosting / runtime**:
- **Primary purpose** (1–2 lines):

## B. Domain rules (project-specific)

Hard rules INVISIBLE must respect for this codebase. Override skill defaults only when intentional. Each rule must have a scope. Bad: "never use X". Good: "in this project's billing/ folder, never use X because Y".

Examples:
- In `app/services/billing/`, never call Stripe SDK directly — always go through `BillingGateway` (audit trail requirement).
- All endpoints under `/api/admin/` require `current_user.admin?` check at controller level, not view level.

## C. Accepted exceptions

Places where INVISIBLE skill defaults are knowingly violated. Self-learner + rule-validator add to this list with user confirmation. Format:

```
- <file or pattern>: <rule waived> — <why> — <expires: yyyy-mm-dd or "permanent">
```

Example:
- `legacy/old_admin/*`: skip auth-net session-rotation rule — legacy code being deleted Q3 2026 — expires: 2026-09-30

## D. Established patterns

Patterns the agent should follow without re-deriving. INVISIBLE's [[pattern-scan-budget]] reads this before scanning code.

| Pattern | Value |
|---|---|
| Pagination | cursor |
| Error response shape | `{code, message, request_id}` |
| Form validation | react-hook-form + zod |
| Auth pattern | scoped query in model layer |
| Background job library | Sidekiq |
| Cache scope | tenant-keyed |

## E. Skill overrides

Per-skill toggles. Skill default `enabled`. Set `disabled` only with reason.

```yaml
auth-net: enabled
payment-net: disabled  # no payments in this project
realtime-net: disabled
i18n-net: enabled
```

## F. Known landmines

Free-form. Things that have bitten the team before. INVISIBLE surfaces these when adjacent files are touched.

- The `users.email` column is case-insensitive in DB but case-sensitive in 3 places in code — see commit a1b2c3d.
- Background job `BillingReconciler` cannot run during deploy window — locks pricing table.

## G. INVISIBLE config (managed)

Do not hand-edit. Owned by `/invisible` CLI.

```yaml
invisible:
  version: 0.1.0-sprint1
  project_hash: <auto>
  telemetry: off
  circuit_breaker: armed
  layer3_enabled: []
```
