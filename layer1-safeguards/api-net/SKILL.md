---
name: api-net
description: HTTP/API endpoint safeguards. Validation, auth wiring, pagination, status codes, idempotency, rate-limit hints, and API-docs-discipline (every new endpoint requires OpenAPI annotation or JSDoc stub).
layer: 1
enabled_default: true
caps:
  body_lines: 300
triggers:
  keywords: [endpoint, route, controller, API, REST, request, response, query param, path param, body, header, status code]
  verbs: [GET, POST, PUT, PATCH, DELETE, HEAD, OPTIONS]
  libs: [express, fastapi, "django-rest-framework", "rails-api", hono, koa, "fastify"]
  paths: ["routes/", "controllers/", "app/api/", "routers/", "api/", "*.routes.ts"]
force_loads: []
---

# api-net

Endpoint-level safety net. Loaded any time HTTP endpoints are touched.

## Hard rules

1. **Every endpoint has explicit input validation** (lib-based: zod, pydantic, dry-validation, joi, etc.). Hand-rolled `if (!req.body.x)` is rejected.
2. **Every endpoint has explicit auth wiring** OR explicit `public: true` comment + reason. Default-deny.
3. **Status codes match semantics**:
   - 200 only when entity exists + returned. Empty list returns 200 with `[]`, not 404.
   - 201 for create + return entity + `Location` header.
   - 204 only when intentionally empty body.
   - 400 = client error in payload shape; 401 = unauth; 403 = forbidden; 404 = entity not found; 409 = conflict; 422 = semantic validation; 5xx never returned to client without sanitization.
4. **List endpoints paginate by default.** No unbounded `find_all`. Default page size declared in [[CLAUDE_TEMPLATE]] section D.
5. **Idempotency on POST when result is non-idempotent.** Charge, send email, create-with-side-effects → accept `Idempotency-Key` header, dedupe within 24h window.
6. **No SQL or ORM building from string concat of user input.** Parameterized queries / safe ORM API only.
7. **Error response shape is consistent** (delegated to [[error-net]]). api-net rejects ad-hoc `{ error: "string" }` if project defines a different envelope.

## API-docs-discipline (hard rule)

**Every new endpoint requires one of:**
- OpenAPI annotation (FastAPI auto, NestJS swagger decorators, Rails apipie, drf-spectacular)
- JSDoc stub above the handler with: summary, params, responses
- Inline TypeScript type for request/response (when stack uses tRPC / typed clients) — counts as docs

Code-scanner flags missing docs as **P1**. Reason: undocumented endpoints become invisible API surface, get used internally without contracts, break silently on refactor.

JSDoc stub minimum:
```ts
/**
 * @summary Create user
 * @body { email: string, password: string }
 * @response 201 { id: string, email: string }
 * @response 409 if email exists
 * @auth public (signup)
 */
```

## Defaults

| Concern | Default |
|---|---|
| Pagination | Cursor-based (`?cursor=...&limit=...`), max limit 100 |
| Validation | Schema lib (project-specific from CLAUDE.md section D) |
| Error envelope | `{ code: string, message: string, request_id: string }` (override in section D) |
| Rate limiting | At reverse proxy / API gateway; per-endpoint annotation if differs |
| Versioning | URL path (`/api/v1/...`), additive changes only within major version |
| CORS | Restricted allow-list, never `*` for credentialed endpoints |

## What scanner flags

Runs on output containing route definitions OR any path-matched file.

- Endpoint handler without validation lib import → P1.
- Endpoint without `@auth` annotation OR auth middleware mounted → P1.
- `find_all`, `.all()`, `findAll()` returned to client without pagination → P1.
- 200 returned on POST-create (should be 201) → P2.
- Generic `500 Internal Server Error` with raw exception message → P1 (PII / stack-trace leak).
- Missing OpenAPI/JSDoc per docs-discipline rule → P1.
- New endpoint without entry in routes index file (if project uses one) → P2.
- Endpoint path collision with existing route → P1.

## Stack overrides

### Rails (Rails API mode)
- Controller actions have `before_action` chain — verify auth runs first.
- `render json: ...` with serializer (AMS / jsonapi-serializer), never `to_json` on raw record.
- Strong parameters required for create/update.

### FastAPI
- Pydantic models for request + response. Auto-generates OpenAPI; docs-discipline considered satisfied.
- `Depends(get_current_user)` on every authed route.
- `response_model=` declared on every route.

### Next.js (app router)
- Route handlers in `app/api/*/route.ts`. Validate with zod before any DB call.
- Server Actions for form submits: same validation rules.
- Don't leak server errors to client — `error.message` belongs in logs, not response body.

### Django REST Framework
- Serializers required, ViewSets preferred over function views for CRUD.
- `permission_classes` explicit on every view; default-deny via global `DEFAULT_PERMISSION_CLASSES`.

### Express / Hono / Koa
- Validation middleware (zod-express-middleware, hono/zod-validator) mounted before handler.
- Centralized error handler (last-mounted middleware) — no try/catch in every handler.

## Force-load relationships

- Loaded → [[auth-net]] is checked for relevance; if any signal touches auth, both load.
- [[error-net]] often co-loads (consistent error envelope).
- [[db-net]] often co-loads (CRUD endpoints touch DB).

## CLAUDE.md hooks

Reads section D:
- `pagination` (default cursor)
- `error_response_shape`
- `api_versioning_strategy`
- `idempotency_required_paths`

## Related

[[auth-net]] · [[db-net]] · [[error-net]] · [[ui-net]] · [[code-scanner]]
