---
name: payment-net
description: Payment safeguards. Covers money representation (integer minor units), idempotency, webhook verification, refund/dispute paths, subscription lifecycle, PCI-DSS scope minimization, and tax/currency correctness. Security-critical, never merged with anything. Force-loads auth-net + error-net.
layer: 1
enabled_default: true
caps:
  body_lines: 300
triggers:
  keywords: ["payment", "charge", "refund", "dispute", "chargeback", "subscription", "invoice", "checkout", "cart", "order", "money", "currency", "Stripe", "PayPal", "Razorpay", "Adyen", "Braintree", "Square", "Mollie", "Paddle", "Lemon Squeezy", "billing", "pricing", "tax", "VAT", "GST", "SCA", "3DS", "PaymentIntent", "SetupIntent", "card", "PCI"]
  libs: ["stripe", "@stripe/stripe-js", "stripe-ruby", "stripe-node", "stripe-python", "paypal-rest-sdk", "@paypal/checkout-server-sdk", "razorpay", "adyen-api", "braintree", "square", "mollie-api-node"]
  paths: ["payments/", "billing/", "subscriptions/", "invoices/", "checkout/", "orders/"]
force_loads:
  - auth-net
  - error-net
---

# payment-net

Payment safety net. Loaded on any payment / billing / currency signal. Force-loads [[auth-net]] and [[error-net]] (money + auth + error envelope are inseparable). Never merged with another skill.

## Hard rules

1. **Money is integer minor units.** Never float. `1099` cents, not `10.99` dollars. `BigDecimal` if your language supports it cleanly (Ruby, Java, Python `Decimal`). `Number` / `float` for money → P1.
2. **Currency carried with every amount.** `{ amount: 1099, currency: "USD" }`. Two amounts in different currencies cannot be added. Cross-currency math goes through an explicit FX step.
3. **Server is the source of truth for prices.** Client never sends amount; client sends product/plan/cart IDs; server computes total. Trusting `req.body.amount` → P1, every time.
4. **Idempotency on every payment mutation.** Each charge/refund call carries an idempotency key (vendor-provided concept for Stripe/Adyen; roll-your-own otherwise). Retries do not double-charge.
5. **Webhooks are the source of truth for state transitions**, not the API response. API may say "succeeded" but webhook may follow with `payment_failed` after issuer rejection. Persist webhook events and update order/subscription state from them.
6. **Webhook signature verification mandatory.** Unsigned webhook handling → P1. See [[integration-net]] for the receive-side recipe.
7. **Webhook idempotent**: `event.id` dedup table. Process once.
8. **No card data on our servers.** Use vendor's hosted checkout / Elements / Drop-in. Storing PAN / CVV → P1, PCI-DSS scope nightmare, almost certainly a compliance violation. Tokens only.
9. **Refunds are first-class operations**, not "manually call Stripe in console". Build refund endpoint with authz, audit, partial-refund support.
10. **SCA / 3DS / 2-step auth flow handled**. Modern card processing requires user interaction on some charges (EU SCA, India RBI). PaymentIntent's `requires_action` state must be propagated to client and handled.
11. **Subscription lifecycle states fully modeled**: `trialing`, `active`, `past_due`, `unpaid`, `canceled`, `incomplete`, `incomplete_expired`. Skipping states causes wrong access.
12. **Dunning configured** (retry policy on failed renewals). 4 attempts over ~3 weeks is the Stripe default — review per business.
13. **Tax computation via tax service** (Stripe Tax / TaxJar / Avalara). Hardcoded tax rate → P1 for any multi-region product (every jurisdiction changes rates regularly).
14. **Audit log** every payment-affecting action: charge, refund, void, subscription state change, manual override. Append-only. Cross-references [[auth-net]] for actor identity.
15. **No payment side-effects in views/templates.** Charge flows live in services/controllers, not React components or ERB partials.

## Money representation table

| Language | Right | Wrong |
|---|---|---|
| JS / TS | `bigint` minor units; or library (`dinero.js`, `currency.js`) | `Number`, `parseFloat`, `*100` ad-hoc |
| Python | `decimal.Decimal` or `int` minor units; `moneyed`/`py-moneyed` | `float`, naive division |
| Ruby | `BigDecimal` or `Money` gem | `Float`, `.to_f` |
| Java/Kotlin | `BigDecimal`, `MonetaryAmount` (JSR 354) | `double`, `Float` |
| Go | int64 minor units + Currency code | `float64` |

`amount / 100.0` formatting is the **display layer's** job. Storage is integer.

## Vendor split — what to use

| Vendor | Strength |
|---|---|
| **Stripe** | Best APIs/docs, broad coverage, tax/billing/connect built-in. Default unless reason otherwise |
| **Adyen / Braintree** | Enterprise, ML risk scoring |
| **PayPal** | Required for some user populations, has unique flows (no auth + capture symmetry) |
| **Razorpay** | India-first |
| **Paddle / Lemon Squeezy** | Merchant of Record — handles tax/VAT for you. Trade flexibility for simplicity |

PCI scope is lowest with hosted Checkout / Elements / Drop-in UI components. Don't reimplement the card form.

## Payment flow (canonical, with intents)

```
1. Client requests checkout       → server creates Order in `pending` state
2. Server creates PaymentIntent   → vendor returns client_secret
3. Client confirms with vendor    → may trigger 3DS (requires_action)
4. Vendor sends webhook           → payment_intent.succeeded | payment_intent.payment_failed
5. Webhook handler verifies sig   → looks up Order by intent_id
6. Webhook handler updates Order  → `paid` | `failed`; triggers fulfillment job
7. Fulfillment job (async)        → grants access, sends receipt, etc.
```

Synchronous "charge and grant access in the controller" is the wrong shape. Use intents + webhooks.

## Refunds

- Build refund endpoint with explicit authz (admin/support role only or self-service window per policy).
- Partial refunds supported (amount field).
- Reason recorded for every refund (user request, fraud, accident, support credit).
- Refund triggers webhook `charge.refunded` → update Order, notify user.
- Refund of a refund is not a thing — track net via ledger entries.

## Disputes / chargebacks

- Webhook event `charge.dispute.created` → freeze related access pending outcome.
- Evidence submission flow (Stripe Dashboard or API). Build evidence-bundle generator if dispute volume warrants.
- Track dispute rate; ≥1% triggers vendor program enrollment / fines.

## Subscriptions

- Source of truth: vendor (Stripe Subscription object) + our `subscription` row mirrored from webhooks.
- Access derived from `subscription.status` + period_end, never from our calculated state.
- Proration on plan change handled by vendor — don't reimplement.
- Cancellation: `cancel_at_period_end` (downgrade at period end) vs `cancel_now` (immediate). Default to period-end unless refund issued.
- Failed renewal → dunning runs → `past_due` → eventually `unpaid` / `canceled`. Each state has a UX (warning banner, restricted access).

## Tax / VAT / GST

- Region detection (billing address + IP fallback) determines tax jurisdiction.
- Use Stripe Tax / TaxJar / Avalara — never hardcode rates.
- Invoice shows tax line item separately. Required by EU/UK/IN/AU and most jurisdictions.
- Reverse-charge VAT for B2B EU customers with valid VAT number — vendor service handles.
- Tax ID collection (VAT, GSTIN, ABN) on customer setup for B2B.

## PCI-DSS scope minimization

- Hosted checkout (Stripe Checkout, PayPal redirect) → SAQ A.
- Embedded fields (Elements, Drop-in) → SAQ A-EP.
- Direct API touching PAN → SAQ D, full PCI assessment. Avoid unless absolutely required.
- If serving the card form ourselves, every page in the auth domain inherits PCI scope → adversarial logging, CSP, integrity controls. Almost never worth it.

## What scanner flags

Runs on output in payments/, billing/, checkout/ OR using vendor names + payment keywords.

- `amount: req.body.amount` / `params[:amount]` passed to vendor charge call → P1 (server must compute).
- Money stored as `FLOAT` / `Number` / `double` column or var → P1.
- `Number(...) * 100` / `Math.round(amount * 100)` for cents → P2 (precision risk).
- Hardcoded tax rate (e.g., `total * 1.07`) → P1.
- Card number (PAN-shaped string) detected in source / logs / DB → P1.
- Charge API call with no `idempotency_key` parameter → P1.
- Webhook handler with no signature verification → P1.
- Webhook handler with no `event.id` dedup → P1.
- Access grant based on charge response (not webhook) → P2.
- Refund call with no audit log entry → P2.
- Subscription access check uses calculated date instead of vendor `current_period_end` → P2.
- Logging full webhook payload (may contain customer/card data) → P1.

## Stack overrides

### Stripe (Node / Python / Ruby)
- Server SDK with API version pinned: `stripe.apiVersion = '2025-04-30'` (or current). Vendor versions break.
- `stripe.paymentIntents.create({ amount, currency, idempotencyKey: orderId })`.
- Webhook: `stripe.webhooks.constructEvent(rawBody, sig, secret)`.
- Test mode keys (`sk_test_...`) for non-prod; CI uses test mode.

### PayPal
- Server-side order creation; client-side approval; server-side capture.
- Capture is a separate step from authorize — track both states.

### Razorpay
- Order created server-side; checkout opens; verify signature on success callback (not just trust client).

## Subscriptions edge cases

- **Trial conversion failure**: card declines at trial end → grace period or downgrade?
- **Plan change mid-period**: prorate up (charge now) or down (credit applied next invoice)?
- **Multiple subscriptions per customer**: explicit business rule; some products allow, most don't.
- **Currency change for existing subscription**: usually requires cancel + new sub.
- **Refunded after access granted**: revoke access on `charge.refunded` if refund > threshold.

## Cross-skill force-loads + collaborations

- payment-net force-loads [[auth-net]] and [[error-net]].
- Inbound payment webhook = [[integration-net]] receiver discipline.
- Idempotent payment job → [[async-ops-net]].
- Subscription state cache → [[data-flow-net]] for cache invalidation on webhook.
- Payment errors surfaced to user → [[error-net]] envelope, scrubbed.
- Order/refund schema → [[db-net]] (decimal type, monetary columns).

## CLAUDE.md hooks

Reads section A: `payment_provider`, `currencies_supported`, `tax_service`, `pci_scope`.
Reads section B: project rules (e.g., "refunds require manager role", "trial 14 days, no card").
Reads section C: accepted exceptions (e.g., "manual reconciliation flow for ACH").

## Related

[[auth-net]] · [[error-net]] · [[integration-net]] · [[async-ops-net]] · [[db-net]] · [[api-net]] · [[data-flow-net]] · [[code-scanner]]
