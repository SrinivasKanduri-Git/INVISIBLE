# meta/interop.md

How INVISIBLE coexists with other skillsets. Versions pinned; quarterly review.

## Rule of thumb

INVISIBLE owns: safeguards (L1), advisor notes (L2), opt-in deep work (L3). Anything else — defer to the other tool's domain.

## Per-skillset rules

| Skillset | Domain | INVISIBLE behavior |
|---|---|---|
| **caveman** | Tone / token compression | Hands off — INVISIBLE never alters caveman's output formatting. INVISIBLE's own advisor notes respect active caveman level (lite/full/ultra). |
| **graphify** | Knowledge graphs, diagrams, visuals | Hands off — graphify owns all visual generation. INVISIBLE's `architecture-advisor` may reference a graph, never produce one. |
| **ruflo** | Routing / orchestration | Defer routing — if ruflo active, DECIDER becomes a *suggestion provider* to ruflo, not the final router. ruflo decides; INVISIBLE annotates. |
| **agency-agents** | Multi-agent review pipelines | Run as one reviewer in agency's pipeline. INVISIBLE never spawns sibling agents. |
| **spec-kit** | Spec generation | Complementary. spec-kit produces specs; INVISIBLE's L3 `full-spec-rewriter` only runs if user explicitly invokes it after spec-kit. No silent overlap. |

## Unknown overlap

When an unfamiliar skillset is detected (file in `~/.claude/skills/<name>/` not in this table):

1. INVISIBLE loads as normal.
2. [[recommender]] surfaces a one-time P3 note: *"Detected `<name>`. Configure interop in `meta/interop.md` or run `/invisible interop add <name>`."*
3. Default behavior: INVISIBLE does not refuse to load, but [[circuit-breaker]] watches for output conflicts (same advice from both, contradictions).

## Version pinning

`interop.md` lists tested version ranges. If detected version falls outside, surface P2 advisor note and degrade to conservative mode (no new rule writes via self-learner until resolved).

```yaml
caveman: ">=2.0,<3.0"
graphify: ">=1.0"
ruflo: ">=0.5"
agency-agents: ">=1.2"
spec-kit: ">=0.9"
```

## Quarterly review

Cron-tracked. Each quarter, run interop smoke tests against latest published version of each pinned skillset. Update ranges in CHANGELOG.

## Related

[[recommender]] · [[circuit-breaker]] · [[conflict-resolver]]
