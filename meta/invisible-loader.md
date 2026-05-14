---
name: invisible
description: "INVISIBLE safeguard skillset. Catches silent killers before they ship."
trigger: /invisible
---

# INVISIBLE — Active

INVISIBLE is a 3-layer safeguard skillset for AI coding agents. Loaded every session via `@import` in `~/.claude/CLAUDE.md`. Full design: `~/.claude/invisible-skillset/skill_build_plan.md` (v6). Routing logic: `~/.claude/invisible-skillset/DECIDER.md`.

## How to operate each turn

1. Score each domain in the routing table below against the user message + in-scope files.
2. Load ≤4 skills scoring ≥3.0 (Read the SKILL.md file from disk on demand).
3. Apply force-load rules (below). Force-loaded skills consume slot budget.
4. Apply skill hard rules before writing code.
5. Run `code-scanner` on output ≥30 LOC OR touching auth/payment/mutation files.
6. Emit L2 advisor notes (≤5/turn, P1 exempt).
7. L3 skills load only on explicit `/invisible <command>` invocation. ≤1 active/turn.

## Routing table (abbreviated — full table: DECIDER.md)

| Skill | Key triggers |
|---|---|
| auth-net | login, JWT, session, token, password, OAuth, role, permission, CSRF |
| api-net | endpoint, route, controller, API, HTTP verb, status code |
| db-net | migration, schema, model, column, index, SQL, query |
| payment-net | payment, Stripe, charge, invoice, refund, subscription |
| error-net | error, exception, try/catch, 500, logging, retry |
| env-net | deploy, Docker, .env, production, secrets, headers |
| test-net | test, spec, RSpec, Jest, coverage, fixture |
| async-ops-net | background job, worker, Sidekiq, queue, email, webhook sender |
| data-flow-net | cache, Redis, tenant, organization, workspace, S3, file upload |
| integration-net | third-party, webhook receiver, SDK, timeout, signature |
| realtime-net | WebSocket, Socket.IO, SSE, real-time, channel |
| ui-net | component, button, form, modal, .tsx, .jsx, a11y |
| i18n-net | i18n, locale, translation, RTL, ICU, BCP47 |
| graphql-net | GraphQL, resolver, Apollo, DataLoader |
| code-scanner | always-on (≥30 LOC output OR auth/payment/mutation files) |

## Skill paths

```
~/.claude/invisible-skillset/layer1-safeguards/<skill>/SKILL.md
~/.claude/invisible-skillset/layer2-advisors/<skill>/SKILL.md
~/.claude/invisible-skillset/layer3-max-performance/_core5/<skill>/SKILL.md
~/.claude/invisible-skillset/layer3-max-performance/_extended8/<skill>/SKILL.md
~/.claude/invisible-skillset/meta/<file>.md
```

## Force-load rules (non-negotiable, consume slot budget)

| If selected | Also load |
|---|---|
| payment-net | auth-net, error-net |
| async-ops-net | error-net |
| realtime-net | auth-net |
| auth-net | error-net |
| db-net (migration) | code-scanner |
| multitenancy signal | auth-net |

## Tiebreaks (when scores tie)

security > user-facing > infrastructure. Hard cap: 4 skills loaded per turn.

## Pattern scan budget

≤1k tokens/turn. Sources: in-scope files + `~/.claude/invisible/<project-hash>/discovered-patterns.json` cache + project `CLAUDE.md` Patterns section. **Never scan the whole codebase.**

## L2 advisors (autoload, silent notes)

scaling-advisor · ux-advisor · cost-advisor · future-self · architecture-advisor · integration-advisor. ≤5 notes/turn, P1 exempt.

## /invisible commands (L3, opt-in)

Read the skill from `layer3-max-performance/` on invocation:

- `/invisible map` — codebase map
- `/invisible spec` — engineer spec from brief
- `/invisible prd` — product doc
- `/invisible audit prod-readiness`
- `/invisible audit security`
- `/invisible refactor`
- `/invisible perf`
- `/invisible trd` · `/invisible design` · `/invisible openapi` · `/invisible runbook` · `/invisible data-model` · `/invisible onboarding`
- `/invisible status` — show DECIDER state, loaded skills, circuit-breaker
- `/invisible validate-rule "<text>"` — dry-run rule-validator
- `/invisible refresh-patterns` — rebuild pattern cache

## Circuit breaker states

`degraded` → L2 muted to P1 only · `noisy` → recommender quiet mode · `misaligned` → self-learner paused. Surface one inline message + auto-recovery window. Source: `meta/circuit-breaker.md`.

## Project state

Per-project state at `~/.claude/invisible/<project-hash>/` (hash = first 12 chars of sha1(project-dir-path)). Holds `discovered-patterns.json`, `decider.log`, accepted-exceptions overrides.
