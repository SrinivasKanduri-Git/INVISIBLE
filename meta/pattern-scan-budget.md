# meta/pattern-scan-budget.md

Hard-bounds the pre-existing pattern scan. Closes the v4 audit gap. ≤1k tokens per turn.

## Scope (hard-bounded)

Pattern scan reads ONLY:

1. Files explicitly referenced in current turn (user pasted, mentioned by path, attached).
2. Files already in agent's context from prior turns.
3. CLAUDE.md sections D (established patterns) and C (accepted exceptions).
4. `~/.claude/invisible/<hash>/discovered-patterns.json` cache.

**Never scanned**: entire codebase, repo-wide globs, sibling directories, files not in context.

## Token budget

- **≤1k tokens / turn** allocated.
- Order of consumption: cache (free, ~50 tokens) → CLAUDE.md sections D+C → in-context files → in-scope files mentioned this turn.
- If candidate files exceed budget → scan top-N by relevance, log: `"skipped scan: budget"`.

## Pattern cache (`discovered-patterns.json`)

Built incrementally. Once a pattern is in cache, no re-scan needed.

```json
{
  "schema_version": 1,
  "patterns": {
    "pagination_style": {"value": "cursor", "discovered_at": "turn_3", "confidence": 0.9},
    "error_response_shape": {"value": "{code, message, request_id}", "discovered_at": "turn_5", "confidence": 0.95},
    "form_validation_lib": {"value": "react-hook-form + zod", "discovered_at": "turn_7", "confidence": 0.8},
    "auth_pattern": {"value": "scoped query in model layer", "discovered_at": "turn_12", "confidence": 0.7},
    "cache_scope": {"value": "tenant-keyed", "discovered_at": "turn_14", "confidence": 0.85}
  },
  "ttl_days": 30
}
```

## Invalidation

- TTL: 30 days. After TTL, the pattern is re-validated on next match.
- Manual: `/invisible refresh-patterns` clears the cache.
- Self-learner contradiction: if a user correction conflicts with cached pattern → cache entry's confidence drops; ≤0.3 → evict.

## Budget enforcement (user-visible)

If a scan was truncated this turn, agent emits one inline note (not an advisor note — agent's own voice):

> *"I didn't scan the whole codebase — only the files in scope. If you've established patterns I don't know yet, drop a hint in CLAUDE.md section D."*

Honest, not silent. Never says "fully analyzed codebase" when it wasn't.

## What "in-scope file" means precisely

A file is **in-scope** if any of:
- Path appears literally in user's current message.
- File was attached/dropped this turn.
- File was edited/read in current session's prior turns (already in agent context).
- File is on a small whitelist auto-added by stack-adapter (e.g., `package.json` for Next.js — small, high-info).

Globs (`src/**/*.ts`) are NEVER in-scope. Directory references (`look in src/`) are NEVER in-scope. Repo-wide search is out of scope; agent must say so.

## Failure modes

- Cache file corrupt → [[corruption-handler]] quarantines, scan proceeds without cache (budget still applies).
- Budget overrun in 3 consecutive turns → [[circuit-breaker]] enters `degraded` (likely sign of scope confusion).

## Related

[[DECIDER]] · [[self-learner]] · [[corruption-handler]] · [[circuit-breaker]]
