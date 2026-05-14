---
name: refactor-architect
description: User-opt-in pass that designs a multi-step refactor plan from a smelly module/file/dir. Surfaces dependency graph, blast radius, safe-move sequence, test gaps to fill before refactor, intermediate commit points, and rollback escape hatches. Outputs a step-by-step plan; does NOT auto-edit code. ≤1 active L3/turn.
layer: 3
group: _extended8
enabled_default: false
opt_in: true
cli: "/invisible refactor [--target <path>] [--strategy extract|split|merge|rename|invert]"
caps:
  body_lines: 400
recommender:
  min_score: 4.5
  triggers: ["refactor", "untangle", "split this up", "extract service", "rename across the codebase", "this got too big", "god object", "circular import"]
---

# refactor-architect

Designs a stepwise refactor plan. Optimized for "this module/file/dir has gotten too big or wrong-shaped — what's the safe path out?" Outputs a plan; the agent (or human) executes step-by-step with checkpoints.

## When to run

- Module / class >500 LOC OR >15 public methods (god-object territory).
- Circular import / dependency tangle.
- Three+ near-duplicates ready for extraction.
- Pre-feature-build where new feature would worsen current structure.
- Inherited code with smell + need to change it soon.

## When NOT to run

- Small fix that doesn't need redesign — just do the fix.
- Refactor for aesthetics only (no upcoming change requiring it). Tech-debt drift, premature.
- Active rewrite already mid-flight — finish that first.

## Strategies

| Strategy | When |
|---|---|
| `extract` | Pull cohesive logic out of god class/file (e.g., service from controller) |
| `split` | Module's two unrelated responsibilities become two modules |
| `merge` | Two similar modules duplicated; one canonical |
| `rename` | Wrong name; cross-cutting rename safely |
| `invert` | Dependency direction wrong (e.g., model importing HTTP layer) |

Auto-detect if `--strategy` omitted.

## Output artifact

```markdown
# Refactor Plan — <target> — <date>
INVISIBLE refactor-architect · strategy=<name>

## 0. Summary
**Goal**: <one-line>
**Strategy**: <name + rationale>
**Estimated effort**: <S/M/L>
**Risk**: <L/M/H> — <main risk source>
**Steps**: <N>
**Intermediate-mergeable commits**: yes/no

## 1. Smell analysis
**Target**: `<file_or_dir>`
**Current size**: <LOC, public-surface count>
**Smells identified**:
- <smell> — evidence `<file>:<line>`
- ...

## 2. Dependency snapshot (before)
**Importers** (who depends on target):
- `<file>` — uses `<symbol>`, `<symbol>`
- ...

**Imports** (what target depends on):
- `<module>` — for `<purpose>`

**Coupling score**: <low/med/high> — <N inbound, N outbound>

## 3. Target shape (after)
**New layout**:
```
<dir>/
  <new_file_1>  — <role>
  <new_file_2>  — <role>
```

**Public-API contract** (callers see what):
- <stable> — `<symbol>` preserved
- <changed> — `<old>` → `<new>` (migration helper present during transition)
- <removed> — `<symbol>` (deprecation cycle: <plan>)

## 4. Test gap fill (BEFORE touching code)
- [ ] Add characterization test: <what behavior currently is>
- [ ] Add boundary test: <edge case at API surface>
- [ ] Add integration test covering <flow that touches target>

**Rationale**: refactor without tests = guess-driven coding. Fill the gap first.

## 5. Stepwise plan (each step is a mergeable commit)

### Step 1 — <name>
**Change**: <what>
**Files touched**: <list>
**Why this step is safe to merge alone**: <reason>
**Verification**: <tests pass, plus what to eyeball>
**Rollback**: <revert this commit; no data shape changed>

### Step 2 — ...

...

### Step N — final cleanup
**Change**: remove now-unused old code
**Why now**: every caller has migrated
**Rollback**: keep deprecation alias for one more release

## 6. Cross-cutting impacts
- DB migrations: <none / list>
- API contract: <unchanged / additive / breaking>
- CLAUDE.md: <patterns to update>
- Tests outside target: <list>
- Feature flags: <use to gate large step?>

## 7. Rollback strategy
Each step is independently revertible. Beyond step N:
- If smoke fails post-step → revert that step.
- If discovered drift mid-plan → re-run refactor-architect with updated state.

## 8. Things NOT changed (out of scope)
- <related but separate smell> — defer to follow-up refactor

## 9. Open questions
- [ ] <decision point that needs human>

## Run metadata
- Files analyzed: <N>
- Import-graph nodes traversed: <N>
- Tokens used: <N>
```

## Strategy patterns

### Extract (god class → service)

Typical: controller / model / "manager" class doing too much.

Steps:
1. Identify cohesive subset (3–8 methods sharing data).
2. Create new module / class for the subset.
3. Add characterization tests on current behavior.
4. Move methods one-by-one, callers updated, tests green at each step.
5. Once moved, eliminate intermediary; callers call new module directly.
6. Delete old method shells.

### Split (one module → two)

Module has two independent responsibilities (e.g., `lib/user.js` does both auth and profile).

Steps:
1. Identify the two clusters by symbol co-usage.
2. New file per cluster; old file re-exports both temporarily.
3. Move callers off old file one-by-one.
4. Remove old re-export shim.

### Merge (two modules → one)

Two near-duplicate modules — pick canonical.

Steps:
1. Diff the two; identify the union of behaviors.
2. Add tests covering both sets of behavior.
3. Pick canonical (more callers, better-named, fewer side-effects).
4. Backfill the canonical with missing behaviors from the other.
5. Migrate callers of the non-canonical to canonical.
6. Delete the non-canonical.

### Rename (cross-cutting symbol rename)

Bad name → good name across N files.

Steps:
1. Add new name as alias of old (both work).
2. Migrate one caller cluster at a time.
3. Delete old name once last caller migrated.

Avoid in one giant commit when callers >20 — landmines in conflicts.

### Invert (dependency direction wrong)

E.g., domain model imports HTTP framework. Invert via dependency injection.

Steps:
1. Identify the wrong-direction import.
2. Introduce abstract interface in the lower layer.
3. Implement interface in the upper layer.
4. Inject implementation from upper → lower at composition root.
5. Lower layer no longer imports upper.

## Safety rules (refactor-architect enforces)

1. **Always fill test gap first.** Refactor without characterization tests is unsafe.
2. **Each step compiles + tests pass.** No "broken on the way to fixed."
3. **Each step is mergeable alone.** Long-lived refactor branches rot. Trunk-merge per step.
4. **No combined refactor + feature.** Smell-fix and behavior-change are separate PRs.
5. **No combined refactor + dep upgrade.** Diff signal preserved.
6. **API surface preserved during transition.** Deprecate, don't break, even internally.
7. **No "big bang" rewrites.** If plan is one giant step, the plan is wrong.
8. **Rollback path on every step.** If revert breaks DB state, the step is not yet safe.

## Auto-detection of strategy

If `--strategy` omitted, infer from target:

- Single file >500 LOC + cohesive subset → **extract**
- Single file with two named domains → **split**
- Two files with >50% symbol overlap → **merge**
- Symbol with consistently-wrong name (≥10 callers) → **rename**
- Cross-layer wrong-direction import → **invert**

If multiple apply, present options and ask user to choose.

## Token budget

| Scope | Tokens |
|---|---|
| Single file refactor | 10–25k |
| Module refactor | 30–70k |
| Multi-module untangle | 80–150k |

## Failure modes

- Target tests don't exist + can't infer behavior from code alone → refuse, recommend writing characterization tests first.
- Refactor scope unbounded ("clean up the codebase") → refuse, request specific target.
- Active feature work in target dir → recommend deferring refactor until feature ships.

## Integration with other tools

- Best run after [[deep-codebase-mapper]] (cleaner dep graph available).
- For perf-driven refactors, run [[perf-deep-dive]] first (don't refactor on speculation).
- Findings recorded in `.invisible/refactors/<target-hash>.md`.

## CLAUDE.md hooks

Reads section A (architecture style), B (project conventions), C (accepted exceptions).
Writes refactor plan to `.invisible/refactors/`. Never edits code directly.

## Related

[[architecture-advisor]] · [[deep-codebase-mapper]] · [[perf-deep-dive]] · [[test-net]] · [[code-scanner]]
