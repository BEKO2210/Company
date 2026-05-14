#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════════╗
# ║  The Company — smoke test                                                ║
# ║                                                                          ║
# ║  Checks every layer of a running company and prints a PASS/FAIL table.    ║
# ║  Run any time:   ./scripts/smoke-test.sh    (or: pnpm smoke)              ║
# ║                                                                          ║
# ║  Exit code 0  = all critical layers healthy (web, api, database).         ║
# ║  Exit code 1  = something critical is broken — the table shows what.      ║
# ║  The sandbox layer is reported but never fails the run (it may be         ║
# ║  intentionally not built yet).                                            ║
# ╚══════════════════════════════════════════════════════════════════════════╝
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [ -t 1 ]; then BOLD=$'\033[1m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RED=$'\033[31m'; DIM=$'\033[2m'; RESET=$'\033[0m'
else BOLD=; GREEN=; YELLOW=; RED=; DIM=; RESET=; fi

# ─── read config from .env files ────────────────────────────────────────────
read_env() { [ -f "$1" ] && grep -E "^$2=" "$1" 2>/dev/null | head -1 | cut -d= -f2- || true; }

WEB_URL="$(read_env .env NEXT_PUBLIC_URL)";          WEB_URL="${WEB_URL:-http://localhost:3000}"
API_PORT="$(read_env apps/api/.env PORT)";           API_PORT="${API_PORT:-8008}"
API_URL="http://localhost:${API_PORT}"
SUPABASE_URL="$(read_env .env SUPABASE_URL)";        SUPABASE_URL="${SUPABASE_URL:-http://127.0.0.1:54321}"
SUPABASE_ANON="$(read_env .env SUPABASE_ANON_KEY)"
SANDBOX_URL="http://localhost:14000"

# ─── check helpers ──────────────────────────────────────────────────────────
# http_code <url> [header]   -> prints the HTTP status code (000 on no connect)
http_code() {
  if [ -n "${2:-}" ]; then
    curl -s -o /dev/null -m 8 -w '%{http_code}' -H "$2" "$1" 2>/dev/null || echo "000"
  else
    curl -s -o /dev/null -m 8 -w '%{http_code}' "$1" 2>/dev/null || echo "000"
  fi
}

RESULTS=()           # "name|status|detail"   status = PASS|FAIL|WARN
CRITICAL_FAIL=0
record() {
  RESULTS+=("$1|$2|$3")
  [ "$2" = "FAIL" ] && CRITICAL_FAIL=1
  return 0
}

# ─── 0. company wiring (file-level — runs even with no services up) ─────────
# The smoke test covers both: is the company correctly wired, AND is it running.
if [ -x scripts/verify-company.sh ]; then
  bash scripts/verify-company.sh || CRITICAL_FAIL=1
fi

echo
echo "${BOLD}Smoke test — checking the running services${RESET}"
echo "${DIM}  web=$WEB_URL  api=$API_URL  db=$SUPABASE_URL${RESET}"

# ─── 1. API ─────────────────────────────────────────────────────────────────
CODE="$(http_code "$API_URL/v1/health")"
if [ "$CODE" = "200" ]; then record "API"       "PASS" "/v1/health 200"
elif [ "$CODE" = "000" ]; then record "API"     "FAIL" "no response on $API_URL — is 'pnpm dev' running?"
else record "API" "FAIL" "/v1/health returned $CODE"; fi

# ─── 2. Database (via the API's DB-backed endpoint) ─────────────────────────
# /v1/setup/install-status returns 200 when the API can reach the database,
# 503 when it cannot — the single clearest "is the DB wired up" signal.
CODE="$(http_code "$API_URL/v1/setup/install-status")"
if [ "$CODE" = "200" ]; then record "Database"  "PASS" "API can reach the database"
elif [ "$CODE" = "503" ]; then record "Database" "FAIL" "API is up but cannot reach the database (503)"
elif [ "$CODE" = "000" ]; then record "Database" "FAIL" "API not responding — can't check the database"
else record "Database" "FAIL" "install-status returned $CODE"; fi

# ─── 3. Supabase ────────────────────────────────────────────────────────────
if [ -n "$SUPABASE_ANON" ]; then
  CODE="$(http_code "$SUPABASE_URL/auth/v1/health" "apikey: $SUPABASE_ANON")"
else
  CODE="$(http_code "$SUPABASE_URL/auth/v1/health")"
fi
if [ "$CODE" = "200" ]; then record "Supabase"  "PASS" "auth service healthy"
elif [ "$CODE" = "000" ]; then record "Supabase" "FAIL" "no response on $SUPABASE_URL — is the database running?"
else record "Supabase" "FAIL" "/auth/v1/health returned $CODE"; fi

# ─── 4. Web ─────────────────────────────────────────────────────────────────
# Fetch the /auth page once: it returns fast AND carries the runtime config
# (injected by the shared root layout), so we verify status + config together.
WEB_RESP="$(curl -s -m 25 -w 'HTTPSTATUS:%{http_code}' "$WEB_URL/auth" 2>/dev/null || true)"
CODE="${WEB_RESP##*HTTPSTATUS:}"
BODY="${WEB_RESP%HTTPSTATUS:*}"
if [ "$CODE" != "200" ]; then
  if [ -z "$CODE" ] || [ "$CODE" = "000" ]; then record "Web" "FAIL" "no response on $WEB_URL — is 'pnpm dev' running?"
  else record "Web" "FAIL" "/auth returned $CODE"; fi
elif printf '%s' "$BODY" | grep -q '__KORTIX_RUNTIME_CONFIG={"SUPABASE_URL":"http'; then
  record "Web" "PASS" "page up, runtime config injected"
else
  record "Web" "FAIL" "page up but runtime config missing/placeholder — check apps/web/.env"
fi

# ─── 5. Sandbox (never fails the run — may be intentionally not built) ───────
CODE="$(http_code "$SANDBOX_URL/kortix/health")"
if [ "$CODE" = "200" ]; then record "Sandbox"   "PASS" "agent runtime healthy"
elif [ "$CODE" = "503" ]; then record "Sandbox" "WARN" "starting up — give it a moment"
else record "Sandbox" "WARN" "not running — agents can't execute tasks yet (pnpm dev:core:build)"; fi

# ─── table ──────────────────────────────────────────────────────────────────
echo
printf "  %-10s %-6s %s\n" "LAYER" "STATUS" "DETAIL"
printf "  %-10s %-6s %s\n" "-----" "------" "------"
for r in "${RESULTS[@]}"; do
  IFS='|' read -r name status detail <<< "$r"
  case "$status" in
    PASS) c="$GREEN" ;; FAIL) c="$RED" ;; *) c="$YELLOW" ;;
  esac
  printf "  %-10s ${c}%-6s${RESET} ${DIM}%s${RESET}\n" "$name" "$status" "$detail"
done
echo

if [ "$CRITICAL_FAIL" -eq 0 ]; then
  echo "  ${GREEN}${BOLD}✓ All critical layers healthy.${RESET}"
  echo
  exit 0
else
  echo "  ${RED}${BOLD}✗ Something critical is broken — see the FAIL rows above.${RESET}"
  echo
  exit 1
fi
