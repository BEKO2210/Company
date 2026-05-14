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

- [ ] Default role agents shipped with the template (orchestrator/"CEO" plus
      worker roles like researcher, writer, analyst, developer) — these are
      Markdown files, not database rows.
- [ ] A starter `.kortix/CONTEXT.md` describing the company.
- [ ] A copy-on-setup step so every clone's workspace gets this structure — a
      clone is a staffed company, not an empty shell.

## Phase 3 — Polish

- [ ] Final README/docs pass.
- [ ] `pnpm doctor` — diagnose a broken setup.
- [ ] Optional: a "choose your workforce" onboarding step.

---

## How each phase runs

`do the work → smoke test → green → commit & push`. Red means stop and fix
before moving on. The owner only needs to say "weiter" between phases.
