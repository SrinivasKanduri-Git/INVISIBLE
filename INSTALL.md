# INSTALL — INVISIBLE

3 steps. ~2 minutes. No network calls required.

## 1. Get the skillset

Clone or download:

```bash
git clone https://github.com/SrinivasKanduri-Git/INVISIBLE.git ~/.claude/invisible-skillset
```

Then symlink each layer into your agent's skill directory:

```bash
ln -s ~/.claude/invisible-skillset/layer1-safeguards      ~/.claude/skills/invisible-layer1
ln -s ~/.claude/invisible-skillset/layer2-advisors        ~/.claude/skills/invisible-layer2
ln -s ~/.claude/invisible-skillset/layer3-max-performance ~/.claude/skills/invisible-layer3
ln -s ~/.claude/invisible-skillset/meta                   ~/.claude/skills/invisible-meta
```

(Other agents: place under the agent's skill-discovery path. INVISIBLE's loader is filesystem-driven; no plugin manifest needed.)

(Other agents: place under the agent's skill-discovery path. INVISIBLE's loader is filesystem-driven; no plugin manifest needed.)

## 2. Initialize project state

From inside your project root:

```bash
mkdir -p ~/.claude/invisible/$(pwd | shasum | cut -c1-12)
cp ~/.claude/invisible-skillset/CLAUDE_TEMPLATE.md ./CLAUDE.md
```

Edit `CLAUDE.md` sections A–F. Stack will auto-detect on first turn via [[stack-adapter]].

## 3. Verify

Start a Claude Code session in the project. Ask:

> What INVISIBLE skills are loaded right now?

Expected reply lists DECIDER decisions for the (empty) turn — typically `[]` with `considered: []` and a stack-adapter note.

If you see "DECIDER not found" — step 1 path is wrong.
If you see "CLAUDE.md missing sections" — re-run step 2.

## Telemetry

Off by default. INVISIBLE will ask once on first turn whether to enable anonymous trip/miss telemetry. Decline is fine; circuit-breaker still works locally.

## Uninstall

See [UNINSTALL.md](./UNINSTALL.md).
