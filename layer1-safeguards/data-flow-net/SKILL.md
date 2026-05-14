---
name: data-flow-net
description: Data-crossing-boundaries safeguards. Cluster of cache (scope, TTL, invalidation, stampede), multitenancy (tenant scoping, cross-tenant leak prevention), and file handling (path traversal, MIME, quotas, Content-Disposition). Tenant signal force-loads auth-net (tenant isolation IS authz).
layer: 1
enabled_default: true
caps:
  body_lines: 450
triggers:
  keywords: [cache, caching, "Redis", "Memcached", TTL, "cache key", "cache invalidation", "stampede", "thundering herd", tenant, "multi-tenant", multitenancy, organization, workspace, "tenant id", "org id", scoping, "file upload", "presigned", "S3", "blob storage", "GCS", "Azure blob", "object storage", "path traversal", MIME, "Content-Disposition", "antivirus", "ClamAV", "image processing", "ImageMagick"]
  libs: ["redis", "ioredis", "node-cache", "memcached", "rails cache", "django-redis", "fastapi-cache", "cachetools", "@aws-sdk/client-s3", "boto3", "google-cloud-storage", "azure-storage-blob", "multer", "carrierwave", "active_storage", "shrine", "django-storages", "fastapi.UploadFile", "minio", "sharp", "imagemagick", "Pillow"]
  paths: ["uploads/", "storage/", "files/", "media/", "public/uploads/", "tmp/uploads/", "cache/"]
force_loads: []
---

# data-flow-net

Data-crossing-boundaries safety net. Cluster of cache, multitenancy, file handling — all about data moving between trust zones (user↔user, tenant↔tenant, internal↔external storage). Tenant signal force-loads [[auth-net]] (tenant isolation IS authz).

## Why cluster

Same mental model:
- A boundary exists (user, tenant, file system root, cache namespace)
- The boundary must be enforced **at lookup time**, not "filtered after"
- Leaks happen when boundary is implicit instead of explicit
- Cache scope and tenant scope are often the same concern

## Hard rules (apply across cluster)

1. **Scope is part of the key.** Cache key, file path, query filter — tenant/user scope is in the identifier, not added by a separate "where".
2. **Default-deny on lookup.** Resolver returns no data when scope missing; never falls back to "global" or "first".
3. **No user input in keys, paths, or filenames** without normalization + allowlist. Path traversal, cache poisoning, header injection all stem from this.
4. **Cross-boundary access is explicit + audited.** Admin viewing another tenant's data is a separate code path, logged.
5. **Eviction/cleanup is part of the design**, not an afterthought. Caches expire. Files have retention. Tenant-deletion has a cascade plan.

## Sub-domain: cache

### Hard rules
1. **Every cached value has a TTL.** No "cache forever, invalidate on write" without a backstop TTL (writes get missed; data drifts).
2. **Cache key includes scope**: `cache:v1:tenant_id:user_id:resource`. Version prefix for schema breaks. Tenant scope mandatory in multi-tenant.
3. **Stale-while-revalidate** preferred over plain TTL for hot keys — serve stale, refresh async.
4. **Stampede protection** on expensive computes: lock-based ("only one regenerates"), probabilistic early refresh, or request coalescing. Don't let 1000 cold-cache hits all hit DB.
5. **Cache writes after DB writes**, not before. If DB write fails, cache must not hold poisoned new value.
6. **Invalidation on write** for cached entities. Document which writes invalidate which keys — invalidation map lives in the model layer.
7. **Bypass for fresh-required reads**: `?fresh=true` admin endpoint or explicit no-cache header for debugging. Never bake fresh-bypass into normal user flow.
8. **No PII in cache values** unless cache itself is access-controlled (Redis on private network with auth + TLS). Public CDN cache → no PII.
9. **Negative caching**: cache "not found" too, with shorter TTL. Prevents lookup-storm on missing IDs.
10. **Cache size monitored**. Memcached/Redis eviction policy explicit (`allkeys-lru` typical). Unbounded growth + crash is a common outage.

### Cache layers (typical)
| Layer | Lifetime | Scope |
|---|---|---|
| HTTP / CDN (Cache-Control, ETag) | seconds–hours | Public OR per-user (Vary: Cookie) |
| Application (Redis/Memcached) | seconds–days | Per-tenant / per-user / global |
| ORM query cache | request | Request only |
| In-process LRU | request | Request / process |

Mixing layers without contract = cascading staleness. Document the layer chain in CLAUDE.md section A.

### Common cache disasters
- Cache key forgot `tenant_id` → tenant A sees tenant B's resource. **P1**.
- TTL of 24h + write invalidation, but invalidation has a bug → stale for a day. Backstop TTL of 5min would catch it.
- Cold cache on deploy → 100% miss → DB overwhelmed. Pre-warm critical keys or stagger deploys.
- Cache stores entire User object → schema change leaves old shape in cache → deserialization crashes.

### Library notes
- Redis: `EX` (seconds) or `EXAT` (unix ts). Pipeline writes for batches. `SCAN`, never `KEYS`.
- Memcached: ≤1MB per value default; large values silently drop.
- Rails: `Rails.cache.fetch(key, expires_in: 5.minutes) { ... }`. `race_condition_ttl:` for stampede.

## Sub-domain: multitenancy

### Hard rules
1. **Tenant is in every WHERE clause** for tenant-scoped tables. Not "added by middleware" — written by the developer at query site. Defense in depth.
2. **`current_tenant` derived from session/auth**, never from request body, query param, or header (unless explicitly admin-impersonation flow with audit).
3. **All multitenant tables have `tenant_id` column** with NOT NULL + FK + index. No "we'll add it later".
4. **Default scope** in ORM where it exists (Rails `default_scope`, SQLAlchemy event), but treat it as a backstop, not the primary defense.
5. **Cross-tenant resource lookup**: by ID only inside the tenant scope. `Resource.find(id)` is wrong; `current_tenant.resources.find(id)` is right.
6. **Cache keys include tenant**: `cache:tenant_id:resource:id`. Without tenant prefix, you'll leak across tenants.
7. **File paths include tenant**: `uploads/tenant_id/...`. Never root + filename collision.
8. **Background jobs carry tenant context**. Job args include `tenant_id`; job code uses it like a request would. No "global queries" inside jobs.
9. **Tenant deletion cascade defined**. Tenant offboarding = data deleted (or anonymized) end-to-end. Compliance requirement, not a nice-to-have.
10. **Tenant impersonation** (support viewing customer data) is a separate code path: explicit start/stop, audit log, never reuses regular user session.

### Tenancy patterns

| Pattern | Pros | Cons |
|---|---|---|
| **Shared DB, tenant_id column** | Cheap, easy joins | Easy to forget `tenant_id` in a query — leak risk |
| **Shared DB, schema per tenant** (Postgres) | Strong isolation, queries naturally scoped | Migrations across N schemas, infra cost |
| **Database per tenant** | Maximum isolation | Cost, ops complexity, no cross-tenant analytics |

Project picks one in CLAUDE.md section A. Mixing is hard. Migrating is harder.

### Tenant ID source
- Subdomain (`acme.app.com`) → middleware resolves to tenant
- Path prefix (`/t/acme/...`) → middleware resolves
- User attribute (`user.tenant_id`) → derived from auth
- Header (`X-Tenant-ID`) → only for B2B API with key auth

Never multiple sources at once (ambiguity = bug).

### Tenant-scoped tests required
Every endpoint touching tenant-scoped data needs a test: "User from tenant A cannot access resource from tenant B." Cross-references [[test-net]].

## Sub-domain: file handling

### Hard rules
1. **Validate file size before reading** the body. Stream-and-cap (multer/multipart limit) — don't buffer 10GB into RAM.
2. **MIME type from content sniff**, not just the user-provided `Content-Type` header or extension. Use libmagic / `file` / `mime-types` content check.
3. **Allowlist MIME types** per upload endpoint. Reject by default.
4. **Filename sanitization**: strip path separators, NULL bytes, control chars. Generate a UUID/ULID server-side; original filename is metadata, not the storage key.
5. **Storage path includes tenant** (or user) scope: `s3://bucket/tenant_id/uploads/<uuid>`. No flat namespace.
6. **Content-Disposition: attachment** for user-uploaded downloads by default. `inline` allowed only for image/PDF previews on same-origin context.
7. **No serving uploads from the app domain.** Use a separate domain or CDN — uploaded HTML/SVG on app domain = stored XSS.
8. **Presigned URLs preferred** for direct uploads to S3/GCS — never proxy file bytes through the app server.
9. **Presigned URLs are short-lived** (≤15min) and scoped to one operation (PUT a specific key).
10. **Virus scanning for accepted inbound files** if user-shared (ClamAV/lambda scanner). Quarantine until clean.
11. **Image processing in sandbox** (separate process / queue) — ImageMagick has had RCE history. Never run image transforms in the request thread for untrusted input.
12. **Quotas per tenant / user**. Unbounded storage = unbounded cost. Quota enforced at upload time, not after.

### Path traversal — common breakages
- `path.join('uploads', userInput)` with `userInput="../../etc/passwd"` → root escape.
- `decodeURIComponent` after normalization → `..%2F..` slips through.
- Symlink in upload dir + restore-from-backup → arbitrary read.
- `serve-static` with `dotfiles: 'allow'` → `.env` served.

### SVG / HTML uploads
SVG can carry `<script>`. Either:
- Reject SVG entirely, OR
- Run through a sanitizer (DOMPurify with SVG profile) on upload, OR
- Serve from sandboxed domain with `Content-Security-Policy: sandbox`.

### Storage providers
- **S3**: bucket policy + signed URLs; `s3:PutObject` with `Content-Type` enforced via policy condition; CORS configured for browser uploads.
- **GCS**: signed URLs v4; uniform bucket-level access preferred over ACLs.
- **Azure Blob**: SAS tokens; private container + SAS for download.
- **Local disk (dev/small)**: only inside designated dir; never user-provided path component.

## What scanner flags

Runs on output touching cache/, uploads/, storage/, multi-tenant queries, or mentioning cache/tenant/file keywords.

- Cache key built from string concat without tenant scope (in known multi-tenant project) → P1.
- `Rails.cache.fetch(key)` without `expires_in:` → P2.
- Cache write inside a DB transaction → P2 (write may rollback, cache holds bad value).
- Query on tenant-scoped table without `where(tenant_id: ...)` / `scope.tenant_id =` → P1.
- `current_tenant` read from `params` / `req.body` / non-auth source → P1.
- Background job with no `tenant_id` arg in known multi-tenant project → P1.
- File save using user-provided filename as path segment → P1.
- `multer({ dest: ... })` without `limits` set → P2.
- `Content-Disposition` missing on download endpoint → P2.
- Presigned URL TTL >1h → P2.
- File upload endpoint with no MIME allowlist → P2.
- `fs.createReadStream(path.join(dir, userInput))` without normalization check → P1.

## Stack overrides

### Rails
- `Rails.cache.fetch(["v1", current_tenant.id, "user", user.id]) { ... }` — array keys auto-handle versioning.
- `acts_as_tenant` or `ros-apartment` for tenancy. Or roll-your-own with `default_scope { where(tenant_id: Current.tenant_id) }` + thread-local `Current` model.
- Active Storage: variant generation off-request (`record.image.variant(...).processed`).

### Django
- `django-tenants` for schema-per-tenant; `django-scopes` for shared-schema.
- Storage: `django-storages` with `S3Boto3Storage`; private bucket + signed URLs.
- Cache: `django-redis` with `KEY_PREFIX` per env + tenant.

### Node (NestJS / Express)
- `cls-hooked` / `AsyncLocalStorage` for request-scoped tenant context.
- `multer` with `limits.fileSize` set + custom `fileFilter` for MIME allowlist.
- `ioredis` cluster client + `cacheable-request` for HTTP cache layer.

### FastAPI
- `Depends(get_current_tenant)` on every tenant-scoped route.
- `aiofiles` + size cap + streaming for uploads.
- `fastapi-cache2` with namespace per tenant.

### Phoenix / Elixir
- `Plug` for tenant resolution; pass through assigns.
- Cachex with tenant in key.
- Waffle / Arc for uploads with content-type validation.

## Cross-skill force-loads + collaborations

- Tenant signal in data-flow-net → force-loads [[auth-net]] (tenant isolation IS authz).
- File-upload signal → also consult [[api-net]] (upload endpoint shape) and [[error-net]] (upload-failure UX).
- Cache + DB migration → consult [[db-net]] (cache invalidation on schema change).
- Background job storing files → cross-references [[async-ops-net]].

## CLAUDE.md hooks

Reads section A: `tenancy_model` (column/schema/db), `cache_layer` (redis/memcached/cdn), `storage_provider` (s3/gcs/local), `tenant_id_source` (subdomain/path/auth).
Reads section B: project rules (e.g., "no file uploads >50MB", "tenant deletion is soft-delete with 30-day retention").
Reads section C: accepted exceptions (e.g., "admin endpoints bypass tenant scope, audited").

## Related

[[auth-net]] · [[db-net]] · [[api-net]] · [[error-net]] · [[async-ops-net]] · [[env-net]] · [[code-scanner]]
