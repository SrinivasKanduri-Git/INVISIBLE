# meta/stack-adapter.md

Injects stack-specific signals into [[DECIDER]] scoring and stack-specific defaults into L1 skills. 6 stacks pre-filled. Add via `/invisible stack add`.

## Detection

First turn per project: scan for manifest files (cheap, no AST). Cache result in `~/.claude/invisible/<hash>/stack.json`.

| Manifest | Stack |
|---|---|
| `Gemfile` + `config/application.rb` | Rails |
| `manage.py` + `requirements.txt`/`pyproject.toml` w/ Django | Django |
| `next.config.{js,mjs,ts}` | Next.js |
| `pyproject.toml` w/ `fastapi` dep | FastAPI |
| `package.json` w/ `express` dep | Express |
| `mix.exs` | Phoenix |

Override via `CLAUDE.md` section A.

## Stack blocks (pre-filled)

### Rails

```yaml
stack: rails
db_default: postgres
orm: activerecord
job_default: sidekiq
auth_libs: [devise, sorcery, authlogic]
test_libs: [rspec, minitest]
signal_boost:
  db-net: [ActiveRecord, ActiveRecord::Migration, "rails generate model", "db/migrate"]
  async-ops-net: [Sidekiq, ActiveJob, "perform_async", "perform_later"]
  realtime-net: [ActionCable, "broadcast_to"]
defaults:
  pagination: kaminari
  error_envelope: "render json: {code:, message:}, status: ..."
file_caps:
  models: 300_loc_advise
  controllers: 200_loc_advise
```

### Django

```yaml
stack: django
db_default: postgres
orm: django_orm
job_default: celery
auth_libs: [django.contrib.auth, django-allauth]
test_libs: [pytest-django, django.test]
signal_boost:
  db-net: ["models.Model", "migrations.RunPython", "manage.py makemigrations"]
  async-ops-net: [Celery, "shared_task", "delay()"]
defaults:
  pagination: cursor (drf-cursor-pagination)
  error_envelope: "DRF default: {detail: ...}"
```

### Next.js

```yaml
stack: nextjs
db_default: postgres
orm: prisma
job_default: bullmq
auth_libs: [next-auth, clerk, lucia]
test_libs: [vitest, jest, playwright]
signal_boost:
  ui-net: [".tsx", "app/", "page.tsx", "layout.tsx", "use client"]
  api-net: ["app/api/", "route.ts", "Server Action"]
  db-net: ["prisma.schema", "prisma migrate"]
defaults:
  forms: react-hook-form + zod
  data_fetching: server-components-first
```

### FastAPI

```yaml
stack: fastapi
db_default: postgres
orm: sqlalchemy
job_default: celery / arq
auth_libs: [fastapi-users, authlib]
test_libs: [pytest, httpx]
signal_boost:
  api-net: ["@router.get", "@router.post", "APIRouter", "Depends"]
  db-net: ["Base.metadata", "alembic upgrade"]
defaults:
  validation: pydantic
  error_envelope: "{detail: ...}"
```

### Express

```yaml
stack: express
db_default: postgres
orm: prisma / typeorm / knex
job_default: bullmq
auth_libs: [passport, express-session, jsonwebtoken]
test_libs: [jest, mocha, supertest]
signal_boost:
  api-net: ["app.get", "app.post", "router.use", "express.Router"]
defaults:
  error_handler: "central middleware required (auth-net force-load)"
```

### Phoenix

```yaml
stack: phoenix
db_default: postgres
orm: ecto
job_default: oban
auth_libs: [phoenix_gen_auth, pow]
test_libs: [exunit]
signal_boost:
  db-net: [Ecto.Schema, "mix ecto.migrate"]
  realtime-net: [Phoenix.Channel, "Phoenix.PubSub"]
  async-ops-net: [Oban, "Oban.Worker"]
defaults:
  pagination: scrivener
```

## How L1 skills consume this

Each L1 SKILL.md has a `stack_overrides:` section. Stack-adapter merges its block into the active skill's runtime context. Example: auth-net loads `devise`-specific rules on Rails, `next-auth`-specific rules on Next.js — same skill, different active rule set.

## Unknown stack

Falls back to language-only detection (just JS / Python / Ruby / Elixir / Go signals). Emits P2 advisor note:

> *"Stack not in adapter library. INVISIBLE running in language-only mode. Add a block via `/invisible stack add` for better routing."*

## CLI

- `/invisible stack show` — current detection
- `/invisible stack override <name>` — force a stack
- `/invisible stack add` — interactive wizard for new stack block

## Related

[[DECIDER]] · [[pattern-scan-budget]] · [[recommender]]
