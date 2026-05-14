# INVISIBLE Refactor Plan — v0.8 UX Overhaul

> **Prepared for Claude Code to analyse and implement.**
> Priority order: P0 (blocker) → P1 (UX-critical) → P2 (quality).

---

## Executive Summary of Problems Found

| # | Problem | Severity | Root Cause |
|---|---|---|---|
| 1 | Skills **never load** in Claude Code | P0 | Claude Code doesn't discover directories of SKILL.mds from `~/.claude/skills/` symlinks — only reads `CLAUDE.md` imports and `settings.json` |
| 2 | `/invisible` command **doesn't exist** | P0 | Claude Code slash commands must be declared in `CLAUDE.md` or `settings.json`; no filesystem-based discovery of commands |
| 3 | `CLAUDE_TEMPLATE.md` costs **~9k tokens on /init** | P1 | Template is bloated with examples and generic filler that users copy verbatim without editing |
| 4 | Install is **4 manual steps** with symlinks + `shasum` | P1 | No `install.sh`; users on Linux/Mac with no `shasum` (GNU sha1sum) fail silently |
| 5 | Uninstall is **ambiguous** — broken state possible | P2 | 3 places to clean up, no verification script |
| 6 | Global `~/.claude/CLAUDE.md` was **overwritten** with the blank template | P0 | `cp CLAUDE_TEMPLATE.md ./CLAUDE.md` from the skillset root is being run inside `~/.claude/`, clobbering the global config that caveman + graphify depend on |

---

## Root Cause Deep-Dive

### How Claude Code Actually Loads Skills

Claude Code reads context from:
1. **`CLAUDE.md`** in the project root and in `~/.claude/CLAUDE.md` (global) — plain markdown, loaded verbatim into every session
2. **`settings.json`** — controls hooks, plugins, slash commands (via `enabledPlugins`)
3. **`~/.claude/skills/<name>/SKILL.md`** — only loaded when explicitly referenced from `CLAUDE.md` using `@import` syntax OR when a plugin with `trigger: /command` is registered

The current install creates symlinks in `~/.claude/skills/invisible-layer{1,2,3}` and `invisible-meta` — pointing to **directories**, not to a single `SKILL.md`. Claude Code does not recursively walk these directories. The skills are **silently never loaded**.

### Why `/invisible` Never Appears

The `README.md` documents `/invisible map`, `/invisible spec`, etc., but these are never registered anywhere. Claude Code slash commands come from:
- `enabledPlugins` in `settings.json` (e.g., how `caveman@caveman` is loaded)
- A `SKILL.md` frontmatter with `trigger: /command` for skills loaded via a plugin

None of the INVISIBLE SKILL.mds have a top-level trigger registered in `settings.json`.

### The Token Bomb in CLAUDE_TEMPLATE.md

The current `CLAUDE_TEMPLATE.md` (74 lines, ~2.4KB) copies into the project root as `CLAUDE.md`. But it contains:
- Example patterns table with **generic rows** users never delete (Sidekiq, cursor pagination, etc.)
- Example domain rules for a billing app users aren't building
- The full `## A–F` section headers with verbose commentary
- Section G YAML block with placeholder values

When combined with the global `~/.claude/CLAUDE.md` (also the template, currently overwritten), every session starts with ~9k tokens of boilerplate before a single user message.

---

## Refactor Plan

### P0 — Fix: Make Skills Actually Load

**Strategy**: Use the same pattern as `graphify` — a single `SKILL.md` per registerable unit with a frontmatter `trigger`, referenced from `CLAUDE.md`. INVISIBLE has too many skills to load all at once; the DECIDER routing must live in `CLAUDE.md` as inline instructions, with skills loaded on-demand via Read tool.

#### P0.1 — Create `~/.claude/CLAUDE.md` Safe Merge (not overwrite)

**Problem**: Step 2 of INSTALL says `cp CLAUDE_TEMPLATE.md ./CLAUDE.md` from inside the skillset dir. If run with `Cwd=~/.claude/invisible-skillset` and the user is confused about working directory, this overwrites `~/.claude/CLAUDE.md`, destroying caveman and graphify registrations.

**Fix**: The install script must write only to the **project root**, never to `~/.claude/`. The global `~/.claude/CLAUDE.md` should only get an INVISIBLE **registration block appended**, not overwritten.

The `install.sh` handles this with an idempotent marker:

```bash
MARKER="<!-- invisible:loader -->"
touch "$GLOBAL_CLAUDE"
if ! grep -q "$MARKER" "$GLOBAL_CLAUDE"; then
  cat >> "$GLOBAL_CLAUDE" << BLOCK
$MARKER
## INVISIBLE
@import $SKILLSET_DIR/meta/invisible-loader.md
<!-- /invisible:loader -->
BLOCK
fi
```

#### P0.2 — Create `meta/invisible-loader.md` (the actual entry point)

This is the single file Claude Code loads on every session via the `@import` in `~/.claude/CLAUDE.md`. It replaces the broken symlink approach with a compact routing table + Read-on-demand pattern.

**File to create**: `meta/invisible-loader.md`

```markdown
---
name: invisible
description: "INVISIBLE safeguard skillset. Catches silent killers before they ship."
trigger: /invisible
---

# INVISIBLE — Active

## How to operate each turn

1. Score each domain against the routing table below.
2. Load ≤4 skills scoring ≥3.0 (Read the SKILL.md file from disk).
3. Apply skill rules before writing code.
4. Run code-scanner on output ≥30 LOC or auth/payment files.
5. Emit L2 advisor notes (≤5/turn, P1 exempt).

## Routing table (abbreviated — full: ~/.claude/invisible-skillset/DECIDER.md)

| Skill | Key triggers |
|---|---|
| auth-net | login, JWT, session, token, password, OAuth, role, permission |
| api-net | endpoint, route, controller, API, HTTP verbs |
| db-net | migration, schema, model, column, index, SQL |
| payment-net | payment, Stripe, charge, invoice, refund |
| error-net | error, exception, try/catch, 500, logging |
| env-net | deploy, Docker, .env, production, secrets |
| test-net | test, spec, RSpec, Jest, coverage |
| async-ops-net | background job, worker, Sidekiq, queue, email |
| data-flow-net | cache, Redis, tenant, organization, S3 |
| integration-net | third-party, webhook, SDK, timeout |
| realtime-net | WebSocket, Socket.IO, real-time |
| ui-net | component, button, form, modal, .tsx, .jsx |
| i18n-net | i18n, locale, translation, RTL |
| graphql-net | GraphQL, resolver, Apollo |
| code-scanner | always-on (≥30 LOC output or auth/payment files) |

## Skill paths

`~/.claude/invisible-skillset/layer1-safeguards/<skill>/SKILL.md`
`~/.claude/invisible-skillset/layer2-advisors/<skill>/SKILL.md`
`~/.claude/invisible-skillset/layer3-max-performance/_core5/<skill>/SKILL.md`
`~/.claude/invisible-skillset/layer3-max-performance/_extended8/<skill>/SKILL.md`

## Force-load rules

| If selected | Also load |
|---|---|
| payment-net | auth-net, error-net |
| async-ops-net | error-net |
| realtime-net | auth-net |
| auth-net | error-net |

## /invisible commands (L3)

Read skill from `layer3-max-performance/` on invocation:
map · spec · prd · audit prod-readiness · audit security · refactor · perf · trd · design · openapi · runbook · data-model · onboarding · status · validate-rule · refresh-patterns
```

This loader is ~70 lines and ~1.0k tokens — a massive reduction from the current non-working state.

---

#### P0.3 — Register `/invisible` as a Claude Code Slash Command

The `install.sh` merges into `~/.claude/settings.json`:

```json
{
  "enabledPlugins": {
    "invisible@invisible": true
  },
  "extraKnownMarketplaces": {
    "invisible": {
      "source": { "source": "local", "path": "~/.claude/invisible-skillset" }
    }
  }
}
```

This mirrors exactly how `caveman@caveman` is registered. The frontmatter `trigger: /invisible` in `invisible-loader.md` activates the slash command.

---

### P1 — Fix: CLAUDE_TEMPLATE.md Token Reduction (9k → <500 tokens)

**Current template problems**:
- 74 lines with instructional text users never read
- Generic example rows users never delete (Sidekiq, cursor pagination for a project they don't have)
- Section G YAML with placeholder comments
- Example domain rules for a billing app

**New template** — 25 lines, ~350 tokens:

```markdown
# CLAUDE.md

## Project
- Name: 
- Stack: (e.g. Rails 7 + PostgreSQL + Sidekiq)
- Purpose: 

## Domain rules
<!-- Scoped rules INVISIBLE must follow. Format: "In <path>, never <X> because <Y>." -->

## Accepted exceptions
<!-- Format: <file-pattern>: <rule waived> — <why> — expires: yyyy-mm-dd -->

## Patterns
| Pattern | Value |
|---|---|
| Pagination | |
| Error shape | |
| Auth library | |

## Known landmines
<!-- Things that have caused bugs. INVISIBLE surfaces these when adjacent files are touched. -->

## INVISIBLE config
```yaml
invisible:
  version: 0.8.0
  telemetry: off
```
```

Users fill in 3 fields (Name, Stack, Purpose). Done. DECIDER auto-detects everything else.

---

### P1 — Fix: Single-Script Install

**Old install** — 5 manual steps, uses broken symlink pattern, fragile `shasum` command:
```bash
git clone ... ~/.claude/invisible-skillset
ln -s ...layer1-safeguards ~/.claude/skills/invisible-layer1   # BROKEN
ln -s ...layer2-advisors   ~/.claude/skills/invisible-layer2   # BROKEN  
ln -s ...layer3-max-performance ~/.claude/skills/invisible-layer3  # BROKEN
ln -s ...meta              ~/.claude/skills/invisible-meta         # BROKEN
mkdir -p ~/.claude/invisible/$(pwd | shasum | cut -c1-12)   # fails on Linux (sha1sum)
cp CLAUDE_TEMPLATE.md ./CLAUDE.md
```

**New install** — one command:
```bash
curl -fsSL https://raw.githubusercontent.com/SrinivasKanduri-Git/INVISIBLE/main/install.sh | bash
# OR, already cloned:
~/.claude/invisible-skillset/install.sh
```

**Full `install.sh`**:

```bash
#!/usr/bin/env bash
# INVISIBLE install script — idempotent, safe to re-run
set -euo pipefail

REPO="https://github.com/SrinivasKanduri-Git/INVISIBLE.git"
SKILLSET_DIR="$HOME/.claude/invisible-skillset"
SETTINGS="$HOME/.claude/settings.json"
GLOBAL_CLAUDE="$HOME/.claude/CLAUDE.md"
INVISIBLE_STATE="$HOME/.claude/invisible"
PROJECT_DIR="${1:-$(pwd)}"

echo "INVISIBLE installer"
echo "==================="

# ── Step 1: Clone or update ──────────────────────────────────────────────────
if [ -d "$SKILLSET_DIR/.git" ]; then
  echo "→ Found existing install at $SKILLSET_DIR"
  git -C "$SKILLSET_DIR" pull --quiet && echo "✓ Updated to latest"
else
  echo "→ Cloning INVISIBLE..."
  git clone --quiet "$REPO" "$SKILLSET_DIR"
  echo "✓ Cloned to $SKILLSET_DIR"
fi

# ── Step 2: Register in ~/.claude/CLAUDE.md (append, never overwrite) ────────
MARKER="<!-- invisible:loader -->"
touch "$GLOBAL_CLAUDE"
if ! grep -q "$MARKER" "$GLOBAL_CLAUDE"; then
  cat >> "$GLOBAL_CLAUDE" << BLOCK

$MARKER
## INVISIBLE
Safeguard skillset. Loaded every session. Catches silent killers before they ship.
@import $SKILLSET_DIR/meta/invisible-loader.md
<!-- /invisible:loader -->
BLOCK
  echo "✓ Registered INVISIBLE in $GLOBAL_CLAUDE"
else
  echo "→ INVISIBLE already in $GLOBAL_CLAUDE"
fi

# ── Step 3: Register /invisible slash command in settings.json ────────────────
if [ -f "$SETTINGS" ] && command -v node &>/dev/null; then
  if ! grep -q '"invisible@invisible"' "$SETTINGS"; then
    node -e "
      const fs = require('fs');
      const s = JSON.parse(fs.readFileSync('$SETTINGS', 'utf8'));
      s.enabledPlugins = s.enabledPlugins || {};
      s.enabledPlugins['invisible@invisible'] = true;
      s.extraKnownMarketplaces = s.extraKnownMarketplaces || {};
      s.extraKnownMarketplaces.invisible = {
        source: { source: 'local', path: '$SKILLSET_DIR' }
      };
      fs.writeFileSync('$SETTINGS', JSON.stringify(s, null, 2));
    "
    echo "✓ Registered /invisible command in settings.json"
  else
    echo "→ /invisible already registered"
  fi
else
  echo "⚠ Skipping settings.json (node not found or file missing)."
  echo "  Add manually: \"enabledPlugins\": { \"invisible@invisible\": true }"
fi

# ── Step 4: Create per-project state dir ──────────────────────────────────────
# Cross-platform hash (sha1sum on Linux, shasum on Mac, md5sum fallback)
PROJECT_HASH=$(printf '%s' "$PROJECT_DIR" | sha1sum 2>/dev/null | cut -c1-12 \
              || printf '%s' "$PROJECT_DIR" | shasum 2>/dev/null | cut -c1-12 \
              || printf '%s' "$PROJECT_DIR" | md5sum 2>/dev/null | cut -c1-12)
mkdir -p "$INVISIBLE_STATE/$PROJECT_HASH"
echo "✓ Project state: $INVISIBLE_STATE/$PROJECT_HASH"

# ── Step 5: Create project CLAUDE.md if missing ───────────────────────────────
if [ ! -f "$PROJECT_DIR/CLAUDE.md" ]; then
  cp "$SKILLSET_DIR/CLAUDE_TEMPLATE.md" "$PROJECT_DIR/CLAUDE.md"
  echo "✓ Created $PROJECT_DIR/CLAUDE.md"
  echo "  → Fill in: Name, Stack, Purpose (3 fields, ~2 minutes)"
else
  echo "→ $PROJECT_DIR/CLAUDE.md exists — not overwriting."
fi

# ── Done ──────────────────────────────────────────────────────────────────────
VERSION=$(cat "$SKILLSET_DIR/VERSION" 2>/dev/null || echo "unknown")
echo ""
echo "✓ INVISIBLE $VERSION installed."
echo ""
echo "Next: start a Claude Code session and ask 'Which INVISIBLE skills are active?'"
echo "L3 commands: /invisible map · /invisible spec · /invisible audit security"
```

---

### P2 — Fix: Uninstall Script

```bash
#!/usr/bin/env bash
set -euo pipefail

SKILLSET_DIR="$HOME/.claude/invisible-skillset"
SETTINGS="$HOME/.claude/settings.json"
GLOBAL_CLAUDE="$HOME/.claude/CLAUDE.md"
INVISIBLE_STATE="$HOME/.claude/invisible"

echo "INVISIBLE uninstaller"
echo "====================="

# Remove old broken symlinks (if present from old install)
for link in invisible-layer1 invisible-layer2 invisible-layer3 invisible-meta; do
  [ -L "$HOME/.claude/skills/$link" ] && rm "$HOME/.claude/skills/$link" && echo "✓ Removed symlink: $link"
done

# Remove loader block from ~/.claude/CLAUDE.md
if grep -q "<!-- invisible:loader -->" "$GLOBAL_CLAUDE" 2>/dev/null; then
  sed -i '/<!-- invisible:loader -->/,/<!-- \/invisible:loader -->/d' "$GLOBAL_CLAUDE"
  echo "✓ Removed INVISIBLE block from $GLOBAL_CLAUDE"
fi

# Remove from settings.json
if [ -f "$SETTINGS" ] && command -v node &>/dev/null; then
  if grep -q '"invisible@invisible"' "$SETTINGS"; then
    node -e "
      const fs = require('fs');
      const s = JSON.parse(fs.readFileSync('$SETTINGS', 'utf8'));
      delete (s.enabledPlugins || {})['invisible@invisible'];
      delete (s.extraKnownMarketplaces || {}).invisible;
      fs.writeFileSync('$SETTINGS', JSON.stringify(s, null, 2));
    "
    echo "✓ Removed /invisible from settings.json"
  fi
fi

read -r -p "Remove skillset at $SKILLSET_DIR? [y/N] " REMOVE
[[ "$REMOVE" =~ ^[Yy]$ ]] && rm -rf "$SKILLSET_DIR" && echo "✓ Removed $SKILLSET_DIR"

read -r -p "Remove per-project state ($INVISIBLE_STATE)? [y/N] " REMOVE
[[ "$REMOVE" =~ ^[Yy]$ ]] && rm -rf "$INVISIBLE_STATE" && echo "✓ Removed $INVISIBLE_STATE"

echo "✓ Done. Start a new Claude Code session to verify."
```

---

## Summary: File Changes Required

### New files to create

| File | Purpose | Est. size |
|---|---|---|
| `install.sh` | One-command idempotent installer | ~80 lines |
| `uninstall.sh` | Safe cleanup with prompts | ~40 lines |
| `meta/invisible-loader.md` | Actual skill entry point (replaces broken symlinks) | ~70 lines |

### Files to modify

| File | Change | Token impact |
|---|---|---|
| `CLAUDE_TEMPLATE.md` | Strip to 25 lines, remove all examples | 9k → 350 tokens |
| `INSTALL.md` | Replace manual steps with one-liner | Clarity only |
| `UNINSTALL.md` | Replace manual steps with `uninstall.sh` | Clarity only |
| `README.md §4` | Update install to one-liner | Clarity only |

### Files NOT to change

All `layer1-safeguards/*/SKILL.md`, `layer2-advisors/*/SKILL.md`, `layer3-max-performance/*/SKILL.md`, `meta/*.md` (except new loader), `DECIDER.md` — the **content** is correct and well-structured. Only the delivery mechanism is broken.

---

## Token Budget After Refactor

| Category | Before | After |
|---|---|---|
| Project `CLAUDE.md` (from template) | ~9k tokens | ~350 tokens |
| Global `~/.claude/CLAUDE.md` loader block | 0 (missing/broken) | ~200 tokens |
| `invisible-loader.md` (compact routing) | 0 (not loaded) | ~1.0k tokens |
| Per-turn L1 skills (≤4, read on demand) | 0 (not loaded) | ~840 tokens |
| **Total session overhead** | **~9k (useless boilerplate)** | **~2.4k (actually working)** |

---

## Acceptance Criteria

- [ ] `./install.sh` completes in <30 seconds with no errors
- [ ] Re-running `install.sh` is fully idempotent
- [ ] New Claude Code session shows INVISIBLE active without any user prompt
- [ ] `/invisible status` returns DECIDER state
- [ ] `/invisible audit security` runs the L3 security skill
- [ ] `~/.claude/CLAUDE.md` retains graphify + caveman registrations after install
- [ ] Project `CLAUDE.md` is created from the 25-line template (not the 74-line one)
- [ ] `./uninstall.sh` removes all INVISIBLE traces, caveman + graphify still work
- [ ] Token cost per session start is <2.5k

---

## Implementation Order for Claude Code

1. **[P0] Create `install.sh`** — foundation
2. **[P0] Create `meta/invisible-loader.md`** — actual entry point  
3. **[P1] Replace `CLAUDE_TEMPLATE.md`** — token reduction
4. **[P0] Run `./install.sh` in terminal** — fix current broken state
5. **[P2] Create `uninstall.sh`** — complete lifecycle
6. **[P2] Update `INSTALL.md`, `UNINSTALL.md`, `README.md §4`** — documentation

> [!IMPORTANT]
> Do NOT modify any SKILL.md files in the layer directories. The skill content is correct and valuable. Only the install and loading mechanism is broken.
