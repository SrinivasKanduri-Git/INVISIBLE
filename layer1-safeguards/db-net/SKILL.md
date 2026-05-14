---
name: db-net
description: Database safeguards. Migrations, schema, indexes, transactions, N+1, connection pooling, AND read-replica routing (read/write split, replica-lag awareness, stale-read tolerance per endpoint).
layer: 1
enabled_default: true
caps:
  body_lines: 300
triggers:
  keywords: [migration, schema, model, column, index, table, query, transaction, "ORM", "join", "foreign key", "constraint"]
  libs: [ActiveRecord, Prisma, SQLAlchemy, Sequelize, TypeORM, Drizzle, Ecto, Mongoose, django.orm]
  paths: ["db/migrate/", "migrations/", "prisma/schema.prisma", "*.sql", "models/", "schema/"]
force_loads:
  on_migration_signal: [code-scanner]
---

# db-net

Database safety net. Loaded on migrations, model changes, query work.

## Hard rules

1. **Every migration is reversible.** `down` must restore the prior schema OR migration is explicitly marked non-reversible with reason. Auto-generated migrations missing `down` → P1.
2. **No data-mutating operation without a transaction** when ≥2 statements participate. Exception: explicitly idempotent single-statement upserts.
3. **No raw SQL with string interpolation of user input.** Parameterized queries / prepared statements only.
4. **Every foreign key column has an index.** Unindexed FKs cause table-scan joins.
5. **No `SELECT *` in production code paths.** Explicit columns only. Reason: schema changes silently break callers.
6. **N+1 detection is on by default.** Loops over a relation that issue per-iteration queries → P1.
7. **Migrations on tables ≥1M rows require a strategy note.** Lock-acquire approach (concurrent index, batch update, dual-write) declared in PR description or migration comment.
8. **No DROP COLUMN without prior deprecation cycle** (rename → null-tolerate → drop). One-shot drops on prod tables → P1.

## Read-replica routing (cluster gap-fill)

When project declares replicas (CLAUDE.md section A: `replicas: true`):

- **Writes always go to primary.** Reads default to replica.
- **Read-your-write windows** (RYW): after a write, the same request's subsequent reads from the affected aggregate route to primary for `ryw_window_ms` (default 200ms). Configurable per-endpoint.
- **Endpoints declare stale-read tolerance**: `@tolerance(stale_ms=2000)` annotation. If replica lag exceeds tolerance, route to primary or 503.
- **Background jobs** route reads to replica by default (high stale tolerance).
- **Admin / reporting** can use replica freely (declared tolerance ≥5000ms).
- **No cross-shard joins via app code** — if multi-DB, use a query-time fan-out + merge, not SELECT across DBs.

Code-scanner flags:
- Write followed by read in the same request without RYW protection → P2.
- Endpoint declared low-tolerance but routes to replica without lag check → P1.
- Background job using primary for reads when replica would suffice → P3.

## Defaults

| Concern | Default |
|---|---|
| Primary key | `bigint` / UUID v7 (sortable); no `int` for new tables |
| Timestamps | `created_at`, `updated_at` always present, timezone-aware |
| Soft delete | Off by default. If used, partial index on `deleted_at IS NULL` for hot queries |
| String columns | `text` over `varchar(N)` unless length cap is enforced by domain |
| Money | Decimal with explicit precision. Never float. (Hard rule via [[payment-net]] when present) |
| Booleans | `NOT NULL DEFAULT false` — no nullable booleans |
| Enum | DB enum OR check constraint; never freeform string + app-side validation |
| Indexes on new FKs | Always created in same migration |
| Connection pool size | Stack-default; flagged if matches 1× CPU on multi-instance deploys |

## Migration discipline

- Migration filename = `YYYYMMDDHHMMSS_verb_object.{rb,py,ts,sql}`.
- One concern per migration. Add-column + backfill + drop-old = 3 migrations across ≥2 deploys.
- Backfills on tables ≥100k rows use batched updates (LIMIT + cursor), never one big UPDATE.
- New non-null column on existing table requires: (1) add nullable, (2) backfill, (3) set NOT NULL — 3 separate migrations.

## What scanner flags

- Migration without `down` block → P1.
- `DROP COLUMN` / `DROP TABLE` in same migration as `ADD` → P1 (split).
- `.all()` / `find_all` / `select` without `LIMIT` in non-admin path → P2.
- `.includes(...)` (Rails) / `selectinload` (SQLAlchemy) / `include:` (Prisma) absent on a loop accessing relations → P1 (N+1).
- Raw SQL with `#{...}` / `${...}` / f-string interpolation of variable → P1.
- `Float` / `float` column for money / quantity → P1.
- Migration on table comment-tagged as `>1M rows` without strategy note → P1.
- FK without index on the FK column → P1.

## Stack overrides

### Rails / ActiveRecord
- `add_index` for every `references`.
- `strong_migrations` gem recommended; surface as advisor note if absent.
- `validates_uniqueness_of` is not a uniqueness guarantee — must pair with DB unique index.
- `default_scope` is rejected (silent global filter).

### Django ORM
- `select_related` / `prefetch_related` on querysets used in templates / serializers with relations.
- `RunPython` migrations require both forwards + reverse callables.
- `unique_together` / `UniqueConstraint` over app-level uniqueness checks.

### Prisma
- `prisma migrate dev` for dev; `prisma migrate deploy` for prod — never `db push` to prod.
- `@relation` with explicit `onDelete` policy.
- No `findMany()` in templates without `take:`.

### SQLAlchemy
- Async session for I/O paths.
- `lazy='selectin'` or explicit `options(selectinload(...))` on relations accessed in loops.
- Alembic auto-generate is a draft, not a contract — review every revision file.

## Force-load relationships

- Migration signal → force-load [[code-scanner]] regardless of LOC (small-but-deadly migrations).
- Tenant signal (via [[data-flow-net]]) → tenant scoping on every query becomes mandatory; db-net cross-checks.
- Payment domain → [[payment-net]] enforces money-as-decimal; db-net enforces schema-level.

## CLAUDE.md hooks

Reads section A: `db_default`, `replicas`, `connection_pool_size`.
Reads section D: `soft_delete_strategy`, `pagination`, `id_strategy`.

## Related

[[api-net]] · [[auth-net]] · [[code-scanner]] · [[data-flow-net]] · [[payment-net]]
