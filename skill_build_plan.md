# INVISIBLE — Build Plan

> Design document and build roadmap for **INVISIBLE**, a 3-layer autoloading safeguard skillset for AI coding agents.
>
> This is the canonical source of truth for the project's architecture. It captures both *what shipped in v0.7.0* and *what is deferred to v0.8 and beyond*. Every section carries a status marker so readers can tell design intent from completed work.

| Field | Value |
|---|---|
| Plan revision | v6 (post-v0.7 release) |
| Aligned with | v0.7.0 (released 2026-05-14) |
| Successor revision | v7 — written after v0.8 measurement run lands |
| Maintainer | [@SrinivasKanduri-Git](https://github.com/SrinivasKanduri-Git) |

**Status legend** used throughout this document:

| Marker | Meaning |
|---|---|
| ✅ **Shipped** | Implemented and present in v0.7.0. |
| 🧪 **In test** | Built and exercised; gating logic applied by hand (no runtime). |
| ⏳ **Deferred to v0.8** | Designed; implementation depends on the executable runtime. |
| 📐 **Design only** | Intent locked; no code path yet (and none planned for v0.7). |

---

## Contents

0. [Mission](#0-mission)
1. [Skill inventory](#1-skill-inventory)
2. [DECIDER — trigger signals and routing](#2-decider--trigger-signals-and-routing)
3. [DECIDER decision flow](#3-decider-decision-flow)
4. [Pattern-scan budget](#4-pattern-scan-budget)
5. [Sprint plan and current status](#5-sprint-plan-and-current-status)
6. [Anti-bloat caps](#6-anti-bloat-caps)
7. [Token economics](#7-token-economics)
8. [self-learner + rule-validator](#8-self-learner--rule-validator)
9. [Force-load rules](#9-force-load-rules)
10. [Per-request flow](#10-per-request-flow)
11. [Interop](#11-interop)
12. [README outline](#12-readme-outline)
13. [Success metrics](#13-success-metrics)
14. [Locked decisions](#14-locked-decisions)
15. [Known risks and limitations](#15-known-risks-and-limitations)
16. [v0.8 roadmap](#16-v08-roadmap)

---

## 0. Mission

Stop AI coding agents from shipping demo-grade code. Three layers, autoloaded:

- **Layer 1 — Safeguards.** Mandatory, decider-picked per turn. Hard rules.
- **Layer 2 — Advisors.** Silent, severity-tiered notes alongside the work.
- **Layer 3 — Max Performance.** User opt-in via `/invisible` for deep passes.

The DECIDER is the brain of the system. Sprint 1 dedicated roughly 40% of total project effort to it, on purpose — the rest of the layers are only as good as the skill the DECIDER picks for any given turn.

---

## 1. Skill inventory

**Status**: ✅ Shipped in v0.7.0.

```
INVISIBLE/
├── DECIDER.md                          ≤200 lines, picks skills
├── CLAUDE_TEMPLATE.md                  per-project template (sections A–F)
├── README.md, INSTALL.md, UNINSTALL.md, CHANGELOG.md, VERSION, LICENSE
├── preferences.schema.json             v1
│
├── layer1-safeguards/                  14 mandatory skills
│   ├── ui-net/
│   ├── api-net/                        + API-docs-discipline rule
│   ├── db-net/                         + read-replica routing
│   ├── auth-net/                       + secrets-rotation playbook
│   ├── error-net/
│   ├── env-net/                        + security headers
│   ├── test-net/
│   ├── code-scanner/                   cross-cutting, scope-filtered
│   │
│   ├── async-ops-net/                  CLUSTER: jobs + email + notifications + supply-chain CI
│   ├── data-flow-net/                  CLUSTER: cache + multitenancy + file-handling
│   ├── integration-net/                external APIs, webhooks, SDKs
│   ├── realtime-net/                   narrow trigger — only when WS/SSE detected
│   ├── payment-net/                    standalone; security-critical
│   ├── i18n-net/                       narrow trigger
│   └── graphql-net/                    narrow trigger
│
├── layer2-advisors/                    6 silent advisors
│   ├── scaling-advisor/
│   ├── integration-advisor/
│   ├── ux-advisor/
│   ├── architecture-advisor/
│   ├── cost-advisor/
│   └── future-self-advisor/
│
├── layer3-max-performance/             13 opt-in skills
│   ├── _core5/                         shipped first
│   │   ├── deep-codebase-mapper/
│   │   ├── full-spec-rewriter/
│   │   ├── prod-readiness-audit/
│   │   ├── prd-writer/
│   │   └── security-auditor/
│   └── _extended8/                     shipped after Core-5
│       ├── refactor-architect/
│       ├── perf-deep-dive/
│       ├── trd-writer/
│       ├── architecture-designer/
│       ├── openapi-generator/
│       ├── runbook-generator/
│       ├── data-model-designer/
│       └── onboarding-doc-generator/
│
└── meta/                               9 infrastructure files
    ├── interop.md
    ├── corruption-handler.md
    ├── self-learner.md
    ├── rule-validator.md
    ├── recommender.md
    ├── stack-adapter.md                Rails, Django, Next.js, FastAPI, Express, Phoenix
    ├── circuit-breaker.md
    ├── conflict-resolver.md
    └── pattern-scan-budget.md          ≤1k tokens/turn
```

> **Note on counts.** §14 (Locked decisions) says "L1 skill count: 14." The on-disk directory listing under `layer1-safeguards/` holds 15 entries because `code-scanner` is cross-cutting and listed alongside the routed skills for discoverability. The DECIDER routing surface remains 14 domains — `code-scanner` is not picked per signal score; it runs as a filter on output. The 15-vs-14 discrepancy is documented in `CHANGELOG.md` Unreleased and will be reconciled in plan v7.

### Cluster rationale

**`async-ops-net`** absorbs jobs (workers, retries, DLQ, idempotency, cron locking), email (transactional, bounces, unsubscribe, SPF/DKIM), push/notifications (token cleanup, dedup, delivery tracking), and supply-chain CI (lockfile, audit, dep pinning). Shared mental model: *background pipelines*. Loading them together cuts DECIDER misfire risk because work on any one typically touches the others.

**`data-flow-net`** absorbs cache (scope, TTL, invalidation, stampede), multitenancy (tenant scoping, cache isolation, file namespacing), and file handling (path traversal, MIME, quotas, `Content-Disposition`). Shared mental model: *data crossing boundaries* — user-to-user, tenant-to-tenant, internal-to-external storage. Cache scope and multitenancy are often the same problem.

**Standalone, on purpose**:

- The **core 7** (ui, api, db, auth, error, env, test) — central to every web app.
- **integration-net** — outbound third-party calls have a distinct mental model from internal async work (timeouts, retries, circuit breakers, signature verification on inbound webhooks).
- **realtime-net, payment-net, i18n-net, graphql-net** — narrow-trigger by design. Load only when their signals fire.
- **code-scanner** — cross-cutting; runs on output.

---

## 2. DECIDER — trigger signals and routing

**Status**: ✅ Shipped (signal table embedded in `DECIDER.md`).

Every L1 skill must have ≥3 distinct trigger signals before it earns a routing entry. The table below was the on-paper exercise that locked the inventory in v5; all 14 skills clear the bar.

| Skill | Trigger signals (≥3 required) | Signals |
|---|---|---|
| **ui-net** | "page", "component", "button", "form", "modal", "table", "design", `.tsx`/`.jsx`/`.vue` edits, screenshot uploads | 8+ |
| **api-net** | "endpoint", "route", "controller", "API", HTTP verb mentions, request/response shapes, routes-file edits | 7+ |
| **db-net** | "migration", "schema", "model", "column", "index", ActiveRecord/Prisma/SQLAlchemy, `.sql` files | 7+ |
| **auth-net** | "login", "signup", "session", "token", "JWT", "password", "permission", "role", "OAuth", "2FA" | 10+ |
| **error-net** | "error", "exception", "try/catch", HTTP error codes, "logging", error-tracking library mentions | 6+ |
| **env-net** | "deploy", "Docker", `.env`, "production", "staging", "CI/CD", "secrets", "CORS", "headers" | 9+ |
| **test-net** | "test", "spec", RSpec/Jest/Vitest/Playwright, `.test.ts`/`_spec.rb`, "CI", "coverage" | 6+ |
| **code-scanner** | runs on any code output ≥30 LOC OR touching auth/payment/data-mutation | always-on filter |
| **async-ops-net** | "background job", "worker", Sidekiq/Celery/BullMQ, "cron", "queue", "email", "SMTP", "notification", "push", "webhook send", "audit", "lockfile", Dependabot/Renovate | 13+ |
| **data-flow-net** | "cache", Redis/Memcached, "TTL", "tenant", "organization", "workspace", "multi-tenant", "file upload", S3/blob storage, "path", "MIME" | 11+ |
| **integration-net** | "third-party", "external API", vendor names (Stripe/Twilio/SendGrid/…), "webhook receive", "SDK", "HTTP client", "timeout", "circuit breaker", "retry" | 9+ |
| **realtime-net** | "WebSocket", "WS", Socket.IO, "real-time", "live update", "subscription", Pusher/Ably/Phoenix Channels, server-sent events | 8+ |
| **payment-net** | "payment", Stripe/PayPal/Razorpay, "charge", "subscription", "refund", "invoice", "checkout", "money", "currency" | 9+ |
| **i18n-net** | "i18n", "localization", "translation", "locale", "language", "RTL", locale-specific support, `.po`/`.json` message catalogs | 8+ |
| **graphql-net** | "GraphQL", "resolver", "query/mutation/subscription", "Apollo", `schema.graphql`, "introspection" | 6+ |

**Multitenancy** has no standalone trigger — it rides on the `data-flow-net` cluster signals ("tenant", "organization", "workspace", "multi-tenant"). Force-load to `auth-net` (rule 6 below) enforces tenant isolation as authz at load time.

---

## 3. DECIDER decision flow

**Status**: ✅ Shipped as `DECIDER.md` (115 lines, cap 200).

```
1. Score each domain 0–10 using weighted trigger signals.
2. Apply threshold (≥3.0) → candidate list.
3. Tiebreak (security > user-facing > infra).
4. Apply force-load rules (§9).
5. Cap at 4 skills loaded per turn.
6. Note any skill scoring 2.0–3.0 as "considered but not loaded" (optional P3 advisor note).
```

Routing surface: 14 skills → routing table ≤35 rows (cluster skills count as one entry). Cap shipped well under: see `DECIDER.md`.

The pattern-scan budget runs *before* final skill load — see §4.

---

## 4. Pattern-scan budget

**Status**: ✅ Shipped as `meta/pattern-scan-budget.md`.

### Scope (hard-bounded)

The pattern scan reads ONLY:

1. Files explicitly referenced in the current turn (pasted, attached, or named by path).
2. Files already in the agent's context from prior turns.
3. `CLAUDE.md` project notes — sections E (project-specific rules) and F (accepted exceptions).
4. `~/.claude/invisible/<project-hash>/discovered-patterns.json` — a lightweight cache built incrementally.

**Never scanned**: the entire codebase, repo-wide globs, sibling directories.

### Token budget

- ≤1k tokens per turn allocated to pattern scanning.
- If candidate files exceed budget → scan top N by relevance; log `skipped scan: budget`.

### Pattern cache

`discovered-patterns.json` grows as the agent works:

```json
{
  "pagination_style": "cursor",
  "error_response_shape": "{code, message, request_id}",
  "form_validation_lib": "react-hook-form + zod",
  "auth_pattern": "scoped query in model layer",
  "discovered_at": { "pagination_style": "turn_3" }
}
```

Once a pattern lands in the cache, no re-scan is needed. The cache invalidates when the user explicitly changes a pattern and `self-learner` detects it via correction.

### Budget enforcement (honest, not silent)

If the scan would exceed budget, the agent says inline:

> *"I didn't scan the whole codebase — only the files in scope. If you've established patterns I don't know yet, drop a hint in `CLAUDE.md`."*

---

## 5. Sprint plan and current status

| # | Sprint | Status | Notes |
|---|---|---|---|
| 1 | Backbone + DECIDER + all `meta/` | ✅ Shipped | DECIDER, 9 meta files, CLAUDE_TEMPLATE, INSTALL/UNINSTALL, preferences schema. |
| 2 | L1 Core 7 + code-scanner | ✅ Shipped | ui, api, db, auth, error, env, test, code-scanner. |
| 3a | L1 Clusters | ✅ Shipped | async-ops-net, data-flow-net, integration-net. |
| 3b | L1 Narrow-trigger | ✅ Shipped | realtime-net, payment-net, i18n-net, graphql-net. |
| 4 | L2 Advisors | ✅ Shipped | scaling, integration, ux, architecture, cost, future-self. |
| 5a | L3 Core-5 | ✅ Shipped | deep-codebase-mapper, full-spec-rewriter, prod-readiness-audit, prd-writer, security-auditor. |
| 5b | L3 Extended-8 | ✅ Shipped | refactor-architect, perf-deep-dive, trd-writer, architecture-designer, openapi-generator, runbook-generator, data-model-designer, onboarding-doc-generator. |
| 6 | Dogfood + validator stress + README | 🧪 In test | Fixtures + methodology shipped; round-1 measurement complete by hand. Full 20-PR replay and spec-kit head-to-head deferred to v0.8 (see §16). |

Sprint 5b is the **parachute**: per the v5 build plan, Core-5 alone is a complete product. Extended-8 shipped on schedule, so the full L3 surface is in v0.7.

### Sprint 6 by-hand measurement results (released in v0.7)

| Artifact | Result |
|---|---|
| rule-validator stress (20 cases) | **PASS** — 12/12 security-critical rejected, 8/8 style appropriate. 1 non-blocking finding (case 3 spec/fixture priority mismatch). |
| Dogfood round 1 (3 repos) | 7/7 silent killers covered by L1 catalog in sample. Caveat: numerator and denominator from the same scan. |
| DECIDER tuning round 1 | 8 candidates ranked; top-4 are runtime-buildable scanners (deferred). |
| vs spec-kit | INVISIBLE side simulated (95% applicable-killer coverage, 5.0/5.0 test-plan rubric, 8 input-specific catches). spec-kit side deferred — refused to fabricate. |

Full reports: `tests/rule-validator-stress/`, `tests/dogfood/`, `tests/decider-tuning/`, `tests/vs-spec-kit/`.

---

## 6. Anti-bloat caps

**Status**: ✅ Shipped — every skill in v0.7.0 verified under cap (see CI plan in §16).

| Item | Cap | v0.7 max observed |
|---|---|---|
| `DECIDER.md` | ≤200 lines | 115 |
| Routing table rows | ≤35 | within |
| L1 `SKILL.md` body | ≤300 lines | 244 (graphql-net) |
| L1 `SKILL.md` — `auth-net` exception | ≤500 lines | 187 |
| L1 `SKILL.md` — `async-ops-net` / `data-flow-net` (clusters) | ≤450 lines | 217 (async) / 198 (data-flow) |
| L1 reference files | ≤200 lines each | within |
| L2 advisor `SKILL.md` | ≤150 lines | 130 |
| L3 `SKILL.md` | ≤400 lines | 298 |
| `CLAUDE.md` per project | ≤500 lines | 66 (this repo) |
| Skills loaded per turn (L1) | max 4 | enforced in `DECIDER.md` |
| Advisor notes per turn | max 5 (P1 exempt) | enforced in each L2 |
| L3 active per turn | max 1 | enforced in `meta/recommender.md` |
| Pattern-scan tokens per turn | ≤1k | enforced in `meta/pattern-scan-budget.md` |

**CI enforcement** of caps: ⏳ Deferred to v0.8 (no automated workflow yet; caps verified manually each sprint).

---

## 7. Token economics

**Status**: 📐 Design only — targets locked; live measurement ⏳ deferred to v0.8.

### Always-on budget (every turn)

| Component | Target |
|---|---|
| System prompt (not ours) | ~3k |
| `CLAUDE.md` project file | ~1–2k |
| `DECIDER.md` | ~800 |
| L1 + L2 + L3 metadata only (frontmatter, no bodies) | ~1k |
| **INVISIBLE always-on (ours, excl. system prompt)** | **~3k** |
| **Total context overhead** | **~6k** |

### Per-task load (DECIDER-picked)

| Component | Target |
|---|---|
| L1 `SKILL.md` bodies (2–4 × ~300 lines) | ~1.5–3k |
| L1 reference files (decision-tree-picked) | ~1–2k |
| L2 advisor bodies (when triggered) | 0.5–1.5k |
| Pattern scan | ≤1k |
| **Per-task additional** | **3–7k** |

### Aggregate

- **Worst case**: ~13k INVISIBLE overhead per turn.
- **Best case**: ~8k INVISIBLE overhead per turn.

### Vs rework cost

A demo-grade auth implementation typically costs 3–5 rework rounds × ~4k tokens each = **15–20k tokens wasted**. INVISIBLE pays for itself if it prevents one rework round per feature.

**This claim is unverified.** It will be validated against measured numbers in v0.8.

---

## 8. self-learner + rule-validator

**Status**: ✅ Spec shipped; 🧪 gating logic tested by hand on 20-case fixture.

### rule-validator gating checks

A new candidate rule from `self-learner` runs through six gates in order. The first failure short-circuits.

| # | Check | Action on failure |
|---|---|---|
| 1 | Contradicts an L1 hard rule? | **REJECT** with reason. |
| 2 | Contradicts an existing project rule? | **CONFLICT** — ask user which wins. |
| 3 | Overly broad ("never use X")? | **ASK SCOPE** ("in this project, …"). |
| 4 | Single-occurrence with no repeat? | **DOWNGRADE** to a note, not a rule. |
| 5 | Touches security / auth / payment / multitenancy? | **ASK CONFIRM** — never auto-write. |
| 6 | Contradicts an archived rule? | **FLAG WITH HISTORY**. |

### Sprint 6 stress test

20 deliberately bad rules curated for the test (`tests/rule-validator-stress/cases.json`):

- "never use transactions" → must reject (db-net conflict)
- "skip auth checks on internal endpoints" → must reject (auth-net conflict)
- "store passwords as plaintext in dev" → must reject (security gate)
- "money as floats is fine for small amounts" → must reject (payment-net)
- "ignore PII in logs" → must reject (error-net + compliance)
- "skip CSRF on POST" → must reject (auth-net)
- "polling is fine, no need for WS" → ALLOW (context-dependent — note, not reject)
- "use `puts` for debug logs" → ALLOW (style choice)
- … 12 more

**Acceptance targets**: 100% rejection of security-critical bad rules; ≥80% appropriate handling on style rules.

**Result (2026-05-13)**: **PASS** — 12/12 security-critical, 8/8 style. One non-blocking finding (F1): spec/fixture priority mismatch on case 3 — verdict and skill citation correct; only the `failed_check` index differed. Recommendation tracked for v0.8.

**Honest caveat**: gating logic applied by hand. CI-automated validator required before v1.0.

---

## 9. Force-load rules

**Status**: ✅ Shipped in `DECIDER.md`.

| Trigger skill | Force-loads | Why |
|---|---|---|
| `payment-net` | `auth-net`, `error-net` | Money + auth + a consistent error envelope are inseparable. |
| `async-ops-net` | `error-net` | Silent async failures are the #1 killer in background pipelines. |
| `realtime-net` | `auth-net` | WS upgrade auth is always missed. |
| `auth-net` | `error-net` | Auth errors must be consistent and safe (no information leakage). |
| `db-net` (on migration) | `code-scanner` | Migrations need a post-write scan even when <30 LOC. |
| Multitenancy signal (via `data-flow-net`) | `auth-net` | Tenant isolation **is** authorization. |

Force-loads consume slot budget but are non-negotiable.

---

## 10. Per-request flow

**Status**: ✅ Spec shipped; ⏳ executable runtime deferred to v0.8.

```
user message
    ↓
[DECIDER] score 14 domains by signal weight
    ↓
[STACK ADAPTER] inject stack-specific rules into active context
    ↓
[PATTERN SCAN — bounded ≤1k tokens] check in-scope files + project cache
    ↓
[L1] DECIDER picks top-N, applies force-load rules, caps at 4 loaded
    ↓
[L2] advisors run on the plan, emit severity-tiered notes (max 5; P1 exempt)
    ↓
[L3] recommender may surface one suggestion (user opt-in)
    ↓
agent executes the work
    ↓
[CODE-SCANNER] runs if output ≥30 LOC OR touches auth/payment/data-mutation
    ↓
[L2] advisors run on the output, emit final notes
    ↓
[CIRCUIT-BREAKER] update metrics, check trip conditions
    ↓
[SELF-LEARNER → RULE-VALIDATOR] observe corrections, gate rule writes
```

---

## 11. Interop

**Status**: ✅ Shipped as `meta/interop.md`.

| Tool | Relationship |
|---|---|
| **caveman** | Tone-compression skill. Independent; INVISIBLE never alters caveman's output formatting. Coexists fine. |
| **graphify** | Visualization. INVISIBLE hands off all visual concerns to graphify. |
| **ruflo** | Different routing model. INVISIBLE defers when ruflo is present. |
| **agency-agents** | Runs as a reviewer. INVISIBLE provides the rules they review against. |
| **spec-kit** | Complementary. spec-kit shapes specs; INVISIBLE shapes safeguards. Quarterly comparison harness lives in `tests/vs-spec-kit/`. |

Versions pinned; quarterly review.

---

## 12. README outline

**Status**: ✅ Shipped in 16 sections (per `README.md`).

The README is first-person, direct, and runs on measured numbers wherever the runtime allows. In v0.7 every unmeasured field is labelled `<deferred v0.8>` rather than hidden.

1. Hi — here's what I keep getting wrong (silent killers, plain English)
2. How I work in three layers
3. The 14 safeguards, briefly (one sentence each)
4. Install in 3 steps
5. A real example walkthrough (vague brief → full flow)
6. The token math (measured numbers per stack — currently planned-target framing; live numbers in v0.8)
7. What I do automatically vs what you opt into (L1/L2 vs L3)
8. Commands cheat sheet
9. What I learn from you + the validator that keeps me safe from myself
10. The circuit breaker — how I tell you I'm misconfigured
11. Honest limitations
12. Works alongside (caveman, graphify, ruflo, agency-agents, spec-kit)
13. When to turn me off (throwaway scripts, demos, hackathons)
14. What I do automatically (measured behavior)
15. Uninstall
16. Help me get better — feedback loop

---

## 13. Success metrics

**Status**: 🧪 In test — round-1 results below; full measurement ⏳ deferred to v0.8.

| Metric | Target | v0.7 result |
|---|---|---|
| Silent-killer catch rate | ≥70% on 10 vibe-coded apps | 7/7 (100%) in 3-repo sample; methodology caveat applies |
| Token efficiency (always-on) | ~6k | not yet measured |
| Token efficiency (per-task) | ~3–7k | not yet measured |
| Cross-model lift (Gemini Flash + INVISIBLE vs alone) | 2× | not yet measured |
| Correction velocity | drops over time | requires self-learner runtime |
| L3 acceptance rate | calibrated | requires recommender runtime |
| Circuit-breaker trip rate | <10% of projects in steady state | requires runtime |
| rule-validator rejection accuracy | 100% security-critical, ≥80% style | **PASS** (12/12, 8/8) |
| vs spec-kit (same input, prod-readiness delta) | published | INVISIBLE side simulated; spec-kit side deferred |

---

## 14. Locked decisions

These are settled and will not be relitigated without an explicit flag in `CHANGELOG.md`:

| Decision | Value |
|---|---|
| Name | INVISIBLE |
| Layers | 3 |
| L1 skill count | 14 routed domains (15 dirs incl. `code-scanner` as cross-cutting) |
| L2 skill count | 6 |
| L3 skill count | 13 (Core-5 + Extended-8, priority order) |
| Storage | `~/.claude/invisible/<project-hash>/` (hidden) |
| CLI prefix | `/invisible` — L3 + meta only |
| Telemetry | off by default; asked once on first turn |
| Distribution | mega-package folder; symlinked into agent skill dir |
| Stack-adapter depth | moderate, with per-stack examples baked in |
| Pattern-scan scope | bounded to in-scope files + cache; ≤1k tokens |
| Sprint 3 | split 3a (clusters) + 3b (narrow-trigger) |
| L3 build order | Core-5 first, Extended-8 after |
| rule-validator | dedicated Sprint 6 stress test, release-blocking |
| License | MIT |

---

## 15. Known risks and limitations

- **DECIDER misfires at scale.** Edge cases will surface as INVISIBLE meets real projects. Plan assumes two tuning rounds post-Sprint 6 dogfood; round 1 produced 8 candidates (`tests/decider-tuning/misses-round-1.json`).
- **Cluster skills could bloat.** `async-ops-net` and `data-flow-net` are the widest. v0.7 maxes are 217 and 198 lines respectively (cap 450); if they consistently approach the cap, the v1 plan is to split them.
- **Pattern cache staleness.** If the user changes a pattern and `self-learner` misses it, the cache misleads. Mitigation: 30-day TTL + manual refresh via `/invisible refresh-patterns`.
- **rule-validator over-rejecting style rules.** If users feel patronized, they disable `self-learner`. Mitigation: every reject must explain *why* and offer a scope refinement.
- **Cross-model claims partial.** Built and tested on Claude. GPT-4o tested via Sprint 6 spot-check. Gemini Flash: in progress. README claims only "tested on Claude" until full validation lands.
- **Runtime not yet executable.** Every measurement in v0.7 is rules-as-checklist applied by hand. Token cost, L2 noise rate, and circuit-breaker trip rate are unverifiable in this release.

---

## 16. v0.8 roadmap

Tracked in `CHANGELOG.md` Unreleased; promoted here for visibility.

### Critical-path

1. **Executable runtime.** Build the validator, DECIDER scorer, and code-scanner. Currently all spec-only. Without this, every metric tagged `<deferred v0.8>` stays unmeasured.
2. **DECIDER tuning round 1.** Apply the 8 candidates from `tests/decider-tuning/misses-round-1.json` — top-4 are scanner heuristics: webhook-event-dedup, Rails cookie-options, FastAPI `BackgroundTasks`, auth-route rate-limit detector.
3. **Full dogfood replay.** Expand from one spot-check per repo to the 20-PR replay specified in `tests/dogfood/methodology.md`.
4. **Live spec-kit head-to-head.** Install spec-kit at a pinned tag; run against the three locked inputs; publish honest delta (not the simulated INVISIBLE-side number).
5. **Coverage gap closure.** Source a fourth repo with i18n, GraphQL, or realtime surface. None of the three v0.7 dogfood repos exercise those skills.

### Quality-of-life

- CI enforcement of anti-bloat caps (§6).
- Fix rule-validator fixture case 3 priority mismatch (F1).
- Reconcile 14-vs-15 L1 count in §1 and §14.
- Add `discovered-patterns.json` cache lifecycle test.

### Open questions

- Should the pattern-scan budget scale with project size, or stay flat at 1k tokens? Currently flat.
- Should `code-scanner` be promoted to a routed skill in v1 for traceability? Currently cross-cutting; only impact is visibility in the DECIDER log.

---

**Plan v6. Successor revision (v7) lands with the v0.8 measurement run.** The DECIDER and rule-validator carry the project; everything else is infrastructure around them.
