---
name: trd-writer
description: User-opt-in pass that produces a Technical Requirements Document (TRD). Audience is engineers across teams who need to integrate, depend on, or operate the system. Heavier on interfaces, contracts, failure modes, SLAs than full-spec-rewriter (which is a feature spec). Used for new services / shared infrastructure / public APIs. ≤1 active L3/turn.
layer: 3
group: _extended8
enabled_default: false
opt_in: true
cli: "/invisible trd [--input <prd_or_spec>] [--mode service|library|api]"
caps:
  body_lines: 400
recommender:
  min_score: 4.0
  triggers: ["TRD", "technical requirements", "tech spec", "internal API contract", "service contract", "platform doc", "design review doc"]
---

# trd-writer

Writes a Technical Requirements Document for engineering consumers. The artifact you give to other teams that need to call, depend on, or operate your service. Distinct from:

- [[prd-writer]] — product side, PM audience.
- [[full-spec-rewriter]] — feature implementation spec, single-feature engineer audience.
- [[architecture-designer]] — system design from scratch.
- **trd-writer**: the contract + operational guarantees others rely on.

## When to run

- Building a new service / shared library / public API that other teams will consume.
- Standardizing an interface for cross-team work.
- Going through formal design review (architecture council, eng-wide review).
- Documenting a contract that already exists but isn't written down.

## When NOT to run

- Single-team feature (full-spec-rewriter fits).
- Throwaway internal tool with no integrators.
- Marketing-flavored doc (prd-writer fits).

## Modes

| Mode | When |
|---|---|
| `service` | Long-running service: covers SLOs, deploy model, on-call, telemetry |
| `library` | Versioned package: covers semver, compat, deprecation policy |
| `api` | Public/partner API: covers auth, rate limits, versioning, ToS-adjacent guarantees |

## Output template

```markdown
# TRD — <system name>
INVISIBLE trd-writer · mode=<mode> · <date> · v<n>

## 0. Summary
**What it does**: <one-line>
**Who consumes it**: <team list / integrators>
**Why it exists**: <one-line>
**Status**: design / alpha / GA / deprecated
**Owner**: <team> · <slack channel> · <on-call rotation>

## 1. Problem + scope
**Problem**: <what need motivated this>
**In scope**: <bullet>
**Out of scope**: <bullet>
**Non-goals**: <bullet>

## 2. Stakeholders
| Role | Team | Concern |
|---|---|---|
| Owner | <team> | Build + operate |
| Consumer | <team> | Integration shape |
| Reviewer | <team> | Architectural fit |

## 3. Interface contract

### 3.1 Surface area
- **Endpoints** (if API): `GET/POST /...`
- **Methods** (if library): `library.method(...)`
- **Topics** (if event-driven): `<topic.name>`
- **CLI commands** (if tool): `<cmd>`

### 3.2 Schema (per surface element)
```
POST /orders
Request:
  { customer_id: string, items: [{sku: string, qty: int}], idempotency_key: string }
Response (200):
  { id: string, status: "pending"|"paid", total: integer_minor_units, currency: string }
Errors:
  400 - validation
  409 - idempotency conflict
  422 - business rule violation
  503 - downstream unavailable (retryable)
```

### 3.3 Auth model
- Method: <session / JWT / mTLS / API key / OAuth>
- Scopes / roles required per endpoint
- Token lifetime, rotation

### 3.4 Versioning
- Scheme: <semver / date-versioned / header-versioned>
- Stability levels: alpha / beta / stable / deprecated
- Deprecation policy: <notice period, sunset signaling, header X-Deprecation>
- Breaking-change rules: <when allowed, how communicated>

### 3.5 Idempotency + safety
- Which mutations require idempotency key
- Idempotency window (24h / 7d / forever)
- Replay behavior

### 3.6 Pagination + filtering (if applicable)
- Style: cursor / offset / keyset
- Page-size limits

### 3.7 Rate limits
- Per-caller-id, per-IP, per-endpoint
- 429 shape + `Retry-After`

## 4. SLOs + SLIs (service mode)

| SLI | Target (SLO) | Error budget |
|---|---|---|
| Availability | 99.9% | 43m / month |
| p95 latency `/orders` | <250ms | per quarter |
| Error rate (5xx) | <0.1% | … |

**Measurement**: <how, dashboard link>
**Alert thresholds**: <page-worthy>

## 5. Failure modes + degradation

| Failure | Symptom | Behavior | Detection | Recovery |
|---|---|---|---|---|
| DB primary down | 5xx on write | Read-only mode, queued writes | Alert <name> | Failover |
| Vendor X down | 503 on charge | Circuit open, retry queue | Alert <name> | Vendor restoration |
| Rate-limit storm | 429 surge | Drop oldest in queue | <metric> | Backoff |

## 6. Data model (high level)
- Owned entities: <list>
- Source-of-truth split (this system vs others)
- Retention: <by entity>
- Deletion / GDPR cascade

## 7. Dependencies
- Upstream: <services / vendors we call>
- Downstream: <services / consumers that call us>
- Infra: <DB, cache, queue, blob>

## 8. Deployment + operations
- Deploy cadence: <continuous / weekly / on-demand>
- Rollback: <flag-based / re-deploy>
- Capacity model: <RPS supported, scale strategy>
- Runbook: <link / where to be written by [[runbook-generator]]>
- On-call: <rotation, escalation path>

## 9. Observability
- Logs: <structured fields, location, retention>
- Metrics: <list of primary metrics>
- Traces: <coverage, sampling>
- Dashboards: <links>
- Alerts: <page vs ticket>

## 10. Security
- Threat model: <link to [[security-auditor]] artifact>
- Data classification: <public / internal / sensitive / regulated>
- Compliance scope: <SOC2 / PCI / HIPAA / GDPR>
- Audit log: <what's logged, retention>

## 11. Cost model
- Per-request cost (compute + DB + egress): <estimate>
- Scaling cost curve (linear / step / saturation)
- Cost owner: <team>

## 12. Compatibility (library / API mode)
- Supported language / client SDKs
- Backwards-compat policy
- Forward-compat (new fields tolerated by old clients)
- Test matrix

## 13. Migration / adoption plan
- Phase 0: <internal / staging>
- Phase 1: <initial consumers>
- Phase 2: <wider rollout>
- Sunset of predecessor system (if any)

## 14. Open questions
- [ ] <question> — owner — needed-by

## 15. Decisions log (append-only)
| Date | Decision | Rationale | Decided by |
|---|---|---|---|

## 16. Review sign-offs
- [ ] Architecture review — <reviewer> — <date>
- [ ] Security review — <reviewer> — <date>
- [ ] Ops review — <reviewer> — <date>

## 17. References
- Related PRD: <link>
- Related ADRs: <link>
- Existing docs: <link>
```

## Question heuristic — what to ask

Cap at 10 questions. Defaults provided; user can `ack defaults`.

| Dimension | Question if missing |
|---|---|
| SLO targets | What's the availability + latency target? (default: 99.9%, p95 <500ms) |
| Idempotency | Which mutations need it? (default: all external-side-effect mutations) |
| Versioning scheme | URL / header / accept-version? (default: URL major version, header minor) |
| Auth | Caller identity model? (default: same as parent system) |
| Rate-limit model | Per-caller, per-endpoint? (default: per-caller token bucket) |
| Deprecation policy | Notice period? (default: 90 days deprecated → 90 days sunset) |
| Data retention | Per entity? (default: 365 days, GDPR-deletion on request) |
| On-call team | Who pages? (default: owning team) |
| Cost owner | Whose budget? (default: owning team) |
| Compat scope | How many client versions supported? (default: current + previous major) |

## Anti-bloat rules

- Don't pad with hypothetical sections (e.g., "i18n" if irrelevant).
- "Out of scope" is mandatory.
- Each section short, dense, scannable.
- Decisions log starts empty; append on each future revision.

## Hand-off

- TRD approved → engineering builds per `[[full-spec-rewriter]]` ticketed slices.
- TRD has open questions → don't approve until answered.
- TRD reviewers: explicitly identify (arch, security, ops, consumer).

## Token budget

| Mode | Tokens |
|---|---|
| library | 10–25k |
| api | 15–35k |
| service | 25–60k |

## Failure modes

- Input is product-shaped (not enough technical detail) → run [[prd-writer]] first or supplement.
- Multiple consumers with conflicting needs → emit "conflict matrix" section and require resolution before approval.
- Existing system being documented retroactively → mode `service` with "current state" focus; mark gaps as TODOs.

## CLAUDE.md hooks

Reads section A (stack, infra), B (project rules), C (exceptions).
Writes to `.invisible/trds/<system-slug>-v<n>.md`. Version-bump on edit.

## Related

[[prd-writer]] · [[full-spec-rewriter]] · [[architecture-designer]] · [[openapi-generator]] · [[runbook-generator]] · [[security-auditor]] · [[data-model-designer]]
