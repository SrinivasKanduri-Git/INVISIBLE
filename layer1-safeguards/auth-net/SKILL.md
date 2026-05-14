---
name: auth-net
description: Authentication and authorization safeguards. Covers session/token lifecycle, password storage, OAuth, 2FA, role/permission checks, CSRF, secrets rotation, leak-response playbook. Security-critical — force-loaded by payment-net, async-ops-net, realtime-net, and tenant signals.
layer: 1
enabled_default: true
caps:
  body_lines: 500
triggers:
  keywords: [login, signup, signin, register, session, token, JWT, refresh, password, hash, bcrypt, argon2, "permission", "role", "authorization", "authentication", "OAuth", "OIDC", "SAML", "2FA", MFA, "CSRF", "CORS preflight", magic link, passkey, webauthn]
  libs: [devise, sorcery, "next-auth", clerk, auth0, lucia, "passport", "django.contrib.auth", "fastapi-users", "supabase auth", warden, pundit, "cancancan", cerbos, oso]
  paths: ["auth/", "sessions/", "passwords/", "tokens/", "permissions/", "policies/"]
force_loads:
  - error-net
---

# auth-net

Auth safety net. Loaded on any auth/authz signal. Force-loads [[error-net]] (auth errors must be consistent + safe).

## Hard rules

1. **Passwords are hashed with a memory-hard KDF.** Argon2id (preferred) OR bcrypt cost ≥12 OR scrypt with appropriate params. Never plain SHA, MD5, or unsalted hashes. Never plaintext, even in dev.
2. **Sessions/tokens have explicit expiry.** Access tokens ≤15 min, refresh tokens ≤30 days (sliding) OR ≤90 days (absolute). No infinite sessions.
3. **Token storage on client**: httpOnly + Secure + SameSite=Lax/Strict cookies for browser sessions. `localStorage` for auth tokens is rejected (XSS leak vector).
4. **CSRF protection on every state-changing request** unless authentication is bearer-token-only and origin is verified. Skipping CSRF on a session-cookie POST → P1.
5. **Authorization check on every protected resource.** "Authenticated user can see all" is not authorization. Tenant scope + role check + resource ownership are three distinct concerns.
6. **No authorization in views/templates.** Authz lives in the policy/permission layer; views read the result.
7. **Default-deny.** New endpoints require explicit auth annotation. Missing annotation → reject as P1, never silent-allow.
8. **No predictable IDs in URLs for resources where enumeration leaks info.** Use UUID/ULID for resources; reserve incrementing integers for non-sensitive (e.g., audit log entry).
9. **Rate-limit auth endpoints**: login, signup, password reset, 2FA verify, refresh. Per-IP + per-account (account lockout on N failures with backoff).
10. **2FA secrets stored encrypted at rest.** Recovery codes hashed (one-way). Never log 2FA verification codes.
11. **OAuth state + PKCE required.** No implicit grant. No state-less flows.
12. **JWT signing**: asymmetric (RS256/ES256/EdDSA) if tokens cross service boundaries. HS256 only for single-service with rotated secret.
13. **`none` algorithm rejected explicitly** when verifying JWTs (library default may be permissive).
14. **No secrets in source code or client bundle.** Use env vars, secret manager, or signed-config. Includes `.env` committed to git → P1.
15. **PII in logs is rejected** (delegated to [[error-net]]). auth-net specifically: never log password fields, tokens, session IDs, 2FA codes, OAuth state.

## Authorization model

Pick one model per project and stick to it. Mixed models are bugs.

| Model | When | Example libs |
|---|---|---|
| RBAC | Small fixed role set, simple resource ownership | Pundit, cancancan, casl |
| ABAC | Attribute-driven (org, tenant, resource attrs combine) | Oso, Cerbos |
| ReBAC | Relationship graphs (Doc shared with User via Folder) | SpiceDB, OpenFGA |

Project declares model in CLAUDE.md section A. Switching models mid-project is a multi-week migration, not a refactor — surface as P1 advisor note if mid-stream change attempted.

## Password reset flow (canonical)

1. User submits email → respond 200 always (no email-existence oracle).
2. If account exists, generate single-use, time-bound, hashed-at-rest reset token. Send link out-of-band.
3. Token TTL ≤30 minutes.
4. Reset request invalidates all existing sessions for that account.
5. On reset success, send "your password was changed" notification (out-of-band, to known channel).
6. Reset token is single-use — record consumption.

## 2FA / MFA

- TOTP (RFC 6238) as baseline. WebAuthn/passkey strongly preferred when stack supports.
- SMS as 2FA is a last resort and explicitly downgraded (SIM-swap risk). Surface as P2 advisor when SMS-only enabled.
- Recovery codes: 8–12 single-use codes, hashed at rest, presented exactly once.
- Backup factor required when primary factor is set up (no one-factor lock-out).

## Session lifecycle

- **Issue**: bind session to user agent + IP class (not exact IP — mobile changes). Bind to absolute issue time.
- **Refresh**: rotating refresh token. Previous refresh becomes invalid on use. Refresh-token reuse → revoke entire session family (token theft indicator).
- **Revoke**: server-side session store (allow-list approach). Stateless JWT-only without revocation list is rejected for sensitive apps.
- **Logout**: invalidates server-side; clears client cookie; refresh token revoked.
- **Concurrent sessions**: cap if business model requires (banking/admin). Default: allow multiple, but show "active sessions" page so user can revoke.

## Secrets rotation playbook

INVISIBLE provides a rotation cadence and what-to-do-on-leak procedure. Project must adapt and store in CLAUDE.md section A.

### Cadence (defaults)

| Secret class | Rotation cadence | On-leak action |
|---|---|---|
| Signing keys (JWT, session cookies, CSRF) | 90 days, overlap window 7 days | Rotate immediately, invalidate all sessions, force re-login |
| Database credentials | 180 days | Rotate immediately, revoke leaked, audit access logs ≥90 days |
| Third-party API keys (Stripe, Twilio, etc.) | 365 days OR per vendor policy | Revoke at vendor, rotate, audit usage for unauthorized activity |
| OAuth client secrets | 365 days | Revoke at IdP, rotate, audit token issuance |
| Internal service-to-service tokens | 30 days | Rotate immediately, audit traffic |
| Encryption-at-rest keys | Never rotate the key; rotate the **DEK**, re-wrap with same KEK | If KEK leaks: rotate KEK + re-wrap all DEKs, audit |

### Rotation procedure (zero-downtime, signing keys)

1. Generate new key.
2. Add new key to **verification** set alongside old (both accept).
3. Wait 1 token TTL + safety margin (≥1 day).
4. Switch **signing** to new key. Old key still verifies.
5. Wait until all tokens signed with old key have expired.
6. Remove old key from verification set.
7. Log rotation event with old key fingerprint (not the key).

### Leaked secret — what to do (playbook)

Suspect a secret has been leaked (committed to git, posted in chat, in a screenshot, in a log file shared externally):

1. **Assume compromise.** Treat all activity from time-of-creation to now as suspect.
2. **Revoke first, investigate second.** Pull the leaked secret immediately. Yes, it may break things.
3. **Rotate**, do not just delete-then-recreate-same-name without coordination — downstream still holds the old value.
4. **Audit access logs** for the time window — anomalous IPs, unusual call patterns, off-hours access.
5. **Force re-auth** if session-signing key compromised; force password resets if account-derived secret compromised.
6. **Notify**: internal incident channel, security team. If user data potentially accessed, follow breach-disclosure obligations (GDPR 72h, state-specific in US).
7. **Postmortem**: how did it leak? Add a pre-commit hook (trufflehog, gitleaks) or scanner if absent. Update CLAUDE.md section F (known landmines) with the incident.
8. **Git history**: if committed, `git filter-repo` or `bfg` to remove from history. Force-push (with team coordination). GitHub still serves old commit SHAs for 90 days — assume the secret is public.

Cross-references [[error-net]] for incident logging conventions.

## What scanner flags

Runs on output touching auth files OR any output mentioning auth keywords.

- Password column with no hash function set → P1.
- `bcrypt(..., cost: <12)` → P1.
- `jwt.sign(..., {algorithm: 'none'})` or `jwt.verify(...)` without `algorithms:` whitelist → P1.
- `localStorage.setItem('token', ...)` for auth tokens → P1.
- `cookie` with no `httpOnly` or no `secure` (in non-dev) for session → P1.
- `csrf:` middleware not mounted on session-cookie POST → P1.
- Authorization check inline in template (`<% if user.admin? %>` followed by sensitive content) → P2 (move to policy).
- Hardcoded secret string ≥20 chars matching common API-key patterns → P1.
- `.env` file in git tree → P1.
- New endpoint without `auth: ...` declaration / middleware → P1.
- Logging `request.headers.authorization` / `params[:password]` / `req.body.token` → P1 (PII / secret leak).

## Stack overrides

### Rails (Devise / Sorcery)
- `devise :registerable` only if signup is public.
- `current_user` must reach the controller via a `before_action :authenticate_user!`.
- Pundit policy per controller; `authorize @record` before render/respond.
- `protect_from_forgery with: :exception` on `ApplicationController`.

### Next.js (next-auth / Clerk / Lucia)
- next-auth: `getServerSession` on server components / route handlers; `useSession` only in client components for UX.
- Cookies must be `httpOnly` (next-auth default — never override).
- Middleware (`middleware.ts`) for auth gating; don't reimplement per-route.
- Clerk: `auth()` in server components; `<SignedIn>` / `<SignedOut>` for UI only — not for protection.

### Django
- `LoginRequiredMixin` / `@login_required` on views.
- Permissions via `django-guardian` for object-level, or DRF `permission_classes` for API.
- Password validators set in `AUTH_PASSWORD_VALIDATORS`.

### FastAPI
- `Depends(get_current_user)` on every protected route. No "I'll add it later" stubs.
- `fastapi-users` for full flows OR custom JWT with `python-jose` + verified `algorithms=['RS256']`.

### Phoenix
- `phx_gen_auth` baseline. Don't roll your own.
- `Plug` chain in router scope; verify `:require_authenticated_user` on protected scope.

## Multi-tenancy auth (cross-cuts data-flow-net)

- Tenant scope is part of the auth check, not a separate query filter. Resource lookup includes `tenant_id` in the WHERE clause.
- `current_tenant` derived from session, never from request body / params.
- Cross-tenant resource access ≠ admin override — explicit `super_admin?` check, audited.

## OAuth / OIDC

- Authorization Code + PKCE only. No implicit grant. No password grant.
- `state` parameter cryptographically random, single-use, bound to session.
- `nonce` parameter for OIDC, verified against id_token.
- Redirect URIs whitelisted server-side. Never allow open-redirect parameters.
- On callback, verify token signature against IdP's published JWKS — refresh JWKS cache hourly.

## Force-load relationships

- auth-net itself force-loads [[error-net]] (auth errors must follow consistent envelope, no info-leak).
- payment-net candidate → force-loads auth-net + error-net.
- realtime-net candidate → force-loads auth-net (WS upgrade auth always missed).
- data-flow-net tenant signal → force-loads auth-net (tenant isolation IS authz).
- db-net migration adding to `users` / `sessions` / `tokens` tables → auth-net consulted for schema correctness.

## CLAUDE.md hooks

Reads section A: `auth_model` (RBAC/ABAC/ReBAC), `auth_lib`, `replicas` (for token-store routing).
Reads section B: project hard rules around auth scope.
Reads section C: accepted exceptions (legacy endpoints).

## Related

[[error-net]] · [[api-net]] · [[db-net]] · [[payment-net]] · [[realtime-net]] · [[data-flow-net]] · [[code-scanner]]
