---
name: async-ops-net
description: Background pipeline safeguards. Covers jobs/workers, email (transactional + bounces), push/notifications, webhook senders, cron locking, and supply-chain CI (lockfile, audit, dep pinning). Cluster skill — all share the "background pipeline" mental model. Force-loads error-net (silent async failure = #1 killer).
layer: 1
enabled_default: true
caps:
  body_lines: 450
triggers:
  keywords: ["background job", "worker", "queue", "cron", "scheduler", "retry", "DLQ", "dead letter", "idempotent", "idempotency", "email", "SMTP", "transactional", "bounce", "unsubscribe", "SPF", "DKIM", "DMARC", "notification", "push", "FCM", "APNs", "device token", "webhook send", "outbound webhook", "lockfile", "audit", "Dependabot", "Renovate", "pinning", "supply chain"]
  libs: [sidekiq, "delayed_job", goodjob, "active_job", celery, rq, dramatiq, bullmq, bull, "agenda", "node-cron", quartz, hangfire, temporal, faktory, resque, "aws sqs", "google pub/sub", sendgrid, mailgun, postmark, ses, "amazon ses", resend, mailtrap, "nodemailer", actionmailer, "django.core.mail", "fastapi-mail", expo, "firebase-admin", "apns2", "node-pushnotifications", "renovate", "dependabot", "snyk", "trivy"]
  paths: ["jobs/", "workers/", "tasks/", "mailers/", "notifications/", "queues/", "cron/", ".github/workflows/", ".github/dependabot.yml", "renovate.json", "package-lock.json", "yarn.lock", "pnpm-lock.yaml", "Gemfile.lock", "poetry.lock", "uv.lock"]
force_loads:
  - error-net
---

# async-ops-net

Background pipeline safety net. Cluster of jobs, email, push/notif, webhook senders, and supply-chain CI — all share the "fire-and-forget that must not silently fail" model. Force-loads [[error-net]].

## Why cluster

Same failure modes recur across all four:
- silent failure (no user-visible error path)
- retry semantics required
- idempotency required (network/queue may deliver twice)
- observability gap (no request/response, easy to lose)
- security boundary (often runs with elevated trust)

If you're touching one, the others' rules usually apply.

## Hard rules (apply across cluster)

1. **Every job is idempotent.** Re-running with the same input produces the same outcome. Use an idempotency key (`job_id`, `event_id`, deterministic hash of payload). Database-level upsert / unique-index check, not "if exists" race.
2. **Every job has explicit retry policy.** Max attempts, backoff (exponential with jitter), and **what counts as retriable**. `NetworkError` retries; `ValidationError` does not — fail-fast and DLQ.
3. **Every queue has a DLQ** (dead-letter queue) for poison messages. DLQ has monitoring, not just a folder things rot in.
4. **No work in the request thread that can be deferred.** Sending email, calling third parties, generating reports → enqueue. Request handler returns ≤200ms when work is deferrable.
5. **Job arguments are serializable + minimal.** Pass IDs, not objects. The job re-fetches at execution time (state may have changed).
6. **Long jobs report progress** if user-visible. Show last-updated timestamp; jobs silent >5 min require heartbeat.
7. **Crons hold a distributed lock** before running. Two app instances → two cron fires → double work. Use Redis `SET NX EX` or DB advisory lock.
8. **Outbound network call timeouts: connect ≤3s, total ≤15s** (unless explicitly long-poll). No infinite-hang on `requests.get`.
9. **Webhook senders sign requests** (HMAC-SHA256 over body + timestamp) and include a replay-protection timestamp.
10. **Supply-chain hygiene**: lockfile committed; lockfile drift fails CI; weekly automated audit (`npm audit`, `bundle audit`, `pip-audit`, `pnpm audit`); critical advisories block merge.

## Sub-domain: jobs / workers

### Picking a queue
| Need | Pick |
|---|---|
| Reliability + visibility on Ruby | Sidekiq (Pro for batches), GoodJob (Postgres-backed, no Redis) |
| Python | Celery (RabbitMQ/Redis) for complex flows, RQ for simple, Dramatiq for ergonomics |
| Node | BullMQ on Redis; or platform queue (SQS/Pub-Sub) for cross-service |
| Cross-service workflow | Temporal — deterministic replay, not "just a queue" |

### Idempotency patterns
- **Idempotency-Key header** for HTTP-triggered jobs.
- **Unique constraint** on `(operation_type, business_key)` in a side table; insert before doing work; ignore conflict.
- **Stripe pattern**: persist idempotency key + response, return cached response on duplicate.

### Retry shape (default)
- Attempt 1: immediate
- Attempt 2: 30s
- Attempt 3: 5m
- Attempt 4: 30m
- Attempt 5: 2h
- Then DLQ.

Jitter ±20% on every backoff. Surge protection.

### What NOT to retry
`ValidationError`, `AuthorizationError`, `404`-equivalent ("user/resource gone"), payload-too-large, parse failures. These will fail forever. Fail-fast to DLQ with reason.

### Job ownership
Every job has a `team` / `owner` tag. DLQ alerts route to owner, not "ops".

## Sub-domain: email (transactional)

### Hard rules (additional)
1. **Transactional only via transactional provider** (SendGrid, Postmark, SES). Never marketing tools.
2. **SPF, DKIM, DMARC configured** on sending domain. DMARC at minimum `p=quarantine` (preferably `reject`).
3. **Unsubscribe link** on every non-essential email — including transactional summaries. Single-click (RFC 8058) for bulk.
4. **List-Unsubscribe-Post header** for one-click unsub on Gmail/Outlook (required for high-volume senders as of 2024).
5. **Bounces processed** — hard bounces suppress sending; soft bounces retry with limit. Suppression list synced with provider.
6. **No raw user input in subject or body** without HTML escape + plain-text fallback. Email is XSS in some clients.
7. **Reply-to** points to a monitored address, not `noreply@`. Replies to noreply lose user signal.
8. **Idempotent send** — same `template + user_id + trigger_event` should not double-fire. Persist send log.

### Common breakages
- Missing DMARC → deliverability tanks; emails go to spam.
- Hard-bounced address re-sent for weeks → provider throttles whole account.
- Magic link email arrives 6h late → user assumes broken; support ticket.
- Newsletter sent from transactional provider → ToS violation.

### Preferences
Treat email-preference toggles as part of user identity. Migrations changing the preference schema → consult [[db-net]].

## Sub-domain: push / notifications

### Hard rules
1. **Device token lifecycle**: tokens rotate. Capture token-invalid responses from APNs/FCM → mark token dead, never retry that exact token.
2. **One device, one token, one user.** Re-assign on login change. Don't broadcast to stale tokens.
3. **Dedup at fanout** — if a notification has multiple delivery channels (push + email + in-app), don't send all three for the same event without explicit user setting.
4. **Quiet hours** respected if user has set them — schedule, don't blast.
5. **Priority** correct: `high` only for user-actionable now; `normal` for background. iOS throttles aggressive senders.
6. **In-app notification center** is the source of truth — push is a delivery hint. Don't lose unread state.

### Token storage
- Encrypted at rest.
- TTL — drop tokens unused for 60 days.
- One row per `(user_id, device_id, channel)`.

## Sub-domain: webhook senders

### Hard rules
1. **Sign every webhook** (HMAC-SHA256 over body, key per receiver).
2. **Timestamp + replay window** (5 min). Receivers reject older.
3. **Retry on 5xx/timeout**, give up on 4xx (receiver bug, not ours).
4. **Exponential backoff** with cap (1m, 5m, 30m, 2h, 6h, 24h, give up).
5. **Per-receiver circuit breaker** — flapping receivers don't drag the whole queue. After N failures, open circuit, alert receiver owner (if internal) or pause endpoint.
6. **Event log persisted** — every webhook delivery attempt with response code, latency, body hash. Replay capability for debugging.

## Sub-domain: cron / scheduled

### Hard rules
1. **Distributed lock before run.** Multiple app instances = multiple fires. Lock TTL > expected job duration.
2. **Cron is a trigger, not a worker.** Cron enqueues a job; job does work. Decouples scheduling from execution capacity.
3. **No clock-skew assumptions.** "Run at midnight" — which timezone? UTC unless business reason. Daylight-saving math gets jobs.
4. **Catch-up policy**: if instance was down at fire time, do we backfill? Decide explicitly per job.
5. **Monitor "did not run"** — silent miss is the failure mode. Heartbeat / dead-man's-switch (Healthchecks.io / Cronitor).

## Sub-domain: supply-chain CI

### Hard rules
1. **Lockfile committed** for every project: `package-lock.json` / `yarn.lock` / `pnpm-lock.yaml` / `Gemfile.lock` / `poetry.lock` / `uv.lock`. Lockfile absent → P1.
2. **CI verifies lockfile not drifted** (`npm ci`, `bundle install --deployment`, `poetry install --no-update`). Drift = build fails.
3. **Audit weekly + on PR**: critical/high vulns block merge. Tool: `npm audit`, `bundle audit`, `pip-audit`, `pnpm audit --prod`, OR Snyk/Trivy in CI.
4. **Dep upgrade automation**: Dependabot or Renovate. Configured to group dev deps, separate major-version PRs from patches, auto-merge patch on green CI (with codeowner review on majors).
5. **Pin direct dependencies** to exact or caret version per project policy. Indirect deps pinned by lockfile.
6. **No `npm install --force` / `bundle install --no-deployment`** in CI. These hide drift.
7. **Provenance**: prefer registry installs over `git+https://` for production deps. Git deps need explicit team approval + commented justification.
8. **Postinstall script audit** — review on dep add (postinstall scripts run arbitrary code at install).

### CI checklist (minimum)
- Lockfile present + verified
- `audit` step (allow `low`, block `high`+`critical`)
- Renovate/Dependabot config present
- License scan (optional but recommended — block GPL in proprietary projects)
- SBOM artifact uploaded (SLSA-style provenance — recommended)

## What scanner flags

Runs on output touching jobs/, workers/, mailers/, notifications/, .github/workflows/, lockfiles, or output mentioning queue/email/push/cron/audit keywords.

- Job class without `retry_on` / `discard_on` declaration → P2.
- Job arg is full ActiveRecord/SQLAlchemy object (not ID) → P1 (serialization risk).
- `mail.deliver_now` / synchronous send in request thread → P2 (should be `deliver_later` / enqueued).
- Email send with no idempotency key + clear "trigger event" → P2.
- `noreply@` as reply-to → P2.
- Cron defined with no lock acquisition → P1.
- Webhook send without HMAC signature → P1.
- `requests.get(...)` / `fetch(...)` with no timeout → P1.
- DLQ not defined for queue → P2.
- `npm install` (not `npm ci`) in CI → P1.
- Lockfile absent → P1.
- Audit step missing in workflow → P2.
- Postinstall scripts in newly-added dep without comment → P2.

## Stack overrides

### Rails (Sidekiq + ActionMailer)
- `sidekiq_options retry: 5, dead: true` baseline.
- `ApplicationJob` defines `retry_on NetworkError` / `discard_on ActiveRecord::RecordNotFound`.
- ActionMailer: `deliver_later` always; `MAILER_QUEUE` mapped to dedicated worker.
- Cron: `sidekiq-cron` or `whenever`; distributed lock via `Redlock` or DB advisory lock.

### Node / NestJS (BullMQ)
- `Queue` + `Worker` separated; never run worker in API process for production.
- `attempts: 5, backoff: { type: 'exponential', delay: 30000 }`.
- Default job options: `removeOnComplete: { count: 1000 }`, `removeOnFail: { count: 5000 }`.

### Python (Celery)
- `acks_late=True` for at-least-once delivery.
- `task_reject_on_worker_lost=True`.
- Result backend with TTL; never store unbounded results.
- Beat schedule + `singleton` decorator to prevent overlap.

### Email — SendGrid / Postmark / SES
- Webhook event consumer for bounces/complaints/spam reports → suppression list update.
- `X-Entity-Ref-ID` header / message stream for idempotency tracking.
- Sandbox domain in non-prod; never use prod sender in dev.

### Push — Expo / FCM / APNs
- Expo: `ExpoPushReceiptId` tracked; receipts checked 15min later for `DeviceNotRegistered`.
- FCM: parse `UNREGISTERED` / `INVALID_ARGUMENT` errors → token cleanup.
- APNs: `BadDeviceToken` / `Unregistered` → drop.

### CI — GitHub Actions
- `actions/setup-node` with `cache: 'pnpm'` (or npm/yarn).
- `pnpm install --frozen-lockfile` in CI.
- `npm audit signatures` for npm provenance check.
- `dependabot.yml` with `package-ecosystem` for every manifest.

## Cross-skill force-loads

- async-ops-net force-loads [[error-net]] (silent failures + DLQ alerting).
- async-ops-net + payment-net → also force-load [[auth-net]] (webhook receivers from payment providers).
- Cron creating DB writes → consult [[db-net]] (transaction boundaries).
- Push/email storing tokens or templates → consult [[data-flow-net]] (PII/tenant scope).

## CLAUDE.md hooks

Reads section A: `queue` (sidekiq/celery/bullmq), `mailer` (sendgrid/ses/postmark), `push` (fcm/apns/expo), `package_manager`.
Reads section B: project-specific retry caps, quiet-hours policy.
Reads section C: accepted exceptions (e.g., "billing reports may run synchronously, max 60s").

## Related

[[error-net]] · [[db-net]] · [[auth-net]] · [[api-net]] · [[env-net]] · [[integration-net]] · [[payment-net]] · [[data-flow-net]] · [[code-scanner]]
