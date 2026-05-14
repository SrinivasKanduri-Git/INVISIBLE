---
name: deep-codebase-mapper
description: Heavy, user-opt-in pass that maps an unfamiliar codebase into a structured onboarding artifact. Produces module map, dependency graph (text), entrypoint catalog, data-flow sketch, hot/dead-zone heat, owned/un-owned regions, naming conventions, and "if you change X, you also touch Y" matrix. Writes to .invisible/maps/ + updates CLAUDE.md section D pattern cache. ≤1 active L3/turn.
layer: 3
group: _core5
enabled_default: false
opt_in: true
cli: "/invisible map [--scope <path>] [--depth shallow|deep] [--update-claude-md]"
caps:
  body_lines: 400
recommender:
  min_score: 5.0
  triggers: ["onboard me", "new to this repo", "first time in this codebase", "where is X?", "map this codebase", "give me a tour", "I just inherited this", "where do I start?"]
---

# deep-codebase-mapper

Runs a structured codebase walk and emits a navigable map. Intended for first-day-on-the-repo and pre-refactor situations.

## When to run

- New contributor needs a 30-min onboarding instead of 3-day spelunking.
- Existing contributor inherits an unfamiliar module / service.
- Pre-refactor: needs a "what touches what" matrix before moving code.
- Before a [[security-auditor]] or [[prod-readiness-audit]] pass — the map seeds the audit.

## When NOT to run

- Codebase is tiny (≤10k LOC, ≤30 files). Just read it.
- Recent map exists (≤30 days old at `.invisible/maps/<scope-hash>.md`) — reuse unless `--force`.
- Codebase is changing rapidly and the map will be stale within a week — note and skip.

## Inputs

| Source | Use |
|---|---|
| `--scope <path>` | Limit walk to subtree (default: repo root) |
| `--depth shallow` | File-level only (5–10 min). Default. |
| `--depth deep` | Symbol-level + call graph (20–60 min, more tokens) |
| `--update-claude-md` | Append discovered patterns to CLAUDE.md section D + project cache |
| Existing CLAUDE.md | Read first — don't re-derive what user already wrote |
| `.git/` log | Identify hot files (high churn), cold files (untouched 12mo+) |

## Output artifact

Writes to `.invisible/maps/<scope-hash>.md`. Structure:

```markdown
# Codebase Map — <scope> — <date>
INVISIBLE deep-codebase-mapper · depth=<level>

## 1. Topography
- Stack: <detected from stack-adapter>
- Lines of code (excl. vendor/test): ~<N>
- Languages: <breakdown>
- Top-level packages / dirs: <list with one-line role each>

## 2. Entrypoints
- HTTP routes: <route table — verb, path, handler file:line>
- CLI commands: <list>
- Background workers: <queue → handler>
- Cron / schedulers: <schedule → entrypoint>
- Webhooks (inbound): <vendor → receiver file>
- WebSockets / subscriptions: <topic → handler>

## 3. Module map
- <package>: <role, key files, exports, who imports it>
  - Internal deps: → <list>
  - External deps: → <list of top vendor SDKs / libs used here>

## 4. Data flow sketch (text)
Request → Controller → Service → Model → DB
                            ↘ Cache
                            ↘ External (Stripe, Twilio, …)

(Custom ASCII per project; pull-back arrows for callbacks/webhooks.)

## 5. Hot zones (high churn last 90 days)
- <file>: <commit count>, <last touched>, <last 3 commit subjects>
(Heat map signals where bugs concentrate + where changes will likely conflict.)

## 6. Cold / dead zones
- <file/dir>: untouched 12+ months, low import count.
(Candidates for deletion / refactor — flag don't act.)

## 7. Naming + convention catalog
- Routes: <kebab/snake, plural/singular>
- Models / classes: <CamelCase, suffix conventions>
- Service classes: <e.g., `*Service.run(ctx)`>
- Test files: <`*.test.ts` vs `_test.go` vs `*_spec.rb`>
- Error envelope: <shape>
- Pagination style: <cursor / offset>
- Date/timestamp columns: <name pattern>

## 8. Cross-cutting concerns
- Auth: <where + how, library>
- Tenancy: <model + scope-source>
- Caching: <layers + key shape>
- Feature flags: <library + flag list with sunset notes>
- Observability: <log lib, error tracker, metrics>
- Background jobs: <queue + retry policy>

## 9. "If you change X, you also touch Y"
A matrix derived from import graph + recent co-edit pairs in git log.

| Change point | Likely co-edits | Evidence |
|---|---|---|
| <file/symbol> | <other files> | <co-edited in N of last M PRs> |

## 10. Open questions for the human
Things the mapper couldn't determine — needs a human:
- [ ] Section labeled "experimental/" — current status? archive or promote?
- [ ] Two modules implement similar logic (`lib/email.js` vs `services/mailer.ts`) — which is canonical?
- [ ] Feature flag `legacy_checkout` — still in use?

## 11. CLAUDE.md sync (if --update-claude-md)
Patterns appended to section D (cached patterns):
- pagination_style, error_envelope, auth_pattern, etc.

## Run metadata
- Files scanned: <N>
- Token budget used: <N>
- Pattern-scan cache built: <path>
```

## How it walks

1. **Read CLAUDE.md first.** If sections A/D already describe the codebase, scope the walk to what's missing.
2. **Glob the tree** at scope. Identify language + framework via [[stack-adapter]].
3. **Entrypoint discovery**: framework conventions (`routes.rb`, `app/router.ts`, `urls.py`, etc.) + worker registrations + cron configs + webhook receivers.
4. **Import-graph build** for the dominant language (TS / Py / Rb / Go). Resolve each module's importers/importees.
5. **Git-log enrichment**: `git log --since=90.days.ago --name-only` → churn count per file. `git log --since=90.days.ago --pretty=format:'%H' --name-only` → co-edit pairs (files in same commit ≥3 times → "co-edit pair").
6. **Pattern detection**: scan a sample of routes/models/tests for naming + conventions. Confidence-flagged: "looks like cursor pagination (3 of 4 list endpoints)".
7. **Open-questions list**: anything ambiguous → human-answered, don't guess.

## Depth modes

### Shallow (default, 5–10 min)
- File-level tree + role inference
- Entrypoint table
- Naming conventions sampled from 5 files per type
- Hot/cold from git
- No call graph

### Deep (20–60 min, opt-in for time/tokens)
- Symbol-level analysis (functions, classes per module)
- Call graph for entrypoint → service → model paths
- Per-route trace: "POST /orders → OrdersController#create → CheckoutService#run → Order.create + Stripe.charge"
- "Touch X, change Y" matrix populated by call-graph + git co-edit

## Token budget

| Depth | Tokens used | Note |
|---|---|---|
| shallow | 5–15k | Mostly file globs + sample reads |
| deep | 30–80k | Symbol resolution costly |

L3 cap is 1 active per turn. Mapper run takes a turn (or several) on its own — agent should not concurrently load other L3 work.

## Resume / incremental

- Re-run with same scope hash → diff against last map. Show "what changed since 2026-04-13".
- `--force` to rebuild from scratch.
- Map cache lives at `.invisible/maps/<scope-hash>.md`. Git-ignore by default; user may opt to commit.

## What it does NOT do

- Does not recommend refactors. (See [[architecture-advisor]] or Sprint 5b refactor-architect.)
- Does not flag bugs. (See L1 code-scanner + Sprint 5a security-auditor.)
- Does not write or modify code (except CLAUDE.md if `--update-claude-md`).

## Interaction with L1 / L2

- Feeds [[pattern-scan-budget]] cache with discovered patterns → cheaper future turns.
- Discovers entrypoints → DECIDER routes better (no longer scoring blind).
- Seeds [[security-auditor]] (knows the attack surface map) and [[prod-readiness-audit]] (knows the entrypoints).

## CLAUDE.md hooks

Reads + optionally writes:
- Section A: stack, primary language, package manager (sets baseline).
- Section D: cached patterns (pagination, error envelope, naming) — appended unless user already filled.
- Section E: project-specific entrypoints/exclusions.

Never overwrites user-written content. Append-only with `<!-- mapper: -->` markers.

## Failure modes

- Repo too large for scope budget → emit partial map with note "scope reduced to X subtree; rerun per-subtree".
- No clear entrypoint discovered → emit "no framework signature detected; supply via CLAUDE.md A".
- Git log unavailable (shallow clone) → skip churn/heat sections, note limitation.

## Example invocation flow

```
user: /invisible map --depth deep --update-claude-md

agent: Detecting stack (Rails + Sidekiq + React frontend in app/javascript/) ...
       Walking app/, lib/, db/, config/ ...
       Reading recent git log (90 days) ...
       Sampling routes (24 routes found) ...
       Inferring patterns (8 conventions detected, 3 ambiguous → questions list) ...

       Map written: .invisible/maps/a3f7e1.md
       CLAUDE.md section D updated with 5 patterns.
       6 open questions for you at bottom of map.

       Token used: 42,800. Next: review and answer the 6 questions.
```

## Related

[[stack-adapter]] · [[pattern-scan-budget]] · [[security-auditor]] · [[prod-readiness-audit]] · [[architecture-advisor]] · [[full-spec-rewriter]]
