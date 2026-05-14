---
name: env-net
description: Deploy, CI/CD, env vars, secrets, CORS, and security headers (CSP, HSTS, X-Frame-Options, Referrer-Policy, Permissions-Policy). The "ship safely" layer.
layer: 1
enabled_default: true
caps:
  body_lines: 300
triggers:
  keywords: [deploy, "Docker", "Dockerfile", ".env", production, staging, "CI/CD", secrets, CORS, headers, "reverse proxy", nginx, ingress, kubernetes, "k8s", helm]
  paths: ["Dockerfile", ".github/workflows/", ".gitlab-ci.yml", "k8s/", "deploy/", "nginx/", ".env*", "fly.toml", "vercel.json", "render.yaml", "docker-compose*.yml"]
  libs: [helmet, "secure_headers", "django-csp"]
force_loads: []
---

# env-net

Shipping discipline. Loaded on deploy / CI / env / headers work.

## Hard rules

1. **`.env` files never committed.** Includes `.env.production`, `.env.local`, `.env.staging`. `.env.example` (no values) is fine and encouraged.
2. **Secrets via secret manager OR encrypted env, not plaintext config files.** Production secrets in Vault / Doppler / AWS Secrets Manager / GCP Secret Manager / sealed-secrets / SOPS.
3. **HTTPS-only in any non-local environment.** HSTS header set with `max-age ≥ 6 months` + `includeSubDomains` once HTTPS is stable. No mixed-content.
4. **CORS allow-list, never wildcard for credentialed endpoints.** `Access-Control-Allow-Origin: *` + `Allow-Credentials: true` is rejected by browsers AND by env-net.
5. **Security headers required** (defaults below). Missing CSP on a site that ships JS → P1.
6. **CI/CD pipelines run security scans** on dependency manifests (npm audit, bundler-audit, pip-audit, govulncheck). High/critical = block merge.
7. **No production deploys directly from local machine.** Deploys originate from CI artifact. Local-deploy paths are P1 if a CI path exists.
8. **Docker images run as non-root.** `USER` directive required when image is the production runtime. Root-as-default → P1.
9. **Images pinned by digest (or at least immutable tag) for production.** `:latest` in production manifest → P1.
10. **Build-time secrets do not leak into final layer.** Use BuildKit secret mounts; never `ENV SECRET=...` in a layer.

## Security headers (defaults)

Set at edge (reverse proxy) OR framework middleware. Project picks one place — applied consistently.

| Header | Default value | Notes |
|---|---|---|
| `Strict-Transport-Security` | `max-age=15552000; includeSubDomains` (preload after stable 6mo) | HSTS |
| `Content-Security-Policy` | `default-src 'self'; script-src 'self' 'nonce-{rand}'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; frame-ancestors 'none'; base-uri 'self'; form-action 'self'` | Tighten per project. `unsafe-inline`/`unsafe-eval` only with documented reason. |
| `X-Content-Type-Options` | `nosniff` | Always |
| `X-Frame-Options` | `DENY` | Or `SAMEORIGIN` if iframing intra-app. Superseded by CSP `frame-ancestors` but kept for old browsers. |
| `Referrer-Policy` | `strict-origin-when-cross-origin` | |
| `Permissions-Policy` | `camera=(), microphone=(), geolocation=(), interest-cohort=()` (extend per project) | |
| `Cross-Origin-Opener-Policy` | `same-origin` | Required for `SharedArrayBuffer`, blocks tab-nabbing |
| `Cross-Origin-Resource-Policy` | `same-origin` | Adjust to `cross-origin` for public CDN assets |
| `Cross-Origin-Embedder-Policy` | `require-corp` | Only if app needs cross-origin isolation |

CSP nonce required for inline `<script>` in SSR/SSG output. Hash-based CSP also acceptable for static inline.

## CORS

- Allow-list of explicit origins in env (`CORS_ALLOWED_ORIGINS=https://app.example.com,https://admin.example.com`).
- Preflight (`OPTIONS`) handled by framework, not custom code.
- `Allow-Credentials: true` only when needed (cookies cross-origin). With it, origin echo only from allow-list.
- `Allow-Methods` and `Allow-Headers` explicit, not wildcard.

## CI/CD discipline

| Stage | Required |
|---|---|
| Lint | Yes — fails build |
| Unit + integration tests | Yes — fails build |
| Type check (TS, mypy, sorbet, etc.) | Yes if project uses types — fails build |
| Dependency audit (npm audit / bundle audit / pip-audit / govulncheck) | High/Critical fails build |
| Secret scanner (gitleaks, trufflehog) | Yes — fails on any finding |
| Container scan (trivy / grype) if building images | Critical fails build |
| Migration dry-run on staging-shape DB | Yes when migration present |
| Production deploy | Tag-protected; requires CI green + manual approval if mutating prod data |

## Env-var discipline

- All env vars declared in `.env.example` with comments.
- Booleans: `"true"`/`"false"` strings — parse explicitly, never `Boolean(env.X)` (non-empty string is truthy).
- Required-at-boot vars validated at process start. Missing → fail loud, not silently default.
- No env-var-driven feature flags for security toggles (e.g., `SKIP_AUTH=true`) — leads to "oops staging deployed with prod env". Use a typed flag system with explicit dev-only enums.

## Docker / image hygiene

- Multi-stage builds; final stage minimal (distroless / alpine / chainguard / wolfi).
- `.dockerignore` excludes `.git`, `.env*`, `node_modules` (build artifacts), test fixtures.
- Health-check defined (`HEALTHCHECK` or k8s probe).
- Resource limits set in orchestrator (k8s `resources.limits`, ECS task def).
- Logs go to stdout/stderr; no log files inside container.

## What scanner flags

Runs on output touching deploy/CI/env files OR any output mentioning deploy keywords.

- `.env*` (other than `.env.example`) added to git → P1.
- `ENV SECRET_KEY=` or any uppercase-looking-secret in Dockerfile → P1.
- `:latest` tag in production manifest / compose file → P1.
- Missing `USER` directive on Dockerfile that copies app code → P2.
- `Access-Control-Allow-Origin: *` with `Allow-Credentials: true` → P1.
- CSP missing or contains `'unsafe-eval'` without comment → P2.
- HSTS missing on production config → P2.
- CI workflow without dependency-audit step → P2.
- CI workflow that has `if: ${{ secrets.X }}` exposing secret in logs → P1.
- Production deploy step running `npm install` (instead of `npm ci`) → P2 (non-reproducible).
- Helm/k8s manifest without `resources.limits` → P3.

## Stack overrides

### Rails
- `secure_headers` gem; configure in initializer.
- `force_ssl = true` in `config/environments/production.rb`.
- `dotenv-rails` only in `:development, :test` groups.
- Rails 7+ credentials (`config/credentials/<env>.yml.enc`) preferred over env vars for secrets-at-rest.

### Next.js / Vercel
- Headers configured in `next.config.js` `headers()` OR via `middleware.ts`.
- Public env vars (`NEXT_PUBLIC_*`) audited — anything secret in here = P1.
- Vercel: secrets via dashboard / `vercel env`, not `.env` in repo.

### Django
- `SECURE_*` settings: `SECURE_SSL_REDIRECT`, `SECURE_HSTS_*`, `SECURE_CONTENT_TYPE_NOSNIFF`, `SECURE_BROWSER_XSS_FILTER`, `X_FRAME_OPTIONS`.
- `django-csp` for CSP.
- `DEBUG = False` in production — `DEBUG = True` shipped to prod is P1.

### FastAPI
- `CORSMiddleware` configured with explicit origins.
- `TrustedHostMiddleware` set.
- Headers via custom middleware OR reverse-proxy.

### Express
- `helmet()` middleware mounted first.
- `cors({ origin: allowList, credentials: true })`.
- `express-rate-limit` for non-edge-handled rate limiting.

## Force-load relationships

env-net does not force-load anything. Touches multiple domains but does not gate other skills.

## CLAUDE.md hooks

Reads section A: `hosting`, `runtime`, `deploy_origin` (where deploys originate), `secret_manager`.
Reads section B: project-specific header overrides, CORS allow-list.

## Related

[[auth-net]] · [[api-net]] · [[error-net]] · [[code-scanner]] · [[async-ops-net]]
