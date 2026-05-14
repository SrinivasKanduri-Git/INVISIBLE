---
name: test-net
description: Test discipline. Real DB for integration tests, factories not fixtures-of-fixtures, no test-prod divergence, deterministic seeds, fail-loud assertions. Coverage gates as advisor, not gate.
layer: 1
enabled_default: true
caps:
  body_lines: 300
triggers:
  keywords: [test, spec, mock, stub, fixture, factory, coverage, "test plan", CI, "test suite", "test runner"]
  libs: [rspec, minitest, jest, vitest, playwright, cypress, "pytest", "django.test", "FastAPI TestClient", supertest, mocha, exunit, "@testing-library/react", msw]
  paths: ["spec/", "test/", "tests/", "__tests__/", "*.test.ts", "*.test.tsx", "*.test.js", "*_test.go", "*_test.py", "*_spec.rb", "e2e/", "cypress/", "playwright.config.*"]
force_loads: []
---

# test-net

Test discipline. Prevents tests that "pass but prove nothing".

## Hard rules

1. **Integration tests hit a real database, not mocked ORM.** Mocked DB tests passed while prod migration failed — the canonical failure mode. Mocked-ORM integration tests → P1, suggest swap to real test DB.
2. **Tests are deterministic.** No `Date.now()` without freezer, no `Math.random()` without seed, no time-based assertions without fakeTimer. Flaky tests are bugs, not "occasionally failing tests."
3. **Each test sets up its own world.** No reliance on test order. Run-in-isolation must pass; run-in-parallel must pass.
4. **DB state isolated per test** — transactional rollback OR truncation between tests. Shared mutable state across tests → P1.
5. **No production secrets in tests.** Even read-only API keys. Use sandbox/mock-server / replay fixtures.
6. **Assertions are specific.** `expect(result).toBeTruthy()` on a complex object → P2 (assert shape). `expect(result).toMatchSnapshot()` only when shape stability is a feature, not laziness.
7. **No skipped tests merged to main without ticket reference.** `xit`, `it.skip`, `@pytest.mark.skip` → require comment with ticket URL + intended unskip date.
8. **Test names describe behavior, not implementation.** `it('redirects unauthenticated user to login')` not `it('calls checkAuth')`.

## Test type pyramid (defaults)

| Type | Target ratio | Speed budget |
|---|---|---|
| Unit | ~60% of count | <50 ms each |
| Integration (DB, API, services) | ~30% of count | <2 s each |
| E2E (browser, full stack) | ~10% of count | <30 s each |

These are guides, not gates. A test-heavy domain (payments, auth) can invert the ratio with reason noted in CLAUDE.md section B.

## What to mock vs not

| Mock | Don't mock |
|---|---|
| Time (use fake timers / freezer) | Database (use real test DB) |
| Network calls to external services (msw, vcr, polly, recorded fixtures) | ORM (use real models) |
| Randomness (seeded fake) | Internal services you own — test them directly |
| Filesystem (memfs / tmpdir) | Authorization layer — test it, don't bypass |
| Email / SMS sending (capture, assert recipient + content) | Application middleware |

## Coverage discipline

- Coverage as advisor, not gate. 100% is not a goal; 0% is a signal.
- Target: 70% line coverage on business logic, 0% requirement on glue/wiring.
- New code without any test → P2 advisor note. New code in auth/payment/data-mutation paths without any test → P1.
- Branch coverage on error paths matters more than line coverage on happy paths.

## Factory discipline

- Prefer factories (factory_bot, factory-girl, factories.factory_boy) over fixtures (static YAML/JSON).
- Each factory produces a valid-by-default entity. Caller overrides what matters for the test.
- No factory-of-factory-of-factory chains 5+ deep — extract a builder helper.

## Anti-patterns

- **Mirror tests**: test asserts the implementation literally (`expect(fn).toHaveBeenCalledWith(...)` for every internal call). Brittle, no behavior coverage.
- **Test the framework**: testing that `useState` updates state. Not a thing.
- **Sleep-based timing**: `setTimeout(..., 1000)` in tests. Use waitFor / polling primitives instead.
- **Conditional assertions**: `if (x) expect(...)`. Either path matters or test is wrong.
- **Disabled assertions left in**: `// expect(...)`. Either delete or fix.

## E2E hygiene

- Stable selectors: `data-testid` over class/text content.
- Page object pattern for ≥5 e2e tests against same page.
- Run against a known seed state — never against shared dev DB.
- Retries: at most 1 retry; flaky test = bug, fix the test or fix the bug.
- Parallel execution requires test isolation — sharded by suite, each shard owns its DB schema.

## CI integration

- Test runner exits non-zero on failure (default — but verify in pipeline).
- Coverage uploaded to CI summary, not gated unless project opted in.
- Slow-test report surfaced (any test >budget → P3 advisor).
- Flake-tracker: same test failing intermittently → auto-tag for investigation.

## What scanner flags

Runs on output touching test files OR any output adding production code without corresponding test.

- New endpoint / controller action / domain service without a corresponding test file → P2 (P1 if auth/payment/data-mutation).
- `it.only` / `fit` / `describe.only` / `pytest.mark.focus` left in committed code → P1.
- `xit` / `it.skip` without comment + ticket → P2.
- `expect(...).toBe(true)` on result of `> 0` (loose) → P3 (assert specific value).
- `jest.mock('@/lib/db')` or equivalent — mocking own data layer → P2.
- `setTimeout(...)` in a test body → P2 (use waitFor).
- Production secrets / hardcoded API keys in test fixtures → P1.
- Tests using `process.env.PRODUCTION_*` → P1.

## Stack overrides

### Rails (RSpec)
- `Rails.application.load_tasks` only in tasks tests, not unit.
- `let!` only when forced eager evaluation needed; prefer `let` lazy.
- `DatabaseCleaner` with `:transaction` strategy for unit, `:truncation` for system specs.
- `Capybara.default_max_wait_time` reasonable (≤5s).

### Jest / Vitest
- `beforeEach(resetMocks)` if `jest.mock` used heavily.
- No `jest.useFakeTimers()` in `setup` without `useRealTimers()` after.
- Snapshot tests only on stable outputs (UI components, serialized API responses); never on objects with dates / ids.

### Pytest
- Fixtures with `scope='function'` by default. `scope='session'` only for heavy expensive setups (test DB, browser).
- `@pytest.mark.parametrize` for combinatorics; not 10 near-identical test functions.
- `conftest.py` per directory level; not one mega-conftest.

### Playwright / Cypress
- `test.beforeEach(async ({ page }) => await page.goto('/'))` only when every test starts there.
- Network stubs via `page.route` / `cy.intercept`; not via app-level mocks.
- Visual regression: opt-in per test, not suite-wide.

### Phoenix / ExUnit
- `Phoenix.ConnTest` for controller; `Phoenix.ChannelTest` for channels.
- `Ecto.Adapters.SQL.Sandbox` for DB isolation.

## Force-load relationships

test-net does not force-load. Other skills don't force-load test-net — it loads via its own signals.

## CLAUDE.md hooks

Reads section A: `test_libs`, `coverage_target`.
Reads section B: skipped-test policy, e2e environment URL.

## Related

[[api-net]] · [[db-net]] · [[auth-net]] · [[code-scanner]] · [[env-net]]
