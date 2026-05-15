# INVISIBLE

> Safeguard skillset for AI coding agents. Stops demo-grade code from shipping. Autoloads in 3 layers.

**Status**: **v0.7.1 (developer-preview)** — released 2026-05-15. Patches loader pipeline so DECIDER + L1/L2 actually run. See `CHANGELOG.md`.

All architectural pieces shipped: 14 L1 + 6 L2 + 13 L3 + 9 meta files + DECIDER + tests harness (see [Repo map](#repo-map)). Sprint 6 round-1 dogfood (3 real repos) + rule-validator stress test (20 cases) complete and **PASS**.

**Honest gap — runtime not yet executable.** Validator, DECIDER, and code-scanner are spec-only documents. Every measurement in this README came from rules-as-checklist applied by hand to file samples. That makes the numbers below **directional, not statistical**:
- ✅ Catch rate: 7/7 silent killers in a 3-repo, 1-sweep spot-check.
- ⏳ Token cost / L2 noise / circuit-breaker trip rate / vs spec-kit head-to-head — all **deferred to v0.8** (requires runtime build + 20-PR replay per repo + live spec-kit run).

Full caveats per metric in §6, §9, §14. Everything labelled `<deferred v0.8>` is a known gap, not a missing number we couldn't find. See `tests/dogfood/aggregate.md` and `tests/vs-spec-kit/comparison-summary.md`.

---

## 1. Hi — here's what I keep getting wrong

I'm an AI coding agent. Left alone, I ship plausible-looking code that fails in ways you only notice in production:

- Auth checks I "knew" to add — missing on the new endpoint.
- Money stored as float in one place, integer cents in another.
- Webhook receiver with no signature verification.
- Multi-tenant query missing `tenant_id` in the WHERE clause.
- Background job that retries on `ValidationError` forever, fills DLQ.
- N+1 query hidden inside a list serializer.
- CSRF skipped because "it's just an internal endpoint".
- Secret in `.env` committed to git.

These are silent killers. They pass review. They pass tests. They break at 3am.

INVISIBLE is the layer that catches them. It runs alongside me on every turn.

## 2. How I work in three layers

```
┌─────────────────────────────────────────────────┐
│ Layer 1 — Safeguards (autoload, mandatory)       │
│   14 domain skills · DECIDER picks ≤4 per turn   │
│   Hard rules · code-scanner runs on output       │
├─────────────────────────────────────────────────┤
│ Layer 2 — Advisors (autoload, silent notes)     │
│   6 advisors · ≤5 notes/turn (P1 exempt)         │
│   Scaling · UX · Cost · Future-self · etc.       │
├─────────────────────────────────────────────────┤
│ Layer 3 — Max Performance (opt-in via /invisible)│
│   13 deep skills · ≤1 active/turn                │
│   Audits · Generators · Designers                │
└─────────────────────────────────────────────────┘
```

Layer 1 fires automatically when relevant. Layer 2 emits silent notes. Layer 3 runs only when you ask.

## 3. The 14 safeguards, briefly

| # | Skill | Catches |
|---|---|---|
| 1 | ui-net | missing loading/error/empty states, a11y baseline, form discipline |
| 2 | api-net | validation, auth wiring, pagination, status semantics, OpenAPI/JSDoc |
| 3 | db-net | migration safety, N+1, FK indexes, read-replica routing |
| 4 | auth-net | KDF, sessions, CSRF, 2FA, OAuth+PKCE, secrets rotation, leak playbook |
| 5 | error-net | error envelope, structured logs, PII scrub, retry stop-conditions |
| 6 | env-net | secrets manager, HTTPS/HSTS, CORS, security headers, CI gates |
| 7 | test-net | real-DB integration, determinism, factory discipline |
| 8 | code-scanner | always-on filter, P1/P2/P3 tiers on output ≥30 LOC OR auth/payment/mutation |
| 9 | async-ops-net | jobs, email, push/notif, webhook senders, supply-chain CI (cluster) |
| 10 | data-flow-net | cache, multitenancy, file handling (cluster) |
| 11 | integration-net | third-party calls (timeout/retry/CB) + webhook receivers (sig/dedup) |
| 12 | realtime-net | WS upgrade auth, per-subscribe authz, tenant-scoped topics |
| 13 | payment-net | integer minor units, server-side pricing, webhook=source-of-truth, PCI scope |
| 14 | i18n-net | BCP47 locales, ICU plurals, RTL, UTC storage |
| 15 | graphql-net | resolver authz, DataLoader N+1, depth/complexity limits |

(15 entries — `code-scanner` is cross-cutting; routing surface still ≤14 domains.)

## 4. Install in one command

```bash
curl -fsSL https://raw.githubusercontent.com/SrinivasKanduri-Git/INVISIBLE/main/install.sh | bash
```

The installer is idempotent:
- Clones (or updates) `~/.claude/invisible-skillset/`.
- Appends a marker-gated INVISIBLE loader block (`@<path>` memory import) to `~/.claude/CLAUDE.md`. Never overwrites — coexists with caveman, graphify, etc.
- Registers the `invisible` plugin + marketplace in `~/.claude/settings.json`.
- Creates per-project state at `~/.claude/invisible/<project-hash>/`.
- Copies the 25-line `CLAUDE_TEMPLATE.md` to `<project>/CLAUDE.md` only if missing.

Then, inside Claude Code, install the plugin once:

```
/plugin marketplace add SrinivasKanduri-Git/INVISIBLE
/plugin install invisible@invisible
/reload-plugins
```

Fill in 3 fields (**Name**, **Stack**, **Purpose**) in your project's `CLAUDE.md`. Domain rules, exceptions, and patterns fill in over time from corrections.

Full details in `INSTALL.md`. Uninstall: `./uninstall.sh` (see `UNINSTALL.md`).

## 5. A real example walkthrough

User pastes 30 lines of a Stripe charge handler. INVISIBLE in flight:

```
[DECIDER] score:
  payment-net 6.0 (Stripe + charge + money signals)
  auth-net 4.5 (force-loaded by payment-net)
  error-net 4.5 (force-loaded by auth-net + payment-net)
  api-net 3.5 (endpoint context)
  load: [payment-net, auth-net, error-net, api-net] (cap 4)

[STACK ADAPTER] Rails + Stripe Ruby SDK → inject Rails examples
[PATTERN SCAN] 612 tokens (in-scope file + CLAUDE.md D cached patterns)

[code-scanner] runs on output:
  P1: amount taken from req.params[:amount] — server must compute total
  P1: charge.create has no idempotency_key
  P2: charge response triggers fulfillment synchronously — should wait for webhook
  P2: rescue Stripe::Error e; render json: e.message — leaks vendor stack to user

[cost-advisor] P3: OpenAI call inside webhook handler could use prompt caching

[recommender] L3 opt-in: Consider /invisible audit security — auth+payment touched on new endpoint. Reply `skip` to mute 24h.
```

User gets the safeguards before they ship the bug, not after.

## 6. The token math

**Measurement status**: deferred to v0.8. Reason: no runtime yet — validator/DECIDER/scanner are spec-only documents. Per-turn token usage cannot be measured by reading files; needs a live executor instrumented during 50-turn samples per stack.

**Planned-target framing** (from plan §8 — to be reconciled with measurement):

| Category | Plan target | Actual |
|---|---|---|
| Always-on overhead | ~3k | `<deferred v0.8>` |
| Per-task L1 bodies (decider-picked) | ~1.5–3k | `<deferred v0.8>` |
| Pattern scan | ≤1k | ≤1k (hard cap, [[pattern-scan-budget]]) |
| L2 advisor bodies (when triggered) | 0.5–1.5k | `<deferred v0.8>` |
| **Total per turn (worst case)** | ~13k | `<deferred v0.8>` |

**Static facts** (countable from files now, will not change):

| Skill body sizes | Lines |
|---|---|
| DECIDER.md | 116 |
| L1 skills (avg) | ~210 (range 162–298, auth-net 187 capped at 500) |
| L2 advisor bodies (avg) | ~120 (range 110–130, capped 150) |
| L3 SKILL.md (avg) | ~260 (range 213–298, capped 400) |
| 9 meta/ files | varies |

Live execution would also pull in CLAUDE.md project file (≤500 lines per cap), pattern cache, and stack-adapter block.

**vs rework cost** (plan §8): one rework round on demo-grade auth costs ~4k tokens × 3–5 rounds = 15–20k wasted. INVISIBLE pays for itself if it prevents one rework round per feature. Validation of this claim needs measured numbers — v0.8.

## 7. What I do automatically vs what you opt into

**Automatic (L1 + L2)**:
- DECIDER picks ≤4 relevant skills/turn.
- Code-scanner reads output and flags issues.
- Advisors emit silent notes (≤5/turn, P1 exempt) on scaling, UX, cost, future-self, architecture, integration.

**Opt-in (L3 via `/invisible`)**:
- `/invisible map` — codebase map for onboarding / refactor prep
- `/invisible spec` — vague brief → engineer-ready spec
- `/invisible prd` — product-side PRD for stakeholders
- `/invisible audit prod-readiness` — pre-ship walk
- `/invisible audit security` — threat model + OWASP-aligned pass
- `/invisible refactor` — stepwise refactor plan
- `/invisible perf` — measurement-first perf dive
- `/invisible trd` — Technical Requirements Doc
- `/invisible design` — architecture design from PRD/TRD
- `/invisible openapi` — generate/refresh OpenAPI 3.1 from code
- `/invisible runbook` — on-call runbook
- `/invisible data-model` — schema design from spec
- `/invisible onboarding` — new-contributor doc

Each L3 ≤1 active per turn. Heavy passes; meant for milestones, not every turn.

## 8. Commands cheat sheet

Claude Code plugin commands are namespaced as `/<plugin>:<command>`. INVISIBLE ships two:

```
/invisible:init                              # seed project CLAUDE.md from template

/invisible:invisible map                     # codebase map
/invisible:invisible spec                    # engineer spec from brief
/invisible:invisible prd                     # product doc
/invisible:invisible audit prod-readiness
/invisible:invisible audit security
/invisible:invisible refactor
/invisible:invisible perf
/invisible:invisible trd
/invisible:invisible design
/invisible:invisible openapi
/invisible:invisible runbook
/invisible:invisible data-model
/invisible:invisible onboarding

/invisible:invisible validate-rule "<text>"  # dry-run rule-validator
/invisible:invisible refresh-patterns        # rebuild pattern cache
/invisible:invisible status                  # which layers loaded, circuit-breaker state
```

## 9. What I learn from you + the validator that keeps me safe from myself

Every time you correct me, `self-learner` proposes a rule. Before that rule lands, `rule-validator` runs 6 gating checks:

1. Contradicts an L1 hard rule? → REJECT
2. Contradicts an existing project rule? → CONFLICT (you decide)
3. Overly broad ("never use X")? → ASK SCOPE
4. Single occurrence with no repeat? → DOWNGRADE (note, not rule)
5. Touches security / auth / payment / multitenancy? → ASK CONFIRM
6. Contradicts an archived rule? → FLAG WITH HISTORY

Sprint 6 stress test: 20 deliberately bad rules (`tests/rule-validator-stress/cases.json`). Validator must reject all 12 security-critical, handle ≥80% of style cases appropriately.

**Test result (2026-05-13, v0.7.0)**: **PASS**.
- Security-critical reject: **12/12 (100%)**
- Style appropriate handling: **8/8 (100%)**
- 1 finding (P2, non-blocking): spec/fixture priority mismatch on case 3 (failed_check 1 vs expected 5); verdict and skill citation correct. Recommendation: update fixture, keep spec order. Deferred to v0.8 spec revision.
- Honest caveat: validator runtime not implemented; gating logic applied by hand to each case. CI-automated validator required before v1.0.

Full results: `tests/rule-validator-stress/results-2026-05-13.json` + `acceptance-report.md`.

## 10. The circuit breaker — how I tell you I'm misconfigured

`circuit-breaker` watches my hit rate. If I'm wrong about which skills to load too often (`degraded`), or if my notes are getting dismissed without action (`noisy`), or if I'm contradicting your corrections (`misaligned`):

- `degraded` → L2 advisor notes muted to P1 only
- `noisy` → recommender enters quiet mode
- `misaligned` → self-learner paused

You see one inline message: *"INVISIBLE entered degraded state because <reason>. Auto-recovery in <window>, or run `/invisible status` for detail."*

No silent drift.

## 11. Honest limitations

- **Cross-model support partial.** Built + tested on Claude. GPT-4o tested via Sprint 6 spot-check. Gemini Flash: in progress; not yet validated. README will say "tested on <models>" once dogfood completes — no claims beyond.
- **Pattern cache can go stale.** TTL 30 days; manual refresh via `/invisible refresh-patterns`.
- **DECIDER misfires at scale.** Plan §16 assumes 2 tuning rounds post-Sprint 6 dogfood. Edge cases will emerge in real use.
- **Cluster skills (async-ops-net, data-flow-net) are wide.** If they consistently hit the 450-line cap, will split post-v1.
- **Not a replacement for code review.** INVISIBLE catches silent killers; humans catch judgement calls.

## 12. Works alongside

- **caveman** — tone compression. Independent skill; coexists fine.
- **graphify** — visualization. INVISIBLE hands off visuals.
- **ruflo** — different routing; INVISIBLE defers when ruflo present.
- **agency-agents** — run as reviewer; INVISIBLE provides the rules they review against.
- **spec-kit** — complementary; spec-kit shapes specs, INVISIBLE shapes safeguards. Quarterly comparison in `tests/vs-spec-kit/`.

Per [[interop]]: versions pinned, quarterly review.

## 13. When to turn me off

- **Throwaway scripts.** A 50-line CSV munger doesn't need 14 safeguards.
- **Hackathons.** Speed > safety. Toggle via `INVISIBLE_OFF=1`.
- **Demos and prototypes** that won't see production. Same toggle.
- **Documentation-only PRs.** No code, nothing to safeguard.

Turn off per-project via `CLAUDE.md` section B: `invisible_enabled: false`.

## 14. What I do automatically (measured behavior)

**Silent-killer catch rate** — Sprint 6 round-1 spot-check (2026-05-13):

| Repo | Stack | Silent killers found (sample) | L1 catalog covered them | Sample rate |
|---|---|---|---|---|
| maybe-finance/maybe | Rails 7 + Sidekiq + Plaid + Stripe | 3 | 3 | 3/3 |
| elie222/inbox-zero | Next.js 14 + Prisma + Lemon Squeezy + LLM | 1 | 1 | 1/1 |
| netflix/dispatch | FastAPI + SQLAlchemy + many plugins | 3 | 3 | 3/3 |
| **Aggregate (sample basis)** | — | **7** | **7** | **7/7 (100%, sample)** |

**Honest reading**: numerator + denominator come from the same scan (rules-as-checklist). This says "the L1 catalog covers the silent-killer patterns visible in 3 real codebases." It does **not** say "INVISIBLE catches 100% of all silent killers." Independent FN measurement requires runtime — v0.8.

**Plan target**: ≥70% silent-killer catch on at least one stack, improving on others. **Met in sample.**

**Skills not exercised this round** (acknowledged gaps):
- i18n-net — none of 3 repos have i18n surface in sample → catch-rate: `<not yet measured>`
- graphql-net — none of 3 repos use GraphQL → catch-rate: `<not yet measured>`
- realtime-net — sample didn't include WS surface → catch-rate: `<not yet measured>`
- env-net + test-net — partial (CI scan deferred)

Full per-repo reports: `tests/dogfood/results/{maybe-finance-maybe,elie222-inbox-zero,netflix-dispatch}.md`. Aggregate: `tests/dogfood/aggregate.md`.

**L2 advisor noise rate**: `<deferred v0.8 — no L2 runtime to measure noise of>`.
**Circuit-breaker trip rate**: N/A — no runtime, no state to trip.
**vs spec-kit**: 3 inputs locked (vague export brief, team-invitation auth ticket, saved-views multi-tenant CRUD). INVISIBLE simulated side surfaces 95% of applicable silent killers averaged across 3 inputs, plus 8 input-specific catches (removed-member race, cross-workspace UUID enumeration, etc.). spec-kit side: **not yet run** — `tests/vs-spec-kit/` honestly refuses to fabricate the other tool's output. Full comparison deferred until both runtimes available — see `tests/vs-spec-kit/comparison-summary.md`.

### Heaviest hit category

5 of 7 silent killers fell under **integration-net** (webhook receiver discipline). Strongest signal that webhook handlers are a category-wide weak spot in production AI-coded + human-coded projects alike. Catalog covers it; tuning round 2 adds scanner heuristic for webhook-event-dedup absence (see `tests/decider-tuning/misses-round-1.json`).

## 15. Uninstall

```bash
~/.claude/invisible-skillset/uninstall.sh
```

Prompts before destructive removals. Strips the loader block from `~/.claude/CLAUDE.md`, removes `invisible@invisible` from `settings.json`, and optionally deletes `~/.claude/invisible-skillset/` and per-project state. caveman + graphify registrations untouched.

Full details in `UNINSTALL.md`.

## 16. Help me get better

Found a silent killer I missed? Open an issue with the diff + the missing finding. That's the most useful feedback I can get.

DECIDER misfire? Capture the turn in `~/.claude/invisible/<project-hash>/decider.log` — format in `tests/decider-tuning/miss-log-format.md` — and attach.

Released numbers reproducible per `tests/dogfood/methodology.md` and `tests/vs-spec-kit/methodology.md`. If your measurements differ from mine by >10%, that's a bug in methodology — file an issue.

---

## Repo map

```
INVISIBLE/
├── README.md                       (this file)
├── INSTALL.md · UNINSTALL.md · CHANGELOG.md · VERSION
├── CLAUDE.md · CLAUDE_TEMPLATE.md
├── DECIDER.md                      (≤200 lines, picks skills)
├── preferences.schema.json         (v1)
│
├── layer1-safeguards/              (14 mandatory skills)
├── layer2-advisors/                (6 silent advisors)
├── layer3-max-performance/
│   ├── _core5/                     (5 ship-first L3 skills)
│   └── _extended8/                 (8 ship-after L3 skills)
│
├── meta/                           (DECIDER infra: stack-adapter, pattern-scan-budget,
│                                    rule-validator, self-learner, conflict-resolver,
│                                    circuit-breaker, recommender, corruption-handler,
│                                    interop)
│
├── tests/                          (Sprint 6)
│   ├── rule-validator-stress/      (20-case fixture, release gate)
│   ├── dogfood/                    (3-repo methodology + results)
│   ├── decider-tuning/             (miss-log + tuning rounds)
│   └── vs-spec-kit/                (comparison harness)
│
└── skill_build_plan.md             (v6, design + roadmap — source of truth)
```

---

**License**: [MIT](./LICENSE).
**Maintainer**: [@SrinivasKanduri-Git](https://github.com/SrinivasKanduri-Git).
**Repository**: <https://github.com/SrinivasKanduri-Git/INVISIBLE>.
**Issues / silent-killer reports**: <https://github.com/SrinivasKanduri-Git/INVISIBLE/issues>.
**Roadmap (v0.8)**: executable runtime (validator + DECIDER + scanner), 20-PR replay per repo, live spec-kit head-to-head, 4th repo for i18n/graphql coverage. Tracked in `CHANGELOG.md` Unreleased section.
