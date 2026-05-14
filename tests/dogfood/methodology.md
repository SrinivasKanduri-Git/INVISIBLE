# Dogfood methodology

Sprint 6 — Run INVISIBLE on 3 real vibe-coded repos. Measure. Tune from miss-log. Publish numbers in README.

## Repo selection (pick BEFORE running)

Pick 3 repos that match the target user:
- **demo-grade output**, ≥30 PRs of AI-assisted code
- **at least one** auth or payment surface (security-critical exercise)
- **at least one** multi-tenant or realtime surface (cluster-skill exercise)
- **distinct stacks** across the three (e.g., Rails / Next.js / FastAPI)
- **not our own code** — bias risk

Document choices in `repo-selection.md` (one paragraph each: stack, size, why picked). Lock in before any measurement to prevent post-hoc cherry-picking.

## What to measure (per repo)

### Catch rate (the headline metric)

For each repo, manually triage the latest 20 PRs. Label each issue found:
- **Silent killer** — security / data integrity / production failure mode that wouldn't fail loudly in dev (auth bypass, money-as-float, missing CSRF, N+1 quadratic, missing webhook signature, secrets in code, multi-tenant leak, etc.)
- **Quality issue** — UX/polish/maintainability (would not page on-call, but degrades product)
- **Style** — formatting, naming, taste

Then run INVISIBLE against each PR (replay turn-by-turn if possible). Count:
- INVISIBLE flagged it (true positive)
- INVISIBLE missed it (false negative)
- INVISIBLE flagged a non-issue (false positive)

**Catch rate** = silent-killer TP / (silent-killer TP + silent-killer FN). Target: ≥70%.

Report each repo's number separately. Average across 3.

### Token cost (per stack)

Per turn, record:
- Always-on overhead (CLAUDE.md + DECIDER + L1/L2/L3 metadata)
- Per-task additional (skill bodies loaded + pattern scan + advisor notes)

Sample 50 turns per repo. Report p50 / p95.

Target (plan §8): always-on ~6k; per-task 3–7k (worst case ~13k).

### Advisor noise

Per turn, count L2 notes emitted. Survey user (or proxy: review each note) for:
- Actionable
- Informational-but-fair
- Noise (would be dismissed without reading)

Target: noise ≤20% of notes. P1 advisor notes 100% actionable.

### Circuit-breaker trips

Track [[circuit-breaker]] state transitions per repo over the 20-PR window.
- Trips to `degraded` / `disabled`
- Triggers per trip
- Recovery (manual or auto)

Target: <10% of projects in `degraded` at any time post-tuning.

### DECIDER misfire log

Every time DECIDER loaded a wrong skill (or missed a clear one): record in `decider-misses.json`:

```json
{
  "turn_id": "...",
  "repo": "...",
  "input_summary": "...",
  "loaded": [...],
  "should_have_loaded": [...],
  "missing_signal": "..." // what signal would have caught it
}
```

Feed into Sprint 6 tuning round.

## How to run (per repo)

1. Clone repo at lock-time commit.
2. `git log --merges --since=... --before=...` to identify the 20 PRs.
3. For each PR:
   - Check out commit before merge.
   - Apply PR diff to a working branch.
   - Replay the PR's authoring turns through INVISIBLE (if conversation log available) OR manually scan diff via L1 skills' patterns.
   - Record all findings + their disposition (TP / FN / FP).
   - Note token usage.
4. Compile per-repo report (`results/<repo-slug>.md`).
5. After all 3, compile `aggregate.md` with averages + per-stack breakdown.

## Output artifacts

```
tests/dogfood/
  methodology.md           ← this file
  repo-selection.md         ← pre-lock selection
  results/
    <repo-1-slug>.md
    <repo-2-slug>.md
    <repo-3-slug>.md
  aggregate.md              ← cross-repo summary
  decider-misses.json       ← tuning input
  notes-noise-survey.md     ← L2 advisor noise audit
```

## Per-repo report template (`results/<slug>.md`)

```markdown
# Dogfood — <repo slug>

## Repo metadata
- Stack: <one-line>
- Size: <LOC, file count>
- Auth + payment: <yes / no>
- Multi-tenant or realtime: <yes / no>
- PRs sampled: 20 (#<first>–#<last>)
- Commit range: <sha1>..<sha2>

## Catch rate
| Class | TP | FN | FP | Rate |
|---|---|---|---|---|
| Silent killer | <N> | <N> | <N> | <X%> |
| Quality | <N> | <N> | <N> | — |
| Style | <N> | <N> | <N> | — |

### Notable catches (TP examples)
- PR #<N>: <one-line> — caught by <skill>
- ...

### Notable misses (FN examples) — drives tuning
- PR #<N>: <issue> — should have triggered <skill> via <signal>
- ...

### Notable false-positives — drives tuning
- PR #<N>: <flag> — actually fine because <reason>
- ...

## Token cost (50 sampled turns)
| Component | p50 | p95 |
|---|---|---|
| Always-on overhead | <N> | <N> |
| Per-task L1 bodies | <N> | <N> |
| Pattern scan | <N> | <N> |
| L2 advisor bodies | <N> | <N> |
| Total per turn | <N> | <N> |

## Advisor noise
- Total L2 notes emitted: <N>
- Actionable: <N> (<%>)
- Informational: <N> (<%>)
- Noise: <N> (<%>)

## Circuit-breaker
- Trips to `degraded`: <N>
- Trips to `disabled`: <N>
- Triggers: <list>

## Notes / recommendations
- <observation>
```

## Aggregate report (`aggregate.md`)

```markdown
# Dogfood aggregate

## Catch rate
| Repo | Stack | Rate |
|---|---|---|
| 1 | Rails+Sidekiq | <X%> |
| 2 | Next.js+Prisma | <X%> |
| 3 | FastAPI | <X%> |
| **Average** | — | <X%> |
| **Target** | — | ≥70% |

## Token cost by stack
| Stack | Always-on p50 | Per-task p50 | Per-task p95 |
|---|---|---|---|
| ... | ... | ... | ... |

## Advisor noise across 3 repos: <X%> (target ≤20%)

## Circuit-breaker trip rate: <X%> (target <10%)

## Top DECIDER tuning issues (going into Sprint 6 tuning round)
1. <issue + proposed fix>
2. ...
```

## Tuning loop

Sprint 6 plan: ≥2 tuning rounds after first dogfood pass.

1. Run dogfood → catch rate measured.
2. Apply tuning (DECIDER weights, skill triggers, advisor severity calibration). Diff in `tuning-round-<n>.md`.
3. Re-run on same 3 repos.
4. Compare. Iterate until catch rate stabilizes or budget exhausted.

## Honesty rules

- **Publish what you measured.** Don't cherry-pick.
- **Document repo selection BEFORE running** — prevents post-hoc bias.
- **FN list is the most important section** — that's where future tuning lives.
- **Per-stack numbers**, not just averages — average hides bad stacks.
- **Compare against rework cost** (plan §8): even 50% catch rate pays for itself if rework rounds cost 4k+ tokens.

## Release gate

Dogfood does **not** block release directly (unlike rule-validator stress). But README cannot be published until aggregate numbers exist. Plan §6: "Write README with *measured* numbers."

If catch rate < 50% across all 3 repos → block release; tune until ≥70% on at least one stack and improving on the other two.
