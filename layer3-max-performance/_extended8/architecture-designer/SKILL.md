---
name: architecture-designer
description: User-opt-in pass that designs a system architecture from a TRD/PRD — bounded contexts, service decomposition (or deliberate non-decomposition), data ownership, sync vs async boundaries, technology choices with rationale, and trade-offs vs alternatives. Refuses cargo-cult. Outputs an ADR-style design doc. ≤1 active L3/turn.
layer: 3
group: _extended8
enabled_default: false
opt_in: true
cli: "/invisible design [--input <prd_or_trd>] [--mode greenfield|extend|migrate]"
caps:
  body_lines: 400
recommender:
  min_score: 4.0
  triggers: ["design the architecture", "system design", "new service architecture", "design review", "should this be a microservice", "monolith or services"]
---

# architecture-designer

Designs a system architecture from a need / PRD / TRD. Produces an ADR-style decision document with alternatives weighed. Distinct from [[refactor-architect]] (works within existing code) and [[full-spec-rewriter]] (designs one feature).

## When to run

- New service / system / major capability — needs a coherent design.
- Existing system needs extension that may cross a structural boundary.
- Migration from one architecture to another (monolith→services or vice versa).
- Pre-build decision when team disagrees on shape.

## When NOT to run

- Single feature within established architecture (full-spec-rewriter fits).
- Refactor of existing code (refactor-architect fits).
- "We need microservices" with no requirements driving it — refuse, ask what problem.

## Modes

| Mode | When |
|---|---|
| `greenfield` | Brand new system; no constraints from existing code |
| `extend` | Add capability to existing system; respect/extend current shape |
| `migrate` | Move from old architecture to new; sequence + rollback critical |

## Output template

```markdown
# Architecture Design — <system name>
INVISIBLE architecture-designer · mode=<mode> · <date>

## 0. Summary
**System**: <one-line>
**Decision**: <chosen architecture in one line>
**Why not alternative**: <one-line>
**Risk**: L/M/H + <main concern>

## 1. Drivers (forces shaping the design)
**Functional**:
- <requirement>
- <requirement>

**Non-functional**:
- Scale target: <RPS / data volume / user count>
- Latency target: <p95 budget>
- Availability target: <SLO>
- Team shape: <N engineers, <area> background, <growth plans>>
- Compliance: <SOC2 / PCI / HIPAA / data-residency>
- Budget envelope: <cost target>

**Constraints**:
- Existing tech stack: <list>
- Existing data ownership: <list>
- Deadline pressure: <yes/no>

## 2. Bounded contexts
Identify the distinct domains.

| Context | Owns | Doesn't own |
|---|---|---|
| <name> | <entities, capabilities> | <related but separate> |

**Why these boundaries**: <explanation tied to functional drivers, team shape, change frequency>

## 3. Architecture options compared

### Option A — <name>
**Shape**: <text diagram or bullet>
**Pros**: <bullet>
**Cons**: <bullet>
**Cost**: <relative>
**Effort to build**: <S/M/L>
**Effort to operate**: <S/M/L>
**Risk**: <L/M/H>

### Option B — <name>
...

### Option C — <name>
...

## 4. Recommendation
**Choose**: Option <X>
**Rationale**: <2–4 sentences citing drivers from §1>
**What we accept by choosing this**: <trade-offs explicit>
**What would change our mind**: <conditions that flip the decision>

## 5. Design detail (chosen option)

### 5.1 Components
- <component name> — <role>
  - Owns: <data>
  - Tech: <language, framework, key libs>
  - Why this tech: <rationale, not cargo-cult>

### 5.2 Interactions
```
[Client] →HTTP→ [API Gateway] →gRPC→ [Service A] →SQL→ [Postgres]
                                       ↓ publish event
                                     [Bus] →subscribe→ [Service B]
```

Sync vs async boundaries marked. Each arrow has a contract.

### 5.3 Data ownership
| Entity | Owner | Replicated to | Consistency |
|---|---|---|---|
| <entity> | <service> | <where, why> | strong / eventual |

### 5.4 Persistence choices
| Need | Choice | Why |
|---|---|---|
| Transactional core | Postgres | ACID + ops experience |
| High-write counters | Redis | Sub-ms; eventual durability acceptable |
| Object blobs | S3 | Cost, durability |
| Search | … | … |

### 5.5 Communication patterns
- **Sync**: when result needed in-line (user-facing read).
- **Async (event)**: when consumers can lag; decouples lifecycle.
- **Async (queue)**: when work is offloaded with retry.
- **Batch**: when latency irrelevant; cost / throughput primary.

### 5.6 Failure model
For each component:
- What if it's down: <degraded behavior>
- What if it's slow: <timeout / circuit breaker>
- What if it's lying: <validation / reconciliation>

### 5.7 Capacity sketch
- Read RPS: <X>, served by <component>
- Write RPS: <X>, served by <component>
- Storage growth: <X GB/month>
- Compute baseline: <N instances / cores>

## 6. Cross-cutting concerns
- **Auth/authz**: <approach>
- **Multi-tenancy**: <approach>
- **Observability**: <log/metric/trace strategy>
- **Deploy**: <unit of deploy, pipeline shape>
- **Config + secrets**: <approach>
- **Testing**: <unit / integration / e2e split>

## 7. Migration plan (if `extend` or `migrate`)
- Sequence of changes that keep system live throughout
- Strangler-fig steps where applicable
- Data migration: online, reversible
- Rollback plan per step
- Sunset of old components

## 8. Non-decisions (explicitly deferred)
- <thing> — defer to <when / trigger>

## 9. ADR series
This design generates ADRs to record:
- ADR-001: choice of <X>
- ADR-002: choice of <Y>
- ADR-003: bounded context split

(Each ADR ≤1 page, in `.invisible/adrs/`.)

## 10. Open questions
- [ ] <question>

## 11. Review sign-offs
- [ ] Architecture review
- [ ] Security review (recommend [[security-auditor]] threat model pass)
- [ ] Ops review
- [ ] Cost review

## 12. References
- PRD / TRD inputs
- Related ADRs
- Industry references (Fowler / Martin / vendor docs) — cite, don't copy
```

## Anti-cargo-cult rules

1. **No "because X uses it"** without local justification. Stripe uses Kafka; that doesn't mean we should.
2. **No microservices without forces** (team boundary, scale boundary, deploy-cadence boundary, language boundary). Modular monolith first.
3. **No new DB engine without a query pattern that breaks the current one.** ACID is good; abandon it deliberately.
4. **No event-sourcing for CRUD.** Event sourcing has heavy operational cost; reserve for genuine audit/temporal needs.
5. **No serverless for steady-state high-RPS.** Lambda is a great choice for spiky, not for sustained.
6. **No "we'll need to scale to 1M users" without traffic evidence.** Design for 10× current, not 1000×.

## Decision-quality heuristics

- Decisions that constrain other decisions are higher-priority (deploy unit constrains language constrains library).
- Reversible decisions (library choice within a service) — decide fast.
- Irreversible decisions (DB engine, service split) — decide slowly with explicit alternatives.
- "Why not X" must be answered for every X that the team would reasonably ask about.

## Bounded-context discipline

Boundaries that hold across change waves:
- Different rates of change (low-churn domain ↔ high-churn domain)
- Different teams (Conway's Law)
- Different scale profiles
- Different data shapes / consistency needs
- Different compliance scopes

Boundaries that don't hold:
- Layer boundaries (controller / service / model) — these are within a context, not between.
- Resource type (one service per entity) — overengineering.
- Performance (extracting "the fast bit") — usually solved by infra not architecture.

## Migration patterns (migrate mode)

- **Strangler fig**: route new endpoints to new system; old system shrinks over time.
- **Branch-by-abstraction**: in-place; abstraction in old code routes to old or new impl; flip per use.
- **Parallel run**: both systems answer; compare; cut over.
- **Big-bang**: discouraged; surface explicitly with risk + revert plan if proposed.

## Stack-aware defaults

Architecture-designer consults [[stack-adapter]] for "what's the org's typical stack" — defaults to that unless drivers say otherwise. New tech requires explicit justification.

## Token budget

| Mode | Tokens |
|---|---|
| greenfield | 25–60k |
| extend | 20–40k |
| migrate | 40–80k |

## Failure modes

- Drivers absent / unclear → refuse design; route to [[prd-writer]] / [[trd-writer]] first.
- Team strongly wants a specific choice but drivers don't support it → emit the design with the team's choice + a section "drivers that don't support this — proceed knowingly."
- Greenfield with no scale information → use conservative defaults; flag for revisit at validation.

## Integration with other tools

- Inputs: [[prd-writer]] / [[trd-writer]] artifacts.
- Outputs: ADR series + design doc → `.invisible/designs/<system-slug>.md`.
- Feeds [[full-spec-rewriter]] (per-feature specs within the design), [[refactor-architect]] (migration steps if `migrate` mode).

## CLAUDE.md hooks

Reads section A (stack defaults), B (org-wide architectural rules — "we use Postgres unless you have a reason"), C (accepted deviations).
Writes design + ADRs.

## Related

[[trd-writer]] · [[prd-writer]] · [[refactor-architect]] · [[full-spec-rewriter]] · [[security-auditor]] · [[architecture-advisor]] · [[data-model-designer]]
