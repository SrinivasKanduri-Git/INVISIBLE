# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository status

**v0.7.0 (developer-preview) released 2026-05-14.** All architectural pieces shipped per `skill_build_plan.md` (v6, post-release): 14 L1 + 6 L2 + 13 L3 skills + 9 meta files + DECIDER + tests harness. Runtime not yet executable — validator, DECIDER scorer, and code-scanner are spec-only documents. Sprint 6 measurement complete by hand (rule-validator stress: PASS; dogfood round-1: 7/7 in sample). Runtime build + full 20-PR replay + spec-kit head-to-head deferred to v0.8 (see plan §16).

When asked to "build", "implement", or "ship" anything here, treat `skill_build_plan.md` (v6) as authoritative and locate the relevant section before writing code. Do not invent commands, directory layouts, or skill names that contradict the plan. v0.8 work expands measurement; it does not relitigate locked decisions (plan §14) without an explicit flag.

## Big-picture architecture (from the plan)

INVISIBLE is a skillset, not an app. It loads into any AI coding agent and runs in three layers:

- **Layer 1 — Safeguards** (`layer1-safeguards/`): 14 skills, autoloaded, mandatory. Picked per turn by the DECIDER. Hard cap: 4 loaded per turn.
- **Layer 2 — Advisors** (`layer2-advisors/`): 6 skills, autoloaded, silent, severity-tiered notes. Cap: 5 notes/turn (P1 exempt).
- **Layer 3 — Max Performance** (`layer3-max-performance/`): 13 skills, user opt-in via `/invisible`. Split into `_core5/` (ship first) and `_extended8/` (ship after). Cap: 1 active/turn.

The **DECIDER** (`DECIDER.md`, 115 lines under the 200-line cap) is the brain. Scores 14 domains by trigger signals (table in plan §2), thresholds at 3.0, tiebreaks security > user-facing > infra, caps at 4 skills/turn. Sprint 1 carried ~40% of total effort by design.

### Critical cross-cutting pieces
- **Force-load rules** (plan §9): payment-net → auth-net+error-net; async-ops-net → error-net; realtime-net → auth-net; auth-net → error-net; db-net migration → code-scanner; multitenancy signal → auth-net. Non-negotiable, consume slot budget.
- **Pattern-scan budget** (`meta/pattern-scan-budget.md`): ≤1k tokens/turn. Scans only in-scope files + `~/.claude/invisible/<hash>/discovered-patterns.json` cache + CLAUDE.md project notes. **Never scans whole codebase.**
- **rule-validator** (`meta/rule-validator.md`): gates self-learner writes. Sprint 6 stress test (20 deliberately bad rules) **PASSED** in v0.7 (12/12 security-critical reject, 8/8 style appropriate, applied by hand). CI-automated validator required before v1.0.
- **Per-request flow**: plan §10 is the canonical pipeline (DECIDER → stack-adapter → pattern-scan → L1 → L2 plan → L3 opt-in → execute → code-scanner → L2 output → circuit-breaker → self-learner/rule-validator).

### Cluster skills (do not split without revising plan)
- **async-ops-net**: jobs + email + push/notifications + supply-chain CI. Shared "background pipeline" model.
- **data-flow-net**: cache + multitenancy + file handling. Shared "data crossing boundaries" model. Multitenancy has no standalone trigger — it rides on this cluster's tenant/organization/workspace signals.
- **payment-net** is standalone and stays standalone — security-critical, never merge.

## Anti-bloat caps (plan §6, CI enforcement deferred to v0.8)

| Item | Cap |
|---|---|
| DECIDER.md | ≤200 lines |
| Routing table rows | ≤35 |
| L1 SKILL.md body | ≤300 lines (auth-net ≤500, async-ops-net/data-flow-net ≤450) |
| L1 reference files | ≤200 lines each |
| L2 advisor SKILL.md | ≤150 lines |
| L3 SKILL.md | ≤400 lines |
| CLAUDE.md per project | ≤500 lines |
| Pattern-scan tokens/turn | ≤1k |

A skill exceeding its cap must split before merge.

## Sprint status (plan §5)

| Sprint | Status |
|---|---|
| 1. Backbone + DECIDER + meta | ✅ Shipped (v0.1) |
| 2. L1 Core 7 + code-scanner | ✅ Shipped (v0.2) |
| 3a. L1 Clusters | ✅ Shipped (v0.3) |
| 3b. L1 Narrow-trigger | ✅ Shipped (v0.3) |
| 4. L2 Advisors | ✅ Shipped (v0.4) |
| 5a. L3 Core-5 | ✅ Shipped (v0.5) |
| 5b. L3 Extended-8 | ✅ Shipped (v0.6) |
| 6. Dogfood + validator stress + README | 🧪 Round-1 done by hand; runtime + full replay → v0.8 |

## Locked decisions (plan §14) — do not relitigate without flagging

Name=INVISIBLE; 3 layers; L1=14 routed (15 dirs incl. code-scanner), L2=6, L3=13; storage `~/.claude/invisible/<project-hash>/`; CLI prefix `/invisible` for L3+meta only; telemetry off by default; pattern scan bounded ≤1k tokens; Sprint 3 split into 3a/3b; L3 build order Core-5 → Extended-8; **License MIT**.

## Interop (plan §11)

caveman (tone only), graphify (hands off visuals), ruflo (defer routing), agency-agents (run as reviewer), spec-kit (complementary). Versions pinned, quarterly review.
