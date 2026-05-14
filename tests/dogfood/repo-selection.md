# Dogfood repo selection — Sprint 6

**Status**: LOCKED — 2026-05-13. Do not change after first dogfood run starts. Any modification requires re-running all rounds + re-publishing aggregate.

## Selection criteria (from methodology.md)

- Demo-grade output, ≥30 AI-assisted PRs available
- At least one auth or payment surface
- At least one multi-tenant or realtime surface
- Distinct stacks across the 3 (Rails / Next.js / FastAPI per chosen mix)
- Not our own code

## Locked selection

### Repo 1 — Rails
- Slug: `maybe-finance/maybe`
- URL: https://github.com/maybe-finance/maybe
- Stack: Rails 7 + Postgres + Hotwire/Stimulus + Sidekiq + Plaid + Stripe
- Public/private: public
- Why picked: actively AI-coded personal-finance app; large PR history; auth + payment + financial-data surfaces hit auth-net, payment-net, integration-net, data-flow-net (multi-account scoping), db-net (money columns, migrations)
- Lock-in commit: `<pin at checkout time>` — record sha + date in `results/maybe-finance-maybe.md`
- PR window: last 20 merged PRs at lock-in time

**Coverage signals**:
- auth-net: Devise / session, OAuth flows
- payment-net: Stripe subscriptions, money columns
- integration-net: Plaid (bank linking), Stripe webhooks
- data-flow-net: user account scoping (per-user data isolation)
- async-ops-net: Sidekiq jobs (bank sync, reports)
- db-net: schema migrations on financial entities

### Repo 2 — Next.js
- Slug: `elie222/inbox-zero`
- URL: https://github.com/elie222/inbox-zero
- Stack: Next.js 14 App Router + Prisma + Postgres + Stripe + Google OAuth + Gmail API + OpenAI/Anthropic
- Public/private: public
- Why picked: documented AI/Claude-assisted development; covers Next.js App Router patterns, OAuth, payments, LLM API integration, multi-tenant (organizations). Hits ui-net, api-net, auth-net, payment-net, integration-net, data-flow-net (org scoping), cost-advisor (LLM tokens)
- Lock-in commit: `<pin at checkout time>`
- PR window: last 20 merged PRs at lock-in time

**Coverage signals**:
- auth-net: NextAuth / OAuth (Google)
- payment-net: Stripe subscriptions
- integration-net: Gmail API, OpenAI/Anthropic SDK calls
- data-flow-net: organization (multi-tenant) scoping
- async-ops-net: background email processing
- cost-advisor: LLM token usage on every email parse
- ui-net: App Router server/client components

### Repo 3 — FastAPI
- Slug: `netflix/dispatch`
- URL: https://github.com/netflix/dispatch
- Stack: FastAPI + SQLAlchemy + Postgres + Celery/RQ + Vue.js frontend + multi-org/project scoping + many integrations (Slack, PagerDuty, Jira, GitHub, Google, Zoom, etc.)
- Public/private: public
- Why picked: enterprise-scale FastAPI; deep multi-tenant model (organizations + projects); heavy integration surface; realtime-adjacent (incident updates, notifications); covers auth-net, api-net, data-flow-net (tenant), integration-net, async-ops-net, error-net

**Known caveat**: Netflix Dispatch predates the AI-coding wave. PR mix is mostly human-authored. Methodology requires ≥30 AI-assisted PRs — this repo may not strictly satisfy that. **Honest mitigation**: report the AI-assisted-PR ratio per repo in `results/netflix-dispatch.md`; if <30 AI PRs available in selected window, treat dispatch as a "complex real-world FastAPI" measurement rather than "vibe-coded" sample. Flag in aggregate.md prominently.

- Lock-in commit: `<pin at checkout time>`
- PR window: last 20 merged PRs at lock-in time (regardless of AI/human authorship — measure on whole sample, note ratio)

**Coverage signals**:
- auth-net: enterprise SSO / OAuth
- data-flow-net: organization + project tenancy (deep)
- integration-net: 10+ third-party services
- async-ops-net: background workers, scheduled tasks
- api-net: REST + OpenAPI generation
- error-net: structured errors, Sentry

## Coverage check

| Concern | Repo with it |
|---|---|
| Auth (login/session/JWT/OAuth) | all 3 |
| Payment | maybe-finance/maybe, elie222/inbox-zero |
| Multi-tenancy | elie222/inbox-zero (orgs), netflix/dispatch (orgs+projects), maybe-finance/maybe (per-user account scoping) |
| Realtime (WS/SSE) | netflix/dispatch (incident updates — partial) |
| Background jobs | all 3 |
| File uploads | netflix/dispatch (incident attachments) |
| i18n | none — **known gap**, note in aggregate.md |
| GraphQL | none — **known gap**, note in aggregate.md |
| LLM API integration | elie222/inbox-zero |
| Financial / money handling | maybe-finance/maybe |

**Coverage gaps acknowledged**: i18n-net and graphql-net will not be exercised in Sprint 6 dogfood. Catch-rate measurement for those skills deferred to a future round with appropriate repo selection. Aggregate.md will note both gaps explicitly; README §14 marks per-skill measurement as `<not yet measured>` for i18n/graphql.

## Lock-in metadata

- Locked on: 2026-05-13
- Locked by: project owner (per /loop /sprint6 /lock-repos exchange)
- INVISIBLE version at lock: 0.7.0-sprint6
- Methodology version: tests/dogfood/methodology.md @ commit-at-lock

## Next steps

1. `git clone` each repo locally. Record HEAD sha + clone date per repo in `results/<slug>.md`.
2. Identify last 20 merged PRs per repo at clone time. Lock PR numbers in result file.
3. Begin per-PR replay per methodology.md "How to run".
4. Compile per-repo report → `results/maybe-finance-maybe.md`, `results/elie222-inbox-zero.md`, `results/netflix-dispatch.md`.
5. Aggregate → `aggregate.md`. Fill README §6 (token math) + §14 (catch rate).

## Anti-cherry-pick guarantee

This file is the lock. Any change to repo list after first PR is scored requires:
- New row in `selection-revisions.md` documenting why
- Re-run all rounds from scratch (no partial revision)
- Honest disclosure in README that selection was revised

No silent swaps.
