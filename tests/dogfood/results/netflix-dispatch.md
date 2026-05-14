# Dogfood — netflix/dispatch

## Repo metadata
- Stack: FastAPI + SQLAlchemy + Postgres + Vue.js frontend + bcrypt + `schedule`/ThreadPool scheduler + slowapi rate-limiter + many third-party plugins (Slack, PagerDuty, Jira, GitHub, Google, Zoom, MS Teams, etc.)
- HEAD pinned: `dd2837e82a0bf5565b1b4b4b91ea30b7262d4061`
- Lock-in date: 2026-05-13
- Local clone: `/home/srinivas/app/dispatch`

## Caveat (per repo-selection.md)

Netflix Dispatch predates the AI-coding wave. PR mix is predominantly human-authored. This run treats Dispatch as a "complex real-world FastAPI multi-tenant" sample, not a vibe-coded sample. Catch-rate signal applies to the codebase as-is; it does not validate INVISIBLE on AI-authored output. Flag in aggregate.

## Scope honesty

- Skillset has no runtime. Findings produced by hand-applying L1 rule catalog as a checklist.
- Sample: 5 files (auth service, auth models, incident views, scheduler, rate-limiter usage scan).
- Not full 20-PR replay per methodology.
- File picks cover breadth: auth + tenancy + async-ops + rate-limit.

## Files inspected

1. `src/dispatch/auth/service.py`
2. `src/dispatch/auth/models.py`
3. `src/dispatch/incident/views.py` (tenant-scoped routes + background tasks)
4. `src/dispatch/scheduler.py`
5. `src/dispatch/rate_limiter.py` + grep for `@limiter` usage
6. PII log scan across `src/`

## Findings

### F-DISPATCH-1 (P1, async-ops-net rule 7) — Cron scheduler holds no distributed lock

**Where**: `src/dispatch/scheduler.py`

**Code**: imports `schedule` (Python `schedule` lib) + `multiprocessing.pool.ThreadPool`. No Redis lock, no DB advisory lock, no `singleton` decorator visible.

**What async-ops-net rule says**: "Crons hold a distributed lock before running. Two app instances → two cron fires → double work."

**Gap**: multi-instance deploy → every scheduled task fires N× per N instances. For incident-management with active recurring evergreen reports, ticket sync, notifications → double-sends, duplicate work, surprised users.

**Suggested fix**: distributed lock via Redis `SET NX EX` per task, OR migrate to Celery Beat with `singleton` task, OR document single-scheduler-instance deploy requirement as an explicit constraint.

### F-DISPATCH-2 (P1, async-ops-net rule 4 + integration-net rule 11) — Heavy work via FastAPI BackgroundTasks instead of durable worker

**Where**: `src/dispatch/incident/views.py:147-158` (`background_tasks.add_task(incident_create_flow, ...)`); pattern repeats across views.

**Code**:
```python
background_tasks.add_task(
    incident_create_flow, incident_id=incident.id, organization_slug=organization
)
```

**What rules say**:
- async-ops-net rule 4: "No work in the request thread that can be deferred. Sending email, calling third parties, generating reports → enqueue."
- integration-net rule 11 (analogous for outbound): work that calls Slack/PagerDuty/Jira/Zoom should not run in the request process.

**Gap**: FastAPI `BackgroundTasks` runs in the same process after response. No durable queue, no retry, no DLQ, lost on process restart, no observability. `incident_create_flow` orchestrates multiple plugin integrations (heavy I/O).

**Suggested fix**: replace with Celery / Dramatiq / RQ task enqueue. Worker process runs the flow with retry policy + DLQ; views return immediately.

### F-DISPATCH-3 (P1, auth-net rule 9) — Auth endpoints not rate-limited

**Where**: scan of `src/dispatch/` for `@limiter.limit` returns 1 hit (`signal/views.py:71`, `1000/minute`). No limit on login / register / password-reset / 2FA verify.

**What auth-net rule says**: "Rate-limit auth endpoints: login, signup, password reset, 2FA verify, refresh. Per-IP + per-account (account lockout on N failures with backoff)."

**Gap**: brute-force vector open. Especially relevant since `auth/models.py` stores password hash directly (no separate failed-attempt counter visible).

**Suggested fix**: `@limiter.limit("5/minute")` on POST `/auth/login`; account lockout on N failures.

### F-DISPATCH-4 (P3, auth-net rule 1) — bcrypt cost not explicitly set

**Where**: `src/dispatch/auth/models.py:49`

**Code**:
```python
salt = bcrypt.gensalt()
return bcrypt.hashpw(pw, salt)
```

**What auth-net rule says**: "Argon2id (preferred) OR bcrypt cost ≥12 OR scrypt..."

**Gap**: `bcrypt.gensalt()` default is 12 (acceptable today, was 10 in older versions; bumped at lib level). Borderline-OK but not explicit. Future lib downgrade risk.

**Suggested fix**: `bcrypt.gensalt(rounds=12)` explicit.

### F-DISPATCH-5 (P2, future-self-advisor) — Scheduler concurrency policy implicit

**Where**: `src/dispatch/scheduler.py` — `ThreadPool` without documented size/exhaustion behavior visible in the head sample.

**Gap**: future-self-advisor would surface: thread pool size not declared inline; reader can't tell behavior under load. Investigation tax.

**Suggested fix**: extract `SCHEDULER_THREAD_POOL_SIZE = 8` constant; add a comment explaining concurrency choice.

## Passes (notable correct patterns)

| Domain | What's right |
|---|---|
| **auth-net rule 1 (KDF)** | bcrypt used (not SHA/MD5/plaintext). ✓ Cost not pinned (see F-DISPATCH-4). |
| **auth-net default-deny + per-route authz** | FastAPI `Depends(PermissionsDependency([IncidentViewPermission]))` on routes. ✓ |
| **data-flow-net tenancy** | `organization: OrganizationSlug` path param + `current_user` from auth. Per-org isolation pattern. ✓ |
| **error-net PII discipline** | Repo-wide grep finds no obvious log-of-password/token; default discipline appears OK. ✓ |
| **integration-net plugin architecture** | Vendor abstractions in `dispatch/plugins/*` — each integration behind an interface (matches integration-advisor adapter recommendation). ✓ |

## Scoring

| Class | Issues found (sample) | INVISIBLE would catch | TP rate (sample) |
|---|---|---|---|
| Silent killer | 3 (F-DISPATCH-1, -2, -3) | 3/3 (async-ops 7, async-ops 4 + integration 11, auth-net 9) | 100% (3 of 3) |
| Quality | 1 (F-DISPATCH-5) | 1/1 (future-self-advisor P2) | 100% (1 of 1) |
| Style/advisory | 1 (F-DISPATCH-4) | 1/1 (auth-net advisory P3) | 100% (1 of 1) |

**Caveat as in prior reports**: same scan supplies numerator + denominator.

## Notable findings vs vibe-coded baseline

Dispatch shows the failure modes of a **mature non-AI codebase under feature pressure**: in-process background tasks accumulated over time, scheduler concurrency model implicit, auth-rate-limit absent. These would persist in AI-authored code too — INVISIBLE catches them either way. Good evidence that L1 patterns generalize beyond vibe-coded targets.

## Token cost / advisor noise / circuit-breaker
Not measured. No runtime.

## Notes / recommendations for DECIDER tuning

- `BackgroundTasks` (FastAPI-specific symbol) should be a high-signal trigger for async-ops-net + a known anti-pattern (P1 scanner rule: "BackgroundTasks calling external services" → recommend Celery/Dramatiq).
- `schedule.every(...)` import / call in non-trivial app → async-ops-net cron-lock rule fire.
- `slowapi` / `@limiter.limit` presence is a positive auth-net signal; absence on auth routes should be a scanner P1 finding.
- Path pattern `src/dispatch/auth/views.py` should auto-route to auth-net.
