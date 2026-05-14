#!/usr/bin/env bash
# INVISIBLE uninstall — safe, prompts before destructive removals.
set -euo pipefail

SKILLSET_DIR="$HOME/.claude/invisible-skillset"
SETTINGS="$HOME/.claude/settings.json"
GLOBAL_CLAUDE="$HOME/.claude/CLAUDE.md"
INVISIBLE_STATE="$HOME/.claude/invisible"

echo "INVISIBLE uninstaller"
echo "====================="

# ── Remove old broken symlinks (legacy install layout) ──────────────────────
for link in invisible-layer1 invisible-layer2 invisible-layer3 invisible-meta; do
  if [ -L "$HOME/.claude/skills/$link" ]; then
    rm "$HOME/.claude/skills/$link" && echo "✓ Removed legacy symlink: $link"
  fi
done

# ── Strip loader block from ~/.claude/CLAUDE.md ─────────────────────────────
if [ -f "$GLOBAL_CLAUDE" ] && grep -q "<!-- invisible:loader -->" "$GLOBAL_CLAUDE" 2>/dev/null; then
  BACKUP="${GLOBAL_CLAUDE}.bak.$(date +%Y%m%d-%H%M%S)"
  cp "$GLOBAL_CLAUDE" "$BACKUP"
  # Portable sed: write to temp, then move (works on GNU + BSD sed without -i differences).
  awk '
    /<!-- invisible:loader -->/ { skip=1; next }
    /<!-- \/invisible:loader -->/ { skip=0; next }
    skip != 1 { print }
  ' "$GLOBAL_CLAUDE" > "${GLOBAL_CLAUDE}.tmp"
  mv "${GLOBAL_CLAUDE}.tmp" "$GLOBAL_CLAUDE"
  echo "✓ Removed INVISIBLE block from $GLOBAL_CLAUDE (backup: $BACKUP)"
fi

# ── Remove from settings.json ───────────────────────────────────────────────
if [ -f "$SETTINGS" ] && command -v node >/dev/null 2>&1; then
  if grep -q '"invisible@invisible"' "$SETTINGS"; then
    SETTINGS_PATH="$SETTINGS" node <<'NODE'
const fs = require('fs');
const path = process.env.SETTINGS_PATH;
let s = {};
try { s = JSON.parse(fs.readFileSync(path, 'utf8') || '{}'); } catch (e) { s = {}; }
if (s.enabledPlugins) delete s.enabledPlugins['invisible@invisible'];
if (s.extraKnownMarketplaces) delete s.extraKnownMarketplaces.invisible;
fs.writeFileSync(path, JSON.stringify(s, null, 2) + '\n');
NODE
    echo "✓ Removed /invisible from $SETTINGS"
  fi
fi

# ── Optional: remove skillset dir/symlink ───────────────────────────────────
if [ -e "$SKILLSET_DIR" ]; then
  read -r -p "Remove skillset at $SKILLSET_DIR? [y/N] " REMOVE
  if [[ "$REMOVE" =~ ^[Yy]$ ]]; then
    rm -rf "$SKILLSET_DIR"
    echo "✓ Removed $SKILLSET_DIR"
  fi
fi

# ── Optional: remove per-project state ──────────────────────────────────────
if [ -d "$INVISIBLE_STATE" ]; then
  read -r -p "Remove per-project state ($INVISIBLE_STATE)? [y/N] " REMOVE
  if [[ "$REMOVE" =~ ^[Yy]$ ]]; then
    rm -rf "$INVISIBLE_STATE"
    echo "✓ Removed $INVISIBLE_STATE"
  fi
fi

echo ""
echo "✓ Done. Start a new Claude Code session to verify INVISIBLE is gone."
echo "  (caveman + graphify registrations preserved.)"
