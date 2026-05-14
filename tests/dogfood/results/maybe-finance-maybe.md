# Dogfood — maybe-finance/maybe

## Repo metadata
- Stack: Rails 7 + Postgres + Hotwire/Stimulus + Sidekiq + Plaid + Stripe (self-hosted option)
- HEAD pinned: `77b5469832758d1cbee1a940f3012a1ae1c74cd3`
- Lock-in date: 2026-05-13
- Local clone: `/home/srinivas/app/maybe`

## Scope honesty

- Skillset has no runtime yet — DECIDER, scanner, advisors not executable. Findings produced by hand-applying L1 rule catalog as a checklist against a targeted sample.
- Sample: 4 files + schema scan (not full 20-PR replay per methodology). Insufficient for token-cost or advisor-noise measurement.
- Catch-rate numbers below are signal, not statistical claim. Larger sample required for headline number.
- File sample picked for coverage breadth (auth + integration + payment + db), not cherry-picked for findings.

## Files inspected

1. `app/controllers/application_controller.rb`
2. `app/controllers/concerns/authentication.rb`
3. `app/controllers/webhooks_controller.rb`
4. `app/jobs/stripe_event_handler_job.rb`
5. `db/schema.rb` (money columns audit)
6. `app/models/import.rb` (float-mention scan)

## Findings

### F-MAYBE-1 (P1, auth-net rule 3) — Session cookie missing Secure + SameSite

**Where**: `app/controllers/concerns/authentication.rb:42`

**Code**:
```ruby
cookies.signed.permanent[:session_token] = { value: session.id, httponly: true }
```

**What auth-net rule says**: "Token storage on client: httpOnly + Secure + SameSite=Lax/Strict cookies for browser sessions."

**Gap**: `httponly: true` present; `secure:` and `same_site:` absent. Cookie travels over plain HTTP in any env without TLS termination. CSRF protection in Rails depends partly on SameSite.

**Suggested fix**:
```ruby
cookies.signed.permanent[:session_token] = {
  value: session.id,
  httponly: true,
  secure: Rails.env.production?,
  same_site: :lax
}
```

### F-MAYBE-2 (P1, auth-net rule 2) — Effectively infinite session lifetime

**Where**: `app/controllers/concerns/authentication.rb:42`

**Code**: `cookies.signed.permanent[:session_token]` — `permanent` sets cookie to expire in 20 years.

**What auth-net rule says**: "Sessions/tokens have explicit expiry. Access tokens ≤15 min, refresh tokens ≤30 days (sliding) OR ≤90 days (absolute). No infinite sessions."

**Gap**: 20-year cookie ≈ no expiry. Server-side `Session` row exists (revocable), but client cookie is essentially permanent.

**Suggested fix**: cookie expiry tied to session policy (e.g., `expires: 30.days.from_now`); refresh on activity.

### F-MAYBE-3 (P1, integration-net rule 10) — Plaid webhook has no event idempotency

**Where**: `app/controllers/webhooks_controller.rb:6-15` (`plaid` action)

**Code**: signature verified, then processor runs without checking event uniqueness.

**What integration-net rule says**: "Inbound webhooks are idempotent — vendor will re-deliver. Dedup by `event_id`."

**Gap**: Plaid retries deliveries; same event may be processed multiple times. For financial sync this can double-apply transaction state.

**Suggested fix**: dedup table on `(vendor='plaid', webhook_code+item_id+ts)`; insert-or-skip before `WebhookProcessor.new(...).process`.

### F-MAYBE-4 (P2, integration-net rule 11) — Plaid webhook processed synchronously

**Where**: `app/controllers/webhooks_controller.rb:11`

**Code**: `PlaidItem::WebhookProcessor.new(webhook_body).process` runs inside request thread.

**What integration-net rule says**: "Webhook receivers return 2xx quickly (≤5s); offload work to a job."

**Gap**: Slow Plaid processing → 5xx to Plaid → retries → potential disable.

**Note**: Stripe path uses `process_webhook_later` (async) — pattern exists, just inconsistent.

### F-MAYBE-5 (P2, error-net) — Webhook error response leaks message detail

**Where**: `app/controllers/webhooks_controller.rb:17-19` (Plaid rescue), `:36-39` (Stripe rescue)

**Code**: `render json: { error: "Invalid webhook: #{error.message}" }`

**Gap**: error.message bubbled to caller. Information disclosure to whoever fires bad webhooks.

**Suggested fix**: log full error; respond with generic `{ error: "invalid webhook" }`.

### F-MAYBE-6 (P3, async-ops-net) — Stripe event job has no retry / DLQ declaration

**Where**: `app/jobs/stripe_event_handler_job.rb`

**Code**: `class StripeEventHandlerJob < ApplicationJob; queue_as :default` — no `retry_on` / `discard_on`.

**Gap**: ApplicationJob may set defaults; not visible here. Job for payment-relevant Stripe events benefits from explicit retry policy (retry on NetworkError, discard on RecordNotFound).

## Passes (notable correct patterns)

| Domain | What's right |
|---|---|
| **payment-net rule 1 (money type)** | Schema uses `decimal(19,4)` for balance/cash_balance/budgeted_spending — Ruby `BigDecimal` mapping. Payment-net allowance for BigDecimal in stack-aware mode. ✓ |
| **auth-net rule 7 (default-deny)** | `Authentication` concern included in ApplicationController with `before_action :authenticate_user!`; opt-out via explicit `skip_authentication`. ✓ |
| **integration-net rule 9 (sig verify)** | Both Plaid and Stripe verify signatures before processing. ✓ |
| **integration-net rule 11 (async)** | Stripe path uses `process_webhook_later`. ✓ |

## Scoring

| Class | Issues found (sample) | INVISIBLE would catch | TP rate (sample) |
|---|---|---|---|
| Silent killer | 3 (F-MAYBE-1, -2, -3) | 3/3 (auth-net 2+3, integration-net 10) | 100% (3 of 3) |
| Quality | 2 (F-MAYBE-4, -5) | 2/2 (integration-net 11, error-net) | 100% (2 of 2) |
| Style/advisory | 1 (F-MAYBE-6) | 1/1 (async-ops-net P3) | 100% (1 of 1) |

**Caveat**: numerator and denominator both come from the same scan (rules-as-checklist applied to L1 catalog). True FN rate (issues skillset would miss that human review catches) requires a separate human pass; not done here.

## Token cost
Not measured. No runtime. Methodology requires p50/p95 over 50 turns — defer to runtime-build round.

## Advisor noise
Not measured. No L2 runtime.

## Circuit-breaker trips
N/A — no runtime.

## Notes / recommendations for DECIDER tuning

- Plaid webhook signal: rule `vendor:plaid` should boost integration-net + force-load consideration for [[data-flow-net]] (financial data, tenant scope on accounts).
- Rails `cookies.signed.permanent` pattern should add a scanner rule under auth-net (likely missing from current scanner list — verify).
- Add scanner rule: webhook handler with no event_id dedup → P1 (verify present; if not, gap).
