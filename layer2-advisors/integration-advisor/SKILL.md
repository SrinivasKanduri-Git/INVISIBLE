---
name: integration-advisor
description: Silent advisor on third-party integration health. Surfaces missing fallback, vendor lock-in, untested failure modes, undocumented retry semantics, SDK-version drift, and "happy path only" coverage. Reads plan + output; emits notes; never blocks.
layer: 2
enabled_default: true
caps:
  body_lines: 150
  notes_per_turn: 5
triggers:
  signals: ["vendor name in plan", "SDK call in output", "webhook receive/send", "API client instantiation", "external service down handling absent"]
  load_when: integration-net loaded OR output touches integrations/, webhooks/, vendor SDK imports
suppress_when:
  - integration-net P1 fired on same line
  - explicit `// vendor-ok: <reason>` annotation
---

# integration-advisor

Surfaces the slow-motion failures of third-party integrations — not the missing-signature-now problems (integration-net handles those), but the "what happens when vendor X is down / changes API / rate-limits us / disappears" questions developers skip.

## What it watches

| Signal | Concern |
|---|---|
| Single point of vendor failure on user-facing path | No fallback when vendor down |
| Vendor-specific data shape leaking through layers | Lock-in; hard to swap |
| Webhook handler with no replay / backfill capability | Missed events lost forever |
| Vendor outage assumed = our outage in plan | Should degrade gracefully |
| SDK pinned to range (`^4.0.0`) on prod-critical path | Silent breaking change risk |
| No test for vendor 5xx / timeout | Untested error path = bugs |
| Two vendors covering same function with no abstraction | Code paths diverge |
| Free-tier vendor on critical flow | Rate-limit cliff |
| Vendor with no SLA on auth path | Auth outage = full outage |
| Hard dependency on vendor feature in beta | Vendor may pull feature |

## Note format

```
[integration-advisor] PX: <vendor + concern>. <consequence>. Suggest: <fallback / abstraction / test>.
```

## Severity

| Tier | When |
|---|---|
| **P1** | Auth / payment / data-write path with no degradation plan when vendor down |
| **P2** | Lock-in choice that will cost weeks to undo. Untested error path on critical flow |
| **P3** | Future-flexibility concern. Migration cost note. |

## Examples

```
[integration-advisor] P1: Login flow depends on Auth0 with no fallback. Vendor outage = no logins. Suggest: cache JWKS + extend session TTL during outage, OR document accepted downtime risk in CLAUDE.md C.

[integration-advisor] P2: Resolver `getOrders` returns Stripe `Invoice` shape directly. Couples API consumers to vendor. Suggest: map to internal `Order` shape at adapter layer.

[integration-advisor] P2: Webhook handler processes events but no `from_event_id` backfill endpoint exists. Vendor downtime → missed events unrecoverable. Suggest: Stripe `events.list` backfill job, run on receiver restart.

[integration-advisor] P3: SendGrid is sole transactional sender. ToS suspension / outage = no emails. Suggest: secondary provider (SES/Postmark) with feature flag.

[integration-advisor] P2: Test suite covers Stripe success path only. Mock 402/timeout/idempotency-conflict scenarios. Suggest: stripe-mock or fixture for each error code.
```

## Adapter-layer rule

Recommend wrapping every vendor in a thin internal interface. Application code calls `payments.charge(order)`, not `stripe.charges.create(...)`. Surfaces:
- Missing adapter where business code imports SDK directly → P2.
- Vendor data shape leaks (`Stripe.Invoice` returned from app service) → P2.

This is the highest-leverage advice the advisor gives — it pays back at every vendor migration / outage / version bump.

## Backfill / replay surface

For every webhook-driven state machine, ask:
- Can the receiver be replayed from a starting event_id?
- Can the vendor's REST API be polled to reconcile state?
- Is there a daily reconciliation job comparing our DB vs vendor truth?

Missing all three on payment/auth state → P1. Note suggests Stripe `events.list` / Slack `conversations.history` / equivalent vendor backfill API.

## Vendor abstraction red flags

- Vendor type imported in domain model (`type User = { stripeCustomerId: Stripe.Customer; ... }`).
- Vendor enum used as application enum.
- Vendor error class caught at controller level instead of adapter.
- Vendor pagination cursor leaked to API consumer.

## Anti-noise rules

1. No "you might want to abstract this" without a vendor failure scenario attached.
2. No second-guessing established vendor choice ("why Stripe, why not Adyen?") — that's project-decision territory.
3. Defer to integration-net for live verification / signature / retry rules.
4. Max 5 notes/turn; P1 exempt. P3 dropped first.
5. Suppress on `// vendor-ok: documented in incident-response.md`.

## Plan-time use

Most valuable at design time: "you're going to integrate Foo for X, here's the failure modes to plan for." Output-time is reminders on the code that lands.

## CLAUDE.md hooks

Reads section A: `vendors` (list with role), `fallback_policy`, `vendor_sla_assumptions`.
Reads section B: project rules (e.g., "no vendor on critical write path without 2nd provider").
Reads section C: accepted exceptions (e.g., "Stripe is sole payments, accepted single-vendor risk").

## Interaction with L1

- integration-net = "your code is correctly calling the vendor right now".
- integration-advisor = "your design assumes this vendor never fails / never changes".

Complementary. No overlap on findings.

## Related

[[integration-net]] · [[async-ops-net]] · [[payment-net]] · [[auth-net]] · [[architecture-advisor]] · [[future-self-advisor]]
