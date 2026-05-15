---
description: INVISIBLE safeguard skillset. Activate Layer 3 skills and meta commands.
argument-hint: [subcommand] e.g. status, map, spec, audit security, refactor
allowed-tools: Read
---

User invoked `/invisible $ARGUMENTS`.

Read `${CLAUDE_PLUGIN_ROOT}/meta/invisible-loader.md` first if not already in context, then dispatch on the first argument token:

- **status** (or no args): Report DECIDER state, loaded skills, circuit-breaker, layer3_enabled list.
- **map**: Read `${CLAUDE_PLUGIN_ROOT}/layer3-max-performance/_core5/codebase-map/SKILL.md` and execute it.
- **spec**: Read `${CLAUDE_PLUGIN_ROOT}/layer3-max-performance/_core5/spec-generator/SKILL.md` and execute it.
- **prd**: Read `${CLAUDE_PLUGIN_ROOT}/layer3-max-performance/_extended8/prd-generator/SKILL.md` and execute it.
- **audit prod-readiness**: Read `${CLAUDE_PLUGIN_ROOT}/layer3-max-performance/_core5/prod-readiness-auditor/SKILL.md` and execute it.
- **audit security**: Read `${CLAUDE_PLUGIN_ROOT}/layer3-max-performance/_core5/security-auditor/SKILL.md` and execute it.
- **refactor**: Read `${CLAUDE_PLUGIN_ROOT}/layer3-max-performance/_core5/refactor-planner/SKILL.md` and execute it.
- **perf**: Read `${CLAUDE_PLUGIN_ROOT}/layer3-max-performance/_extended8/perf-investigator/SKILL.md` and execute it.
- **trd**: Read `${CLAUDE_PLUGIN_ROOT}/layer3-max-performance/_extended8/trd-generator/SKILL.md` and execute it.
- **design**: Read `${CLAUDE_PLUGIN_ROOT}/layer3-max-performance/_extended8/arch-designer/SKILL.md` and execute it.
- **openapi**: Read `${CLAUDE_PLUGIN_ROOT}/layer3-max-performance/_extended8/openapi-generator/SKILL.md` and execute it.
- **runbook**: Read `${CLAUDE_PLUGIN_ROOT}/layer3-max-performance/_extended8/runbook-generator/SKILL.md` and execute it.
- **data-model**: Read `${CLAUDE_PLUGIN_ROOT}/layer3-max-performance/_extended8/data-model-designer/SKILL.md` and execute it.
- **onboarding**: Read `${CLAUDE_PLUGIN_ROOT}/layer3-max-performance/_extended8/onboarding-doc-generator/SKILL.md` and execute it.
- **validate-rule**: Read `${CLAUDE_PLUGIN_ROOT}/meta/rule-validator.md` and dry-run it on the quoted rule text in `$ARGUMENTS`.
- **refresh-patterns**: Read `${CLAUDE_PLUGIN_ROOT}/meta/pattern-scan-budget.md` and rebuild the pattern cache.

If the target SKILL.md path does not exist, list available L3 skills from `${CLAUDE_PLUGIN_ROOT}/layer3-max-performance/` and stop.

Honour L3 cap: ≤1 active per turn.
