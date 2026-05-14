---
name: full-spec-rewriter
description: User-opt-in pass that takes a vague brief / one-paragraph feature request / messy ticket and rewrites it as a complete implementation spec — scope, acceptance criteria, edge cases, dependencies, rollout plan, test plan. Distinct from prd-writer (product-side intent); this is engineer-side spec. ≤1 active L3/turn.
layer: 3
group: _core5
enabled_default: false
opt_in: true
cli: "/invisible spec [--brief <file_or_text>] [--depth normal|deep]"
caps:
  body_lines: 400
recommender:
  min_score: 5.0
  triggers: ["vague spec", "one-paragraph ticket", "build me X", "rewrite the spec", "incomplete brief", "ambiguous requirement", "spec is one sentence"]
---

# full-spec-rewriter

Take a half-formed feature request and produce an engineer-ready spec. Surfaces what was assumed, asks the right questions before coding starts, ends with a buildable artifact.

## When to run

- Brief is < 1 page or < 200 words.
- Ticket has acceptance criteria but no edge cases / no error paths.
- "Just build me X" with no rollout / test / dependency plan.
- Multiple stakeholders disagree on scope — surface points of disagreement.
- Pre-implementation; you'd otherwise be guessing 5+ decisions during code.

## When NOT to run

- Spec already complete and engineer-reviewed.
- Throwaway script / hackathon (overhead > value).
- Brief is **intentionally** open ("explore options") — use [[prd-writer]] in discovery mode instead.

## Inputs

| Source | Use |
|---|---|
| `--brief <file>` | Raw text / Markdown / Linear ticket export |
| Existing CLAUDE.md | Stack, conventions, accepted exceptions |
| `.invisible/maps/` (if present) | Codebase entrypoints, existing patterns |
| User clarifications (Q&A loop) | Fills gaps surfaced during pass |

## The pass — what it does

1. **Parse the brief.** Extract intent, surface area, named users / roles, named entities, mentioned constraints.
2. **Detect assumption gaps.** Every "obvious" implicit decision surfaced as a question (with a recommended default).
3. **Map onto current codebase** (if mapper output present). Otherwise note "no map — assumptions may not match repo".
4. **Surface dependencies**: data, APIs, third parties, infra changes, migrations, feature flags, deprecations.
5. **Produce a structured spec.** See output template below.
6. **Ask up to 10 high-value questions.** Each question carries a recommended default — user can `ack` to accept all defaults at once.
7. **On user answers, finalize spec** + write to `.invisible/specs/<feature-slug>.md`.

## Output template

```markdown
# Spec — <feature title>
INVISIBLE full-spec-rewriter · <date>

## 1. Problem
<1–3 sentences. What user pain / business gap. Why now.>

## 2. Goals + non-goals
**In scope**:
- <bullet>
**Out of scope (explicit)**:
- <bullet>
**Success looks like**:
- <measurable outcome>

## 3. Users / roles
- <role>: <what they do, what changes for them>

## 4. User flows
### Happy path
1. <step>
2. <step>

### Edge cases / alternate flows
- <flow>: <expected behavior>

### Error paths
- <error>: <user sees, system does>

## 5. Data model changes
- New entities: <list with fields + relations>
- Modified entities: <field additions, type changes>
- Migration shape: <reversible? online? estimated row count?>

## 6. API / interface changes
- New endpoints: <verb, path, request, response, auth>
- Modified endpoints: <breaking? deprecation timeline?>
- GraphQL schema changes: <types, deprecations>
- Internal interfaces: <service method signatures>

## 7. UI surfaces (if applicable)
- Screens / components affected
- New screens with rough sketch (text)
- States: loading / empty / error / success per screen

## 8. Cross-cutting impacts
- Auth model: <RBAC role additions, scope changes>
- Tenancy: <tenant-scoped? cross-tenant? admin-only?>
- Caching: <invalidation targets>
- Background jobs: <new jobs, queue choice, idempotency key>
- Notifications: <emails, push, in-app>
- i18n: <new strings, RTL impact>
- Search/index: <reindex required?>
- Feature flag: <name, rollout plan, sunset>
- Observability: <new metrics, alerts, dashboards>

## 9. Dependencies / sequencing
- Blocked by: <other work, vendor SLA, design assets>
- Blocks: <downstream features>
- External: <vendor sandbox, OAuth app, DNS, …>

## 10. Test plan
- Unit: <key cases>
- Integration: <real-DB scenarios>
- E2E: <happy + 2 sad paths>
- Manual: <what needs human eyes>
- Load: <if applicable>

## 11. Rollout
- Phase 0: <feature flag off, code merged>
- Phase 1: <internal / staff only>
- Phase 2: <% rollout cadence>
- Phase 3: <general availability>
- Rollback plan: <feature flag, data migration reversibility>

## 12. Risks + mitigations
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| <risk> | L/M/H | L/M/H | <plan> |

## 13. Open questions (answered before build)
- [x] <question> → <answer>
- [x] <question> → <answer>

## 14. Out-of-scope deferrals (tracked, not built)
- <thing> — defer to <ticket / next sprint>

## 15. Spec metadata
- Brief source: <link>
- Rewritten on: <date>
- Reviewed by: <names>
- Estimated effort: <rough> (this is a guess from the spec, not a commitment)
```

## Question heuristic — what to ask

The spec is incomplete unless the following are answered. Each missing answer → one question (recommended default included):

| Dimension | Question if missing |
|---|---|
| Authorization | Which roles can do this? (default: same as current similar action) |
| Tenancy | Tenant-scoped? Cross-tenant view? (default: tenant-scoped) |
| Mutation type | Create / update / delete / soft-delete? (default: soft-delete for user data) |
| Concurrency | Two users acting at once → what? (default: last-write-wins + optimistic lock) |
| Notification | Notify involved parties? Channels? (default: in-app + email digest) |
| Audit | Logged as user action? (default: yes for state changes) |
| Rate limit | Per user? Per endpoint? (default: same as nearest endpoint) |
| Idempotency | Required? Key source? (default: required if external side-effect) |
| Migration | Online? Reversible? (default: online + reversible) |
| Feature flag | Required? Rollout? (default: yes, 10/50/100 cadence) |
| Rollback | What if we ship and it's wrong? (default: flag-off + data reversible) |
| Observability | What do we watch post-launch? (default: error rate, p50/p95 latency, success count) |

Cap questions at 10. Group related, allow batch `ack defaults` reply.

## Question / answer flow

```
agent: Spec drafted with 7 open questions. Each has a default — reply with answers or `ack defaults`.
       Q1. Tenant scope: scoped to current tenant? [default: yes]
       Q2. Notifications on event: email + in-app, or in-app only? [default: in-app only]
       ...

user: Q1 yes, Q2 both, others ack defaults

agent: Spec finalized → .invisible/specs/<slug>.md (1,240 words)
       Estimated effort (rough): 3–5 days. Suggested entry point: services/checkout.rb.
```

## Codebase grounding

If a [[deep-codebase-mapper]] map exists:
- Entry-point suggestions reference real files.
- Pattern conventions inherited (pagination style, error envelope).
- Cross-impact section cites real modules.

If not, spec runs in *codebase-agnostic* mode and explicitly notes that assumptions are nominal.

## Token budget

| Depth | Tokens |
|---|---|
| normal | 8–20k |
| deep (with mapper grounding + full edge-case walk) | 30–60k |

## Failure modes

- Brief is too vague to extract intent → produce a 3-question "what are we actually building?" loop before spec attempt.
- Brief conflicts with CLAUDE.md hard rules (e.g., proposes plaintext password) → surface conflict, refuse to draft until resolved.
- Stakeholders disagree (multiple briefs supplied) → spec emits a "disagreement matrix" instead of a single spec.

## Hand-off

After spec finalized:
- Suggest running [[security-auditor]] in design-review mode if auth/payment touched.
- Suggest [[prod-readiness-audit]] before going GA.
- For PRD-style document (audience: PM / non-engineers), use [[prd-writer]] instead — different audience.

## CLAUDE.md hooks

Reads section A (stack defaults), section B (project rules), section C (exceptions), section D (cached patterns).
Does not write to CLAUDE.md. Writes only to `.invisible/specs/<slug>.md`.

## Related

[[prd-writer]] · [[deep-codebase-mapper]] · [[prod-readiness-audit]] · [[security-auditor]] · [[architecture-advisor]]
