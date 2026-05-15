#!/usr/bin/env bash
# INVISIBLE install script — idempotent, safe to re-run.
# Usage:
#   ./install.sh                # install/update in current project
#   ./install.sh /path/to/proj  # install/update for a specific project
set -euo pipefail

REPO="https://github.com/SrinivasKanduri-Git/INVISIBLE.git"
SKILLSET_DIR="$HOME/.claude/invisible-skillset"
SETTINGS="$HOME/.claude/settings.json"
GLOBAL_CLAUDE="$HOME/.claude/CLAUDE.md"
INVISIBLE_STATE="$HOME/.claude/invisible"
PROJECT_DIR="${1:-$(pwd)}"

echo "INVISIBLE installer"
echo "==================="

# ── Step 1: Clone or update skillset ─────────────────────────────────────────
if [ -d "$SKILLSET_DIR/.git" ]; then
  echo "→ Found existing install at $SKILLSET_DIR"
  if git -C "$SKILLSET_DIR" pull --quiet 2>/dev/null; then
    echo "✓ Updated to latest"
  else
    echo "→ Skipped pull (local changes or offline)"
  fi
else
  # If we're running from inside an already-cloned copy, use it instead of re-cloning.
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  if [ -d "$SCRIPT_DIR/.git" ] && [ -f "$SCRIPT_DIR/DECIDER.md" ]; then
    echo "→ Using local copy at $SCRIPT_DIR"
    mkdir -p "$(dirname "$SKILLSET_DIR")"
    if [ ! -e "$SKILLSET_DIR" ]; then
      ln -s "$SCRIPT_DIR" "$SKILLSET_DIR"
      echo "✓ Linked $SKILLSET_DIR → $SCRIPT_DIR"
    fi
  else
    echo "→ Cloning INVISIBLE..."
    mkdir -p "$(dirname "$SKILLSET_DIR")"
    git clone --quiet "$REPO" "$SKILLSET_DIR"
    echo "✓ Cloned to $SKILLSET_DIR"
  fi
fi

# ── Step 2: Register in ~/.claude/CLAUDE.md (append-only, marker-gated) ──────
MARKER_OPEN="<!-- invisible:loader -->"
MARKER_CLOSE="<!-- /invisible:loader -->"
mkdir -p "$(dirname "$GLOBAL_CLAUDE")"
touch "$GLOBAL_CLAUDE"
if ! grep -qF "$MARKER_OPEN" "$GLOBAL_CLAUDE"; then
  cat >> "$GLOBAL_CLAUDE" << BLOCK

$MARKER_OPEN
## INVISIBLE
Safeguard skillset. Loaded every session. Catches silent killers before they ship.
@$SKILLSET_DIR/meta/invisible-loader.md
$MARKER_CLOSE
BLOCK
  echo "✓ Registered INVISIBLE block in $GLOBAL_CLAUDE"
else
  echo "→ INVISIBLE block already present in $GLOBAL_CLAUDE"
fi

# ── Step 3: Register /invisible slash command in settings.json ───────────────
if command -v node >/dev/null 2>&1; then
  mkdir -p "$(dirname "$SETTINGS")"
  [ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
  if ! grep -q '"invisible@invisible"' "$SETTINGS" 2>/dev/null; then
    SETTINGS_PATH="$SETTINGS" node <<'NODE'
const fs = require('fs');
const path = process.env.SETTINGS_PATH;
let s = {};
try { s = JSON.parse(fs.readFileSync(path, 'utf8') || '{}'); } catch (e) { s = {}; }
s.enabledPlugins = s.enabledPlugins || {};
s.enabledPlugins['invisible@invisible'] = true;
s.extraKnownMarketplaces = s.extraKnownMarketplaces || {};
s.extraKnownMarketplaces.invisible = {
  source: { source: 'github', repo: 'SrinivasKanduri-Git/INVISIBLE' }
};
fs.writeFileSync(path, JSON.stringify(s, null, 2) + '\n');
NODE
    echo "✓ Registered /invisible command in $SETTINGS"
  else
    echo "→ /invisible already registered in $SETTINGS"
  fi
else
  echo "⚠ node not found — skipping settings.json patch."
  echo "  Add manually to $SETTINGS:"
  echo '    "enabledPlugins": { "invisible@invisible": true },'
  echo '    "extraKnownMarketplaces": { "invisible": { "source": { "source": "github", "repo": "SrinivasKanduri-Git/INVISIBLE" } } }'
fi

# ── Step 4: Create per-project state dir ─────────────────────────────────────
hash_path() {
  local p="$1"
  if command -v sha1sum >/dev/null 2>&1; then
    printf '%s' "$p" | sha1sum | cut -c1-12
  elif command -v shasum >/dev/null 2>&1; then
    printf '%s' "$p" | shasum | cut -c1-12
  elif command -v md5sum >/dev/null 2>&1; then
    printf '%s' "$p" | md5sum | cut -c1-12
  else
    echo "nohashtool" >&2
    return 1
  fi
}
PROJECT_HASH=$(hash_path "$PROJECT_DIR")
mkdir -p "$INVISIBLE_STATE/$PROJECT_HASH"
echo "✓ Project state dir: $INVISIBLE_STATE/$PROJECT_HASH"

# ── Step 5: Create project CLAUDE.md if missing ──────────────────────────────
if [ ! -f "$PROJECT_DIR/CLAUDE.md" ]; then
  cp "$SKILLSET_DIR/CLAUDE_TEMPLATE.md" "$PROJECT_DIR/CLAUDE.md"
  echo "✓ Created $PROJECT_DIR/CLAUDE.md from template"
  echo "  → Fill in: Name, Stack, Purpose (3 fields)"
else
  echo "→ $PROJECT_DIR/CLAUDE.md exists — left untouched"
fi

# ── Done ────────────────────────────────────────────────────────────────────
VERSION=$(cat "$SKILLSET_DIR/VERSION" 2>/dev/null || echo "unknown")
echo ""
echo "✓ INVISIBLE $VERSION installed."
echo ""
echo "Next: start a Claude Code session and ask:"
echo "  'Which INVISIBLE skills are active?'"
echo ""
echo "L3 commands: /invisible map · /invisible spec · /invisible audit security · /invisible status"
