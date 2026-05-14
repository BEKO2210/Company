# Roadmap — The Company

Goal: a reusable template where **every clone becomes a working company** that
works for its owner. Guiding rule: **nothing breaks** — each phase leaves the
product working, and from Phase 1 on, a smoke test must pass before any change
is called done.

---

## Phase 0 — Solid foundation *(no new features, just remove the traps)*

- [x] Fix Supabase port mismatch (`apps/api/.env.example` used `64321/64322`
      while the rest of the stack uses `54321/54322` — the API could point at a
      dead database).
- [x] Stop shipping another machine's state in the template (`test-results/`
      was committed on import; now untracked and gitignored).
- [x] Harden `setup.sh`:
  - tool **version checks** (node ≥20, pnpm 8.x, docker compose v2)
  - **port preflight** for 3000 / 8008 / 54321-54323
  - explicit **database migration** step (no longer relies on implicit behaviour)
  - **validates** the Supabase keys it captures are non-empty (fails loud, not silent)
  - **honest final status** — won't claim "ready" when the sandbox build failed
    or no LLM key is set

## Phase 1 — Prove it works *(smoke test)*

- [ ] `scripts/smoke-test.sh` — checks each layer (web / API / database /
      sandbox) and prints a PASS/FAIL table.
- [ ] `setup.sh` runs it automatically at the end.
- [ ] From here on: no change is "done" until the smoke test is green.

## Phase 2 — Ship a working company *(the actual feature)*

Research finding that shaped this phase: the runtime's delegation always
spawns the generic `worker` agent — there is no mechanism for the orchestrator
to delegate to named role-agent files. Shipping `researcher.md` / `writer.md`
etc. would be dead code nothing ever calls. So the company is defined where it
actually takes effect: a `CONTEXT.md` the orchestrator reads.

- [x] `CONTEXT.md` company template
      (`core/kortix-master/opencode/workspace-template/.kortix/CONTEXT.md`) —
      defines the company, its departments/roles (which the orchestrator uses
      to brief workers), and operating principles.
- [x] Copy-on-boot seeding in `core/startup.sh` — every fresh clone's
      workspace gets the template (per-file guarded; never overwrites).
- [x] **Logic check** (`scripts/verify-company.sh`, `pnpm verify:company`) —
      validates every agent definition is structurally sound AND the
      delegation graph is intact (`worker` / `project-maintainer` exist and
      are enabled, the orchestrator can delegate). Runs anywhere; folded into
      `pnpm smoke`.
- [x] **Live agent test** (`scripts/agent-e2e.sh`, `pnpm test:agents`) — gives
      the orchestrator a real task and proves it delegates to a worker, the
      worker delivers, and the real side effect lands. Runs where the sandbox
      is up.

## Phase 3 — Polish

- [x] `pnpm doctor` (`scripts/doctor.sh`) — diagnoses tools, Docker, config,
      env files, database, sandbox image and company wiring; for every problem
      it prints the exact fix. The "something is wrong, what do I do" tool.
- [x] Final README pass — documents the doctor/smoke/test:agents trio and
      points users at `pnpm doctor` first when something breaks.
- [ ] *Deferred — not polish:* a "choose your workforce" onboarding step is a
      real frontend feature (new React flow), not a finishing touch, and can't
      be verified in a sandboxless environment. Left as a future phase rather
      than shipped half-tested.

## The verification trio

The whole point of Phases 1-3: you never have to guess whether it works.

| Command | Answers |
|---|---|
| `pnpm doctor` | Is my machine + config set up right? (prints fixes) |
| `pnpm smoke` | Is the company wired up and running? |
| `pnpm test:agents` | Do the agents actually delegate and deliver? |

---

## How each phase runs

`do the work → smoke test → green → commit & push`. Red means stop and fix
before moving on. The owner only needs to say "weiter" between phases.
