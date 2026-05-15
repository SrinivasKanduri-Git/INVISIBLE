---
description: Initialize INVISIBLE-shaped CLAUDE.md in current project from template.
argument-hint: (no args)
allowed-tools: Read, Write, Bash(pwd:*), Bash(test:*)
---

Initialize a project-scoped `CLAUDE.md` using INVISIBLE's template.

## Steps

1. Run `pwd` to get the current project directory `$PROJECT`.
2. Check if `$PROJECT/CLAUDE.md` already exists:
   - If yes: read it, confirm with the user whether to overwrite (default: keep), and stop unless they say overwrite.
   - If no: continue.
3. Read `${CLAUDE_PLUGIN_ROOT}/CLAUDE_TEMPLATE.md`.
4. Write the template contents to `$PROJECT/CLAUDE.md` verbatim.
5. Scan the project root for stack signals (in this order, stop at first hit):
   - `package.json` → infer Stack from `dependencies` (React/Next/Vue/Express/etc.)
   - `Gemfile` → Ruby/Rails
   - `pyproject.toml` / `requirements.txt` → Python (Django/Flask/FastAPI)
   - `go.mod` → Go
   - `Cargo.toml` → Rust
   - `pom.xml` / `build.gradle` → Java
   - else: leave Stack blank
6. Best-effort fill `## Project` block:
   - **Name**: directory basename
   - **Stack**: detected stack from step 5 (or blank)
   - **Purpose**: leave blank for the user
7. Print the final path + a one-line reminder: "Fill in Domain rules, Patterns, Known landmines as you discover them. INVISIBLE reads this every turn."

## Hard rules

- Do NOT scan the codebase beyond the stack-signal files above. Pattern discovery is `/invisible refresh-patterns`, not `/init`.
- Do NOT write anything outside `$PROJECT/CLAUDE.md`.
- Do NOT prepend or append to existing CLAUDE.md. Either overwrite (with confirmation) or leave it.
- Keep the template's section structure intact — `## Project`, `## Domain rules`, `## Accepted exceptions`, `## Patterns`, `## Known landmines`, `## INVISIBLE config` (yaml block).
