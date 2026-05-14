---
name: prod-readiness-audit
description: User-opt-in audit before shipping a feature / branch / repo to production. Walks all 14 L1 domains plus deploy/runbook/observability/rollback. Emits a structured checklist with pass/fail/N-A per item + blockers + recommended fixes. ≤1 active L3/turn.
layer: 3
group: _core5
enabled_default: false
opt_in: true
cli: "/invisible audit prod-readiness [--scope branch|repo|feature] [--target <path|branch>]"
caps:
  body_lines: 400
recommender:
  min_score: 4.5
  triggers: ["ship", "production", "go-live", "launch", "release", "are we ready", "ship today", "deploy today", "prod-ready"]
---

# prod-readiness-audit

Walks the L1 catalog + ops surfaces and produces a ship/don't-ship dossier. Designed to be run pre-deploy, pre-launch, or before flipping a feature flag to 100%.

## When to run

- Pre-deploy of a non-trivial change.
- Pre-launch (GA flip).
- Returning to a long-paused project before re-deploying.
- After a near-miss / incident — confirm latent risks gone.
- New service / first prod deployment.

## When NOT to run

- Tiny patch (typo / single-line / docs).
- Throwaway / hobby project.
- Hot-fix where speed > thoroughness (run a focused [[security-auditor]] subset instead if auth/payment touched).

## Scope modes

| Scope | What |
|---|---|
| `branch` | Audit diff vs `main` for the branch (default for `/invisible audit prod-readiness` from feature branch) |
| `repo` | Whole repo audit (use for new project, big release, or first audit) |
| `feature` | Subset tied to a feature flag / module |

## Output artifact

```markdown
# Production Readiness — <scope> — <date>
INVISIBLE prod-readiness-audit

## Verdict
**Ship / Hold / Ship-with-watch** — <one-line summary>

### Blockers (must fix before ship)
- [ ] <P1 item> — <where>
- [ ] <P1 item> — <where>

### Watch items (ship OK, monitor post-deploy)
- <P2 item> — <where>

### Notes (no action)
- <P3 item>

## Walk: L1 domain checklist
Each domain = pass / fail / N-A with evidence.

### ui-net
- [x] Loading states present on async surfaces
- [x] Error boundaries on top-level routes
- [ ] **Empty states have CTA** — `/dashboard` empty state is dead-end (P2)
- [N-A] No new forms in this scope

### api-net
- [x] All new endpoints have OpenAPI / JSDoc stub
- [x] Pagination on list endpoints (cursor)
- [ ] **`POST /orders` has no rate limit** (P1, blocker — abuse vector)
- [x] Versioning consistent

### db-net
...
(repeat for all loaded L1 domains)

## Ops checklist (beyond L1)

### Observability
- [ ] Error tracker initialized + DSN in env (Sentry / Bugsnag / …)
- [ ] Structured logs on new code paths
- [ ] Metrics: request count, p50/p95 latency, error rate
- [ ] Dashboards: <name + link>
- [ ] Alerts: <which signals page>
- [ ] Trace coverage on critical paths

### Runbook + on-call
- [ ] Runbook exists for new feature (one-pager — what it does, common failure, who to page)
- [ ] On-call team identified
- [ ] Incident playbook covers this surface
- [ ] Customer-facing status page accounts for this feature

### Deploy + rollback
- [ ] Feature flag wraps risky change
- [ ] Rollback plan documented (flag off + data reversible)
- [ ] Migration is online + reversible (or rollback-via-flag explicit)
- [ ] Canary / phased rollout planned (10/50/100 or staff-first)
- [ ] Deploy outside business hours / freeze windows respected

### Capacity + load
- [ ] Load test if traffic shape changes (>30% of current p95)
- [ ] DB connection pool sized for expected load
- [ ] Cache warm-up plan if cold-cache risk
- [ ] Rate limits set on new endpoints
- [ ] Background queue can handle expected job rate

### Compliance + privacy
- [ ] PII fields documented in data model
- [ ] User-facing privacy / TOS update if data type changes
- [ ] Audit log on sensitive actions
- [ ] Data retention / deletion policy honored for new entities
- [ ] Region / GDPR-zone constraints respected

### Auth + payment specific (if touched)
- [ ] Refer to [[security-auditor]] full pass (recommended)
- [ ] Webhook signatures verified
- [ ] PCI / SAQ scope unchanged or re-attested
- [ ] Idempotency keys on new payment flows

### Test coverage gate
- [ ] Critical path covered by integration test (real DB)
- [ ] Auth boundary tested (cross-tenant attempt = 403)
- [ ] Error envelope tested
- [ ] Rollback path tested (flag flip leaves valid state)

## Token-budget summary
Files scanned: <N>
LOC reviewed: <N>
Token used: <N>
```

## How the audit walks

1. **Identify scope** (branch diff / repo / feature).
2. **Re-run [[DECIDER]]** against the diff to load relevant L1 skills.
3. **For each loaded L1**, run its scanner against the scope. Aggregate findings P1/P2/P3.
4. **Ops walk** (per "Ops checklist" above) — check infra / config files / env-net / runbook presence.
5. **Verdict logic**:
   - Any P1 from L1 OR any Ops blocker → **Hold**.
   - All P1 clear, P2 present, monitoring in place → **Ship-with-watch**.
   - All clear → **Ship**.
6. **Write artifact** to `.invisible/audits/prod-readiness-<date>-<scope-hash>.md`.

## Severity → blocker mapping

| Finding | Maps to |
|---|---|
| L1 P1 in scope | Blocker |
| Webhook with no signature, charge with no idempotency, etc. | Blocker |
| Missing runbook for new on-call surface | Blocker if customer-facing critical |
| No rollback plan on irreversible migration | Blocker |
| No error tracker initialized (new repo) | Blocker |
| L1 P2 | Watch |
| Missing observability metric on non-critical | Watch |
| Empty-state polish, naming nits | Note |

## Stack-specific ops checks

Loaded via [[stack-adapter]]:

### Rails
- `config/database.yml` has prod entry with envvar DB URL.
- `bin/rails db:prepare` runs cleanly.
- Sidekiq workers configured for prod count.
- `secret_key_base` from env, not generated at boot.

### Next.js
- `next build` succeeds; `NEXT_TELEMETRY_DISABLED=1` if policy.
- `output: 'standalone'` or platform-specific build.
- Env vars present in deploy target (Vercel / Render / Fly).

### Django
- `DEBUG = False` in prod settings.
- `ALLOWED_HOSTS` set.
- `collectstatic` runs.
- DB migrations idempotent + tested on prod-like data.

### FastAPI / Node
- Health check endpoint (`/healthz`) returning 200 with deps OK.
- Readiness vs liveness probes distinct.
- Graceful shutdown handled (SIGTERM → finish in-flight, close pools).

### Containers
- Non-root user.
- Image digest pinned (not `:latest`).
- Health check defined.
- `.dockerignore` excludes `.env`, `node_modules` (multi-stage), VCS.

## Pre-launch (GA flip) extra checks

When `--scope feature` + flag in question:

- [ ] Feature has been internal-only for ≥1 week with no critical bugs.
- [ ] Staged rollout at 10% for ≥48h with stable error rate.
- [ ] Rollback drilled (flag flipped off, verified clean state).
- [ ] Comms drafted (release notes, customer email if applicable).
- [ ] Support team briefed.

## Integration with other L3

- Run [[deep-codebase-mapper]] first if no map exists (cheaper audit afterwards).
- Run [[security-auditor]] if auth/payment/data-mutation touched.
- Run [[runbook-generator]] (Sprint 5b) if missing runbook is a blocker.

## Token budget

| Scope | Tokens |
|---|---|
| branch (typical PR) | 10–25k |
| repo (small/medium) | 40–80k |
| repo (large) | reduce scope; run per-subtree |

## Refusal cases

- Scope is unbounded ("audit everything") on a 500k LOC repo → refuse, request `--scope <path>`.
- Branch has no diff vs `main` → refuse, nothing to audit.
- Scope is the lockfile only → refuse, no signal worth audit.

## Telemetry

Outcomes recorded:
- Verdict (ship / hold / watch)
- Blocker count
- Whether user shipped within 24h
- Whether incident occurred within 7 days post-ship

Feeds [[circuit-breaker]] (if audit consistently says "ship" but incidents happen, recommender deprioritizes audit until tuned).

## CLAUDE.md hooks

Reads section A (stack, infra), B (project hard rules — "no ship Fridays"), C (accepted risks), F (incident history → known landmines to re-check).
Writes audit artifact under `.invisible/audits/`.

## Related

[[security-auditor]] · [[deep-codebase-mapper]] · [[full-spec-rewriter]] · [[env-net]] · [[code-scanner]] · [[circuit-breaker]]
