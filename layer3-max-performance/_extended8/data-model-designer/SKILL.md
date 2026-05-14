---
name: data-model-designer
description: User-opt-in pass that designs a data model from a feature spec / domain description. Produces entity diagrams (text), per-entity field tables, relationship + cardinality, indexes, constraints, migration sketch, soft-delete / audit / tenancy decisions, and trade-off notes (denormalization, JSON columns, partitioning). Stack-aware. ≤1 active L3/turn.
layer: 3
group: _extended8
enabled_default: false
opt_in: true
cli: "/invisible data-model [--input <spec_or_prd>] [--mode greenfield|extend]"
caps:
  body_lines: 400
recommender:
  min_score: 4.0
  triggers: ["data model", "schema design", "ER diagram", "tables for", "migration design", "normalize this", "denormalize", "what columns"]
---

# data-model-designer

Designs schemas + relationships from a feature spec or domain description. Optimized for "we've got a spec, what should the DB look like?" Produces a model, not just a migration file.

## When to run

- New feature with non-trivial data shape.
- New service designing its own persistence layer.
- Refactoring existing model under feature pressure.
- Migrating from one model style to another (relational ↔ document, normalized ↔ denormalized).

## When NOT to run

- Adding a single column (just write the migration).
- Throwaway prototype.
- Existing data model is correct and stable.

## Modes

| Mode | When |
|---|---|
| `greenfield` | No existing schema constraint |
| `extend` (default) | Existing schema; design fits in |

## Output template

```markdown
# Data Model — <feature / domain> — <date>
INVISIBLE data-model-designer · mode=<mode>

## 0. Summary
**Domain**: <one-line>
**Persistence**: <Postgres / MySQL / Mongo / etc.>
**New entities**: <count>
**Modified entities**: <count>
**Migration sketch**: <reversible? online? estimated row count>

## 1. Entities

### Entity: `<name>`
**Role**: <one-line>
**Identity**: <UUID / ULID / int>
**Tenancy**: <tenant-scoped? owner field?>
**Lifecycle**: <soft-delete? archive? hard-delete?>

| Column | Type | Null | Default | Constraints | Index | Note |
|---|---|---|---|---|---|---|
| id | uuid | no | uuid_v4() | PK | — | |
| tenant_id | uuid | no | — | FK→tenants(id) | yes | scope key |
| status | text | no | 'pending' | CHECK in (...) | — | |
| amount_cents | bigint | no | — | CHECK > 0 | — | money — integer minor units |
| currency | text | no | 'USD' | CHECK length=3 | — | ISO 4217 |
| metadata | jsonb | yes | — | — | gin (selective) | extensible — see "JSON columns" §5.3 |
| created_at | timestamptz | no | now() | — | — | UTC |
| updated_at | timestamptz | no | now() | — | — | UTC, trigger to maintain |
| deleted_at | timestamptz | yes | — | — | yes (partial WHERE NOT NULL) | soft-delete |

**Why this shape**: <2–4 sentences>

### Entity: `<name>`
...

## 2. Relationships

```
Tenant ──┬─< Order ──< OrderItem >── SKU
         └─< User ──< Session
```

(Crow's-foot text diagram; one entity per line if too wide.)

### Relationship: Order → OrderItem
- Cardinality: 1 : N
- FK: `order_items.order_id → orders.id`
- On delete: `CASCADE` (items meaningless without order) — **note: cascades through soft-delete only if app-level**
- On update: `RESTRICT` (id immutable)

### Relationship: Order → Customer
- Cardinality: N : 1
- FK: `orders.customer_id → customers.id`
- On delete: `RESTRICT` (don't lose orders if customer record removed; archive customer instead)

## 3. Indexes

| Table | Columns | Type | Why |
|---|---|---|---|
| orders | (tenant_id, created_at DESC) | btree | scoped recency queries |
| orders | (customer_id, created_at DESC) | btree | customer history |
| orders | (status) WHERE status='pending' | partial | pending-queue scan |
| orders | (metadata) | gin | jsonb selective field search |

**Index discipline**:
- Every FK has an index.
- Composite indexes lead with the most-selective tenant-scope column.
- Partial indexes for skewed predicates ('pending' is 1% of rows).

## 4. Constraints

### Database-level
- `CHECK amount_cents > 0` (money positive)
- `UNIQUE (tenant_id, slug)` (unique slug per tenant, allowed globally)
- `FOREIGN KEY` with `ON DELETE` rules per relationship
- `NOT NULL` on every non-optional field

### Application-level (enforce, document)
- Transitions only via state machine (e.g., `pending → paid → fulfilled`, no `paid → pending`)
- Idempotency key required on creation if external side-effect

## 5. Design decisions

### 5.1 Identifier choice
- UUIDv7 (time-sortable) preferred over UUIDv4 for write-heavy tables — index locality + readable in logs.
- Integer auto-increment OK for non-tenant-scoped reference tables (countries, currencies).
- Public exposure: never expose internal integer IDs to non-trusted parties (enumeration leak).

### 5.2 Money + numeric
- Integer minor units for currency amounts (`amount_cents bigint`), never `numeric` or `float`.
- Where `numeric` is necessary (tax rate, FX rate), specify scale and precision explicitly (`numeric(8, 6)`).
- `bigint` over `int` on tables likely to exceed 2B rows (events, audit).

### 5.3 JSON columns
Use `jsonb` (Postgres) / `JSON` (MySQL ≥5.7) when:
- Extensibility needed without migration churn (vendor metadata, feature payloads).
- Sparse fields where most rows don't have most fields.
- Read pattern fetches the whole blob anyway.

**Don't** use JSON for:
- Fields you'll filter / join on heavily (slow without expression indexes).
- Fields with stable schema (just use columns).
- Anything you'd want a CHECK / UNIQUE / FK on.

If using JSON, document the shape elsewhere (TypeScript type, JSON Schema in `db/schemas/`).

### 5.4 Soft delete
- `deleted_at timestamptz NULL` field.
- All queries scope `WHERE deleted_at IS NULL` (preferably via default scope / ORM concern).
- Partial unique indexes (`UNIQUE (tenant_id, slug) WHERE deleted_at IS NULL`) to allow slug reuse after deletion.
- Hard-delete after retention period (GDPR / privacy).

### 5.5 Audit
For audit-required tables:
- `created_at`, `updated_at`, `created_by`, `updated_by`.
- Separate `<entity>_versions` table with full row snapshots if temporal queries needed.
- Triggers preferred over app-level audit (closer to truth).

### 5.6 Tenancy
- `tenant_id` on every tenant-scoped table.
- `NOT NULL` + FK + indexed.
- Composite unique constraints include `tenant_id` (`UNIQUE (tenant_id, email)`).
- Default scope in ORM + WHERE-clause discipline in [[data-flow-net]].

### 5.7 Denormalization choices
Denormalize when:
- Read pattern requires data that would be a 5+ JOIN to assemble.
- Read frequency >> write frequency.
- Source of truth still single-write, projected to denormalized copy via app or trigger.

Examples:
- `orders.customer_name` cached from customers — accept it goes stale, refresh on customer write.
- `posts.comment_count` counter — increment on write, periodically reconcile.

Don't denormalize for theoretical perf; measure first via [[perf-deep-dive]].

### 5.8 Partitioning (if applicable)
For high-volume tables (>100M rows or fast growth):
- Range partition by `created_at` (events, logs).
- Hash partition by `tenant_id` for very large multi-tenant.
- Document partition pruning patterns; queries must include partition key.

## 6. Migration sketch

```sql
-- 20260513120000_create_orders.sql
-- Reversible: yes
-- Online: yes (table create + zero-fill backfill)

CREATE TABLE orders (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id     uuid NOT NULL REFERENCES tenants(id),
  customer_id   uuid NOT NULL REFERENCES customers(id),
  status        text NOT NULL DEFAULT 'pending'
                CHECK (status IN ('pending', 'paid', 'fulfilled', 'cancelled', 'refunded')),
  amount_cents  bigint NOT NULL CHECK (amount_cents > 0),
  currency      text NOT NULL DEFAULT 'USD' CHECK (length(currency) = 3),
  metadata      jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  deleted_at    timestamptz
);

CREATE INDEX idx_orders_tenant_created ON orders (tenant_id, created_at DESC);
CREATE INDEX idx_orders_customer_created ON orders (customer_id, created_at DESC);
CREATE INDEX idx_orders_status_pending ON orders (id) WHERE status = 'pending';
CREATE INDEX idx_orders_metadata ON orders USING gin (metadata);

CREATE TRIGGER orders_updated_at
  BEFORE UPDATE ON orders
  FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();
```

## 7. Open questions
- [ ] <decision needed before migration>

## 8. Out of scope
- <related but deferred>
```

## Stack-aware variations

### Postgres (default)
- `uuid` / `timestamptz` / `jsonb` / `text` (over `varchar(N)` unless length matters semantically).
- `gen_random_uuid()` or `uuid_generate_v7()` (extension).
- Partial / expression indexes available.

### MySQL
- `BINARY(16)` for UUIDs (or `CHAR(36)`).
- `DATETIME(6)` (no tz — store UTC by convention, document).
- `JSON` column (less rich than jsonb).
- No partial indexes — use trigger-maintained shadow columns.

### SQLite
- Single-writer; design for that.
- `TEXT` for everything practical.
- `WITHOUT ROWID` for narrow PK tables.

### Mongo
- Document boundary = transaction boundary; design entities to fit.
- Embed when always-read-together; reference when independent lifecycle.
- Per-tenant collection vs tenant_id field — usually field, indexed.

## Anti-patterns the designer refuses

1. **Money as `float`** — P0 reject.
2. **Naive datetime in multi-region app** — P0 reject (must be `timestamptz` / UTC + explicit tz handling).
3. **Polymorphic association** (single FK pointing at any of N tables) — flag as fragility; recommend explicit FK per relation.
4. **Boolean flag explosion** (`is_active`, `is_deleted`, `is_archived`, `is_published`) — recommend `status` enum.
5. **EAV (entity-attribute-value)** — flag heavily; recommend jsonb or proper schema.
6. **One giant table** (`events` / `data`) — flag; recommend domain-driven split.
7. **No FK constraints "for performance"** — reject; integrity > marginal perf.
8. **Composite PK without thought** — usually surrogate ID + unique constraint is cleaner.

## Decisions to surface (not auto-decide)

| Decision | Default | When to deviate |
|---|---|---|
| ID type (UUID / int) | UUIDv7 | int for reference tables |
| Soft vs hard delete | soft | hard for audit-irrelevant transient data |
| Audit columns | created_at + updated_at | + created_by + updated_by + versions for sensitive |
| Tenancy | tenant_id column | schema-per-tenant for hard isolation needs |
| JSON columns | only for sparse / extensible | none if shape stable |
| Partitioning | none | when >100M rows or compliance |

Surface as open questions if spec doesn't decide.

## Token budget

| Scope | Tokens |
|---|---|
| 1–3 entities | 10–25k |
| 4–10 entities | 25–55k |
| Domain redesign | 55–100k |

## Integration with other tools

- Inputs: [[full-spec-rewriter]] / [[trd-writer]] / [[prd-writer]].
- Output: design doc + migration SQL → `.invisible/data-models/<feature-slug>.md`.
- Feeds [[openapi-generator]] (response shapes derived from entity).
- Feeds [[db-net]] (live migration-time enforcement).

## CLAUDE.md hooks

Reads section A (db_engine, tenancy_model, audit_policy, id_scheme), B (project conventions — naming, indexing rules), C (accepted exceptions).
Writes design doc + migration sketch. Doesn't apply migration.

## Failure modes

- Spec is ambiguous on tenancy / lifecycle / identity → emit "open questions" block; don't guess.
- Existing schema conflicts with proposed addition → flag conflict; recommend [[refactor-architect]] pass.
- Domain proposal violates a stated invariant (e.g., money as float) → reject with reason.

## Related

[[db-net]] · [[data-flow-net]] · [[full-spec-rewriter]] · [[trd-writer]] · [[architecture-designer]] · [[openapi-generator]] · [[refactor-architect]]
