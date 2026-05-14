---
name: i18n-net
description: Internationalization safeguards. Covers locale resolution, message catalogs (ICU MessageFormat), pluralization, RTL layout, date/number/currency formatting per locale, timezone handling, and CLDR-correct fallbacks. Narrow trigger — loads only when i18n signals present.
layer: 1
enabled_default: true
caps:
  body_lines: 300
triggers:
  keywords: ["i18n", "internationalization", "localization", "l10n", "translation", "translate", "locale", "language", "multilingual", "RTL", "right-to-left", "Arabic", "Hebrew", "Persian", "Urdu", "CJK", "Chinese", "Japanese", "Korean", "ICU", "MessageFormat", "pluralization", "CLDR", "timezone", "DateTimeFormat", "Intl"]
  libs: ["i18next", "react-intl", "formatjs", "@lingui/core", "vue-i18n", "next-intl", "next-i18next", "rails-i18n", "i18n-tasks", "django.utils.translation", "gettext", "babel", "fluent", "polyglot"]
  paths: ["locales/", "i18n/", "translations/", "messages/", "lang/", "config/locales/", "po/", ".po", "*.pot", "*.arb"]
force_loads: []
---

# i18n-net

Internationalization safety net. Loaded only when i18n signals are present (project has locales/, message catalogs, RTL/language keywords). Most apps starting in English add this when expanding — getting the foundation wrong is expensive to retrofit.

## Hard rules

1. **No hardcoded user-visible strings** in feature code. Every UI string goes through the i18n function (`t('...')`, `__('...')`, etc.). Mixed-mode (some strings translated, some hardcoded) is the most common failure.
2. **Keys are stable identifiers, not English.** Use `checkout.button.submit`, not `Submit Order`. English text changes; keys shouldn't.
3. **Locale resolved server-side** (when SSR) AND client-side, with documented precedence: query param → user preference → cookie → `Accept-Language` → default. Don't let them disagree.
4. **All user-generated content has a locale tag** if multi-locale (post.locale, comment.locale). Required for proper search, display direction, language-detection skip.
5. **Plural forms use ICU MessageFormat / CLDR plural categories** — not `count === 1 ? 'item' : 'items'`. Many languages have 3+ plural forms (Russian, Arabic, Polish).
6. **Dates / numbers / currency use `Intl.*` (or stack equivalent)** — never `toLocaleString()` without explicit locale, never custom formatters that bake in en-US assumptions.
7. **Timezones stored in UTC**, rendered in user TZ. User TZ is per-user setting + per-request override. Naive datetimes in DB → P1.
8. **RTL handled at the layout level**, not per-component. `dir="rtl"` on `<html>` or framework primitive; CSS logical properties (`margin-inline-start`, not `margin-left`).
9. **Locale fallback chain explicit**: `pt-BR` → `pt` → `en`. Missing key falls through chain. Missing in fallback → dev surfaces error, prod logs + shows key OR friendly placeholder (project policy).
10. **Translator context provided** for ambiguous strings — `"Edit"` as button vs `"Edit"` as page title need different keys / descriptions. Most catalogs support comment fields.
11. **Variable interpolation uses named placeholders**, not positional `%s`. Translators rearrange word order: `"Welcome, {name}!"` not `"Welcome, %s!"`.
12. **Pseudo-localization in CI** — auto-expand strings (`[!!! Submitt !!! ]`) to catch overflow + concatenation bugs before user-facing locales added.

## Locale code conventions

- Use **BCP 47** tags: `en`, `en-US`, `pt-BR`, `zh-Hans`, `zh-Hant`. Not `en_US` mixed with `en-US`.
- Persist as a single canonical form across DB / cookie / URL. Pick `xx-XX` (hyphen) for web; convert at adapter boundary if a tool uses underscore (`xx_XX`).
- `und` (undetermined) for content with unknown language.

## Locale-resolution precedence (default)

1. Explicit override (`?lang=pt-BR` query — for testing / shareable links)
2. Authenticated user's preference (`user.locale`)
3. Cookie / session (`locale=...`)
4. `Accept-Language` header (parse + match against supported set)
5. Geo-IP heuristic (last resort, often wrong — only suggest, don't force)
6. Default locale

Resolved locale persisted on first decision; subsequent requests don't redo geo.

## Message catalog shape

### ICU MessageFormat (recommended)

```json
{
  "checkout.items": "{count, plural, one {# item} other {# items}} in your cart",
  "user.greeting": "Hello, {name}!",
  "order.shippedDate": "Shipped {date, date, long}"
}
```

Plural categories per CLDR: `zero`, `one`, `two`, `few`, `many`, `other`. Not all languages use all categories — translator decides per locale.

### Avoid

```js
// concatenation across translation boundary
t('greeting') + ' ' + name + '!'   // breaks in languages where greeting is "Foo {name}!"

// ternary plural
count === 1 ? t('item') : t('items')  // wrong in Russian, Arabic, Polish

// English in keys leaking to UI
t('Click here to continue')   // change "Click" → key changes → all translations stale
```

## RTL discipline

- `<html dir="rtl" lang="ar">` for Arabic, Hebrew, Persian, Urdu.
- CSS: use **logical properties** (`margin-inline-start`, `padding-inline-end`, `border-inline-start`). Avoid `margin-left`, `padding-right` for layout flow.
- Flex / grid mostly fine — they mirror automatically with `dir="rtl"`.
- Icons: directional icons (arrows, back/forward) must mirror. Text-aligned icons stay.
- Don't mirror logos, brand marks, embedded code, charts.
- Test in RTL early — retrofitting is painful.

## Date / number / currency

### Use `Intl` (browser, Node ≥18, Deno) or stack equivalent

```js
new Intl.DateTimeFormat('pt-BR', { dateStyle: 'long' }).format(new Date());
new Intl.NumberFormat('de-DE').format(1234567.89);   // 1.234.567,89
new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR' }).format(1234567);
new Intl.RelativeTimeFormat('fr', { numeric: 'auto' }).format(-1, 'day');  // "hier"
```

### Pitfalls

- `Date.toLocaleDateString()` without locale arg — uses runtime locale, not user's.
- Custom `MM/DD/YYYY` — only works for US; rest of world is `DD/MM` or `YYYY-MM-DD`.
- Currency formatting from a translation string (`"$ {amount}"`) — currency symbol position varies; use `Intl.NumberFormat` with `currency`.
- `toFixed(2)` for currency — ignores locale grouping (`.` vs `,`) and rounds in wrong direction for some currencies.
- Sorting strings with `[].sort()` — uses code-point order; collation differs by locale. Use `Intl.Collator`.

## Timezone

- DB stores `TIMESTAMP WITH TIME ZONE` or UTC `TIMESTAMP`. Naive `TIMESTAMP` in multi-region app → P1.
- Server logic uses UTC; presentation layer converts.
- User's TZ from profile (preferred) OR browser (`Intl.DateTimeFormat().resolvedOptions().timeZone`).
- DST transitions: scheduled jobs at `2:30am` local time on DST-transition day either run twice or skip. Choose UTC-anchored cron unless business requires local.
- Recurring events (calendar invites) need TZ identifier (`America/New_York`), not offset — offset changes with DST.

## Translation workflow

1. Source language = development language (usually English). Catalog generated from code.
2. CI extracts new keys → translation service (Crowdin, Lokalise, Phrase, custom).
3. Translations merged back. Missing translations: fall through chain, log + dashboard.
4. PR cannot merge with un-extracted keys (CI gate via `i18next-extract`, `i18n-tasks check`, etc.).
5. Pseudo-locale in CI build for layout sanity.

## Search + content concerns

- Full-text search: per-language analyzer (Postgres `tsvector` with `'simple'` vs `'english'` vs `'arabic'`, ES analyzers).
- Mixed-language content: store + index per locale; `und` falls back to `simple` analyzer.
- Slugs: transliterate non-ASCII (`Привет` → `privet`) OR keep Unicode and URL-encode — pick one consistently.

## Accessibility intersection

- `lang` attribute on root + on language-mixed inline elements (`<span lang="ja">こんにちは</span>`).
- Screen readers switch voices on `lang` change. Critical for multilingual readers.
- Locale-aware label/aria-label translations.

## What scanner flags

Runs on output in feature code OR using i18n / locale / translation / Intl keywords.

- String literal in JSX / template that looks user-facing and is not wrapped in `t(...)` → P2 (project policy may override).
- `Date.now().toLocaleDateString()` without locale → P2.
- `count === 1 ? 'item' : 'items'` ternary plural → P2.
- Hardcoded currency symbol concatenation (`'$' + amount`) → P2.
- `margin-left: ...` / `padding-right: ...` in a project using `dir="rtl"` somewhere → P3 (logical property suggestion).
- `new Date(...)` stored without TZ awareness in multi-region project → P1.
- `Accept-Language` parsed manually instead of using a library → P3.
- Translation key looks like prose (`t("Submit your order")`) → P3 (stable-id refactor suggestion).

## Stack overrides

### Next.js (next-intl / next-i18next)
- App Router: route-level `[locale]` segment; `useTranslations()` server + client.
- Locale-aware `<Link>` (auto-prefixes).
- Middleware resolves locale before page render.

### Rails (rails-i18n)
- `config.i18n.available_locales = [...]`; `config.i18n.fallbacks = true`.
- `t('.button')` (lazy lookup, scoped to template).
- `Time.zone` for timezone-aware times; `Time.current` not `Time.now`.

### Django
- `USE_I18N = True`, `USE_TZ = True`.
- `LocaleMiddleware` for resolution.
- `{% trans "..." %}` / `gettext()` — keep English strings, marker-based extraction (Django convention).
- `django.utils.timezone.now()` not `datetime.now()`.

### FormatJS / react-intl
- `<FormattedMessage id="checkout.button" defaultMessage="..." />`.
- ICU MessageFormat by default.
- `babel-plugin-formatjs` extracts at build.

### Vue
- `vue-i18n` with `$t('...')` / `useI18n()`.
- Locale messages in `locales/*.json` or `.yml`.

## Cross-skill collaborations

- Locale stored on user → [[auth-net]] (user model field).
- Locale-aware emails → [[async-ops-net]] (template per locale, fall through chain).
- Multi-language search → [[db-net]] (per-locale index strategy).
- Locale resolved in URL prefix → [[api-net]] (route shape).
- RTL CSS → [[ui-net]] (logical properties).

## CLAUDE.md hooks

Reads section A: `default_locale`, `supported_locales`, `i18n_lib`, `rtl_required`, `timezone_storage`.
Reads section B: project rules (e.g., "all emails localized to user.locale", "no transliterated slugs").
Reads section C: accepted exceptions (e.g., "admin UI English-only").

## Related

[[ui-net]] · [[api-net]] · [[db-net]] · [[auth-net]] · [[async-ops-net]] · [[env-net]] · [[code-scanner]]
