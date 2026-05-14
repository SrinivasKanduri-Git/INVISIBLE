# DECIDER

Routes each user turn to ≤4 Layer-1 skills. Always-on. ≤200 lines.

## 1. Score (0–10) per domain

Each L1 domain has a **trigger-signal table**. For every signal hit in the current turn (user message + referenced file paths + dropped files + recent context window), add weight:

| Signal class | Weight |
|---|---|
| Exact keyword match (e.g., "JWT", "migration") | 2.0 |
| Library/framework name (e.g., "Sidekiq", "Apollo") | 2.0 |
| File extension / path pattern (`.tsx`, `routes/`, `*.sql`) | 1.5 |
| Domain noun in prose (e.g., "tenant", "endpoint") | 1.0 |
| Verb match (e.g., "deploy", "cache", "charge") | 1.0 |
| Dropped asset (screenshot for ui-net, JSON for api-net) | 1.5 |

Cap raw score at 10. No domain can exceed.

## 2. Threshold + candidate list

- Score **≥3.0** → candidate
- Score **2.0–2.99** → "considered but not loaded" (recommender may surface as P3 note)
- Score **<2.0** → ignored

## 3. Tiebreak order

When more candidates than slots:

1. **Security-critical** (auth-net, payment-net, code-scanner on auth/payment paths)
2. **User-facing** (ui-net, api-net)
3. **Infra** (env-net, db-net, async-ops-net, etc.)

Ties within tier → higher raw score wins. Still tied → alphabetical.

## 4. Slot budget

**Max 4 L1 skills loaded per turn.** Force-loads (§7) consume slots.

If candidates >4 after force-loads, drop lowest-tier candidates. Log dropped skills to `~/.claude/invisible/<hash>/decider.log` for Sprint 6 tuning.

## 5. Routing table (14 skills, ≤35 rows)

| # | Skill | Primary signals (sampled — full list in skill SKILL.md) |
|---|---|---|
| 1 | ui-net | "page" "component" "button" "form" "modal" "table"; .tsx/.jsx/.vue; screenshot drop |
| 2 | api-net | "endpoint" "route" "controller" "API"; HTTP verbs; routes file edit |
| 3 | db-net | "migration" "schema" "model" "column" "index"; ORM names; .sql |
| 4 | auth-net | "login" "signup" "session" "token" "JWT" "password" "permission" "role" "OAuth" "2FA" |
| 5 | error-net | "error" "exception" "try/catch" "500/404/400" "logging"; Sentry/Rollbar/Bugsnag |
| 6 | env-net | "deploy" "Docker" ".env" "production" "staging" "CI/CD" "secrets" "CORS" "headers" |
| 7 | test-net | "test" "spec"; RSpec/Jest/Vitest/Playwright; .test.ts/_spec.rb; "coverage" |
| 8 | code-scanner | always-on filter — runs on output ≥30 LOC OR touching auth/payment/data-mutation |
| 9 | async-ops-net | "background job" "worker" "Sidekiq/Celery/BullMQ" "cron" "queue" "email" "SMTP" "transactional" "notification" "push" "webhook send" "audit" "lockfile" "Dependabot" |
| 10 | data-flow-net | "cache" "Redis/Memcached" "TTL" "tenant" "organization" "workspace" "multi-tenant" "file upload" "S3" "path" "MIME" |
| 11 | integration-net | "third-party" "external API" "Stripe/Twilio/SendGrid/etc" "webhook receive" "SDK" "HTTP client" "timeout" "circuit breaker" "retry" |
| 12 | realtime-net | "WebSocket" "WS" "Socket.IO" "real-time" "live update" "subscription" "Pusher/Ably/Phoenix Channels" "SSE" |
| 13 | payment-net | "payment" "Stripe/PayPal/Razorpay" "charge" "subscription" "refund" "invoice" "checkout" "money" "currency" |
| 14 | i18n-net | "i18n" "localization" "translation" "locale" "RTL" "Arabic/Hebrew/Chinese"; .po/locale.json |
| 15 | graphql-net | "GraphQL" "resolver" "query/mutation/subscription" "Apollo" "schema.graphql" "introspection" |

(15 rows. Other 20 reserved for stack-adapter overrides + future skills.)

## 6. Stack-adapter pass

After candidate list, [[stack-adapter]] injects stack-specific signals (e.g., Rails project boosts `ActiveRecord` → db-net, `ActionCable` → realtime-net). Re-score, re-rank.

## 7. Force-load rules (non-negotiable)

| Trigger candidate | Force-loads | Reason |
|---|---|---|
| payment-net | auth-net, error-net | money + auth + error envelope inseparable |
| async-ops-net | error-net | silent async failures = #1 killer |
| realtime-net | auth-net | WS upgrade auth always missed |
| auth-net | error-net | auth errors must be consistent + safe |
| db-net (migration signal) | code-scanner | migrations need post-write scan even <30 LOC |
| data-flow-net (tenant signal) | auth-net | tenant isolation IS authz |

Force-loaded skills count against the 4-slot cap. If forced load would exceed cap, drop the lowest-scoring non-forced candidate first.

## 8. Pattern-scan hand-off

After candidate list locked, hand off to [[pattern-scan-budget]] (≤1k tokens). Only in-scope files + cache. Never repo-wide.

## 9. Output contract

DECIDER produces JSON loaded into agent context:

```json
{
  "turn": 17,
  "loaded": ["auth-net", "error-net", "api-net", "code-scanner"],
  "forced": ["error-net"],
  "considered": ["db-net (score 2.4)"],
  "dropped_for_cap": [],
  "pattern_scan_tokens": 612
}
```

## 10. Failure modes + fallback

- **All candidates scored <3.0** → load nothing (L1). Code-scanner still runs on output if ≥30 LOC.
- **Routing table corrupt** → [[corruption-handler]] restores from `~/.claude/invisible/default/`.
- **Decider misfire detected** (user correction tagged "wrong skill") → [[self-learner]] logs, [[circuit-breaker]] increments miss count.

## 11. Caps (CI-enforced)

- This file ≤200 lines
- Routing table ≤35 rows
- Skills/turn ≤4
- Pattern-scan ≤1k tokens

## 12. Related

[[stack-adapter]] · [[pattern-scan-budget]] · [[corruption-handler]] · [[self-learner]] · [[circuit-breaker]] · [[conflict-resolver]] · [[recommender]]
