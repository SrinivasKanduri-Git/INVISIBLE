---
name: error-net
description: Error handling, logging, and PII discipline. Consistent error envelope, structured logging, no PII/secret leaks, exception trapping at boundaries, alerting hooks. Force-loaded by auth-net, async-ops-net.
layer: 1
enabled_default: true
caps:
  body_lines: 300
triggers:
  keywords: [error, exception, "try/catch", "rescue", "5xx", "404", "400", logging, log, alert, "stack trace", crash, retry]
  libs: [Sentry, Rollbar, Bugsnag, Honeybadger, Datadog, "winston", "pino", "structlog", "logger", "exception_notification"]
  paths: ["middleware/", "exception_handlers/", "logging/", "log_helpers/"]
force_loads: []
---

# error-net

Error envelope + logging discipline. Forced by [[auth-net]] (auth errors must be consistent), [[async-ops-net]] (silent async failures = top killer), [[payment-net]] (money + auth + error are inseparable).

## Hard rules

1. **One error envelope, project-wide.** Declared in CLAUDE.md section D (default `{code, message, request_id}`). Ad-hoc shapes rejected.
2. **No raw exception messages or stack traces in client responses.** Sanitize at the boundary; log full detail server-side.
3. **No PII in logs.** Includes email, phone, full name, address, payment info, government IDs, auth tokens/passwords, session IDs, IPs in some jurisdictions. Scrub at logger middleware, not per-call.
4. **Every async/background operation has explicit error handling.** Unhandled rejection / unhandled exception → process-level handler logs + alerts.
5. **`catch` blocks must do something.** Empty `catch {}`, `rescue => e` with no action, `except: pass` → P1.
6. **Logs are structured** (JSON), not human-prose strings concatenated. Searchable by field.
7. **Every request has a `request_id`** generated at edge, propagated downstream, returned to client, included in every log line.
8. **Retries have a stop condition.** Unbounded retry loops → P1. Exponential backoff + max attempts + dead-letter target.

## Error envelope (default)

```json
{
  "code": "PAYMENT_REQUIRED",
  "message": "Subscription expired. Renew at /billing.",
  "request_id": "req_01HX...",
  "details": { "expired_at": "2026-05-12T..." }
}
```

- `code`: stable, UPPER_SNAKE_CASE, machine-readable. Clients branch on this.
- `message`: human-readable, safe-to-show. No internal paths, no DB errors, no stack frames.
- `request_id`: same as `X-Request-Id` response header.
- `details`: optional, structured. Never include sensitive fields.

Codes are namespaced: `AUTH_*`, `PAYMENT_*`, `RATE_LIMIT_*`, `VALIDATION_*`, `NOT_FOUND_*`, `CONFLICT_*`, `INTERNAL_*`.

## Logging discipline

| Level | Use |
|---|---|
| DEBUG | Local dev only. Stripped in production builds. |
| INFO | Domain events worth replaying (login, payment, plan change). One line per event. |
| WARN | Recoverable anomaly. Retry succeeded. Cache miss past threshold. |
| ERROR | Operation failed but request handled. Server returned 4xx/5xx with envelope. |
| FATAL | Process-level crash, will exit. Reserved. |

Every log line includes: `timestamp`, `level`, `request_id`, `user_id` (if known + non-PII), `route`, `event` (UPPER_SNAKE_CASE), `duration_ms` (if applicable), `error.code` / `error.class` (for errors only).

## PII scrub list (default)

Scrubber runs at logger middleware. Redacts these fields recursively in any logged object:

```
password, password_confirmation, current_password
token, access_token, refresh_token, id_token, api_key, secret
authorization (header), cookie (header), set-cookie (header)
ssn, social_security, tax_id, ein
credit_card, card_number, cvv, cvc, pan
email (configurable: hash to e_<sha8> or pass-through depending on jurisdiction)
phone, mobile_number (hash or last-4)
full_name (configurable)
address, street, postal_code, zip (configurable)
date_of_birth, dob
```

Replace value with `[REDACTED:<reason>]` to preserve shape. Project can extend the list in CLAUDE.md section B.

## Boundaries (where errors get caught + transformed)

- **HTTP entry middleware**: turns exceptions into envelope responses. Single handler, not per-route.
- **Background job wrapper**: catches, increments retry count, sends to DLQ on max attempts.
- **External API client wrapper**: catches network/timeout/5xx, maps to typed errors for callers.
- **DB layer**: maps constraint violations to domain errors (`UniqueViolation` → `CONFLICT_EMAIL_EXISTS`).
- **Don't catch in business logic.** Let it propagate to a boundary.

## Retries (where appropriate)

- Only on **transient** errors: network, 5xx, rate-limit-with-retry-after.
- Never retry on **permanent** errors: 4xx (other than 408/429), validation failures, auth failures.
- Cap attempts (default 3). Exponential backoff with jitter. Max total wait declared.
- Idempotency required for any retried mutation — coordinate with [[api-net]] idempotency rules.

## What scanner flags

- Empty `catch {}`, `rescue => e ... end` (with nothing inside), `except: pass` → P1.
- `console.log(req)` / `puts params` / `print(request)` (whole-object dumps) → P1 (likely PII).
- `console.log(error)` / `print(e)` without structured logger → P2 (works but not searchable).
- `try { ... } catch (e) { res.send(e.message) }` or equivalent — exception leak to client → P1.
- 5xx response with `error.stack` in body → P1.
- Retry loop with no max attempts → P1.
- New error code not following `NAMESPACE_REASON` convention → P3.
- `logger.info(user)` where `user` may have PII fields → P2 (route through scrubber).

## Stack overrides

### Rails
- `rescue_from` in `ApplicationController` for project-level exception → envelope mapping.
- `Rails.logger.tagged(request_id) { ... }` around request handling.
- `exception_notification` or Sentry middleware mounted in `config/application.rb`.

### Django
- `EXCEPTION_HANDLER` in DRF settings → custom function returning envelope.
- `LOGGING` dict configures structured formatter (json-log-formatter / python-json-logger).
- `middleware.AuditMiddleware` adds request_id to log records.

### Next.js
- `app/error.tsx` for client-side route errors.
- API route handlers wrap try/catch around the controller call, map via central handler.
- `pino` or `winston` for server logs; never `console.log` in production.

### FastAPI
- `@app.exception_handler(Exception)` registers central handler returning envelope.
- `loguru` or `structlog` for structured logs.
- `slowapi` for rate-limit envelope consistency.

### Express
- Last-mounted middleware `(err, req, res, next) => ...` is the only error responder.
- `express-request-id` for request_id; propagate to logger via async-local-storage.
- `pino-http` for request logs with auto-scrubbing.

### Phoenix
- `Plug.ErrorHandler` use'd in Endpoint.
- `Logger.metadata(request_id: id)` per request.
- `Tower` / `Sentry` for error tracking.

## Force-load relationships

- error-net is force-loaded by [[auth-net]], [[async-ops-net]], [[payment-net]] (per [[DECIDER]] §7).
- It does not force-load anything itself.

## CLAUDE.md hooks

Reads section D:
- `error_response_shape` (envelope override)
- `error_code_namespaces`
- `log_level_default`
- `pii_scrub_extra_fields`

Reads section A: `log_aggregator` (Sentry/Datadog/etc).

## Related

[[auth-net]] · [[api-net]] · [[async-ops-net]] · [[payment-net]] · [[code-scanner]]
