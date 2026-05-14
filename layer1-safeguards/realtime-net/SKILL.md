---
name: realtime-net
description: WebSocket, Server-Sent Events, and pub/sub realtime safeguards. Covers connection auth at upgrade, message-shape contracts, reconnection + backpressure, broadcast scope (tenant/room), and presence/typing fan-out limits. Narrow trigger — loads only when realtime signals present. Force-loads auth-net (WS upgrade auth is the most-missed control).
layer: 1
enabled_default: true
caps:
  body_lines: 300
triggers:
  keywords: ["WebSocket", "WS", "Socket.IO", "real-time", "realtime", "live update", "subscription", "Pusher", "Ably", "Phoenix Channels", "Phoenix.Channel", "Phoenix.PubSub", "SSE", "Server-Sent Events", "EventSource", "presence", "typing indicator", "broadcast", "channel", "topic", "pub/sub", "Redis pub/sub"]
  libs: ["socket.io", "ws", "uWebSockets", "engine.io", "@nestjs/websockets", "actioncable", "phoenix", "phoenix_live_view", "django-channels", "fastapi.WebSocket", "starlette.websockets", "pusher", "pusher-js", "ably", "centrifuge", "soketi", "supabase-realtime"]
  paths: ["channels/", "websockets/", "ws/", "realtime/", "live/", "subscriptions/"]
force_loads:
  - auth-net
---

# realtime-net

Realtime (WS / SSE / pub-sub) safety net. Loaded only on WS/SSE/Phoenix-Channels/Pusher/Ably signals. Force-loads [[auth-net]] because the WS upgrade is where auth most often gets skipped.

## Hard rules

1. **Authenticate at upgrade.** WS HTTP-upgrade request goes through the same auth chain as HTTP requests. Cookie / token must be verified before `accept`. Anonymous WS upgrade → P1.
2. **Re-check authorization on every subscribe.** Subscribing to channel `org:123:notifications` requires checking the user is in org 123. Auth-at-upgrade is necessary, not sufficient.
3. **Tenant scope in topic names.** Channels named `notifications` (global) are wrong. `org:{tenant_id}:notifications` is right. No magic broadcast that fans out across tenants.
4. **Server-controlled topic membership.** Client cannot subscribe to arbitrary topics; server validates each subscription against the user's access.
5. **Message-shape contract.** Every event has `type`, `payload`, `id`, `ts`. Schema versioned. Unknown event type → client logs + ignores; never crashes.
6. **Backpressure handling.** Slow consumers don't bring down the server. Per-connection send queue with cap; drop or disconnect on overflow.
7. **Heartbeat / ping-pong** at fixed interval (20–30s). No keep-alive → connections die behind NAT/proxies silently.
8. **Reconnect on client side**: exponential backoff with jitter, max attempts before surfacing error.
9. **Resume after reconnect**: server gives client a cursor / last-event-id; client requests events since cursor on reconnect. Otherwise updates lost during reconnect window.
10. **Origin check on upgrade** to prevent cross-origin WS hijack (CSWSH). Allowlist origins.
11. **Rate-limit messages from client.** Per-connection cap (e.g., 30 msgs/sec). Drop excess. Prevent client-side message flood DoS.
12. **No secrets in messages broadcast to channels** — anyone subscribed sees them. Filter server-side before send.

## Connection lifecycle

```
[client] ws.connect()  →  HTTP Upgrade with Cookie/Token
                            ↓
[server] auth middleware verifies → 401 closes upgrade  OR
                                   →  accept()
                            ↓
[server] track connection (user_id, tenant_id, conn_id)
                            ↓
[client] send "subscribe" {topic}
[server] check authz(user, topic) → ack OR error
                            ↓
[server] on event matching subscribed topic → send to client
                            ↓
[client] disconnect / timeout / explicit close
[server] cleanup subscriptions + presence
```

## Topic / channel naming convention

```
<scope>:<scope_id>:<resource>[:<resource_id>][:<sub>]

org:123:notifications          (tenant-scoped feed)
org:123:room:456:messages      (tenant + resource)
user:789:dm                    (per-user feed)
public:status                  (truly public — explicit prefix)
```

Server-side allowlist of namespaces. `public:` requires explicit annotation; default is private + auth-required.

## SSE vs WS — when to pick

| Pick | When |
|---|---|
| **SSE** | Server→client only (notifications, live feed). Simpler, plays nice with HTTP/2, auto-reconnect built into `EventSource` |
| **WS** | Bidirectional (chat, collab editing, presence). More moving parts |
| **Polling** | Updates infrequent (>30s gap). Don't over-engineer realtime |

If user asks for "realtime" but only one direction → push back toward SSE (simpler, fewer landmines).

## Presence / typing / live-cursor (fan-out concerns)

- **Presence** is N×M traffic — N viewers × M actors. Cap the room size before enabling.
- **Typing indicators** must debounce server-side (don't broadcast every keystroke; broadcast "X started typing" + "X stopped typing").
- **Cursor sharing** — throttle to ≤10 Hz; drop intermediate updates.
- Hard cap on concurrent connections per room (e.g., 100). Beyond that, switch to read-only mode or summary updates.

## Broadcast scope rules

1. Server picks recipients, not sender. Client sends `send to room X` — server enforces "is user allowed to broadcast to X?"
2. No reflection-style broadcast (`broadcast to socket.handshake.query.room`). Trust nothing from client for routing.
3. Cross-tenant broadcast = bug. Add a runtime assert in dev: every broadcast verifies recipient tenant matches sender tenant (unless explicit cross-tenant flow).

## Backpressure + slow consumer

- Per-connection send buffer cap (e.g., 100 pending messages).
- Overflow policy explicit:
  - **drop oldest** for ephemeral updates (cursor, typing)
  - **drop newest** for catchup-not-required
  - **disconnect** for ordered streams (chat) — better to force reconnect-and-resume than corrupt order
- Log overflow events. Repeated overflow on same connection = client bug or DoS.

## Scaling beyond one node

Single node: in-memory pub/sub fine.
Multi-node (typical prod): need an external broker:
- **Redis pub/sub** — fast but no replay; subscribers must be online
- **Redis Streams** — pub/sub + replay window
- **NATS / Kafka** — durable + scalable
- **Phoenix.PubSub w/ Redis or pg2** for Elixir

Adapter pattern: app code publishes to broker; each node subscribes to broker; broker fans out to connected clients. Without this, "broadcast" only reaches clients on the same node.

## Common breakages

- WS upgrade has no cookie/token check → anyone connects → can subscribe to (poorly-scoped) topics → leak.
- `socket.join(roomFromClient)` → client picks own room → reads other users' messages.
- Broadcast fired inside a DB transaction → rollback leaves clients with stale "fact" they saw it.
- Reconnect storm after deploy → all clients hit at once → cold backend dies. Stagger reconnects with random delay.
- No heartbeat → connections appear alive but messages don't arrive (silent NAT timeout).
- Server crashes don't clear presence → ghost users in room list.
- Token expires mid-session → server keeps connection open with stale auth. Periodically re-verify or kill on expiry.

## What scanner flags

Runs on output in channels/, ws/, realtime/, live/, OR using WS / SSE / Pusher / Ably keywords.

- WS upgrade handler with no auth check → P1.
- `socket.on('subscribe', (topic) => socket.join(topic))` without authz on `topic` → P1.
- Broadcast call where recipient set built from client input → P1.
- `socket.emit('...', { password|token|... })` — secret in payload → P1.
- WS server with no origin check / accepts `*` → P1.
- Heartbeat / ping not configured → P2.
- Per-connection rate limit absent → P2.
- Server pub-sub fan-out without per-node broker (multi-node deploy) → P1.
- Broadcast inside DB transaction → P2 (move after commit).
- Client-side WS with no reconnect logic → P2.

## Stack overrides

### Node / Socket.IO
- `io.use((socket, next) => { /* auth */ })` middleware — verify session/JWT, attach `socket.data.userId`.
- Server-controlled `join` only; never trust `socket.handshake.query.room`.
- `@socket.io/redis-adapter` for multi-node fan-out.
- Origin allowlist via `cors: { origin: [...] }`.

### Rails / ActionCable
- `connect` in `ApplicationCable::Connection` verifies user via cookies/Devise.
- `Channel#subscribed` checks authorization per stream.
- `stream_for` resource (auto-scopes); avoid `stream_from string_from_client`.

### Phoenix Channels / LiveView
- `connect/3` in `UserSocket` verifies token; assigns `user_id`.
- `join("room:" <> id, _, socket)` pattern-matches + authorizes.
- Phoenix.PubSub clusters via `:pg` or Redis adapter.

### Django Channels
- `AuthMiddlewareStack` wraps router; `scope["user"]` available.
- `async def connect(self)` rejects if `scope["user"].is_anonymous`.
- Channel layer Redis for prod (`channels_redis`).

### FastAPI WebSockets
- Manual auth on `@app.websocket(...)` — `websocket.cookies` / `headers` parsed; `await websocket.close(code=1008)` on auth fail.
- For pub/sub, use Redis directly + `aioredis` listener task per connection.

### Pusher / Ably (hosted)
- "Private channel" auth endpoint required — server signs subscription requests, vendor enforces.
- Never use public channels for user-specific data.
- Webhook receiver for connection events → cross-references [[integration-net]].

## Cross-skill force-loads + collaborations

- realtime-net force-loads [[auth-net]] (upgrade auth).
- Tenant-scoped topics → consults [[data-flow-net]] (multitenancy rules).
- Broadcast after DB write → consults [[db-net]] for transaction-boundary discipline.
- WS server errors → [[error-net]] for envelope + logging.
- Pusher/Ably integration → [[integration-net]].

## CLAUDE.md hooks

Reads section A: `realtime_transport` (ws/sse/pusher/ably), `pubsub_broker` (redis/nats/kafka), `presence_enabled`.
Reads section B: project rules (e.g., "max 50 users per room", "no realtime in admin").
Reads section C: accepted exceptions (e.g., "status page is truly public, no auth").

## Related

[[auth-net]] · [[api-net]] · [[error-net]] · [[data-flow-net]] · [[db-net]] · [[integration-net]] · [[env-net]] · [[code-scanner]]
