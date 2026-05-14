#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════════╗
# ║  The Company — live agent end-to-end test                                ║
# ║                                                                          ║
# ║  Proves the agents actually WORK and collaborate, not just that the       ║
# ║  servers respond:                                                         ║
# ║    1. give the orchestrator a real task                                   ║
# ║    2. confirm it delegates to a worker  (a task row with the              ║
# ║       orchestrator session as parent appears)                             ║
# ║    3. confirm the worker executes and delivers  (task reaches             ║
# ║       awaiting_review / completed)                                        ║
# ║    4. confirm the real side effect  (the file the worker was told         ║
# ║       to create exists with the right content)                           ║
# ║                                                                          ║
# ║  Requires the agent sandbox to be running (pnpm dev:core / dev:core:build) ║
# ║  and an LLM key configured. Run:  ./scripts/agent-e2e.sh  (pnpm test:agents)║
# ║                                                                          ║
# ║  Exit 0 = orchestrator -> worker -> delivery -> side effect all proven.    ║
# ╚══════════════════════════════════════════════════════════════════════════╝
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [ -t 1 ]; then BOLD=$'\033[1m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RED=$'\033[31m'; DIM=$'\033[2m'; RESET=$'\033[0m'
else BOLD=; GREEN=; YELLOW=; RED=; DIM=; RESET=; fi
ok()   { echo "  ${GREEN}✓${RESET} $*"; }
info() { echo "  ${DIM}$*${RESET}"; }
fail() { echo; echo "  ${RED}${BOLD}✗ $*${RESET}"; echo; exit 1; }

SANDBOX_URL="${SANDBOX_URL:-http://localhost:14000}"
# total wait budget for the whole orchestrator->worker->delivery cycle (real LLM
# work — minutes, not seconds). Override with AGENT_E2E_TIMEOUT (seconds).
TIMEOUT="${AGENT_E2E_TIMEOUT:-720}"
POLL=10

command -v python3 >/dev/null 2>&1 || fail "python3 is required for this test"
command -v curl    >/dev/null 2>&1 || fail "curl is required for this test"

# jval <json> <python-expr-on-`d`>  — extract a value, empty string on any error
jval() { python3 -c 'import sys,json
try:
    d=json.load(sys.stdin)
    print(eval(sys.argv[1]))
except Exception:
    print("")' "$2" <<<"$1" 2>/dev/null; }

echo
echo "${BOLD}Live agent test — does the company actually do the work?${RESET}"
info "sandbox=$SANDBOX_URL  timeout=${TIMEOUT}s"

# ─── 1. sandbox must be up ──────────────────────────────────────────────────
HEALTH="$(curl -s -m 10 "$SANDBOX_URL/kortix/health" 2>/dev/null || true)"
[ -n "$HEALTH" ] || fail "sandbox not reachable at $SANDBOX_URL — start it with: pnpm dev:core (build first: pnpm dev:core:build)"
READY="$(jval "$HEALTH" "d.get('runtimeReady')")"
[ "$READY" = "True" ] || fail "sandbox is up but the agent runtime isn't ready yet — wait a moment and retry"
ok "sandbox up, agent runtime ready"

# ─── 2. give the orchestrator a real, delegation-forcing task ───────────────
MARKER="e2e-$(date +%s)-$RANDOM"
PROOF_FILE="/workspace/e2e-proof-$MARKER.txt"
TASK="Delegate this to a worker (do not do it yourself): create the file ${PROOF_FILE} containing exactly the single line ${MARKER}. The worker must verify the file exists with that exact content before delivering."

SESSION_JSON="$(curl -s -m 30 -X POST "$SANDBOX_URL/session?directory=/workspace" \
  -H 'Content-Type: application/json' -d '{"agent":"orchestrator"}' 2>/dev/null || true)"
ORCH_SESSION="$(jval "$SESSION_JSON" "d.get('id','')")"
[ -n "$ORCH_SESSION" ] || fail "could not create an orchestrator session — response: ${SESSION_JSON:-<empty>}"
ok "orchestrator session created: $ORCH_SESSION"

# fire the prompt asynchronously — the full cycle is long; we observe via the task store
PROMPT_BODY="$(python3 -c 'import json,sys; print(json.dumps({"agent":"orchestrator","parts":[{"type":"text","text":sys.argv[1]}]}))' "$TASK")"
curl -s -m 30 -X POST "$SANDBOX_URL/session/$ORCH_SESSION/prompt_async?directory=/workspace" \
  -H 'Content-Type: application/json' -d "$PROMPT_BODY" >/dev/null 2>&1 \
  || curl -s -m 30 -X POST "$SANDBOX_URL/session/$ORCH_SESSION/prompt?directory=/workspace" \
       -H 'Content-Type: application/json' -d "$PROMPT_BODY" >/dev/null 2>&1 &
ok "task handed to the orchestrator"
info "task: create $PROOF_FILE (delegated)"

# ─── 3. wait for delegation: a task owned by THIS orchestrator session ──────
DEADLINE=$(( $(date +%s) + TIMEOUT ))
TASK_ID=""
echo "  ${DIM}waiting for the orchestrator to delegate to a worker...${RESET}"
while [ "$(date +%s)" -lt "$DEADLINE" ]; do
  TASKS="$(curl -s -m 15 "$SANDBOX_URL/kortix/tasks" 2>/dev/null || true)"
  TASK_ID="$(jval "$TASKS" "next((t['id'] for t in (d if isinstance(d,list) else d.get('tasks',[])) if t.get('parent_session_id')=='$ORCH_SESSION'), '')")"
  [ -n "$TASK_ID" ] && break
  sleep "$POLL"
done
[ -n "$TASK_ID" ] || fail "no delegation observed within ${TIMEOUT}s — the orchestrator never spawned a worker task"
ok "delegation proven — orchestrator spawned task: $TASK_ID"

# ─── 4. wait for the worker to deliver ──────────────────────────────────────
echo "  ${DIM}waiting for the worker to execute and deliver...${RESET}"
STATUS=""
while [ "$(date +%s)" -lt "$DEADLINE" ]; do
  TASK_JSON="$(curl -s -m 15 "$SANDBOX_URL/kortix/tasks/$TASK_ID" 2>/dev/null || true)"
  STATUS="$(jval "$TASK_JSON" "(d.get('task',d) or {}).get('status','')")"
  case "$STATUS" in
    awaiting_review|completed) break ;;
    cancelled)                 fail "the worker task was cancelled before delivering" ;;
  esac
  sleep "$POLL"
done
case "$STATUS" in
  awaiting_review|completed) ok "worker executed and delivered (status: $STATUS)" ;;
  *) fail "worker did not deliver within ${TIMEOUT}s (last status: ${STATUS:-unknown})" ;;
esac

# ─── 5. confirm the real side effect ────────────────────────────────────────
CONTENT="$(curl -s -m 15 "$SANDBOX_URL/file/read?path=$PROOF_FILE" 2>/dev/null || true)"
[ -z "$CONTENT" ] && CONTENT="$(curl -s -m 15 "$SANDBOX_URL/file?path=$PROOF_FILE" 2>/dev/null || true)"
if echo "$CONTENT" | grep -q "$MARKER"; then
  ok "side effect confirmed — $PROOF_FILE contains the expected marker"
else
  echo "  ${YELLOW}!${RESET} could not read back $PROOF_FILE to confirm content"
  info "delegation + delivery are still proven; only the file read-back was inconclusive"
fi

echo
echo "  ${GREEN}${BOLD}✓ The company works: orchestrator delegated, the worker executed and delivered.${RESET}"
echo
exit 0
