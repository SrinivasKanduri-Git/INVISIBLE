---
name: perf-deep-dive
description: User-opt-in performance investigation pass. Profiles a hot path (endpoint, query, render, job) — flame-graph-style breakdown, bottleneck identification, layered fix options (caching / query / index / batch / async / topology), measure-before/measure-after discipline. Refuses speculation; insists on numbers. ≤1 active L3/turn.
layer: 3
group: _extended8
enabled_default: false
opt_in: true
cli: "/invisible perf [--target <route|query|job|render>] [--baseline <measurement>]"
caps:
  body_lines: 400
recommender:
  min_score: 4.5
  triggers: ["slow", "p95 high", "latency", "performance issue", "profile this", "why is X slow", "memory leak", "OOM", "CPU pegged"]
---

# perf-deep-dive

Performance investigation pass. Refuses to optimize without measurement. Produces a profile, identifies the actual bottleneck, proposes a fix ladder (cheapest correct fix first), measures after, reports delta.

## When to run

- A real measurement says X is slow (p95 above SLO, user complaint with HAR, log evidence).
- Pre-launch capacity concern with concrete scale target.
- Cost-driven (CPU/memory bill spiking — see also [[cost-advisor]]).
- Post-incident analysis: "we paged on latency at 14:00 — why?"

## When NOT to run

- "I think this might be slow" with no measurement → refuse, ask user to measure first (return a one-liner: how to measure).
- Tiny endpoint with negligible call volume → spend isn't worth the dive.
- Performance is fine and a feature is desired → don't optimize prematurely.

## The "no measurement, no fix" rule

A perf fix without before/after numbers is FUD. Every perf-deep-dive run produces:

1. **Baseline measurement** before any change.
2. **Hypothesis** about bottleneck location.
3. **Targeted profile** to confirm hypothesis.
4. **Proposed fixes** ranked by `delta-per-effort`.
5. **After-measurement** to confirm fix worked.

If user supplied no baseline, the first thing the dive does is help them gather one.

## Output artifact

```markdown
# Perf Deep Dive — <target> — <date>
INVISIBLE perf-deep-dive

## 0. Summary
**Target**: <endpoint / query / job / render>
**SLO**: <target p50/p95/p99>
**Current**: p50 <Xms>, p95 <Yms>, p99 <Zms> (<sample size>)
**Bottleneck**: <one-line>
**Proposed fix (top recommendation)**: <what + expected delta>
**Expected post-fix**: p95 <est ms>

## 1. Baseline measurement
**How measured**: <APM, load test, prod sample, micro-bench>
**Sample size**: <N requests / N runs>
**Conditions**: <data volume, concurrency, cold/warm>

```
p50: <ms>
p90: <ms>
p95: <ms>
p99: <ms>
avg: <ms>
errors: <%>
throughput: <rps>
```

## 2. Breakdown (where time goes)
**Top spans by total time**:
```
DB queries:        45%  (N queries, slowest <ms>)
External API:      30%  (vendor X, <ms>)
Render/template:   12%  (<ms>)
Serialization:      8%  (<ms>)
Other:              5%
```

**Hottest single call**: `<location>` — <ms> per invocation, called <N>× per request.

## 3. Bottleneck analysis

### Primary bottleneck
**Location**: `<file>:<line>` (or query / external call)
**Mechanism**: <why it's slow>
**Evidence**: <profile data, query plan, trace>

### Secondary (if any)
**Location**: ...

## 4. Fix ladder (cheapest correct fix first)

### Option A — <name> (recommended)
**What**: <change>
**Why this first**: <delta-per-effort>
**Effort**: <S/M/L>
**Expected delta**: <ms or %>
**Risk**: <L/M/H + reason>
**Reversibility**: <flag-controlled / data-shape-safe>

### Option B — <name>
...

### Option C — <name> (heavier, if A+B insufficient)
...

## 5. Anti-patterns to avoid
- <thing user might be tempted to do that won't actually help>

## 6. After-measurement (post-fix)
**Same conditions as baseline**.

```
p50: <ms> (Δ -X%)
p95: <ms> (Δ -Y%)
```

**Verdict**: <hit SLO / partial / need next-rung fix>

## 7. Follow-ups
- <Next bottleneck visible only after fix landed — defer>
- <Monitor: alert on regression>
- <Test: load test added to CI>

## Run metadata
- Token used: <N>
- Profiles attached: <yes/no, location>
```

## Bottleneck mental model

When investigating, the dive walks the call in time-order and identifies dominant cost. Common bottleneck classes (rough order of frequency):

| Class | Symptom | Typical fix |
|---|---|---|
| N+1 query | DB calls scale with list size | DataLoader / `include`/`select_related` / single JOIN |
| Missing index | Sequential scan on >10k rows | Add index; verify with EXPLAIN |
| Sync external call | Long tail; vendor latency dominates | Cache / async / circuit breaker / parallel |
| Large payload serialization | Render dominates DB-fast endpoints | Reduce shape; cursor-paginate; conditional fields |
| Over-fetch | Selecting columns you don't use | `select` allowlist |
| Cold cache | Cache miss spikes after deploy | Pre-warm, stale-while-revalidate |
| Lock contention | Tail latency under concurrency | Reduce critical section, advisory locks, batch flush |
| GC / memory pressure | Periodic pauses | Reduce allocation, pool, tune GC |
| CPU-bound logic in request thread | Single-request slow regardless of load | Offload to worker / use C extension / cache result |
| Render in request thread | Big templates / SSR | Stream, defer, cache |
| Round-trip stacking | Many sequential ops each <50ms | Batch / pipeline |

## Profile method per stack

### Rails
- `rack-mini-profiler` for dev visibility
- `bullet` for N+1
- `Skylight` / `Scout APM` / `New Relic` for prod
- `EXPLAIN ANALYZE` on slow queries

### Django
- `django-debug-toolbar` for dev
- `silk` for profiling
- `pg_stat_statements` for top queries

### Node
- `clinic.js` (flame, doctor, bubbleprof)
- `0x` for flame
- APM (Datadog / New Relic / Honeycomb tracing)
- Async hooks for promise tracing

### Python
- `py-spy` (no instrumentation needed)
- `cProfile` + `snakeviz`
- `line_profiler` for line-level

### Frontend
- Lighthouse for end-user
- Chrome DevTools Performance + Memory tabs
- React DevTools profiler
- Core Web Vitals as SLO

### Database
- `EXPLAIN (ANALYZE, BUFFERS)` — Postgres
- `EXPLAIN FORMAT=JSON` — MySQL
- `pg_stat_statements` / `slow query log`
- Index hit ratio, cache hit ratio

## Fix-ladder discipline

Always present **cheapest correct fix first**. Heuristic order:

1. **Index / query fix** (no infra change)
2. **Batching / N+1 fix** (no infra change)
3. **Caching** (Redis already present)
4. **Defer to async** (queue already present)
5. **Architecture change** (new infra, materialized view, denormalization)
6. **Rewrite in faster language / service split** (last resort)

Each rung 5–10× more effort than previous. Don't propose rung 5 when rung 1 fixes it.

## Anti-speculation rules

1. **No fix without measurement.** "This will probably help" without numbers = decline.
2. **No multi-rung jumps without justification.** If rung 1 not tried, ladder starts at rung 1.
3. **Big-O claims need evidence at the actual N.** "O(n²)" doesn't matter at n=50.
4. **Microbenchmarks ≠ system measurements.** A `for` loop benchmark proves nothing about request latency.
5. **Premature distribution is anti-perf.** Splitting into microservice adds network hops. Don't propose until single-process options exhausted.

## Token budget

| Depth | Tokens |
|---|---|
| Single endpoint / query | 15–35k |
| Multi-endpoint feature | 40–80k |
| Whole-service deep dive | 80–150k |

## Output rule

If the bottleneck can't be confirmed (insufficient profiling data, prod-only behavior, intermittent), the dive's output is a **measurement plan**, not a fix. "Run this to gather data" is a valid result.

## Failure modes

- No baseline + can't be measured (no APM, can't reproduce locally) → emit measurement-setup plan as output.
- Bottleneck is in vendor / external system not under our control → propose isolation (cache, async, fallback) rather than chasing vendor.
- Performance is acceptable and ask is "make it faster anyway" → push back; recommend defer.

## Integration with other tools

- Often run after [[deep-codebase-mapper]] (knows entrypoints) and before [[refactor-architect]] (perf may motivate refactor).
- Feeds [[cost-advisor]] (perf fix often saves money) and [[prod-readiness-audit]] (latency budget verified).
- Findings → `.invisible/perf/<target-hash>.md`.

## CLAUDE.md hooks

Reads section A (stack, APM, DB engine), B (SLOs), F (perf incident history).
Writes profile artifact + post-fix delta record.

## Related

[[scaling-advisor]] · [[cost-advisor]] · [[db-net]] · [[api-net]] · [[deep-codebase-mapper]] · [[refactor-architect]]
