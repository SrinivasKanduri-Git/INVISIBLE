---
name: integration-net
description: External-service integration safeguards. Covers third-party API calls (HTTP clients, retries, timeouts, circuit breakers), inbound webhook receivers (signature verification, replay protection, idempotency), and SDK usage patterns (auth handling, error mapping, rate limits). Distinct from async-ops-net (which covers outbound async jobs).
layer: 1
enabled_default: true
caps:
  body_lines: 300
triggers:
  keywords: ["third-party", "external API", "external service", "integration", "webhook", "webhook receive", "inbound webhook", "callback", "SDK", "HTTP client", "axios", "fetch", "requests", "httpx", "retry", "circuit breaker", "timeout", "rate limit", "429", "exponential backoff", "Stripe", "Twilio", "SendGrid", "Slack", "GitHub API", "Shopify", "Plaid", "Algolia", "Mixpanel", "Segment"]
  libs: ["axios", "got", "node-fetch", "undici", "ky", "requests", "httpx", "aiohttp", "faraday", "http.rb", "rest-client", "guzzle", "polly-js", "cockatiel", "opossum", "@octokit/rest", "stripe", "twilio", "@slack/web-api", "shopify-api-node", "plaid", "algoliasearch"]
  paths: ["integrations/", "webhooks/", "callbacks/", "external/", "clients/", "vendor/"]
force_loads: []
---

# integration-net

External-service integration safety net. Loaded when calling third-party APIs, receiving webhooks, or wrapping vendor SDKs. Distinct mental model from internal async — every call crosses a trust + reliability boundary you don't control.

## Hard rules

1. **Every outbound call has a timeout.** Connect ≤3s, total ≤15s default. `fetch`/`axios`/`requests` with no timeout → P1.
2. **Every outbound call has a retry policy** — but only for retriable errors (network, 5xx, 429-with-Retry-After). 4xx (except 408/429) does not retry.
3. **Exponential backoff with jitter** on retries. No tight retry loops.
4. **Circuit breaker on flaky dependencies.** After N consecutive failures, open circuit (fail-fast) for a cool-down window. Prevents one dead vendor from taking down the app.
5. **Rate-limit handling**: respect `Retry-After`, `X-RateLimit-Remaining`. Token-bucket on our side per vendor.
6. **Outbound auth credentials in env / secret manager**, never in code. Vendor key rotation per [[auth-net]] secrets-rotation playbook.
7. **Logging the request**: log method, URL (no query secrets), status, latency, request ID. Redact body unless `LOG_VENDOR_BODIES=true` (off in prod).
8. **No sensitive data in vendor logs/error reports** unless contract permits — error responses may include our payload.
9. **Inbound webhooks verified by signature**, every time. Unsigned webhooks → P1.
10. **Inbound webhooks are idempotent** — vendor will re-deliver. Dedup by `event_id`.
11. **Webhook receivers return 2xx quickly** (≤5s); offload work to a job. Slow webhook handlers cause vendor to retry and eventually disable endpoint.
12. **Vendor errors mapped to our error envelope** before bubbling — never leak raw vendor stack traces to API consumers.

## HTTP client setup (default)

| Lib | Timeout | Retry | Notes |
|---|---|---|---|
| `axios` | `timeout: 15000` + `signal: AbortSignal.timeout(15000)` (axios timeout = read only) | `axios-retry` with exponential | Set `validateStatus` for expected error codes |
| `got` | `timeout: { request: 15000 }` | Built-in `retry: { limit: 3 }` | Hooks for logging |
| `undici` / `fetch` | `AbortSignal.timeout(15000)` | Manual or `p-retry` | Native — preferred for Node ≥18 |
| `requests` (Python) | `timeout=(3, 15)` (connect, read) | `urllib3.util.Retry` + `HTTPAdapter` | `requests` retry is **off by default** |
| `httpx` | `timeout=httpx.Timeout(15.0, connect=3.0)` | `httpx-retries` or manual | async-friendly |
| `faraday` | `request: { open_timeout: 3, timeout: 15 }` | `faraday-retry` | Hooks for logging |

### Retry policy (default)
- Max 3 attempts (1 try + 2 retries).
- Backoff: 500ms, 2s (with ±20% jitter).
- Retry on: network errors, 5xx, 408, 429 (respect `Retry-After`).
- Never retry on: 400, 401, 403, 404, 422.

### Circuit breaker
- Open after 5 consecutive failures or 50% failure rate over 20 calls.
- Half-open after 30s cool-down, one probe.
- Per-vendor circuit, not global.
- Libraries: `opossum` (Node), `cockatiel` (Node), `pybreaker` (Python), `circuitbox` (Ruby).

## Outbound auth patterns

- **API key in header** (`Authorization: Bearer ...` or `X-API-Key: ...`). Key from env. Never in URL.
- **OAuth client_credentials** for service-to-service: fetch token, cache until expiry-30s, refresh.
- **Signed request** (e.g., AWS SigV4) — use vendor SDK; don't reimplement.
- **mTLS** for sensitive vendors — cert + key from secret manager, rotated per [[auth-net]] cadence.

## Inbound webhooks (receiver)

### Verification by vendor
| Vendor | Signature header | Method |
|---|---|---|
| Stripe | `Stripe-Signature` | HMAC-SHA256, timestamped, `t=...,v1=...` format. `stripe.webhooks.constructEvent` |
| GitHub | `X-Hub-Signature-256` | HMAC-SHA256 of body, `sha256=...` |
| Slack | `X-Slack-Signature` + `X-Slack-Request-Timestamp` | Versioned HMAC, check timestamp ≤5min |
| Shopify | `X-Shopify-Hmac-SHA256` | Base64 HMAC-SHA256 of raw body |
| Twilio | `X-Twilio-Signature` | HMAC-SHA1 of URL + sorted params |

**Raw body required** for signature verification. Frameworks that body-parse JSON before your handler will break the signature — preserve raw bytes (e.g., Express `express.raw()` on webhook routes, FastAPI `await request.body()`).

### Receiver structure
1. Read raw body.
2. Verify signature → if invalid: `401`, log, do not process.
3. Verify timestamp within window → if stale: `400`, do not process (replay defense).
4. Parse event, look up `event_id` in dedup table → if seen: `200`, exit.
5. Persist event row (`event_id` UNIQUE, status `received`).
6. Return `200` to vendor.
7. Enqueue async job to process. Job updates row status `processed`/`failed`.

Never run business logic synchronously in the webhook handler — webhook timeouts cause retries.

### Idempotency table
```sql
CREATE TABLE webhook_events (
  id BIGSERIAL PRIMARY KEY,
  vendor TEXT NOT NULL,
  event_id TEXT NOT NULL,
  event_type TEXT NOT NULL,
  payload JSONB NOT NULL,
  received_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  processed_at TIMESTAMPTZ,
  status TEXT NOT NULL DEFAULT 'received',
  UNIQUE (vendor, event_id)
);
```

## SDK usage rules

1. **Use the official SDK** when one exists. Roll-your-own HTTP is a maintenance + correctness trap (signing, retries, pagination already solved).
2. **Pin SDK major version** in package manifest. SDK breaking changes silently introduced via caret-range have caused outages.
3. **Wrap SDK in a thin adapter** layer per vendor — your code calls `payments.createCharge(...)`, not `stripe.charges.create(...)` directly. Lets you swap or mock.
4. **Error mapping**: catch SDK error types, translate to your error envelope. Don't `throw e` (leaks vendor internals).
5. **Sandbox/test mode** in dev/staging — explicit env var; never use prod keys in non-prod.
6. **Deprecated SDK methods** flagged at upgrade time. Some vendors (Stripe, Twilio) version their API — pin version + plan upgrades.

## What scanner flags

Runs on output in integrations/, webhooks/, external/ OR mentioning vendor names + HTTP keywords.

- `fetch(url)` / `axios.get(url)` / `requests.get(url)` without timeout → P1.
- Webhook handler with no signature verification → P1.
- Webhook handler doing DB writes / vendor calls synchronously before responding → P2 (should enqueue).
- Raw body consumed by JSON parser on webhook route (signature will fail) → P1.
- `try { ... } catch (e) { throw e }` around vendor SDK → P2 (no error mapping).
- Vendor API key embedded as string literal → P1.
- No retry / no circuit breaker around frequent external call → P2.
- Webhook event with no idempotency lookup → P1.
- Vendor SDK pinned with caret/tilde on major version (in prod manifest) → P2.

## Stack overrides

### Node (Express / NestJS)
- `express.raw({ type: 'application/json' })` on webhook routes; parse JSON manually after verification.
- `axios-retry` + `opossum` for client; one adapter per vendor.
- NestJS: `HttpModule` with interceptor for retries + logging.

### Python (FastAPI / Django)
- FastAPI: `Request.body()` for raw bytes; verify before parsing.
- `httpx.AsyncClient` reused across requests (don't create per-call).
- Django: `csrf_exempt` on webhook endpoints; verify signature instead.

### Rails
- `Faraday` connection with retry + logging middleware as a shared config.
- Webhook controllers: `protect_from_forgery with: :null_session` + signature verify.
- ActiveJob for async processing post-verify.

### Go
- `http.Client` with `Timeout` (mandatory) + `Transport` configured for keep-alive limits.
- Context propagation: `ctx, cancel := context.WithTimeout(...)` per call.

## Cross-skill collaborations

- Receiving payment webhooks → [[payment-net]] for amount/refund rules, [[auth-net]] for signature + idempotency depth.
- Outbound webhook sending → [[async-ops-net]] (covered there).
- Vendor errors surfaced to user → [[error-net]] for envelope.
- Rate-limit handling on vendor calls → may share infra with [[data-flow-net]] cache (token bucket in Redis).

## CLAUDE.md hooks

Reads section A: vendor list, HTTP client choice, retry config, circuit-breaker thresholds.
Reads section B: project rules (e.g., "vendor X never used in user-facing latency path").
Reads section C: accepted exceptions (e.g., "internal trusted service, no signature verification").

## Related

[[async-ops-net]] · [[auth-net]] · [[error-net]] · [[api-net]] · [[payment-net]] · [[data-flow-net]] · [[env-net]] · [[code-scanner]]
