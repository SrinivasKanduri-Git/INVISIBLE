---
name: ui-net
description: Frontend safeguards. Loads on UI/component/form/page work. Catches missing a11y, missing loading/error states, unbounded lists, uncontrolled inputs, inline-handler leaks, key-prop bugs.
layer: 1
enabled_default: true
caps:
  body_lines: 300
triggers:
  keywords: [page, component, button, form, modal, table, design, dropdown, dialog, sidebar, header, footer, layout]
  libs: [react, vue, svelte, solid, tailwind, "@chakra-ui", "@mui/material", "shadcn"]
  paths: ["*.tsx", "*.jsx", "*.vue", "*.svelte", "components/", "pages/", "app/"]
  assets: [screenshot, mockup_image]
force_loads: []
---

# ui-net

Frontend safety net. Catches what a vibe-coded UI ships without.

## Hard rules (never violate)

1. **Every async UI op needs a visible loading + error state.** A spinner-less `fetch()` in a component is a bug, not an oversight.
2. **No unbounded list renders.** Lists ≥50 items must virtualize OR paginate. Hardcoded `<ul>` over `data` is rejected at scanner.
3. **No uncontrolled inputs in forms that submit data.** Use refs only for focus/scroll, never for value collection.
4. **`key` prop on every iterated element.** Never `key={index}` on a list whose order can change.
5. **Every form has client + server validation.** Client UX, server truth. Skipping server-side is rejected.
6. **No secrets, tokens, or user PII in client-bundled code.** Includes `.env.NEXT_PUBLIC_*` containing secrets, hardcoded API keys, debug `console.log(user)`.
7. **A11y minimums**: every `<button>` has accessible label; every form input has associated `<label>`; every image has `alt` (decorative = `alt=""`, explicit).

## Defaults (override per-project in CLAUDE.md section B)

| Concern | Default |
|---|---|
| Form lib | react-hook-form + zod (Next.js / React) / VeeValidate (Vue) |
| State for forms | Controlled inputs, form lib owns state |
| Data fetching | Server components / SSR when stack supports (Next.js app router, Remix loaders) |
| Loading skeletons | Required for any fetch >300ms expected p50 |
| Error boundaries | One per route, plus one per data-island |
| Accessibility lib | `@axe-core/react` in dev mode, fails CI on new violations |

## What scanner flags

Code-scanner runs on output ≥30 LOC OR any `.tsx/.jsx/.vue/.svelte` change. Flags:

- `fetch(...).then(...)` without surrounding `try/catch` or error state.
- `useState(...)` for form data when form lib is configured (use form lib instead).
- `.map(item => ...)` without `key`, or `key={index}` on reorderable list.
- Inline event handlers creating new functions every render on memoized children → P3.
- `<button>` with no text + no `aria-label`.
- `<img>` with no `alt` attribute (not `alt=""`).
- `dangerouslySetInnerHTML` without explicit sanitizer call → P1.

## Stack overrides

### Next.js
- Default to server components. Client components require `'use client'` and explicit reason.
- Forms via Server Actions when no client-side interactivity needed.
- Data fetching: `fetch()` in server components with cache strategy explicit (`{ cache: 'force-cache' | 'no-store' | { revalidate: N } }`).

### Vue 3 / Nuxt
- Composition API preferred over Options for new code.
- `<script setup>` only.
- Pinia for cross-component state.

### React (vanilla / Vite)
- React Query / TanStack Query for server state; not raw useEffect+fetch.
- Suspense boundaries scoped — not one giant root boundary.

## Force-load relationships

ui-net itself does not force any skill, but is force-loaded by realtime-net when WS-driven UI is in scope (live update components need ui-net's loading-state rules).

## Anti-patterns specific to AI agents

These are mistakes Claude/GPT/Gemini make in fresh codebases, listed because we keep seeing them:

- Generating a "complete" form with no validation library, then a separate file with hand-rolled validation that duplicates the form schema.
- `useEffect(() => { fetch(...) }, [])` instead of the project's data-fetching library.
- One mega-component (500+ lines) with form + table + modal in one file.
- "Stub" components left as `<div>TODO</div>` and never returned to.

When detected, code-scanner emits P2 with a one-line refactor suggestion.

## CLAUDE.md hooks

ui-net reads from CLAUDE.md section D for:
- `form_validation_lib`
- `data_fetching` (e.g., "server-components-first")
- `pagination`
- `component_library`

If sections D is empty for these, ui-net asks once per session.

## Related

[[api-net]] · [[auth-net]] · [[error-net]] · [[code-scanner]]
