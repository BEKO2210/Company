# The Company

**A clone-and-run template for your own autonomous company.**

Clone this repo, run one command, and you have a company: a cloud computer where
AI agents do real work — research, content, sales, finance, support, code — for
you, the owner. Every clone is a fresh, isolated company. You are the boss; the
agents work for you.

Built on the open-source [Kortix](https://github.com/kortix-ai/suna) runtime
([OpenCode](https://github.com/anomalyco/opencode) under the hood).

---

## Quick start

```bash
git clone https://github.com/beko2210/company.git
cd company
cp .env.example .env        # then add your LLM key (see below)
./setup.sh
```

`./setup.sh` does everything: checks prerequisites, generates secrets, starts the
database, installs dependencies, builds the agent sandbox, and boots the company.

When it finishes, your company is running:

| Service     | URL                       |
|-------------|---------------------------|
| Web app     | http://localhost:3000     |
| API         | http://localhost:8008     |
| Database UI | http://localhost:54323    |

### Prerequisites

`setup.sh` checks for these and tells you what's missing — it does not install
them for you:

- **Docker** (daemon running) — runs the database and the agent sandbox
- **Node.js** v20+, **pnpm** 8.15.8, **bun** — the app runtime
- **Supabase CLI** — the local database stack
- **openssl**, **curl**

### The one thing you must provide

The agents need an AI model to think with. Open `.env` and set **one** of:

```
ANTHROPIC_API_KEY=...     # https://console.anthropic.com
OPENAI_API_KEY=...        # https://platform.openai.com
```

Everything else in `.env` has a working default for a local setup. Secrets are
generated automatically on first run.

---

## What you get

A full autonomous workforce, organized like a company:

- **~60 skills** across business functions — research, content & creative
  (docs, slides, spreadsheets, sites, logos, video, audio), sales, finance &
  accounting, legal & compliance, support, data & analysis.
- **Agents** — an orchestrator that delegates, workers that execute, each
  running in a real Linux machine (bash, filesystem, browser).
- **Channels** — give the company tasks via Slack, Telegram, CLI, or 3,000+
  integrations.
- **Triggers** — cron schedules and webhooks, so the company keeps working
  when you're not around.
- **Persistent memory** — shared context that compounds over time.

---

## Common commands

```bash
./setup.sh                 # full bootstrap (first run)
./setup.sh --skip-sandbox  # bootstrap without building the heavy sandbox image
./setup.sh --no-start      # prepare everything but don't start the servers

pnpm dev                   # start web + API
pnpm dev:core:build        # build & start the agent sandbox
pnpm nuke                  # tear down the local environment
```

To re-run setup safely at any time: `./setup.sh` is idempotent — it keeps your
`.env`, regenerates the per-service env files, and skips work already done.

## Checking that it works

Three commands, each answering a different question:

```bash
pnpm doctor                # is my machine + config set up right?  (prints fixes)
pnpm smoke                 # is the company wired up and running?
pnpm test:agents           # do the agents actually delegate and deliver?
pnpm verify:company        # (part of `pnpm smoke`) just the agent/delegation wiring
```

If something is wrong, **start with `pnpm doctor`** — for every problem it
prints the exact command to fix it.

---

## How it fits together

```
apps/web        Next.js front end — the company dashboard
apps/api        Bun/Hono back end — router, billing, platform, cron
core/           the agent sandbox runtime (Docker) + OpenCode config
packages/       shared db schema, utils, agent tunnel
supabase/       database migrations
```

`web` <-> `api` <-> `core` (agent sandbox). Auth and data run on Supabase.

---

## License

See [LICENSE](LICENSE).
