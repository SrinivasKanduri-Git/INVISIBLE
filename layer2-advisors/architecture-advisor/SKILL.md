---
name: architecture-advisor
description: Silent advisor on architectural drift — layering violations, premature abstraction, premature extraction (service / microservice), god objects, tight coupling, missing seams. Surfaces structural concerns the agent isn't trained to see while writing one feature. Notes only; never blocks.
layer: 2
enabled_default: true
caps:
  body_lines: 150
  notes_per_turn: 5
triggers:
  signals: ["new service", "extract", "refactor", "shared util", "controller calls model directly", "model knows about HTTP", "new top-level dir", "circular import"]
  load_when: any L1 skill loaded OR output adds new module/service/abstraction
suppress_when:
  - explicit `// arch-ok: <reason>` annotation
  - tiny diff (≤30 LOC change) — too small to warrant arch concern
---

# architecture-advisor

Watches for structural drift while a feature is being built. Not a refactor recommender — it raises notes when **the current change is making the codebase worse-shaped**, with the cheap fix-now option.

## What it watches

| Signal | Concern |
|---|---|
| Controller / route handler doing business logic | Should live in service / use-case layer |
| Model importing HTTP / framework symbols | Wrong direction of dependency |
| View / template calling DB | Skipping layers |
| Three copies of similar logic in three places | Extract? (only when ≥3 — not 2) |
| Single class >500 lines / >15 public methods | God object forming |
| Module with no clear responsibility ("utils", "helpers", "common") | Drift dump |
| Circular import / requires | Coupling bug |
| New microservice / new top-level package introduced for one feature | Premature extraction |
| Shared mutable state across requests | Race + test pain |
| Concrete vendor type in domain model | Coupling to external (cross with [[integration-advisor]]) |
| Configuration via global singleton vs DI | Test pain ahead |

## Note format

```
[architecture-advisor] PX: <structural smell>. <future cost>. Suggest: <cheap fix now>.
```

## Severity

| Tier | When |
|---|---|
| **P1** | Active layering violation (DB call from view, model importing HTTP layer, circular dep). Cheaper to fix now. |
| **P2** | Drift forming (god object growing, util dumping). Note now, don't force action. |
| **P3** | Future-flexibility (could extract behind interface; could parameterize). Style. |

## Examples

```
[architecture-advisor] P1: `OrderController#checkout` does pricing + tax + payment + email send inline (~120 lines). Suggest: extract `CheckoutService.run(order)` — controller becomes 6 lines.

[architecture-advisor] P2: `lib/utils.js` now has 14 unrelated helpers. Becoming a drift dump. Suggest: split by domain (`lib/dates.js`, `lib/strings.js`) before next addition.

[architecture-advisor] P2: Three copies of "format user display name" across 3 files (varying logic). Suggest: single `formatUserName(user)` in domain helper; tests follow.

[architecture-advisor] P3: New endpoint instantiates `StripeClient` directly. Suggest: inject via container — keeps test seams + matches pattern in payments/.
```

## Premature abstraction guardrail

This advisor is explicitly biased *against* premature extraction:

- **Two duplicates = leave alone.** Don't extract on second sight.
- **Three duplicates = consider** extraction.
- **Four+ duplicates = recommend** extraction.

Notes never say "this might be reused elsewhere — extract now." Real reuse, not imagined.

## Premature microservice guardrail

Splitting into a new service requires:
- Distinct deployment cadence (e.g., team boundary, scale boundary)
- Distinct data ownership
- Stable contract surface

A new top-level service for one feature with no team boundary → P1, "extract a module, not a service."

## Layer model (default)

```
view / route        ← presentation
   ↓
controller / handler ← request glue
   ↓
service / use-case   ← business logic, transaction boundaries
   ↓
domain model        ← entities + invariants
   ↓
repository / data   ← persistence
```

Skipping a layer (view → model, controller → DB) = P1 note. Reverse direction (model importing view) = P1.

Stack-specific:
- Rails: thin controller / fat service / skinny model (or POROs in `app/services/`).
- Django: views → services → models; avoid logic in views.
- NestJS: explicit module structure already enforces this.
- Next.js App Router: server components ≠ business logic dumping ground; extract server actions / services.

## Anti-noise rules

1. **No tiny-diff arch notes.** A 30-LOC patch doesn't justify a structural critique.
2. **No "everything is a service" dogma.** Static utils are fine; not every function needs a class.
3. **No DDD lecture.** Notes describe smell + cheap fix, not aesthetics.
4. **Defer to project conventions** in CLAUDE.md section B (some projects use different layer names; respect them).
5. Max 5 notes/turn; P1 exempt. P3 drops first.
6. Suppress on `// arch-ok: legacy, scheduled for X`.

## Plan-time use

When plan introduces a new service / module / extraction, this advisor weighs in *before* the code lands. Cheaper to redirect at plan time than after.

## CLAUDE.md hooks

Reads section A: `architecture_style` (layered / hex / clean / DDD-lite), `layer_names`, `service_layer_present`.
Reads section B: project conventions (e.g., "use-case classes in `app/use_cases/`").
Reads section C: accepted exceptions (e.g., "admin/ bypasses service layer, audited").

## Interaction with L1

- code-scanner catches mechanical violations (e.g., `db.query` from view file).
- architecture-advisor catches design-shape issues (god object growth, mis-layered logic).

## Related

[[code-scanner]] · [[api-net]] · [[db-net]] · [[integration-advisor]] · [[scaling-advisor]] · [[future-self-advisor]]
