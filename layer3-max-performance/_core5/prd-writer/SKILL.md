---
name: prd-writer
description: User-opt-in pass that produces a product-side PRD (Product Requirements Doc) from a user need, a half-formed idea, or a brief. Audience is PMs / designers / stakeholders, not just engineers. Distinct from full-spec-rewriter (engineer-side spec) — this is the doc that gets approved before any spec exists. ≤1 active L3/turn.
layer: 3
group: _core5
enabled_default: false
opt_in: true
cli: "/invisible prd [--idea <file_or_text>] [--mode discovery|definition]"
caps:
  body_lines: 400
recommender:
  min_score: 4.0
  triggers: ["PRD", "product spec", "requirements doc", "product brief", "stakeholder doc", "ask docs", "exec summary", "feature proposal"]
---

# prd-writer

Take a user need / idea / brief and produce a PRD. Optimized for the audience that approves before engineering builds — PM lead, design lead, eng manager, stakeholders. Not a technical spec.

## When to run

- New feature in discovery — need a doc to align stakeholders.
- Loose idea ("we should let users do X") needs grounding in problem + outcome.
- Cross-team initiative requires written commitment to scope + outcome.
- Pre-roadmap planning — multiple ideas competing for prioritization.

## When NOT to run

- Implementation already starting (use [[full-spec-rewriter]]).
- Tiny improvements (copy change, small UX tweak) — overhead too high.
- Pure tech debt / refactor with no user-visible outcome — PRD is wrong shape.

## Modes

| Mode | When | Output flavor |
|---|---|---|
| `discovery` | Idea is loose, scope uncertain | Problem-heavy, multiple options, no commitment |
| `definition` (default) | Decision likely; we're scoping for build | Committed scope, success metrics, single path |

## Output template

```markdown
# PRD — <feature name>
INVISIBLE prd-writer · <date> · mode=<discovery|definition>

## 1. TL;DR
<3–5 sentences. What we're doing, for whom, why now, expected outcome.>

## 2. Problem
**Who experiences it**: <user segment, role, scale of pain>
**What they currently do**: <workaround / abandonment / competitor product>
**Why it hurts**: <quantified if possible — drop-off, support ticket count, NPS verbatims>
**Why this is the right time**: <market shift, prior dependency landed, regulatory, …>

## 3. Goals + non-goals
**Goals (what success unlocks)**:
- <user-facing outcome>
- <business outcome>
**Non-goals (explicitly OUT of scope)**:
- <thing>
- <thing>
**Explicitly not solving** (related problems we're choosing to defer):
- <thing>

## 4. Success metrics
**Primary metric**: <single most-important measure>
- Baseline: <current value>
- Target: <value, by when>
- How measured: <source>

**Guardrail metrics** (must not regress):
- <metric>: current X, must stay ≥ Y
- <metric>: current X, must stay ≤ Y

**Counter-metric** (what tells us we made it worse, even if primary improves):
- <metric>

## 5. User stories / jobs-to-be-done
"As a <user>, I want to <goal>, so that <reason>."
- <story> — acceptance: <criterion>
- <story> — acceptance: <criterion>

## 6. UX / experience sketch
- Entry points: <how users get to this feature>
- Key screens / states: <list with short description>
- Empty / error / success states described
- (Reference design files / Figma if linked)

## 7. Solution options (discovery mode) OR chosen approach (definition mode)

### Discovery mode — Options compared
| Option | Description | Effort | Risk | Recommendation |
|---|---|---|---|---|
| A | <description> | S/M/L | Low/Med/High | <yes/no/why> |
| B | <description> | … | … | … |

### Definition mode — Chosen approach
<2–4 sentences describing the path. Why this option over alternatives.>

## 8. Scope (definition mode)
**v1 (this release)**:
- <bullet>
**v1.x (fast follow if v1 lands)**:
- <bullet>
**v2+ (later)**:
- <bullet>

## 9. Dependencies
- Other product areas: <list with required state>
- Engineering prerequisites: <list>
- External: <vendor / legal / compliance / data>
- Design assets: <list with owner>
- Content / translation: <list>

## 10. Risks + mitigations
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| <risk> | L/M/H | L/M/H | <plan> |

Common categories to consider:
- Adoption risk (will users actually use it?)
- Revenue impact (positive or negative)
- Support load
- Compliance / privacy
- Brand / messaging
- Competitive response

## 11. Open questions
- [ ] <question> — owner: <name> — needed by: <date>
- [ ] <question> — owner: <name> — needed by: <date>

## 12. Rollout
**Phase 0 — internal**: <who, how long>
**Phase 1 — beta / cohort**: <who, success bar>
**Phase 2 — GA**: <triggers, comms>
**Rollback / wind-down**: <conditions, plan>

## 13. Comms plan
- Internal: <announcement, training, support>
- External: <release notes, blog, social, sales enablement>
- Customer-facing: <in-product, email, help center>

## 14. Decisions log (append-only)
| Date | Decision | Rationale | Decided by |
|---|---|---|---|

## 15. References
- <link to research / user interviews / data>
- <link to competitor analysis>
- <link to related PRDs / specs>
```

## Question heuristic — what to ask

Cap at 8 questions. If the brief leaves these unanswered, ask (each with a recommended default):

| Dimension | Question if missing |
|---|---|
| User segment | Which user are we solving for? (default: existing core user) |
| Pain quantification | How big is this pain — ticket count, drop-off, etc.? (default: qualitative + "to be measured") |
| Primary success metric | What's the single number that tells us this worked? (default: feature adoption rate) |
| Counter-metric | What would tell us we made things worse? (default: support ticket rate in adjacent flow) |
| Scope upper bound | What is explicitly NOT in v1? (default: list discovered non-goals) |
| Timeline pressure | Is there a hard date? (default: no, we ship when ready) |
| Differentiation | Why our solution vs competitor's? (default: native to our product surface) |
| Reversibility | Can we wind this down if it doesn't work? (default: yes via feature flag) |

## Discovery vs definition behavior

### Discovery mode
- Multiple solution options compared with effort/risk.
- Lighter on commitments; heavier on understanding the problem.
- "Recommended approach" is advisory, not decided.
- Ends with: which option to pursue + next discovery step.

### Definition mode
- Single chosen approach with rationale for not choosing alternatives.
- Committed scope (v1 / fast-follow / later).
- Ends with: ready for engineering to write a spec ([[full-spec-rewriter]]).

## Tone discipline

- First person plural ("we") not corporate ("the product team will").
- Specifics over hedges. "30% drop in Step 3 conversion" > "low engagement".
- Honest about uncertainty. "We don't know X yet" is better than fake confidence.
- No marketing fluff. "Game-changer", "delightful experience" — strip.
- Cite sources for data. A claim without a citation is a guess.

## Anti-bloat rules

- TL;DR ≤ 5 sentences.
- Each section as short as possible while still complete.
- "Out of scope" is mandatory — protects against scope creep later.
- "Open questions" section forces explicit unknowns instead of hidden ones.

## Token budget

| Mode | Tokens |
|---|---|
| discovery | 10–25k |
| definition | 15–35k |
| with deep research / multiple option write-up | 40–60k |

## Hand-off

- **Approved PRD** → [[full-spec-rewriter]] for engineer-side spec.
- **Decisions made** → log in PRD section 14; archive PRD with version bump.
- **Changes after PRD approval** → don't edit silently; append decision to log.

## CLAUDE.md hooks

Reads section A (product, audience, business model — affects metric defaults), B (writing-style / format rules), E (linked-doc locations).
Writes PRD to `.invisible/prds/<feature-slug>-v<n>.md`. Version-bumps on edit.

## Failure modes

- Brief is implementation-only ("build a button") → flag mismatch, ask for the problem the button solves.
- Multiple conflicting briefs → surface conflict matrix, refuse to draft single PRD until resolved.
- "PRD" requested but goal is internal alignment doc → recommend lighter format (RFC), then proceed.

## Distinction from full-spec-rewriter

| | prd-writer | full-spec-rewriter |
|---|---|---|
| Audience | PM, design, exec, stakeholders | Engineers (implementer) |
| Focus | Problem + outcome | Implementation surface |
| Includes | Success metrics, options, rollout, comms | API shape, data model, test plan, codebase grounding |
| Phase | Pre-decision, pre-build | Post-decision, pre-build |
| Stops at | Approved direction | Buildable artifact |

Run PRD first, then spec. Don't run them concurrently — PRD output is spec input.

## Related

[[full-spec-rewriter]] · [[deep-codebase-mapper]] · [[architecture-advisor]] · [[future-self-advisor]]
