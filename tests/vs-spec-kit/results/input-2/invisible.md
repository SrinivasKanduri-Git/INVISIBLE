# INVISIBLE — Input 2 (team invitations)

**Method**: simulated.

## DECIDER pass

Keywords: "invite", "email", "signup", "signin", "link", "expire", "join team", "role", "removed".

| Skill | Score | Loaded |
|---|---|---|
| auth-net | 7.5 | ✓ |
| api-net | 4.0 | ✓ |
| data-flow-net | 4.5 | ✓ (tenant signal: "team") |
| async-ops-net | 4.0 | ✓ (email send) |
| error-net | force-load | ✓ (force by auth-net + async-ops-net) |
| db-net | 3.5 | considered |

Cap 4 + force-loaded error-net. Loaded: auth-net, data-flow-net, async-ops-net, error-net. api-net + db-net dropped (logged as considered).

## Surfaced safeguards

### auth-net (deep — security-critical input)
- **Invite token shape**: cryptographically random ≥256 bits, single-use, hashed-at-rest in DB (`invite.token_hash`), token shown to user once via email link.
- **TTL**: 7 days as requested; backend stores `expires_at`; expired check on every redemption attempt.
- **Single-use**: token marked `consumed_at` on first redemption. Replays after consumption → 410 Gone.
- **Removed-member edge** (specifically called out in brief): on `membership.destroy`, all outstanding invites for `(team_id, invitee_email)` revoked (`revoked_at` set). Redemption checks revocation status.
- **Email enumeration**: don't reveal whether invitee already has account. Same response for both flows; routing decided server-side after token validation.
- **Sign-in path after token validation**: if existing user, require fresh auth (re-prompt password / 2FA if enrolled) before joining team — don't auto-attach to an authenticated session that may belong to a different user on shared device.
- **Sign-up path**: invite-bound; the new user record is created with `email = invite.invitee_email`, no email re-confirmation needed for that one email (already proven via link possession). Other emails on the user require confirmation.
- **CSRF on POST /invites/:token/accept**: token-bearing GET → confirmation page → POST consume. Token in URL is OK for the read, but consumption is a POST with CSRF.
- **Audit log**: invite created, sent, accepted, revoked, expired — each with actor + timestamp.
- **Rate limit**: invite creation (per user, e.g., 20/day), invite acceptance (per token, 5/hour).
- **Role assignment**: default role = `member` (least privilege). Inviter cannot assign `admin` on a fresh invite — escalation requires post-join admin action.
- **2FA inheritance**: if team has 2FA-required policy, accepting invite triggers 2FA enrollment within N days (per team policy).

### data-flow-net
- **Tenant scope on invite lookup**: `Invite.find_by(token_hash: ...)` returns invite with `team_id`; team membership write goes through `team.memberships.create!(user:, role:)` — not raw insert.
- **Removed-member race**: between invite read and membership write, possible to be re-added racewise. Wrap in transaction with `SELECT FOR UPDATE` on `(team_id, user_id)` row or unique index `UNIQUE (team_id, user_id) WHERE revoked_at IS NULL` to prevent ghost membership.

### async-ops-net
- **Invite email** via transactional provider (SendGrid, brief specifies).
- **deliver_later** — async, idempotent (idempotency key = invite.id; suppression check on duplicate enqueue).
- **Bounce handling**: hard-bounce on invitee_email → mark invite `email_bounced`; inviter sees status; no retry.
- **No PII in job args**: `SendInviteEmailJob.perform_later(invite_id)`, not the email body.

### error-net (force-load)
- Invite-redemption errors map to user-friendly envelope: expired → "this invite expired, ask for a new one"; revoked → "this invite is no longer valid"; consumed → "this invite has already been used".
- No leak of "user already exists" vs "no such user" via different error codes.
- Server-side log includes invite-id + reason; PII scrubbed.

## L2 advisor notes

- [ux-advisor] **P1**: redeemed-invite-after-deletion (user accepted invite, then was removed, then clicks link in old email tab) — destructive surprise. Show explicit "you've been removed from team X; contact admin" message; not generic 404.
- [scaling-advisor] **P3**: 7-day TTL × hundreds of teams = manageable; no scaling concern at typical volume.
- [future-self-advisor] **P2**: invite link format (`/invites/:token`) — store `format_version` field if expecting to change token shape later. Migration path saved.
- [architecture-advisor] **P2**: invite redemption logic touches User + Team + Membership + Audit + Email. Extract `AcceptInviteService` (use-case class) — single transactional unit. Don't put in controller.
- [cost-advisor] **P3**: 1 transactional email per invite — negligible cost.

## L3 opt-in

[recommender] L3: `/invisible audit security --scope this-feature` — auth + tenancy + token-bearing-email = high-value security audit pass. Reply `skip` to mute 24h.

## Silent killers identified (12-checklist)

| # | Killer | Mentioned? |
|---|---|---|
| 1 | Auth check on new endpoint | ✓ |
| 2 | CSRF on cookie-auth POST | ✓ (consumption POST) |
| 3 | Idempotency | ✓ (single-use token; email-send idempotency) |
| 4 | Rate limit on auth endpoints | ✓ (invite create + accept) |
| 5 | Webhook signature verification | N/A |
| 6 | Money as integer minor units | N/A |
| 7 | Multi-tenant scope | ✓ (team scope through .memberships.create!) |
| 8 | N+1 prevention | N/A (point lookups) |
| 9 | Cache invalidation | N/A |
| 10 | Background job retry + DLQ | ✓ (email job) |
| 11 | Error envelope consistency | ✓ |
| 12 | PII scrubbing in logs | ✓ |

Applicable: 9. Mentioned: 9/9.

Plus 4 INPUT-SPECIFIC silent killers caught:
- **Removed-member race** (explicitly mentioned in brief — handled with transaction + unique constraint)
- **Email enumeration via differential responses** (avoided)
- **Stale-session takeover** (require fresh auth even for signed-in user)
- **Privilege escalation via inviter-set role** (default to `member`)

## Test plan
- Unit: token generation entropy, expiry calc
- Integration (real DB): full happy path (create → email → redeem → membership exists)
- Auth boundary: redeem-as-wrong-user → 403; redeem-after-revocation → 410; redeem-after-expiry → 410; double-redeem → 409
- Race: concurrent redemption attempts → exactly one succeeds (unique constraint test)
- Email bounce → invite status updates
- Audit log assertions on each state transition

## Edge cases enumerated
- Invitee already on team (re-invite no-op or error?)
- Invitee email belongs to user signed in to *different* account in same browser
- Inviter removed from team between create + send
- Team deleted between invite send + redeem
- Concurrent multiple invites for same email to same team
- User has 2 accounts with same email (shouldn't be possible if email unique; if it is, ambiguity)

## Stack-aware (Rails 7 + Devise)
- `Invite < ApplicationRecord` with `before_validation :generate_token` + `has_secure_token`
- Devise's `confirmable` flow integrated with invite acceptance (skip confirmation when invite-bound)
- `Pundit::Policy` for InvitePolicy on invite creation
- Token URL via `invites_path(token: invite.token)` (URL-encoded)
- `ActionMailer` + `deliver_later` → Sidekiq

## Tokens
Estimate (not measured): 6–10k for L1 bodies + L2 notes + L3 suggestion.
