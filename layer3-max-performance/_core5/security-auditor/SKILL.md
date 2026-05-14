---
name: security-auditor
description: User-opt-in deep security pass on a scope (branch / diff / module / repo). Goes beyond L1 code-scanner — threat-models the surface, walks OWASP-style categories with project context, audits secrets, dependencies, auth flows, payment paths, multi-tenancy isolation, supply-chain. Produces severity-tagged findings with reproduction steps + remediation. ≤1 active L3/turn.
layer: 3
group: _core5
enabled_default: false
opt_in: true
cli: "/invisible audit security [--scope branch|repo|module] [--target <path|branch>] [--depth fast|standard|deep]"
caps:
  body_lines: 400
recommender:
  min_score: 4.5
  triggers: ["security review", "security audit", "pentest prep", "compliance review", "auth review", "payment review", "secret leak", "vuln", "vulnerability"]
---

# security-auditor

Heavy, focused security pass. Distinct from L1 code-scanner (mechanical pattern flags on every turn) — security-auditor reasons about the **surface** as a whole: who attacks how, where the trust boundaries are, where defense-in-depth is thin.

## When to run

- Pre-launch on a feature touching auth / payment / data write / file upload / multi-tenancy.
- Pre-pentest (clean up obvious issues before paying pentester).
- After security incident (audit nearby code for related issues).
- Quarterly review on critical service.
- After major refactor in security-sensitive area.

## When NOT to run

- Tiny diff with no security signal — L1 code-scanner suffices.
- Pure tech-debt refactor with no behavior change → L1 scanner.
- Throwaway code that won't see prod.

## Depth modes

| Mode | Time | Tokens | What |
|---|---|---|---|
| `fast` | 5–10 min | 10–20k | Diff-scope only, top-10 categories, no deep trace |
| `standard` (default) | 20–40 min | 30–60k | Diff + adjacent surfaces, full category walk, threat-model sketch |
| `deep` | 60+ min | 80–150k | Whole-repo or whole-feature, threat model + dataflow per asset + supply-chain |

## Threat model first

Before the category walk, sketch:

1. **Assets** — what attacker wants. User PII, auth tokens, payment data, internal credentials, intellectual property, account takeover, lateral movement target.
2. **Actors** — anonymous external, authenticated user, malicious tenant member, compromised vendor, insider, supply-chain attacker.
3. **Trust boundaries** — internet ↔ app, app ↔ DB, app ↔ vendor, tenant ↔ tenant, user ↔ user, request ↔ background job, dev ↔ prod.
4. **Most-likely paths** — list top-5 plausible attack scenarios for the scope.

Output of threat model sets *priorities* for the category walk.

## Category walk

Adapted from OWASP Top 10 + ASVS + practical patterns. Each item: status (pass/fail/N-A), evidence, severity.

### A1 — Auth + Session
- Password hashing (Argon2id / bcrypt ≥12)
- Session token storage (httpOnly + Secure + SameSite)
- CSRF on state-changing cookie endpoints
- 2FA available + enforced for sensitive roles
- OAuth state + PKCE + nonce verification
- JWT algorithm whitelist (`none` rejected); JWKS rotation
- Rate limit on auth endpoints (login, signup, reset, verify)
- Account lockout / progressive delay
- Recovery flow: no email-existence oracle, single-use token, all sessions invalidated on reset
- Magic links: short TTL, single-use, scope to operation

### A2 — Authorization
- Authz check at resolver / controller for every protected resource
- Default-deny on new endpoints
- Object-level authz (not just role check; resource ownership / tenant scope)
- No authz in views/templates as primary defense
- Admin / impersonation has explicit start/stop + audit log
- Cross-tenant access path is separate code path

### A3 — Multi-tenancy + data isolation
- `tenant_id` in every WHERE clause on tenant-scoped tables (no reliance on default scope alone)
- `current_tenant` derived from auth, never from request body/params
- Cache keys include tenant scope
- File paths include tenant scope
- Background jobs carry + use tenant context
- Cross-tenant ID enumeration not possible (UUIDs or scoped IDs)

### A4 — Injection
- Parameterized queries everywhere (no string-built SQL)
- ORM raw-SQL audited where used
- Command injection: no shell-exec with user input
- LDAP / NoSQL / GraphQL injection (depth + complexity limits)
- Header injection: no user input directly in response headers
- Template injection: untrusted input never into template engine
- SSRF: no user-controlled URL fetches without allowlist

### A5 — Crypto + secrets
- Secrets in env / secret manager, never in code or client bundle
- `.env` not in git history (check via `git log --diff-filter=A`)
- TLS everywhere; HSTS preload-ready
- No custom crypto. Use stdlib / vetted lib
- KDF for at-rest sensitive blobs (encryption-at-rest at provider level)
- Signing keys rotated per [[auth-net]] cadence
- Pre-commit secret scanner (trufflehog/gitleaks) installed

### A6 — Input + validation
- Server-side validation on every endpoint (client-side is UX, not security)
- Strict allowlist over denylist
- Size limits on every input (body, params, headers, files)
- Content-type validated on uploads (sniffed, not just header)
- JSON parsing depth limit set
- Regex DoS (ReDoS) audited on user-pattern regexes

### A7 — Output + XSS
- Templates auto-escape (verify framework default not disabled)
- `dangerouslySetInnerHTML` / `v-html` / `raw` audited per use
- User-generated HTML sanitized (DOMPurify allowlist)
- `Content-Disposition: attachment` on user-uploaded downloads
- Uploads served from sandboxed domain
- CSP header configured (script-src, object-src, base-uri, frame-ancestors)

### A8 — Auth integrity + CSRF/CORS
- CSRF token on cookie-auth POST
- CORS allowlist explicit (no wildcard with credentials)
- Origin / Referer checked on sensitive ops
- WS upgrade origin allowlisted

### A9 — Logging + monitoring
- PII redacted in logs (password, token, session ID, OAuth state, 2FA code, card data)
- Auth-related events logged (login success/fail, password change, 2FA enroll, permission change, impersonation start/stop)
- Anomaly detection or alerting on auth failures
- Error tracker scrubs sensitive fields

### A10 — Dependencies + supply chain
- Lockfile committed + verified in CI
- Audit step in CI (npm/bundle/pip-audit), critical advisories block
- Renovate/Dependabot configured
- No git-URL or unpinned deps in production manifest
- Postinstall scripts audited on add
- SBOM artifact recommended

### Payment-specific (if payment touched)
- Money as integer minor units; never float
- Server-side pricing (client cannot supply amount)
- Charge call has idempotency key
- Webhook signature verified, raw body preserved
- Webhook idempotent (event_id dedup)
- PCI scope minimal (hosted Checkout / Elements; no PAN on our servers)
- Refund / dispute paths authorized + audited
- Subscription state from webhook, not API response

### Realtime-specific (if WS touched)
- Upgrade auth at HTTP handshake
- Per-subscribe authz on every topic
- Origin allowlist
- No client-controlled broadcast targets
- Tokens re-verified on long-lived connections

### File-specific (if uploads touched)
- Size cap before reading body
- MIME sniffed + allowlisted
- Filename sanitized; storage key UUID-based
- Storage path tenant-scoped
- Presigned URLs short-lived (≤15min) + scoped
- SVG / HTML uploads rejected or sanitized
- Image processing sandboxed (out of request thread)
- Antivirus on user-shared inbound files

## Output artifact

```markdown
# Security Audit — <scope> — <date>
INVISIBLE security-auditor · depth=<level>

## Verdict
**Status**: <Clean | Blockers Present | High-Risk Findings>

### Blockers (must fix before ship)
- [F1] <P0 finding>
- [F2] <P0 finding>

### High (fix this sprint)
- [F3] <P1 finding>

### Medium (track + fix soon)
- [F4] <P2>

### Low / advisory
- [F5] <P3>

## Threat model
**Assets**: <list>
**Actors**: <list>
**Trust boundaries**: <list>
**Top-5 plausible attacks** for this scope:
1. <attacker path>
2. ...

## Findings (one block per)

### F1 — <title> (P0)
**Where**: `<file>:<line>`
**What**: <one-line>
**Why it matters**: <impact in concrete terms>
**Repro**: <steps to demonstrate>
**Suggested fix**: <code-level direction>
**Refs**: <CWE / OWASP / RFC link>

### F2 — ...

## Category walk results
(Pass / fail / N-A per category. Evidence lines if fail.)

## Dependencies snapshot
- Critical advisories: <count, details>
- High advisories: <count>
- Outdated by major: <list>

## Secret-scan results
- `.env` in git history: <yes/no>
- Hardcoded high-entropy strings: <count, files>
- Pre-commit hook installed: <yes/no>

## Run metadata
Files scanned, LOC, tokens used.
```

## Severity scale

| Tier | When |
|---|---|
| **P0 (Blocker)** | Active exploit path. Data leak in production today. Auth bypass. Plaintext secret committed. Public RCE primitive. |
| **P1 (High)** | Likely-exploitable under realistic conditions. Missing CSRF on cookie-auth POST. Tenant isolation gap. Weak password hashing. |
| **P2 (Medium)** | Defense-in-depth gap. Not immediately exploitable but reduces resilience. Missing rate limit on non-auth endpoint. No HSTS. |
| **P3 (Low / advisory)** | Best-practice. CSP could be stricter. Logging could be richer. |

## Reproduction discipline

Every P0/P1 finding includes **how to demonstrate it** — payload, request, or test case. Without repro, a security claim is FUD.

If repro requires destructive action (DROP TABLE, real money), describe in writing only; do not run.

## Anti-patterns (auditor refuses these)

- Will NOT run exploits against production systems.
- Will NOT generate attack tooling beyond proof-of-concept relevant to the finding.
- Will NOT propose detection-evasion techniques.
- Will NOT audit a target without authorization (project ownership implicit when run via `/invisible`).

## Token budget

| Depth | Tokens |
|---|---|
| fast | 10–20k |
| standard | 30–60k |
| deep | 80–150k |

Deep mode on large repo: reduce by scoping to module / feature.

## Integration with other L3

- Best run after [[deep-codebase-mapper]] — map identifies attack surface.
- Feeds [[prod-readiness-audit]] (security checklist filled from this run).
- Findings → tracked in `.invisible/audits/security-<date>.md`.

## Telemetry

Outcomes recorded:
- Findings count by tier
- User remediations within 7 days
- Incidents within 30 days post-audit (validates findings prioritization)

## CLAUDE.md hooks

Reads section A (stack, vendors, compliance posture), B (project hard rules), C (accepted risks — auditor cites in finding "accepted exception per CLAUDE.md C, double-check"), F (incident history — auditor re-checks adjacent code).

## Failure modes

- Out-of-scope target (different repo / production system) → refuse, request authorization.
- Auditor finds active exploit primitive → emit blocker with **emphasis**, suggest immediate kill switch (revoke key, flag off) before remediation.
- Scope too broad for budget → emit threat model + top-10 findings only, recommend re-run scoped per area.

## Related

[[auth-net]] · [[payment-net]] · [[data-flow-net]] · [[code-scanner]] · [[env-net]] · [[integration-net]] · [[prod-readiness-audit]] · [[deep-codebase-mapper]]
