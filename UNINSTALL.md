# UNINSTALL — INVISIBLE

One command. Prompts before destructive removals. Leaves caveman + graphify intact.

## Quick uninstall

```bash
~/.claude/invisible-skillset/uninstall.sh
```

## What it does

1. Removes any legacy broken symlinks under `~/.claude/skills/invisible-*`.
2. Strips the marker-gated INVISIBLE block from `~/.claude/CLAUDE.md` (backup written alongside as `CLAUDE.md.bak.<timestamp>`).
3. Removes `invisible@invisible` from `~/.claude/settings.json` (`enabledPlugins` + `extraKnownMarketplaces`).
4. Strips `invisible@invisible` from `~/.claude/plugins/installed_plugins.json` and `known_marketplaces.json`.
5. Removes `~/.claude/plugins/cache/invisible/` and `~/.claude/plugins/marketplaces/invisible/`.
6. Prompts before deleting `~/.claude/invisible-skillset/`.
7. Prompts before deleting per-project state at `~/.claude/invisible/`.

## Disable without removing

Comment out the `@<path>` line inside the `<!-- invisible:loader -->` block in `~/.claude/CLAUDE.md`. INVISIBLE goes silent; files stay on disk.

## Verify

```bash
grep -c invisible ~/.claude/CLAUDE.md   # → 0
grep -c invisible ~/.claude/settings.json   # → 0
```

Start a new Claude Code session. No INVISIBLE references should appear.
