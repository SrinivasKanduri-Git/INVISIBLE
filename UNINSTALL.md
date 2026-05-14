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
4. Prompts before deleting `~/.claude/invisible-skillset/`.
5. Prompts before deleting per-project state at `~/.claude/invisible/`.

## Disable without removing

Comment out the `@import` line inside the `<!-- invisible:loader -->` block in `~/.claude/CLAUDE.md`. INVISIBLE goes silent; files stay on disk.

## Verify

```bash
grep -c invisible ~/.claude/CLAUDE.md   # → 0
grep -c invisible ~/.claude/settings.json   # → 0
```

Start a new Claude Code session. No INVISIBLE references should appear.
