# INSTALL — INVISIBLE

One command. Idempotent. Safe to re-run.

## Quick install

```bash
curl -fsSL https://raw.githubusercontent.com/SrinivasKanduri-Git/INVISIBLE/main/install.sh | bash
```

Or, if already cloned somewhere:

```bash
./install.sh                       # current dir = project to register
./install.sh /path/to/your-project # specify project dir
```

## What it does

1. Clones (or updates) the skillset to `~/.claude/invisible-skillset/`.
2. Appends a marker-gated INVISIBLE loader block to `~/.claude/CLAUDE.md` using the `@<path>` memory-import form — **never overwrites** existing content. Coexists with caveman, graphify, etc.
3. Registers `invisible@invisible` in `~/.claude/settings.json` (`enabledPlugins` + `extraKnownMarketplaces`).
4. Creates per-project state dir at `~/.claude/invisible/<project-hash>/` (12-char sha1/shasum/md5 fallback).
5. Copies `CLAUDE_TEMPLATE.md` to `<project>/CLAUDE.md` only if missing.

## One-time plugin install inside Claude Code

After the bash script, install the plugin from inside Claude Code (the script alone cannot trigger plugin discovery):

```
/plugin marketplace add SrinivasKanduri-Git/INVISIBLE
/plugin install invisible@invisible
/reload-plugins
```

Confirm `/invisible:invisible` and `/invisible:init` appear when you type `/`.

## Verify

Start a new Claude Code session in the project. Ask:

> Which INVISIBLE skills are active?

Expected: DECIDER state for the (empty) turn — typically `[]` with a stack-adapter note. `/invisible:invisible status` returns the same.

## Project CLAUDE.md

After install, fill in 3 fields in `<project>/CLAUDE.md`: **Name**, **Stack**, **Purpose**. Domain rules, exceptions, patterns, and landmines fill in over time from corrections.

## Requirements

- `bash`, `git`
- `node` (used to JSON-patch `settings.json` — script falls back to manual instructions if absent)
- One of `sha1sum` / `shasum` / `md5sum` (auto-detected per OS)

## Telemetry

Off by default. Circuit-breaker still works locally.

## Uninstall

```bash
./uninstall.sh
```

See [UNINSTALL.md](./UNINSTALL.md).
