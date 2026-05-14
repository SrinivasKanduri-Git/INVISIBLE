# spec-kit — Input 1 (vague export brief)

**Status**: DEFERRED. No local spec-kit runtime available. Fabricating spec-kit's output would violate the honesty rule in `tests/vs-spec-kit/methodology.md` ("Failures published. Not a smear of spec-kit. Goal is honest delta, not marketing.").

## Protocol to complete this artifact

1. Install spec-kit per https://github.com/github/spec-kit official instructions. Pin to a release tag at lock-in time.
2. Feed `tests/vs-spec-kit/inputs/input-1-brief.md` through spec-kit's `/specify` → `/plan` → `/tasks` pipeline (or whichever phases the pinned version exposes).
3. Capture raw output into this file.
4. Score per rubric in methodology.md.

## What spec-kit is designed to produce (from public docs)

For honest framing — not a substitute for actual run:

spec-kit operates in phases. The brief would typically generate:
- A **spec** (`/specify` phase) documenting what the feature does, user stories, acceptance criteria.
- A **plan** (`/plan` phase) — technical decisions, tech stack alignment, library choices.
- **Tasks** (`/tasks` phase) — sequenced build steps.

It optimizes for structured, repeatable spec generation. It does **not** apply a continuous safeguard layer to every turn; that's an architecturally different concern.

## What this comparison should actually measure

Per methodology rubric — applied once spec-kit is run:
- Output length (tokens)
- Time to produce
- Silent-killer count (12-item list)
- Security checks
- Test-plan rubric (0–5)
- Edge cases enumerated
- Stack-aware specifics
- Open questions

Pending real run.

## Why not just describe spec-kit's likely output

Reasons for refusal:
1. Misrepresenting another tool's output as if it ran is dishonest.
2. spec-kit version drift: what its current pinned release produces differs from older snapshots.
3. spec-kit may produce stronger spec structure than INVISIBLE's simulation; pretending to know which side wins without running it skews the headline number.
4. README §11 ("Honest limitations") promises measurements are reproducible; faked spec-kit output would not be.

## When to complete

Sprint 6 round 2 OR v0.8 release prep, whichever has live spec-kit access. Until then, comparison-summary.md marks this row "spec-kit: not yet run".
