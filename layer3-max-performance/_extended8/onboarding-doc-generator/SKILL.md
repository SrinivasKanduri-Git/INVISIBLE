---
name: onboarding-doc-generator
description: User-opt-in pass that generates a new-contributor onboarding doc for a repo / service / area. Output: dev environment setup, run-it-locally commands, layout tour, conventions cheat sheet, first-PR walk, glossary, "where to ask" pointers. Distinct from deep-codebase-mapper (which is an analytical map for any context); this is a human-friendly start-here. ≤1 active L3/turn.
layer: 3
group: _extended8
enabled_default: false
opt_in: true
cli: "/invisible onboarding [--scope <repo|service|area>] [--mode new|update]"
caps:
  body_lines: 400
recommender:
  min_score: 4.0
  triggers: ["onboarding doc", "new contributor", "getting started", "README", "set up dev", "how do I run this", "first PR guide"]
---

# onboarding-doc-generator

Produces a new-engineer onboarding doc. Optimized to take someone from "git clone" to "shipped first small PR" without 14 Slack questions. Distinct from [[deep-codebase-mapper]] (mapper is analytical; this is human-friendly).

## When to run

- New repo / service has no README or stale README.
- Team growing; new hires keep asking the same questions.
- Existing onboarding doc has rotted (commands broken, links 404).
- Open-source project needs contributor pathway.

## When NOT to run

- Single-engineer side project (audience-of-one).
- Internal tool that no one new will touch.
- Repo with high-quality existing README that just needs incremental edits.

## Output template

```markdown
# Welcome to <repo / service name>
INVISIBLE onboarding-doc-generator · v<n> · <date>

> If you're new — read this once start to finish, then bookmark. ~20 minutes to local dev. ~1 day to first PR.

## What this is + why
**Service**: <one paragraph — what it does, who uses it, scale>
**Status**: <active / maintenance / experimental>
**Tech**: <stack one-line>

## Before you start (prereqs)
- <tool> ≥ <version>
- <tool> ≥ <version>
- Access to <secret store / VPN / cloud account> — request via <process>

## Set up local dev

```bash
# 1. Clone
git clone <url> && cd <repo>

# 2. Install deps
<exact command>

# 3. Copy env
cp .env.example .env
# Edit .env: see "Required env vars" below

# 4. Start dependencies (DB, Redis, ...)
<exact command> (docker compose up -d / bin/setup / ...)

# 5. Migrate + seed
<exact command>

# 6. Run
<exact command>

# Visit
open http://localhost:<port>
```

**If you hit X, do Y**:
- `command not found: <tool>` → install via <link>
- `port already in use` → `<command to free port>`
- `database does not exist` → re-run step 4
- (one entry per common stumble — derived from past incidents / Slack questions)

## Required env vars
| Name | What | How to get | Local default |
|---|---|---|---|
| `DATABASE_URL` | Postgres URL | use bundled docker-compose | `postgres://...` |
| `STRIPE_SECRET_KEY` | Test key | request via 1Password | `sk_test_...` |
| `AUTH_SECRET` | session signer | generate: `openssl rand -hex 32` | any random |

## Run the test suite

```bash
<exact command for unit tests>
<exact command for integration>
<exact command for e2e>
```

**Speed tips**:
- `<command>` — run one test file
- `<command>` — run with watch mode

## Repo layout
```
<repo>/
├── app/             — main application code
│   ├── controllers/ — HTTP entrypoints
│   ├── services/    — business logic
│   ├── models/      — domain + persistence
│   └── jobs/        — background workers
├── lib/             — internal libraries
├── config/          — env-specific config
├── db/              — migrations + seeds
├── test/            — tests (mirror app/ layout)
└── docs/            — design docs, ADRs
```

(Auto-generated from real tree; one-line role per top-level dir.)

## Where things live (quick answer)
- HTTP routes: `<file>`
- Auth: `<dir>`
- Background workers: `<dir>`
- Migrations: `<dir>`
- Tests: `<convention>`
- Feature flags: `<file>` / `<service>`
- Errors / exceptions: `<convention>`

## How requests flow
```
Browser → Nginx → Rails (puma) → Controller → Service → Model → Postgres
                                              ↓
                                              Redis (cache, queue)
                                              ↓
                                              Sidekiq (workers)
```

(Text diagram appropriate to this project.)

## Conventions cheat sheet

### Code style
- Formatter: <tool> — runs via <command> (pre-commit hook)
- Linter: <tool>
- Type-check: <tool>

### Tests
- Naming: `<convention>`
- Layout: <mirror app/>
- Real DB or mock: <project rule>
- Coverage expectation: <%>

### Commits + branches
- Branch from: `<base branch>`
- Naming: `<convention>` (e.g., `<user>/<area>/<short-desc>`)
- Commit message: <convention link>
- PR description: <template link>
- Reviewers: <how chosen>

### Naming
- Controllers: <convention>
- Services: <convention>
- DB tables: <convention>
- API paths: <convention>

(All inferred from sample; not invented.)

## How to ship your first PR

1. **Find a starter issue**: <label> in <issue tracker>.
2. **Set up locally** (above) — confirm tests pass on `main` before changing anything.
3. **Branch**: `git checkout -b <user>/<area>/<short-desc>`.
4. **Make the change**: small. Add a test. Run the test.
5. **Pre-PR checklist**:
   - [ ] Tests pass locally
   - [ ] Formatter run
   - [ ] No new lint warnings
   - [ ] PR description filled
6. **Push + open PR**.
7. **Request review**: <how>.
8. **CI signals**: <which checks must pass>.
9. **Merge**: <who merges, how>.

## Glossary

- **<term>** — <plain-english definition>. (Where it appears in code.)
- **<term>** — <definition>.

(Project-specific jargon. Auto-derived from frequent terms in docs/comments; reviewed by human.)

## Where to ask
- Casual questions: #<channel>
- Urgent: page <on-call>
- Architecture / design: #<channel>
- Security: #<channel>
- New-hire weekly: <day>, <time>, <link>

## Common rough edges (and what to do)
- <thing that is weird about this project> → <how to handle>
- <thing that bites everyone once> → <how to handle>

## Deeper reading (when you're ready)
- Architecture: `<link>`
- Runbook: `<link>`
- ADRs: `<link>`
- Postmortems: `<link>`
- Codebase map: `<link>` (generated by [[deep-codebase-mapper]])

## You're not the first to ask
Past new-hires hit these specific bumps — we've documented:
- <issue> → <doc / Slack thread / fix>
- <issue> → <doc>

Document something new you hit. Edit this doc. Future you will thank you.
```

## Inputs

| Source | Use |
|---|---|
| Existing README / CONTRIBUTING / docs | Reuse content, refresh stale parts |
| `.invisible/maps/` (if present) | Repo layout, request flow, glossary seeds |
| Existing setup scripts (`bin/setup`, `Makefile`) | Verify commands work |
| `package.json` / `Gemfile` / `pyproject.toml` | Prereqs, exact tool versions |
| `.env.example` | Env var table |
| CI config | Test commands, lint commands |
| Recent PR template | First-PR walk |

## Verification step (recommended, optional)

The generator can optionally execute setup commands in a clean environment (`docker run` or fresh checkout) to validate:
- Every command in "set up local dev" actually works.
- Test commands return green.
- Stale commands flagged.

Gated by `--verify` flag (more tokens, slower, higher signal).

## Tone discipline

- **Second person, friendly, direct.** "You'll need..." not "the developer should...".
- **Specific, not aspirational.** "Run `pnpm install`" not "install dependencies".
- **Honest about rough edges.** A doc that pretends the project is polished when it isn't burns trust.
- **No marketing.** This is for new contributors, not for selling the project.
- **Future-you energy.** "Document the next bump" — keep the doc alive.

## Anti-patterns the generator refuses

- "Just clone and run" without specifying what "run" means.
- Listing every config option (move to reference doc).
- Long architecture exposition (move to design doc; link).
- Out-of-date commands left in. (Verification mode catches; refresh mode strips.)
- Copy-pasted generic SRE / "best practices" content.

## Update mode

`--mode update`:
- Preserve human edits in marked sections (`<!-- onboarding-edit:human -->`).
- Refresh commands (re-derived from current scripts).
- Add new env vars detected.
- Remove dead commands / links.
- Mark stale sections (e.g., "this references `Foo` which no longer exists").

## Validation

After generation:
- Every command compiles / parses (no obvious typos).
- Every link has a target (no `<TBD>`).
- Length ≤3,000 words (longer than a runbook OK, but still bounded).
- Glossary entries reviewed (auto-derived terms may be noise; mark `<!-- review -->`).

## Token budget

| Scope | Tokens |
|---|---|
| Single repo | 10–25k |
| Multi-service monorepo (per service doc) | 25–55k |
| With `--verify` (executed validation) | +20k |

## Integration with other tools

- Best run after [[deep-codebase-mapper]] (layout + glossary derived from map).
- Pairs with [[runbook-generator]] (cross-link in "deeper reading").
- Pairs with [[trd-writer]] / [[architecture-designer]] (linked, not duplicated).
- Output: `<repo>/ONBOARDING.md` (or `docs/onboarding.md` per project convention).

## CLAUDE.md hooks

Reads section A (stack, dev-env tooling), B (contribution rules), E (linked-doc locations).
Writes onboarding doc to project-preferred location. Doesn't modify code.

## Failure modes

- No setup scripts + ambiguous dev process → emit doc with "TODO: verify setup commands" blocks; recommend the team formalize a `bin/setup`.
- Heavy proprietary dependencies (LDAP, internal registry) → flag in prereqs; recommend bootstrapping mini-guide separately.
- Multi-language polyglot repo → per-language setup blocks, clearly labeled.

## Related

[[deep-codebase-mapper]] · [[runbook-generator]] · [[trd-writer]] · [[architecture-designer]] · [[full-spec-rewriter]]
