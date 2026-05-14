# INVISIBLE — Input 3 (saved-views CRUD, multi-tenant)

**Method**: simulated.

## DECIDER pass

Keywords: "workspace member", "save", "view", "share with workspace", "private", "pinned", "filters", "list".

| Skill | Score | Loaded |
|---|---|---|
| data-flow-net | 6.0 | ✓ (workspace = strong tenant signal) |
| auth-net | force-load by tenant signal | ✓ |
| api-net | 5.0 | ✓ |
| db-net | 4.0 | ✓ |
| ui-net | 3.5 | considered |
| error-net | force-load by auth-net | ✓ (5th slot — but cap is 4, so error-net drops one) |

Tiebreak: security > user-facing > infra. error-net (force-loaded) keeps slot; db-net considered drops to logged-only. Final: data-flow-net, auth-net, api-net, error-net loaded; db-net + ui-net considered.

## Surfaced safeguards

### data-flow-net (heavy, workspace-tenant focus)
- **Every WHERE clause** on saved_views includes `workspace_id`. Not just `default_scope`; explicit at query site.
- **Private vs shared**: `visibility: 'private' | 'workspace'`. Index `(workspace_id, owner_id, visibility, pinned)` to support dropdown queries.
- **Lookup discipline**: `prisma.savedView.findUnique({ where: { id, workspaceId } })` — *not* `findUnique({ where: { id } })` followed by tenant-check. Make tenant part of the key.
- **Permission model**:
  - `private` view: readable + editable only by owner
  - `workspace` view: readable by all members; editable only by owner or admin
  - **Cross-workspace leak vector**: user is member of W1 and W2; view id is a UUID; user fetches view from W2 from a W1 context → must 404 because workspace mismatch
- **Filter-payload schema**: filters stored as `jsonb`. Validation on save: allowlist filter keys, max size, no arbitrary code-eval shapes.

### auth-net (force-loaded by tenant signal)
- **`current_workspace`** from session/membership, never from request body / params.
- **Cross-workspace impersonation**: support viewer of a workspace as admin → separate code path, audited.
- **Default-deny** on new endpoints: `POST /api/saved-views`, `PATCH /api/saved-views/:id`, `DELETE /api/saved-views/:id`, `POST /api/saved-views/:id/pin`.
- **Authorization at resolver**: pin/unpin allowed for owner of private; admin or owner for shared.
- Member-removed-from-workspace scenario: their private views become inaccessible (correct — they're not in the workspace). Cleanup policy: keep, hard-delete on tenant-deletion cascade. Soft-delete during membership change.

### api-net
- **Pagination on list**: cursor (or offset for small N — but list of saved views per user typically <100 so cursor + 50 default OK).
- **Validation** server-side: name length, filter shape, visibility enum, pinned bool.
- **Status codes**: 201 on create, 200 on update, 204 on delete, 403 on cross-user edit, 404 on cross-workspace access.
- **OpenAPI/JSDoc** annotation on each new endpoint.

### error-net
- Cross-tenant access → 404 (not 403 — don't confirm existence of resource in other workspace).
- Permission denial on shared-view edit by non-owner → 403 with clear message.
- Validation error → structured field-level error envelope.

## L2 advisor notes

- [scaling-advisor] **P3**: saved-views list per workspace member typically small (≤100); offset pagination fine. Skipping cursor here is OK.
- [ux-advisor] **P2**: pinned + non-pinned mixed in dropdown — UI sort + visual divider expected. Empty state: "no saved views yet — save the current filter to create one".
- [ux-advisor] **P2**: deleting a shared view that other members have pinned — destructive to others. Confirm dialog should surface "X other members have this view; deleting will remove it for everyone". Optional alternative: convert to private on delete-by-non-owner-admin.
- [architecture-advisor] **P3**: saved-view = filter payload + columns payload + metadata. If columns and filters diverge in shape later, consider separating tables. For v1, single table OK.
- [future-self-advisor] **P2**: `filters: jsonb` — store `schema_version` field. Filter system will evolve; old views with old schema should still resolve gracefully.

## L3 opt-in

[recommender] L3: `/invisible data-model --input input-3` — schema design pass with workspace-scoped saved_views table + indexes + jsonb filter shape would land before code. Reply `skip` to mute 24h.

## Silent killers (12-checklist)

| # | Killer | Mentioned? |
|---|---|---|
| 1 | Auth check on new endpoint | ✓ |
| 2 | CSRF on cookie-auth POST | ✓ (implicit Next.js — but auth-net flags explicitly for POST/PATCH/DELETE) |
| 3 | Idempotency | partial (pin/unpin idempotent by nature; not all mutations need keys) |
| 4 | Rate limit | ✓ (create endpoint; not auth path) |
| 5 | Webhook sig | N/A |
| 6 | Money | N/A |
| 7 | Multi-tenant scope in WHERE clauses | ✓ (heavy) |
| 8 | N+1 prevention | partial (Prisma `include` shape implied; not detailed in 1 turn) |
| 9 | Cache invalidation | N/A (no cache mentioned) |
| 10 | Background jobs | N/A |
| 11 | Error envelope | ✓ |
| 12 | PII scrubbing | ✓ (filter values may include PII when filtering by user-search) |

Applicable: 9. Mentioned: 7 fully + 2 partial = **8/9 applicable**.

Plus input-specific:
- **Cross-workspace view-ID enumeration via UUID** — INVISIBLE caught (find with workspace_id in WHERE)
- **Member-removed orphans** — INVISIBLE caught
- **Shared-view destructive-deletion-other-members-affected** — INVISIBLE caught (ux-advisor P2)
- **Filter jsonb code-injection** — INVISIBLE caught (data-flow-net allowlist)

## Test plan
- Unit: visibility logic, pin toggle
- Integration: cross-workspace access returns 404
- Boundary: edit-shared-as-non-owner → 403; non-admin tries to admin op → 403
- Race: two members pin/unpin concurrently
- Schema: jsonb filter validation rejects unknown keys

## Edge cases
- View created in W1; member moved to W2 → loses access (correct, but support team gets confused)
- View shared then converted to private — others lose access; their dropdown updates next fetch
- Filter references a column that no longer exists in the projects table
- Pinned-view dropdown ordering when 50+ pinned (overflow scrolling?)
- Concurrent edits to shared view (last-write-wins acceptable, but inform user when version mismatch)

## Stack-aware (Next.js 14 App Router + Prisma)
- Server actions OR route handlers for mutations; consistent with project pattern (see [[deep-codebase-mapper]] output if run)
- Prisma: `prisma.savedView.findFirst({ where: { id, workspaceId } })` — `findFirst` because composite-key check
- Zod schemas at route boundary
- Optimistic UI for pin toggle (ux-advisor recommendation)
- `revalidatePath` after mutation if data fetched in server component

## Tokens
Estimate (not measured): 5–8k.
