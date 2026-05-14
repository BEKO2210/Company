#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════════╗
# ║  The Company — one-command bootstrap                                     ║
# ║                                                                          ║
# ║  Clone the repo, then run:   ./setup.sh                                   ║
# ║                                                                          ║
# ║  It checks prerequisites, generates secrets, starts the database,         ║
# ║  installs dependencies and boots your company at http://localhost:3000.   ║
# ║                                                                          ║
# ║  Flags:                                                                   ║
# ║    --skip-sandbox   Don't build the agent sandbox image (faster, but      ║
# ║                     agents can't execute tasks until it's built).         ║
# ║    --no-start       Prepare everything but don't start the dev servers.   ║
# ╚══════════════════════════════════════════════════════════════════════════╝
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

SKIP_SANDBOX=0
NO_START=0
for arg in "$@"; do
  case "$arg" in
    --skip-sandbox) SKIP_SANDBOX=1 ;;
    --no-start) NO_START=1 ;;
    -h|--help) sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown flag: $arg" >&2; exit 1 ;;
  esac
done

# ─── pretty output ──────────────────────────────────────────────────────────
if [ -t 1 ]; then BOLD=$'\033[1m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RED=$'\033[31m'; DIM=$'\033[2m'; RESET=$'\033[0m'
else BOLD=; GREEN=; YELLOW=; RED=; DIM=; RESET=; fi
step() { echo; echo "${BOLD}▶ $*${RESET}"; }
ok()   { echo "  ${GREEN}✓${RESET} $*"; }
warn() { echo "  ${YELLOW}!${RESET} $*"; }
die()  { echo "  ${RED}✗ $*${RESET}" >&2; exit 1; }

SUPA_LOG="/tmp/the-company-supabase.log"
SANDBOX_LOG="/tmp/the-company-sandbox-build.log"

# ─── 1. prerequisites ───────────────────────────────────────────────────────
step "Checking prerequisites"
MISSING=()
need() { command -v "$1" >/dev/null 2>&1 || { warn "$1 — not found"; MISSING+=("$1"); return 1; }; }

if need node; then
  NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
  if [ "$NODE_MAJOR" -ge 20 ] 2>/dev/null; then ok "node v$(node -v | sed 's/^v//')"
  else warn "node — v20+ required, found $(node -v 2>/dev/null)"; MISSING+=("node>=20"); fi
fi
if need pnpm; then
  PNPM_MAJOR="$(pnpm -v 2>/dev/null | cut -d. -f1)"
  if [ "$PNPM_MAJOR" = "8" ]; then ok "pnpm $(pnpm -v)"
  else warn "pnpm $(pnpm -v 2>/dev/null) — repo pins v8.x; other versions may misbehave"; fi
fi
need bun        && ok "bun $(bun -v 2>/dev/null)"
need python3    && ok "python3"
need openssl    && ok "openssl"
need curl       && ok "curl"
need supabase   && ok "supabase $(supabase -v 2>/dev/null | head -1)"
if need docker; then
  if docker compose version >/dev/null 2>&1; then ok "docker + docker compose v2"
  else warn "docker compose v2 — not available (old 'docker-compose' is not supported)"; MISSING+=("docker-compose-v2"); fi
fi

if [ "${#MISSING[@]}" -ne 0 ]; then
  echo
  die "Missing or unsupported: ${MISSING[*]}
     Install/upgrade, then re-run ./setup.sh
       docker      → https://docs.docker.com/get-docker/  (needs Compose v2)
       node v20+   → https://nodejs.org
       pnpm 8.x    → npm install -g pnpm@8.15.8
       bun         → curl -fsSL https://bun.sh/install | bash
       supabase    → https://github.com/supabase/cli#install-the-cli"
fi
if ! docker info >/dev/null 2>&1; then
  die "Docker is installed but the daemon isn't running. Start Docker and re-run."
fi
ok "docker daemon is running"

# ─── 2. port preflight ──────────────────────────────────────────────────────
step "Checking ports"
port_busy() { (echo >"/dev/tcp/127.0.0.1/$1") >/dev/null 2>&1; }
PORT_CONFLICT=0
for p in 3000 8008 54321 54322 54323; do
  if port_busy "$p"; then
    warn "port $p is in use — fine if this company is already running, otherwise free it"
    PORT_CONFLICT=1
  else
    ok "port $p free"
  fi
done
[ "$PORT_CONFLICT" -eq 1 ] && echo "  ${DIM}(port-in-use is expected when re-running setup on an already-running company)${RESET}"

# ─── 3. .env ────────────────────────────────────────────────────────────────
step "Preparing .env"
if [ ! -f .env ]; then
  cp .env.example .env
  ok "created .env from .env.example"
else
  ok ".env already exists — keeping it"
fi

# helper: read/set a KEY=value in .env
get_env() { grep -E "^$1=" .env | head -1 | cut -d= -f2- || true; }
set_env() {
  local key="$1" val="$2"
  if grep -qE "^$key=" .env; then
    sed -i.bak "s|^$key=.*|$key=$val|" .env && rm -f .env.bak
  else
    echo "$key=$val" >> .env
  fi
}

# ─── 4. secrets ─────────────────────────────────────────────────────────────
step "Generating secrets"
gen_secret() {
  local key="$1" bytes="$2"
  if [ -z "$(get_env "$key")" ]; then
    set_env "$key" "$(openssl rand -hex "$bytes")"
    ok "$key — generated"
  else
    ok "$key — already set"
  fi
}
gen_secret API_KEY_SECRET 32
gen_secret TUNNEL_SIGNING_SECRET 32
gen_secret CRON_TICK_SECRET 16
gen_secret INTERNAL_SERVICE_KEY 32
gen_secret CHANNELS_CREDENTIAL_KEY 32

# ─── 5. database (local Supabase) ───────────────────────────────────────────
step "Starting the database"
SUPABASE_TARGET="$(get_env SUPABASE_URL)"
if [[ "$SUPABASE_TARGET" == http://127.0.0.1:* || "$SUPABASE_TARGET" == http://localhost:* ]]; then
  if (cd supabase && supabase status >/dev/null 2>&1); then
    ok "local Supabase already running"
  else
    echo "  ${DIM}first run pulls Docker images, this can take a few minutes...${RESET}"
    if ! (cd supabase && supabase start) >"$SUPA_LOG" 2>&1; then
      die "Supabase failed to start — see $SUPA_LOG"
    fi
    ok "local Supabase started"
  fi

  # ensure all migrations are applied (idempotent — no-op if already up to date)
  if ! (cd supabase && supabase migration up --local) >>"$SUPA_LOG" 2>&1; then
    die "Database migrations failed — see $SUPA_LOG"
  fi
  ok "database migrations applied"

  # capture and validate the keys Supabase generated
  STATUS="$(cd supabase && supabase status -o env 2>/dev/null || true)"
  ANON="$(echo "$STATUS"  | grep -E '^ANON_KEY='         | cut -d= -f2- | tr -d '"')"
  SERVICE="$(echo "$STATUS" | grep -E '^SERVICE_ROLE_KEY=' | cut -d= -f2- | tr -d '"')"
  [ -n "$ANON" ]    || die "Could not read SUPABASE_ANON_KEY from 'supabase status' — see $SUPA_LOG"
  [ -n "$SERVICE" ] || die "Could not read SUPABASE_SERVICE_ROLE_KEY from 'supabase status' — see $SUPA_LOG"
  set_env SUPABASE_ANON_KEY "$ANON"
  set_env SUPABASE_SERVICE_ROLE_KEY "$SERVICE"
  ok "Supabase keys captured into .env"
else
  # external/hosted Supabase — the user must have filled the keys in .env
  ok "using external Supabase: $SUPABASE_TARGET"
  [ -n "$(get_env SUPABASE_ANON_KEY)" ]         || die "SUPABASE_ANON_KEY is empty in .env — fill it from your Supabase dashboard"
  [ -n "$(get_env SUPABASE_SERVICE_ROLE_KEY)" ] || die "SUPABASE_SERVICE_ROLE_KEY is empty in .env — fill it from your Supabase dashboard"
  [ -n "$(get_env DATABASE_URL)" ]              || die "DATABASE_URL is empty in .env — fill it from your Supabase dashboard"
  warn "remember to apply migrations to your external database (supabase/migrations/)"
fi

# ─── 6. per-service env files ───────────────────────────────────────────────
step "Generating per-service env files"
# these are generated artifacts — always regenerate from the root .env
rm -f apps/api/.env apps/web/.env
bash scripts/setup-env.sh >/dev/null
ok "apps/api/.env and apps/web/.env generated"
# the sandbox runtime reads its own env file
{
  echo "# Auto-generated by setup.sh — sandbox runtime env"
  echo "ANTHROPIC_API_KEY=$(get_env ANTHROPIC_API_KEY)"
  echo "OPENAI_API_KEY=$(get_env OPENAI_API_KEY)"
  echo "KORTIX_API_URL=http://host.docker.internal:8008"
  echo "KORTIX_TOKEN="
  echo "INTERNAL_SERVICE_KEY=$(get_env INTERNAL_SERVICE_KEY)"
  echo "SANDBOX_ID=local"
  echo "PROJECT_ID=local"
  echo "ENV_MODE=local"
} > core/docker/.env
ok "core/docker/.env generated"

# ─── 7. LLM key check ───────────────────────────────────────────────────────
LLM_KEY_SET=1
if [ -z "$(get_env ANTHROPIC_API_KEY)" ] && [ -z "$(get_env OPENAI_API_KEY)" ]; then
  LLM_KEY_SET=0
  warn "No LLM key set in .env (ANTHROPIC_API_KEY or OPENAI_API_KEY)."
  warn "The app will start, but agents can't perform tasks until you add one."
  warn "Add it to .env and re-run ./setup.sh."
fi

# ─── 8. dependencies ────────────────────────────────────────────────────────
step "Installing dependencies (pnpm install)"
pnpm install --silent
ok "dependencies installed"

# ─── 9. sandbox image ───────────────────────────────────────────────────────
SANDBOX_STATUS="built"
if [ "$SKIP_SANDBOX" -eq 1 ]; then
  SANDBOX_STATUS="skipped"
  step "Skipping sandbox image build (--skip-sandbox)"
  warn "Agents can't execute tasks until you build it:  pnpm dev:core:build"
else
  step "Building the agent sandbox image"
  echo "  ${DIM}this is a large image and can take 10-20 minutes the first time...${RESET}"
  if docker compose -f core/docker/docker-compose.yml -f core/docker/docker-compose.dev.yml build >"$SANDBOX_LOG" 2>&1; then
    ok "sandbox image built"
  else
    SANDBOX_STATUS="failed"
    warn "sandbox image build FAILED — see $SANDBOX_LOG"
    warn "The web app and API still work. Retry later with: pnpm dev:core:build"
  fi
fi

# ─── 10. done — honest status ───────────────────────────────────────────────
step "Setup complete"
echo
if [ "$SANDBOX_STATUS" = "built" ] && [ "$LLM_KEY_SET" -eq 1 ]; then
  echo "  ${GREEN}${BOLD}Your company is fully ready.${RESET}"
else
  echo "  ${YELLOW}${BOLD}Your company is running, but not fully operational yet:${RESET}"
  [ "$LLM_KEY_SET" -eq 0 ]            && echo "  ${YELLOW}  • no LLM key — agents can't think yet (add it to .env)${RESET}"
  [ "$SANDBOX_STATUS" = "failed" ]    && echo "  ${YELLOW}  • sandbox build failed — agents can't run tasks (see $SANDBOX_LOG)${RESET}"
  [ "$SANDBOX_STATUS" = "skipped" ]   && echo "  ${YELLOW}  • sandbox skipped — run 'pnpm dev:core:build' to enable agents${RESET}"
fi
echo
echo "  Web app:        ${BOLD}http://localhost:3000${RESET}"
echo "  API:            http://localhost:8008"
echo "  Database UI:    http://localhost:54323"
echo

if [ "$NO_START" -eq 1 ]; then
  echo "  Start it with:  ${BOLD}pnpm dev${RESET}"
  echo
  exit 0
fi

step "Starting the company (Ctrl+C to stop)"
exec pnpm dev
