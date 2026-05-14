# Input 2 — Auth-touching ticket

**Locked: 2026-05-13. Do not modify after first comparison run.**

## Source

Ticket-shaped brief with explicit security surface.

## Brief

> Add team invitations. Existing user can invite someone by email. Invitee clicks a link in the email, signs up (or signs in if they have an account), and joins the inviting user's team with a default role. Should expire after a week. Need to make sure people can't accept old invites for teams they were removed from.

## Stack assumption (for both tools)

- Rails 7 + Devise + Postgres + Sidekiq + SendGrid (transactional)
- Team-based multi-tenancy: `teams`, `memberships(team_id, user_id, role)`

## Why this input

- Multiple auth surfaces (signup, signin, role assignment)
- Multi-tenant boundary (team scope)
- Token-bearing email link (TTL, single-use, revocation)
- Race conditions (removed-member edge case)
- Tests both tools' security-depth + edge-case enumeration
