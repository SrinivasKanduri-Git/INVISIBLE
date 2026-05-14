# Input 3 — Multi-tenant CRUD ticket

**Locked: 2026-05-13. Do not modify after first comparison run.**

## Source

Standard product feature ticket with implicit tenant boundary.

## Brief

> Build saved-views for the projects list. A workspace member can save their current filters + column choices as a named view, see them in a dropdown, share with the workspace, or keep private. Pinned views show at the top.

## Stack assumption (for both tools)

- Next.js 14 App Router + Prisma + Postgres
- Workspace multi-tenancy: `workspaces`, `workspace_members(workspace_id, user_id, role)`
- Existing `projects` table workspace-scoped

## Why this input

- Multi-tenant boundary (workspace scope)
- Per-user vs shared resources (private vs workspace-shared views)
- CRUD with permissions (who can edit/delete a shared view?)
- Tests both tools' tenant-scoping discipline + permission-model surfacing
- Realistic — every B2B SaaS has a "saved views" feature; landmine-rich domain
