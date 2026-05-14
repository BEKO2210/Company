#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════════╗
# ║  The Company — doctor                                                    ║
# ║                                                                          ║
# ║  Diagnoses your setup and config, and for every problem prints the        ║
# ║  exact fix. This is the "something is wrong, what do I do" tool.          ║
# ║                                                                          ║
# ║  Division of labour:                                                      ║
# ║    pnpm doctor          — is my machine + config set up right (with fixes)║
# ║    pnpm smoke           — is the company wired up and running             ║
# ║    pnpm test:agents     — do the agents actually do the work              ║
# ║                                                                          ║
# ║  Exit 0 = nothing blocking.  Exit 1 = at least one PROBLEM found.         ║
# ╚══════════════════════════════════════════════════════════════════════════╝
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [ -t 1 ]; then BOLD=$'\033[1m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RED=$'\033[31m'; DIM=$'\033[2m'; RESET=$'\033[0m'
else BOLD=; GREEN=; YELLOW=; RED=; DIM=; RESET=; fi

PROBLEMS=0
WARNINGS=0
section() { echo; echo "${BOLD}$*${RESET}"; }
good()  { echo "  ${GREEN}✓${RESET} $*"; }
bad()   { echo "  ${RED}✗${RESET} $*"; PROBLEMS=$((PROBLEMS+1)); }
warnp() { echo "  ${YELLOW}!${RESET} $*"; WARNINGS=$((WARNINGS+1)); }
fixline() { echo "      ${DIM}fix: $*${RESET}"; }

get_env() { [ -f "$1" ] && grep -E "^$2=" "$1" 2>/dev/null | head -1 | cut -d= -f2- || true; }

echo
echo "${BOLD}The Company — doctor${RESET}"
echo "${DIM}  checking your setup and configuration${RESET}"

# ─── tools ──────────────────────────────────────────────────────────────────
section "Tools"
MISSING_TOOLS=()
for t in docker node pnpm bun supabase python3 openssl curl; do
  command -v "$t" >/dev/null 2>&1 || MISSING_TOOLS+=("$t")
done
if [ "${#MISSING_TOOLS[@]}" -eq 0 ]; then
  good "all required tools present (docker, node, pnpm, bun, supabase, python3, openssl, curl)"
else
  bad "missing tools: ${MISSING_TOOLS[*]}"
  fixline "install them — see README 'Prerequisites' — then re-run ./setup.sh"
fi
if command -v node >/dev/null 2>&1; then
  NM="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
  [ "$NM" -ge 20 ] 2>/dev/null && good "node $(node -v)" || { bad "node $(node -v 2>/dev/null) — v20+ required"; fixline "install Node.js v20 or newer from https://nodejs.org"; }
fi
if command -v pnpm >/dev/null 2>&1; then
  [ "$(pnpm -v 2>/dev/null | cut -d. -f1)" = "8" ] && good "pnpm $(pnpm -v)" || warnp "pnpm $(pnpm -v 2>/dev/null) — repo pins v8.x; other versions may misbehave"
fi

# ─── docker ─────────────────────────────────────────────────────────────────
section "Docker"
if command -v docker >/dev/null 2>&1; then
  if docker info >/dev/null 2>&1; then good "docker daemon is running"
  else bad "docker daemon is not running"; fixline "start Docker, then re-run"; fi
  if docker compose version >/dev/null 2>&1; then good "docker compose v2 available"
  else bad "docker compose v2 not available"; fixline "upgrade Docker — the legacy 'docker-compose' is not supported"; fi
else
  bad "docker not installed"; fixline "install Docker from https://docs.docker.com/get-docker/"
fi

# ─── configuration ──────────────────────────────────────────────────────────
section "Configuration"
if [ -f .env ]; then
  good ".env present"
  if [ -n "$(get_env .env ANTHROPIC_API_KEY)" ] || [ -n "$(get_env .env OPENAI_API_KEY)" ]; then
    good "LLM key set — agents can think"
  else
    warnp "no LLM key set — the app runs but agents can't perform tasks"
    fixline "add ANTHROPIC_API_KEY or OPENAI_API_KEY to .env, then ./setup.sh"
  fi
  MISSING_SECRETS=()
  for s in API_KEY_SECRET TUNNEL_SIGNING_SECRET INTERNAL_SERVICE_KEY; do
    [ -z "$(get_env .env "$s")" ] && MISSING_SECRETS+=("$s")
  done
  if [ "${#MISSING_SECRETS[@]}" -eq 0 ]; then good "security secrets generated"
  else bad "missing secrets: ${MISSING_SECRETS[*]}"; fixline "run ./setup.sh — it generates them automatically"; fi
  if [ -n "$(get_env .env SUPABASE_ANON_KEY)" ] && [ -n "$(get_env .env SUPABASE_SERVICE_ROLE_KEY)" ]; then
    good "Supabase keys present"
  else
    bad "Supabase keys missing from .env"
    fixline "run ./setup.sh — it starts Supabase and captures the keys"
  fi
else
  bad ".env not found"
  fixline "cp .env.example .env   (then add an LLM key)   then ./setup.sh"
fi
# per-service env files are generated artifacts — must exist to run
MISSING_ENVS=()
for e in apps/api/.env apps/web/.env core/docker/.env; do
  [ -f "$e" ] || MISSING_ENVS+=("$e")
done
if [ "${#MISSING_ENVS[@]}" -eq 0 ]; then good "per-service env files generated"
else bad "missing generated env files: ${MISSING_ENVS[*]}"; fixline "run ./setup.sh — it regenerates them from .env"; fi

# ─── database ───────────────────────────────────────────────────────────────
section "Database"
if [ -d supabase ] && command -v supabase >/dev/null 2>&1; then
  if (cd supabase && supabase status >/dev/null 2>&1); then good "local Supabase is running"
  else warnp "local Supabase is not running"; fixline "run ./setup.sh   (or: cd supabase && supabase start)"; fi
else
  warnp "cannot check Supabase (CLI or supabase/ dir missing)"
fi

# ─── agent sandbox image ────────────────────────────────────────────────────
section "Agent sandbox"
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  if docker image inspect kortix/computer:dev >/dev/null 2>&1; then
    good "sandbox image built (kortix/computer:dev)"
  else
    warnp "sandbox image not built — agents can't execute tasks yet"
    fixline "pnpm dev:core:build"
  fi
else
  warnp "cannot check the sandbox image (docker not available)"
fi

# ─── company wiring ─────────────────────────────────────────────────────────
section "Company wiring"
if [ -x scripts/verify-company.sh ]; then
  if bash scripts/verify-company.sh >/dev/null 2>&1; then
    good "agent definitions valid, delegation graph intact"
  else
    bad "company wiring has a problem"
    fixline "run: pnpm verify:company   (shows exactly what's broken)"
  fi
else
  warnp "scripts/verify-company.sh not found — cannot check wiring"
fi

# ─── summary ────────────────────────────────────────────────────────────────
section "Summary"
if [ "$PROBLEMS" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
  echo "  ${GREEN}${BOLD}Everything looks good.${RESET}"
  echo "  ${DIM}Next: 'pnpm smoke' checks the running services, 'pnpm test:agents' tests the agents.${RESET}"
elif [ "$PROBLEMS" -eq 0 ]; then
  echo "  ${YELLOW}${BOLD}$WARNINGS warning(s)${RESET} — the company runs, but not everything is enabled (see the ! lines)."
else
  echo "  ${RED}${BOLD}$PROBLEMS problem(s)${RESET} and ${YELLOW}$WARNINGS warning(s)${RESET} — fix the ✗ lines above, then re-run: ${BOLD}./setup.sh${RESET}"
fi
echo
[ "$PROBLEMS" -eq 0 ] && exit 0 || exit 1
