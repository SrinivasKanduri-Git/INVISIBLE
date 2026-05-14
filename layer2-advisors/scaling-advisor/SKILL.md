---
name: scaling-advisor
description: Silent advisor that surfaces capacity/throughput risks before they ship. Watches list endpoints, fan-out, hot keys, unbounded loops, sync-where-async-belongs, and missing pagination. Severity-tiered notes; max 5/turn (P1 exempt). Reads plan + output; emits suggestions, never blocks.
layer: 2
enabled_default: true
caps:
  body_lines: 150
  notes_per_turn: 5
triggers:
  signals: ["list endpoint", "GET /xxx", "fetch all", "for each", "fan-out", "broadcast", "report", "export", "background job processing N records", "search", "aggregation", "join"]
  load_when: any-L1-skill-loaded OR output contains list/aggregate operation
suppress_when:
  - L1 already flagged the same line as P1 (no duplicate)
  - explicit project annotation `// scaling-ok: <reason>`
---

# scaling-advisor

Reads the plan and the code output; raises capacity / throughput concerns the developer hasn't priced in yet. Silent — emits notes only, no blocking.

## What it watches

| Signal in plan/output | Concern |
|---|---|
| `findAll` / `Model.all` / `select * from t` with no `limit` | Will OOM when table grows |
| List endpoint with no pagination | Latency spike + memory hit |
| `forEach` calling async DB/HTTP inside | Sequential when parallelizable; or fan-out with no concurrency cap |
| Nested loops over user-scoped data | Quadratic / N×M |
| Sync send inside request thread (email, webhook, report build) | Latency tail + downstream timeout |
| Broadcast to room with no size cap | O(N) per event |
| Hot-key cache invalidation on every write | Cache stampede risk |
| Counter incremented in DB on user action with no batching | Lock contention at scale |
| Cron job iterating "all rows" | Grows linearly forever |
| Aggregate query without index hint | Sequential scan slope |

## Note format

```
[scaling-advisor] PX: <one-sentence finding>. At ~<scale>, <consequence>. Suggest: <fix>.
```

Pattern:
- **what** the code does
- **scale threshold** where it breaks (rows / RPS / fan-out width)
- **suggested fix** (one option, concrete)

## Severity

| Tier | When |
|---|---|
| **P1** | Code will break before 1K users / 100K rows. Synchronous expensive operation in request thread. Unbounded loop. |
| **P2** | Code will degrade between 10K–100K rows / 100 RPS. Missing pagination. Sequential fan-out. |
| **P3** | Future concern. Hot path will need caching at 100K+ users. Style note. |

## Note examples

```
[scaling-advisor] P1: `User.all.each { ... }` in /admin/cleanup will OOM beyond ~50k users. Suggest: `find_each(batch_size: 1000)`.

[scaling-advisor] P2: GET /api/posts returns full list, no `limit`/cursor. At 1k+ rows, response >500KB. Suggest: cursor pagination per api-net.

[scaling-advisor] P2: Webhook fan-out via `subscribers.forEach(await send(...))` runs sequentially. 50 subs × 200ms = 10s. Suggest: `Promise.all` with concurrency cap (`p-limit(10)`).

[scaling-advisor] P3: Counter `posts.likes_count` incremented per like via UPDATE. At 100+ likes/sec, row-lock contention. Suggest: queue + batch-flush every 1s, or counter-cache pattern.
```

## Anti-noise rules

1. **No duplicate of an L1 finding.** If api-net already flagged "no pagination" as P1, skip.
2. **No "future concerns" without a concrete threshold.** "This won't scale" without a number = noise.
3. **Bounded fan-out is fine.** `tenants.forEach(async ...)` for 10 known tenants is not a scaling problem.
4. **Single-user admin tools exempt** when annotated (`// admin-only, runs hourly, ok`).
5. **Note budget**: max 5/turn (P1 always allowed); P2/P3 drop oldest if over.
6. **Suppress on explicit ack**: `// scaling-ok: report runs nightly, table <10k` — read it, don't repeat the warning.

## Plan-time vs output-time

| Phase | Triggers |
|---|---|
| **Plan-time** (before code) | Plan mentions "list of X", "loop over Y", "broadcast to Z", "export every record" |
| **Output-time** (after code) | Pattern scan over diff: `findAll`/`find_each` missing, `for ... in await`, sync external call in handler |

Plan-time is preferred — it shapes the design. Output-time is the safety net.

## Stack-aware thresholds

Reads [[stack-adapter]] for stack defaults:
- Rails: `find_each` / `in_batches` recommended at 5k+ rows
- Django: `iterator()` over `all()` at 10k+ rows
- Node: stream / cursor for 100MB+ result sets
- Postgres: warn on `SELECT *` over tables >100k rows without index plan

## CLAUDE.md hooks

Reads section A: `expected_scale` (users / RPS / row counts) — calibrates thresholds.
Reads section B: project scaling rules (e.g., "all admin tools assume <1k rows").
Reads section C: exempted endpoints (e.g., "internal export, runs in maintenance window").

## Interaction with L1

- Defers to api-net on pagination shape.
- Defers to db-net on indexing.
- Defers to async-ops-net on retry/concurrency caps.
- Defers to data-flow-net on cache stampede defense.

scaling-advisor surfaces the **gap** between what L1 enforces and what the workload requires — not the fix L1 already mandates.

## Related

[[api-net]] · [[db-net]] · [[async-ops-net]] · [[data-flow-net]] · [[realtime-net]] · [[architecture-advisor]] · [[cost-advisor]]
