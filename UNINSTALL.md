# UNINSTALL — INVISIBLE

Clean removal. No residual state, no agent breakage.

## 1. Remove the skillset

```bash
rm -rf ~/.claude/skills/invisible
```

## 2. Remove per-project state (optional)

Each project has its own state dir under `~/.claude/invisible/<project-hash>/`. Remove all:

```bash
rm -rf ~/.claude/invisible
```

If you want to keep learned patterns / accepted exceptions for re-install later, skip this step.

## 3. Restore project CLAUDE.md (optional)

If your project's `CLAUDE.md` was generated from INVISIBLE's template, you can leave sections A–F (they're plain markdown — useful even without INVISIBLE). Section G (`invisible:` block) is dead config — delete it.

## 4. Verify

```bash
ls ~/.claude/skills/invisible 2>&1
# expected: No such file or directory
```

Start a new Claude session. No INVISIBLE references should appear in any turn.

## Disable without removing

Edit `CLAUDE.md` section E:

```yaml
invisible:
  enabled: false
```

This keeps the files but skips all loading.
