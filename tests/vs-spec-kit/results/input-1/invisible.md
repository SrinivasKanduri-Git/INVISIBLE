# INVISIBLE — Input 1 (vague export brief)

**Method**: simulated — no runtime. DECIDER scoring + L1 hard-rule application + L2 advisor surfacing + L3 recommender all walked by hand per spec.

## DECIDER pass

Input keywords: "export", "data", "CSV", "JSON", "account settings", "hundreds of thousands of records", "secure".

| Skill | Score | Loaded? | Reason |
|---|---|---|---|
| api-net | 4.5 | ✓ | endpoint + response shape |
| auth-net | 4.0 | ✓ | "secure" + force-load by data-flow tenancy signal |
| data-flow-net | 5.0 | ✓ | "data export" crosses boundary + file generation |
| async-ops-net | 4.5 | ✓ (force-load via "hundreds of thousands") | large export = job, not request thread |
| db-net | 3.5 | considered | iteration over N rows, pagination semantics |
| ui-net | 3.5 | considered | account-settings page surface |

Cap 4. Loaded: api-net, auth-net, data-flow-net, async-ops-net. db-net + ui-net dropped (logged P3 advisor note: "considered — db-net pattern relevant").

[recommender] `/invisible spec` proposed — vague brief, ≤1 page, would benefit from full-spec-rewriter pass. Reply `skip` to mute 24h.

## Surfaced safeguards (L1 hard rules)

### From api-net
- Export endpoint requires auth annotation (default-deny).
- Streaming response shape for large payloads, not buffer-then-send.
- Status semantics: 202 + job-id polling pattern (export is async).
- OpenAPI annotation on new endpoint.

### From auth-net
- Authorization check at resolver: user can only export *their own* data; admin override is a separate code path with audit log.
- Rate-limit the export endpoint (per-user, ≥1h cooldown — exports are expensive).
- Audit log entry on export (PII access event).

### From data-flow-net
- File path includes user/tenant scope: `exports/<user_id>/<timestamp>-<uuid>.csv` — never flat namespace.
- Presigned URL for download, ≤15min TTL, scoped to one operation.
- File served from sandboxed domain (not app domain — CSV injection / formula-injection risk on app domain).
- Storage quota per user (unbounded exports = cost).
- Filename sanitization at generation time.
- CSV-injection defense: prefix leading `=`, `+`, `-`, `@`, `\t`, `\r` with `'` to prevent formula execution in Excel/Sheets.

### From async-ops-net
- Export runs in background job, not request thread (scale signal: 100k+ records).
- Job is idempotent: same export-request-id → same result file (dedup table).
- Retry policy: retry on transient (network/storage), discard on user-not-found.
- DLQ with monitoring.
- Job progress observable: status `queued | running | succeeded | failed`; expose via polling endpoint.
- Email notification on completion (transactional, per email rules).

### From force-loads
- async-ops-net → error-net (silent async failures = #1 killer): error envelope on export failures, structured logs, no PII in logs.

## L2 advisor notes (max 5/turn, P1 exempt)

- [scaling-advisor] **P1**: at 100k+ records and CSV serialization, naive `to_csv` will OOM. Suggest streaming writer + iterator pagination (`find_each` / `select_related().iterator()`).
- [scaling-advisor] **P2**: hot-key cache stampede if multiple users hit export at once. Per-user concurrent-export cap (1 in-flight) recommended.
- [cost-advisor] **P2**: presigned-URL download from S3 = direct egress (cheap). Proxying through app = bandwidth bill. Use presigned. (Reinforces data-flow rule.)
- [ux-advisor] **P2**: export takes minutes — user needs progress indicator + email-when-done. Show last-export-time + status in account settings.
- [future-self-advisor] **P3**: "some users want CSV, others want JSON" — design for format pluggability now (formatter interface), not retrofit later. ≥2 formats requested = sufficient signal.

## L3 opt-in suggestion

[recommender] L3: `/invisible spec --brief input-1-brief.md` — spec is vague; full-spec-rewriter would surface 12 likely-missing decisions (which records? per-tenant or per-user? deletion of past exports? compression? expiration of presigned URLs? rate-limit shape? notification channel? error UX? etc.). Reply `skip` to mute 24h.

## Silent killers identified (rubric scoring input)

INVISIBLE-mentioned silent killers from §[12-checklist] in `tests/vs-spec-kit/methodology.md`:

| # | Killer | Mentioned? |
|---|---|---|
| 1 | Auth check on new endpoint | ✓ (api-net + auth-net) |
| 2 | CSRF on cookie-auth POST | N/A (export is GET-initiated) |
| 3 | Idempotency for payment / external side-effect | ✓ (job idempotency, async-ops) |
| 4 | Rate limit on auth endpoints | ✓ (auth-net + rate-limit on export) |
| 5 | Webhook signature verification | N/A (no webhook in this feature) |
| 6 | Money as integer minor units | N/A (no money in this feature) |
| 7 | Multi-tenant scope in WHERE clauses | ✓ (data-flow-net + auth-net authz at resolver) |
| 8 | N+1 prevention | ✓ (db-net considered + scaling-advisor explicit) |
| 9 | Cache invalidation strategy | partial (stampede mentioned, full invalidation not detailed in 1 turn) |
| 10 | Background job retry + DLQ | ✓ (async-ops-net rules listed) |
| 11 | Error envelope consistency | ✓ (error-net force-loaded) |
| 12 | PII scrubbing in logs | ✓ (auth-net + error-net + export-touches-PII signal) |

**Applicable**: 10 of 12 (CSRF + money N/A). **Mentioned**: 9 fully + 1 partial = **9.5/10 applicable**.

## Test plan included?

Yes (per [[test-net]] force-pull on critical-path):
- Unit: format serializers
- Integration: real-DB iteration over 10k+ rows in test
- Boundary: cross-user export attempt = 403
- E2E: queue → process → presigned URL → download
- Load: 5 concurrent exports per user instance

## Edge cases enumerated
- Empty export (no rows) → return empty file w/ header, not error
- Export-while-deleting (record removed mid-export) → snapshot at queue time
- Presigned URL expiry mid-download → re-issue if user still authorized
- Browser tab closed during long export → email notification still fires
- Export of user's own data after account deletion → forbidden vs grace-window?
- Excel formula injection on user-supplied field values

## Stack-aware specifics
- Rails: `find_each(batch_size: 1000)` + `csv` stdlib `<<` streaming
- Next.js: streaming Response + `ReadableStream`
- Python: `csv.writer` + generator
- Postgres: server-side cursor for >100k rows

## Tokens

Estimate (not measured): 4–7k for L1 bodies + L2 notes + L3 suggestion. No runtime to confirm.
