# Dogfood — elie222/inbox-zero

## Repo metadata
- Stack: Next.js 14 App Router + Prisma + Postgres + Lemon Squeezy + Google OAuth + Gmail/Outlook API + Anthropic/OpenAI (AI SDK)
- HEAD pinned: `91a78dffd6480d06e0730acc9bdd97237e33967c`
- Lock-in date: 2026-05-13
- Local clone: `/home/srinivas/app/inbox-zero`

## Scope honesty

- Skillset has no runtime. Findings produced by hand-applying L1 rule catalog as a checklist to a targeted sample.
- Sample: 5 files (auth middleware, webhook receiver, tenant-scoped endpoint, AI integration spot-check, validators).
- Not full 20-PR replay per methodology. Insufficient for token-cost or advisor-noise measurement.
- File picks cover breadth: auth (middleware), payment (LS webhook), tenancy (rules route), LLM cost (prompt caching), validation (Zod usage).

## Files inspected

1. `apps/web/utils/middleware.ts` (`withEmailAccount` wrapper)
2. `apps/web/app/api/lemon-squeezy/webhook/route.ts`
3. `apps/web/app/api/user/rules/route.ts` (tenant-scoped endpoint sample)
4. `apps/web/__tests__/ai-assistant-chat.test.ts` (prompt-cache assertions — implies prod uses it)
5. Schema scan via `grep` for Zod validators in `app/api/user/**`

## Findings

### F-INBOX-1 (P1, integration-net rule 10) — Lemon Squeezy webhook has no event idempotency

**Where**: `apps/web/app/api/lemon-squeezy/webhook/route.ts`

**Code**: signature verified via timing-safe HMAC; event branched on `payload.meta.event_name`; `payload.data.id` referenced only in logger.

**What integration-net rule says**: "Inbound webhooks are idempotent — vendor will re-deliver. Dedup by `event_id`."

**Gap**: LS retries; same `data.id` may arrive twice. `subscriptionUpdated`/`subscriptionPlanChanged` are not naturally idempotent (state diffs may double-apply, telemetry double-counts, premium grant logic could overgrant on race).

**Suggested fix**: dedup table on `webhook_events(vendor, event_id UNIQUE, received_at, status)`; insert-and-return-200 on conflict; downstream branches gated on insert success.

### F-INBOX-2 (P2, integration-net rule 11) — Webhook handler runs business logic synchronously

**Where**: `apps/web/app/api/lemon-squeezy/webhook/route.ts:25-95`

**What integration-net rule says**: "Webhook receivers return 2xx quickly (≤5s); offload work to a job."

**Code**: `subscriptionCreated`/`subscriptionUpdated`/`subscriptionPlanChanged` run inside POST handler. They touch DB + PostHog + Loops (transactional email service).

**Gap**: third-party Loops API call inside webhook → tail latency → LS sees timeout → retries → F-INBOX-1 collides.

**Suggested fix**: receive → persist event → enqueue worker → 200. Worker runs the side-effecty work with [[async-ops-net]] retry/DLQ.

### F-INBOX-3 (P2, integration-net replay window) — No timestamp replay-window check

**Where**: `apps/web/app/api/lemon-squeezy/webhook/route.ts:115-126` (`getPayload`)

**Gap**: signature verified but no timestamp / replay-window check. Captured signed payload can be replayed by an attacker who later obtains the signing secret indirectly. Lower severity than F-INBOX-1 (depends on secret hygiene) but worth flagging.

**Suggested fix**: reject events where `payload.data.attributes.created_at` is older than N minutes from `now()`.

## Passes (notable correct patterns)

| Domain | What's right |
|---|---|
| **auth-net + data-flow-net (tenancy)** | `withEmailAccount` wrapper — `emailAccountId` derived from `request.auth`, never from body/params. Query scoped: `where: { emailAccountId }`. ✓ |
| **integration-net rule 9 (sig verify)** | LS webhook uses HMAC-SHA256 + `crypto.timingSafeEqual`. ✓ |
| **api-net validation** | Heavy Zod usage across `app/api/user/**` — request shape validated server-side, not just client. ✓ |
| **cost-advisor (LLM prompt caching)** | Anthropic `providerOptions.anthropic.cacheControl: { type: 'ephemeral' }` wired on AI assistant chat. ✓ — what cost-advisor would have requested is already done. |
| **error-net envelope** | `SafeError` distinguishes user-safe messages from leaky internals; central middleware error handler observed. ✓ |

## Scoring

| Class | Issues found (sample) | INVISIBLE would catch | TP rate (sample) |
|---|---|---|---|
| Silent killer | 1 (F-INBOX-1) | 1/1 (integration-net 10) | 100% (1 of 1) |
| Quality | 2 (F-INBOX-2, -3) | 2/2 (integration-net 11 + replay window) | 100% (2 of 2) |

**Caveat**: as with maybe report, same scan produces numerator + denominator. Real FN rate (issues a human reviewer would catch but skillset would miss) needs an independent human pass not done here.

## Notable absence — what we'd expect to find but didn't

This codebase shows discipline in places where many vibe-coded Next.js projects fail:
- Tenant scope enforced via middleware, not ad-hoc.
- Validators at every API surface.
- Prompt caching on LLM calls (cost discipline).

Suggests project either has internal review pressure or has been through a prior audit. Catch-rate signal here is lower than expected for the "vibe-coded" hypothesis — flag in aggregate.

## Token cost / advisor noise / circuit-breaker
Not measured. No runtime.

## Notes / recommendations for DECIDER tuning

- Lemon Squeezy is a payment vendor not in current trigger lists (`payment-net` libs covers Stripe/PayPal/Razorpay/etc.). Add: `lemon-squeezy`, `paddle`, `polar` as payment-net libs. Verify against current routing table.
- Next.js App Router `route.ts` files under `app/api/**/webhook/` should be a high-confidence integration-net signal (receiver discipline). Add path pattern.
- `providerOptions.anthropic.cacheControl` is a positive cost-advisor signal — could be inverted: absence of cache control on AI calls → cost-advisor P1. Pattern-scan rule.
