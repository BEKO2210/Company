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

# ─── 1. prerequisites ───────────────────────────────────────────────────────
step "Checking prerequisites"
MISSING=()
need() { command -v "$1" >/dev/null 2>&1 && ok "$1" || { warn "$1 — not found"; MISSING+=("$1"); }; }
need docker
need pnpm
need bun
need node
need python3
need openssl
need curl
if ! command -v supabase >/dev/null 2>&1; then
  warn "supabase CLI — not found"
  MISSING+=("supabase")
else
  ok "supabase"
fi
if [ "${#MISSING[@]}" -ne 0 ]; then
  echo
  die "Missing tools: ${MISSING[*]}
     Install them, then re-run ./setup.sh
       docker     → https://docs.docker.com/get-docker/
       pnpm       → npm install -g pnpm@8.15.8   (or https://pnpm.io/installation)
       bun        → curl -fsSL https://bun.sh/install | bash
       node       → https://nodejs.org  (v20+)
       supabase   → https://github.com/supabase/cli#install-the-cli"
fi
if ! docker info >/dev/null 2>&1; then
  die "Docker is installed but the daemon isn't running. Start Docker and re-run."
fi
ok "docker daemon is running"

# ─── 2. .env ────────────────────────────────────────────────────────────────
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
    # use a non-/ delimiter; values are hex/base64-url so | is safe
    sed -i.bak "s|^$key=.*|$key=$val|" .env && rm -f .env.bak
  else
    echo "$key=$val" >> .env
  fi
}

# ─── 3. secrets ─────────────────────────────────────────────────────────────
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

# ─── 4. database (local Supabase) ───────────────────────────────────────────
step "Starting the database (local Supabase)"
SUPABASE_TARGET="$(get_env SUPABASE_URL)"
if [[ "$SUPABASE_TARGET" == http://127.0.0.1:* || "$SUPABASE_TARGET" == http://localhost:* ]]; then
  if (cd supabase && supabase status >/dev/null 2>&1); then
    ok "local Supabase already running"
  else
    echo "  ${DIM}first run pulls Docker images, this can take a few minutes...${RESET}"
    (cd supabase && supabase start >/dev/null)
    ok "local Supabase started"
  fi
  # capture the keys it generated
  STATUS="$(cd supabase && supabase status -o env 2>/dev/null)"
  ANON="$(echo "$STATUS"  | grep -E '^ANON_KEY='         | cut -d= -f2- | tr -d '"')"
  SERVICE="$(echo "$STATUS" | grep -E '^SERVICE_ROLE_KEY=' | cut -d= -f2- | tr -d '"')"
  [ -n "$ANON" ]    && set_env SUPABASE_ANON_KEY "$ANON"       && ok "SUPABASE_ANON_KEY captured"
  [ -n "$SERVICE" ] && set_env SUPABASE_SERVICE_ROLE_KEY "$SERVICE" && ok "SUPABASE_SERVICE_ROLE_KEY captured"
else
  ok "using external Supabase: $SUPABASE_TARGET (skipping local start)"
fi

# ─── 5. per-service env files ───────────────────────────────────────────────
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

# ─── 6. LLM key check ───────────────────────────────────────────────────────
if [ -z "$(get_env ANTHROPIC_API_KEY)" ] && [ -z "$(get_env OPENAI_API_KEY)" ]; then
  warn "No LLM key set in .env (ANTHROPIC_API_KEY or OPENAI_API_KEY)."
  warn "The app will start, but agents can't perform tasks until you add one."
  warn "Add it to .env and re-run ./setup.sh."
fi

# ─── 7. dependencies ────────────────────────────────────────────────────────
step "Installing dependencies (pnpm install)"
pnpm install --silent
ok "dependencies installed"

# ─── 8. sandbox image ───────────────────────────────────────────────────────
if [ "$SKIP_SANDBOX" -eq 1 ]; then
  step "Skipping sandbox image build (--skip-sandbox)"
  warn "Agents won't be able to execute tasks until you build it:"
  warn "  pnpm dev:core:build"
else
  step "Building the agent sandbox image"
  echo "  ${DIM}this is a large image and can take 10-20 minutes the first time...${RESET}"
  if docker compose -f core/docker/docker-compose.yml -f core/docker/docker-compose.dev.yml build >/tmp/the-company-sandbox-build.log 2>&1; then
    ok "sandbox image built"
  else
    warn "sandbox image build failed — see /tmp/the-company-sandbox-build.log"
    warn "The rest of the company still works. Retry later with: pnpm dev:core:build"
  fi
fi

# ─── 9. done ────────────────────────────────────────────────────────────────
step "Setup complete"
echo
echo "  ${GREEN}${BOLD}Your company is ready.${RESET}"
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
