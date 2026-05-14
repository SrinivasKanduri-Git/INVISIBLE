# CHANGELOG

All notable changes to INVISIBLE.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versioning: [SemVer](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned for v0.8
- Build executable runtime: validator + DECIDER scorer + code-scanner (currently spec-only).
- Apply DECIDER tuning round-1 proposals (see `tests/decider-tuning/misses-round-1.json`): webhook-event-dedup scanner, Rails cookie-options scanner, FastAPI BackgroundTasks detector, auth-route rate-limit detector.
- Re-run dogfood with token counter instrumentation → real per-turn token budget for README §6.
- Expand dogfood from 1 spot-check per repo → full 20-PR replay per repo (per `tests/dogfood/methodology.md`).
- Live spec-kit head-to-head on 3 locked inputs (currently INVISIBLE side simulated, spec-kit side deferred).
- Add 4th repo with i18n / GraphQL / realtime surface to close coverage gaps.
- Update rule-validator fixture case 3 to align with spec gating order (F1 finding from v0.7).
- Reconcile plan §15 L1-count statement ("14 skills") with actual inventory (15 dirs incl. code-scanner as cross-cutting).

## [0.7.0] — 2026-05-14

First public developer-preview release. Skillset architecturally complete; runtime build deferred to v0.8.

### Highlights
- **14 L1 safeguards** (autoload, mandatory, DECIDER picks ≤4/turn): ui-net, api-net, db-net, auth-net, error-net, env-net, test-net, code-scanner, async-ops-net, data-flow-net, integration-net, realtime-net, payment-net, i18n-net, graphql-net.
- **6 L2 advisors** (autoload, silent, ≤5 notes/turn with P1 exempt): scaling-, integration-, ux-, architecture-, cost-, future-self-advisor.
- **13 L3 max-performance skills** (opt-in via `/invisible`, ≤1 active/turn): Core-5 (deep-codebase-mapper, full-spec-rewriter, prod-readiness-audit, prd-writer, security-auditor) + Extended-8 (refactor-architect, perf-deep-dive, trd-writer, architecture-designer, openapi-generator, runbook-generator, data-model-designer, onboarding-doc-generator).
- **9 meta files**: DECIDER, stack-adapter, pattern-scan-budget, rule-validator, self-learner, conflict-resolver, circuit-breaker, recommender, corruption-handler, interop.
- **Tests harness**: rule-validator stress fixture (20 cases) + dogfood methodology (3-repo protocol) + decider-tuning miss-log + vs-spec-kit comparison harness.

### Sprint 6 measurement results (rules-as-checklist, by-hand)

**Rule-validator stress test (release gate)** — **PASS** on 2026-05-13:
- Security-critical reject: **12/12 (100%)**.
- Style appropriate handling: **8/8 (100%)**.
- 1 finding (P2, non-blocking): spec/fixture priority mismatch on case 3. Verdict and skill citation correct; only the `failed_check` index differed. Recommendation: keep spec order, update fixture. Tracked for v0.8.
- Gap: checks 2 (project-rule conflict), 4 (single-occurrence downgrade), 6 (archived-rule re-learn) not yet exercised in fixture v1. Expansion proposed for v0.8.
- Honest caveat: gating logic applied by hand to each case. CI-automated validator required before v1.0.
- Full results: `tests/rule-validator-stress/results-2026-05-13.json` + `acceptance-report.md`.

**Dogfood round 1** — 3 repos, 1 sweep per repo (HEADs pinned in `tests/dogfood/repo-selection.md`):

| Repo | Stack | Findings (P1/P2/P3) | L1 caught |
|---|---|---|---|
| maybe-finance/maybe | Rails 7 + Sidekiq + Plaid + Stripe | 3/2/1 | 3/3 |
| elie222/inbox-zero | Next.js 14 + Prisma + Lemon Squeezy + LLM | 1/2/0 | 1/1 |
| netflix/dispatch | FastAPI + SQLAlchemy + Celery + plugins | 3/1/1 | 3/3 |
| **Aggregate (sample)** | — | **7/5/2** | **7/7 (100%)** |

- Plan target ≥70% catch rate: **met in sample**.
- Heaviest hit category: **integration-net** (webhook discipline) — 5 of 7 findings.
- Honest caveat: numerator + denominator from same scan. "L1 catalog covers silent-killer patterns visible in 3 codebases" — not "INVISIBLE catches 100% of all silent killers." Independent FN measurement requires runtime → v0.8.
- Coverage gaps acknowledged: i18n-net, graphql-net, realtime-net not exercised (no surface in 3-repo sample). env-net + test-net partial.
- Full per-repo reports: `tests/dogfood/results/*.md`. Aggregate: `tests/dogfood/aggregate.md`.

**DECIDER tuning round 1** — 8 candidates ranked by impact: `tests/decider-tuning/misses-round-1.json`. Top-4 are runtime-buildable scanners (deferred to v0.8 with the runtime).

**vs spec-kit comparison** — locked 3 inputs (vague export brief, team-invitation auth ticket, saved-views multi-tenant CRUD), simulated INVISIBLE side (95% applicable-silent-killer coverage averaged, test-plan rubric 5.0/5.0, 8 input-specific catches). spec-kit side **deferred** — refused to fabricate, per `tests/vs-spec-kit/methodology.md` honesty rule. Full head-to-head awaits both runtimes → v0.8. Details: `tests/vs-spec-kit/comparison-summary.md`.

### Honesty disclosures (this release)
- Runtime not yet executable. All Sprint 6 measurement is rules-as-checklist applied by hand.
- Sample size per dogfood repo: 5–6 files, 0 PR replays (methodology target was 20 PRs/repo).
- Token cost, L2 advisor noise rate, circuit-breaker trip rate: **not measured** in this release (`<deferred v0.8>` everywhere they appear).
- vs spec-kit numbers are INVISIBLE-side only; the comparison is **not** complete.
- Skills shipped but unexercised in dogfood: i18n-net, graphql-net, realtime-net.

### Repo / packaging
- LICENSE: MIT.
- Repository: <https://github.com/SrinivasKanduri-Git/INVISIBLE>.
- `.gitignore` added for runtime cache, local Claude settings, OS/IDE noise, future Python/Node tooling artifacts.
- README §14 vs-spec-kit row: honest partial-comparison framing — does not claim head-to-head delta.

### Notes
- Plan §6 Sprint 6 deliverables shipped (fixtures, methodology, README scaffold, by-hand measurement).
- Skillset architecturally complete: 14 L1 + 6 L2 + 13 L3 + 9 meta + DECIDER + CLAUDE_TEMPLATE + tests harness.

## [0.6.0-sprint5b] — 2026-05-13

### Added (Sprint 5b — L3 Extended-8, opt-in)
- layer3-max-performance/_extended8/refactor-architect — stepwise refactor plan (extract/split/merge/rename/invert). Mandatory test-gap-fill first, mergeable per-step commits, rollback per step. CLI `/invisible refactor`.
- layer3-max-performance/_extended8/perf-deep-dive — measurement-first perf pass: baseline → hypothesis → profile → fix ladder (cheapest first) → after-measurement. Refuses speculation. CLI `/invisible perf`.
- layer3-max-performance/_extended8/trd-writer — Technical Requirements Doc for cross-team consumers. service/library/api modes. Covers SLOs, failure modes, versioning, compat. CLI `/invisible trd`.
- layer3-max-performance/_extended8/architecture-designer — ADR-style system design from PRD/TRD. greenfield/extend/migrate modes. Anti-cargo-cult guardrails. CLI `/invisible design`.
- layer3-max-performance/_extended8/openapi-generator — generate/refresh/drift-check OpenAPI 3.1 from code. Schema inference precedence, drift report, preserves human edits. CLI `/invisible openapi`.
- layer3-max-performance/_extended8/runbook-generator — 3am-paged-on-call runbook: alert response, failure modes with mitigate-vs-resolve, diagnostic one-liners, escalation. CLI `/invisible runbook`.
- layer3-max-performance/_extended8/data-model-designer — schema design from spec: entities, indexes, constraints, soft-delete/audit/tenancy decisions, migration sketch. Stack-aware. CLI `/invisible data-model`.
- layer3-max-performance/_extended8/onboarding-doc-generator — new-contributor guide: dev setup, layout, conventions, first-PR walk. Optional `--verify` executes setup in clean env. CLI `/invisible onboarding`.

### Notes
- All 8 opt-in via `/invisible` CLI, recommender min-score 4.0–4.5 per skill.
- Cap audit: all ≤400 lines (range 241–298). Clear.
- L3 complete: 5 Core-5 + 8 Extended-8 = 13 skills per plan §2.
- Sprint 6 next: dogfood on 3 vibe-coded repos + rule-validator stress test (20 bad rules, must reject all 6 security-critical) + README with measured numbers.

## [0.5.0-sprint5a] — 2026-05-13

### Added (Sprint 5a — L3 Core-5, opt-in)
- layer3-max-performance/_core5/deep-codebase-mapper — repo walk → entrypoints, module map, hot/cold zones, "if-you-touch-X" matrix, pattern catalog. shallow/deep depth. Writes `.invisible/maps/<scope-hash>.md`. CLI `/invisible map`.
- layer3-max-performance/_core5/full-spec-rewriter — vague brief → engineer-ready spec (15 sections incl. data model, API shape, test plan, rollout). Cap-10-questions w/ batch `ack defaults`. CLI `/invisible spec`.
- layer3-max-performance/_core5/prod-readiness-audit — pre-ship pass: L1 walk + ops checklist (observability/runbook/deploy/rollback/capacity/compliance). Verdict: Ship/Hold/Ship-with-watch. CLI `/invisible audit prod-readiness`.
- layer3-max-performance/_core5/prd-writer — product-side doc for PMs/stakeholders (problem, success metrics, options, rollout, comms). discovery/definition modes. CLI `/invisible prd`. Distinct from full-spec-rewriter.
- layer3-max-performance/_core5/security-auditor — threat model + OWASP-aligned category walk (auth/authz/tenancy/injection/crypto/input/output/CSRF-CORS/logging/deps). P0–P3 findings with repro + remediation. fast/standard/deep. CLI `/invisible audit security`.

### Notes
- All L3 opt-in via `/invisible` CLI per plan §15. Recommender thresholds wired (≥4.0–5.0 per skill).
- Cap audit: all ≤400 lines (213/220/235/239/282). Clear.
- L3 hard cap: ≤1 active per turn (plan §7).
- Extended-8 not yet implemented — Sprint 5b next (refactor-architect, perf-deep-dive, trd-writer, architecture-designer, openapi-generator, runbook-generator, data-model-designer, onboarding-doc-generator).
- Parachute reached: per plan §6, Core-5 alone is shippable as a complete product.

## [0.4.0-sprint4] — 2026-05-13

### Added (Sprint 4 — L2 Advisors, all 6 shipped)
- layer2-advisors/scaling-advisor — capacity/throughput risks (unbounded list, missing pagination, sequential fan-out, hot-key contention). P1/P2/P3 notes, max 5/turn, scale-threshold required.
- layer2-advisors/integration-advisor — vendor failure surface (no fallback, no replay/backfill, SDK range pinning, vendor-shape lock-in). Adapter-layer + reconciliation focus.
- layer2-advisors/ux-advisor — beyond ui-net baseline: optimistic UI, destructive-confirm + undo, debounce, skeleton-over-spinner, empty-state CTA, error message quality.
- layer2-advisors/architecture-advisor — layering violations, god objects, premature extraction guardrail (2-leave / 3-consider / 4+-recommend), premature microservice rejection.
- layer2-advisors/cost-advisor — egress traps, log volume, LLM token bleed (prompt caching), idle compute, observability cardinality. Magnitude required on every note.
- layer2-advisors/future-self-advisor — comment-the-why, magic numbers (≥3 occurrences), TODO hygiene (owner+ticket+date), feature-flag sunset, time-bomb literals, naming.

### Notes
- All advisors silent by design (notes only, never block). Severity tiers P1/P2/P3 consistent across.
- Note budget: max 5/turn, P1 exempt; P3 drops first when over.
- Cap audit: all six ≤150 lines (110–130). Clear.
- L3 max-performance not yet implemented — Sprint 5a (Core-5) next.

## [0.3.0-sprint3] — 2026-05-13

### Added (Sprint 3a — L1 Clusters)
- layer1-safeguards/async-ops-net — background pipeline cluster (jobs/workers, email + bounces, push/notifications, webhook senders, cron locking, supply-chain CI). Force-loads error-net.
- layer1-safeguards/data-flow-net — data-boundary cluster (cache scope/TTL/stampede, multitenancy WHERE-clause discipline, file handling with path-traversal + MIME defenses). Tenant signal force-loads auth-net.
- layer1-safeguards/integration-net — outbound third-party calls (timeout, retry, circuit breaker, rate-limit) + inbound webhook receivers (signature, replay window, idempotency dedup).

### Added (Sprint 3b — L1 Narrow-trigger)
- layer1-safeguards/realtime-net — WS/SSE/pub-sub: upgrade auth, per-subscribe authz, tenant-scoped topics, backpressure, reconnect-resume. Force-loads auth-net.
- layer1-safeguards/payment-net — integer minor-units, server-side pricing, idempotency, webhook-as-source-of-truth, refunds/disputes, SCA/3DS, PCI scope minimization, subscription state machine. Force-loads auth-net + error-net.
- layer1-safeguards/i18n-net — BCP47 locale resolution, ICU MessageFormat plurals, RTL via logical properties, UTC storage + Intl rendering, pseudo-loc CI.
- layer1-safeguards/graphql-net — per-resolver authz, DataLoader N+1 prevention, depth+complexity limits, introspection scoping, persisted queries, subscription auth.

### Notes
- L1 complete: 14 skills shipped (8 core + 3 clusters + 4 narrow-trigger = 15 dirs total; matches plan §2).
- Cap audit: clusters ≤450 lines (async 217, data-flow 198), narrow ≤300 (integration 162, realtime 183, payment 171, i18n 190, graphql 244). All clear.
- L2 advisors + L3 max-performance not yet implemented — Sprint 4 + Sprint 5 onward.

## [0.2.0-sprint2] — 2026-05-13

### Added
- layer1-safeguards/ui-net — a11y, loading/error states, form discipline, list virtualization
- layer1-safeguards/api-net — validation, auth wiring, pagination, status semantics, API-docs-discipline (P1 on missing OpenAPI/JSDoc)
- layer1-safeguards/db-net — migration discipline, N+1, FK indexes, read-replica routing with RYW windows + stale-tolerance annotations
- layer1-safeguards/auth-net — KDF, sessions/tokens, CSRF, 2FA, OAuth+PKCE, secrets-rotation cadence + leaked-secret playbook (500-line cap)
- layer1-safeguards/error-net — single envelope, structured logs, PII scrub list, retry stop-conditions
- layer1-safeguards/env-net — secret manager, HTTPS/HSTS, CORS allow-list, security headers (CSP/COOP/CORP/COEP), CI/CD audit gates, Docker non-root + digest pinning
- layer1-safeguards/test-net — real-DB integration, determinism, factory discipline, mock/don't-mock guidance
- layer1-safeguards/code-scanner — always-on filter, P1/P2/P3 tiers, finding format, false-positive dismissal cache, ≤500-token output budget

### Notes
- L2 advisors + L3 max-performance not yet implemented — Sprint 4 + Sprint 5 onward.

## [0.1.0-sprint1] — 2026-05-13

### Added
- DECIDER.md — confidence scorer, 14-skill routing table, force-load rules, 4-slot cap
- CLAUDE_TEMPLATE.md — per-project template (sections A–F)
- INSTALL.md, UNINSTALL.md
- preferences.schema.json (v1)
- meta/interop.md — caveman, graphify, ruflo, agency-agents, spec-kit
- meta/corruption-handler.md — quarantine + restore-default
- meta/self-learner.md — observe corrections, route to rule-validator
- meta/rule-validator.md — 6 gating checks
- meta/recommender.md — L3 opt-in surfacer
- meta/stack-adapter.md — Rails, Django, Next.js, FastAPI, Express, Phoenix
- meta/circuit-breaker.md — trip + recovery
- meta/conflict-resolver.md — project vs skill vs new
- meta/pattern-scan-budget.md — ≤1k tokens/turn, in-scope only

### Notes
- Layers L1/L2/L3 not yet implemented — Sprint 2 onward.
- README withheld until Sprint 6 (measured numbers only).
