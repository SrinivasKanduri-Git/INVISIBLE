---
name: graphql-net
description: GraphQL safeguards. Covers resolver auth, N+1 prevention (DataLoader/batching), query depth + complexity limits, persisted queries, introspection scoping, mutation idempotency, subscription auth, and schema design discipline. Narrow trigger — loads only when GraphQL detected.
layer: 1
enabled_default: true
caps:
  body_lines: 300
triggers:
  keywords: ["GraphQL", "graphql", "resolver", "query", "mutation", "subscription", "Apollo", "schema.graphql", "introspection", "DataLoader", "Relay", "persisted query", "automatic persisted query", "APQ", "fragment", "@defer", "@stream", "federation"]
  libs: ["graphql", "apollo-server", "@apollo/server", "@apollo/client", "graphql-yoga", "mercurius", "graphene", "strawberry-graphql", "ariadne", "graphql-ruby", "gqlgen", "hotchocolate", "graphql-tools", "type-graphql", "nexus", "pothos", "dataloader", "graphql-shield", "graphql-armor"]
  paths: ["graphql/", "schema/", "resolvers/", "schema.graphql", "*.gql", "schema.graphqls"]
force_loads: []
---

# graphql-net

GraphQL safety net. Loaded only when GraphQL signals present. The "one endpoint" architecture eliminates some HTTP-level safeguards from [[api-net]] and adds GraphQL-specific landmines.

## Hard rules

1. **Authorization per resolver / field, not per route.** A single GraphQL endpoint cannot use route-based middleware to gate resources. Every protected field/edge checks authz at resolution time.
2. **N+1 is a defect.** Every list resolver that touches a related entity uses DataLoader (or stack equivalent batching). Direct ORM access in a list resolver → P1.
3. **Query depth + complexity limited.** Server enforces max depth (e.g., 10), max complexity (cost calc), and timeout. Unbounded recursive query = trivial DoS.
4. **Introspection disabled in production.** Schema exploration is a recon vector. Allow only in dev / for authenticated admin tools.
5. **No internal IDs / paths in error messages.** GraphQL default error formatter leaks stack traces, file paths. Custom formatter in prod.
6. **Mutations are idempotent where it matters** (payments, sends). Idempotency key as input.
7. **Persisted queries (PQs) preferred** for client-server traffic — client sends hash, server resolves to pre-approved query. Eliminates a class of injection + complexity attacks.
8. **Subscriptions authenticate at connection AND per-subscription topic** — same rules as [[realtime-net]].
9. **Schema is the contract** — breaking changes require deprecation cycle. Don't delete fields without `@deprecated` + sunset window.
10. **No file uploads through GraphQL `Upload` scalar** unless absolutely necessary. Use signed-URL upload (cross-references [[data-flow-net]]) and pass the resulting key.

## Authorization patterns

### Per-resolver (most explicit, recommended)

```ts
const resolvers = {
  Query: {
    organization: (parent, { id }, ctx) => {
      requireAuth(ctx);
      const org = orgs.find(id);
      requireMember(ctx.user, org);   // 403 if not a member
      return org;
    }
  },
  Organization: {
    invoices: (org, _, ctx) => {
      requireRole(ctx.user, org, 'admin');
      return loaders.invoicesByOrg.load(org.id);
    }
  }
};
```

### Schema directives (cleaner, requires support)

```graphql
type Organization @auth(required: true) {
  id: ID!
  invoices: [Invoice!]! @requireRole(role: "admin")
}
```

Directive implementation in middleware. Less repetition, but the check is invisible at the call site — keep directives discoverable.

### Library options
- `graphql-shield` (Node) — rule-based composition.
- `pundit-graphql` (Ruby) — Pundit policies as field resolvers.
- `strawberry-django.permissions` (Python) — declarative.

## N+1 prevention

**Symptom**: list of 50 posts, each resolver fetches `author` separately → 50 DB queries.

**Fix**: DataLoader batches + caches within a request.

```ts
const authorLoader = new DataLoader(ids => db.users.findMany({ where: { id: { in: ids } } }));
const resolvers = {
  Post: {
    author: (post, _, ctx) => ctx.loaders.author.load(post.authorId)
  }
};
```

### Rules
- One DataLoader instance per request, not global (cache must clear).
- Create loaders in context factory (`function context({ req }) { return { loaders: makeLoaders() } }`).
- Loader fetches by ID; returns in input order; nulls preserved for misses.
- For relations with extra filtering (e.g., `commentsByPost(postId, onlyApproved)`), key the loader by tuple.

### Stack equivalents
- Ruby (graphql-ruby): `Sources` or `dataloader` gem.
- Python (graphene/strawberry): `aiodataloader` / strawberry's `DataLoader`.
- Go (gqlgen): generated `dataloaden`.
- Postgres-direct alternative: `JOIN` in a single query if relation simple — but loader still needed for complex graphs.

## Depth + complexity limits

### Depth
Set hard max depth (e.g., 10). Most legitimate queries are <6. Recursive types (comments-on-comments) are the abuse vector.

### Complexity / cost
Each field has a cost. List fields multiply by limit:

```graphql
type Query {
  posts(limit: Int!): [Post!]!  # cost = limit
}
type Post {
  id: ID!         # cost 1
  author: User!   # cost 1
  comments(limit: Int!): [Comment!]!  # cost = limit
}
```

Query cost = sum. Reject if > max (e.g., 1000).

Libraries: `graphql-query-complexity`, `graphql-armor`, `graphql-cost-analysis`.

### Timeout
Per-request execution timeout (e.g., 10s). Long queries killed.

### Rate-limit per operation
Per-user / per-IP, per-operation (login mutation has tighter limit than list query).

## Introspection scoping

Production:
- `introspection: false` in Apollo / graphql-yoga.
- Schema served separately to internal tooling (CI builds client SDK from schema artifact).

Allow introspection in dev / for authenticated admins only. Public production introspection = giving attackers the map.

## Error handling

Default error formatters leak internals. Prod formatter:

```ts
function formatError(err) {
  log.error(err);   // full stack server-side
  if (err.originalError instanceof UserFacingError) {
    return { message: err.message, extensions: { code: err.code } };
  }
  return { message: 'Internal server error', extensions: { code: 'INTERNAL_ERROR' } };
}
```

Cross-references [[error-net]] for envelope shape.

## Mutations

### Naming + shape
- Verb-noun: `createOrder`, `cancelSubscription`. Not `orderCreate`.
- Input type: one `input: SomeInput!` argument, never positional.
- Result type: `{ ok, error, data }` or relay-style `{ node, clientMutationId }`. Be consistent.
- Return updated object — clients re-cache without refetch.

### Idempotency
For payment / send / external-effect mutations, accept `clientMutationId` or explicit `idempotencyKey: String!`. Persist + check. See [[payment-net]] and [[integration-net]].

### Authorization
Same per-resolver rules. Mutations are often where authz is missed (devs guard queries, forget mutations).

## Subscriptions

- Authenticate WS at connection (same recipe as [[realtime-net]]).
- Per-subscription authz: check user can subscribe to `orderUpdates(orderId)` before establishing.
- Topic includes scope (`order:${id}` only published to subscribers who passed authz on `id`).
- Server controls fan-out — don't trust client-supplied filters.

## Persisted queries (PQ / APQ)

Client sends query hash; server resolves to stored query.

Benefits:
- Eliminates client-injected complexity (server only runs known queries).
- Smaller request payloads.
- Easier rate-limit / cache per-operation.

APQ (Automatic Persisted Queries): client tries hash first; on miss, sends full query + hash; server stores. Production should be PQ-only (no on-the-fly storage from client; allow-list from build artifact).

## Federation / stitching

If using Apollo Federation / schema stitching:
- Each subgraph owns its types + auth checks (don't assume gateway gates everything).
- `@requires` / `@external` directives understood — cross-service N+1 is worse.
- Header forwarding for auth tokens — explicit, allowlisted.
- Per-subgraph complexity caps.

## What scanner flags

Runs on output in graphql/, schema/, resolvers/ OR using GraphQL keywords.

- Resolver doing direct ORM query inside list-field resolution (no batching) → P1 (N+1).
- Field returns related entity with no loader / `include`/`select` evidence → P2.
- Apollo / yoga config with `introspection: true` (or default in prod env) → P2.
- No depth / complexity limit configured → P1.
- Mutation with side effect + no idempotency key parameter → P2.
- Subscription resolver with no auth check at subscribe → P1.
- Default error formatter (leaks stack) in prod build → P1.
- Schema field deleted without `@deprecated` cycle → P2.
- `Upload` scalar used for >1MB files → P2 (use signed-URL flow).
- GraphQL endpoint behind no rate limit → P2.

## Stack overrides

### Node (Apollo Server / graphql-yoga / Mercurius)
- Apollo: `ApolloServerPluginUsageReporting`, `ApolloArmor` for depth/complexity/cost.
- Context factory creates loaders per request.
- `formatError` set in production.

### Python (Strawberry / Graphene / Ariadne)
- Strawberry: `permission_classes=[IsAuthenticated]` per field.
- `aiodataloader` for async batching.
- `extensions=[QueryDepthLimiter(max_depth=10)]`.

### Ruby (graphql-ruby)
- `Sources::ActiveRecord` for batching.
- `max_depth`, `max_complexity` on `Schema`.
- `GraphQL::Pro` for persisted queries.

### Go (gqlgen)
- Code-generated resolvers; dataloaders via `dataloaden`.
- Middleware for auth / complexity.

## Cross-skill collaborations

- Per-resolver authz → [[auth-net]].
- Subscription auth → [[realtime-net]].
- File upload via signed URL instead of `Upload` scalar → [[data-flow-net]].
- Error formatter shape → [[error-net]].
- Mutation idempotency for payments → [[payment-net]].
- DataLoader batching to DB → [[db-net]] for query shape.

## CLAUDE.md hooks

Reads section A: `graphql_server` (apollo/yoga/mercurius/graphql-ruby), `loader_lib`, `persisted_queries`, `federation`.
Reads section B: project rules (e.g., "no `Upload` scalar; presigned URLs only").
Reads section C: accepted exceptions (e.g., "introspection on staging for internal tools").

## Related

[[auth-net]] · [[api-net]] · [[db-net]] · [[error-net]] · [[realtime-net]] · [[data-flow-net]] · [[payment-net]] · [[integration-net]] · [[code-scanner]]
