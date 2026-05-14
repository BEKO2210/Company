#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════════╗
# ║  The Company — company logic check                                       ║
# ║                                                                          ║
# ║  Validates the WIRING of the company, not just that servers respond:      ║
# ║    • every shipped agent definition is structurally valid                 ║
# ║    • the delegation graph is intact (the agents the runtime hands work    ║
# ║      to actually exist and are enabled)                                   ║
# ║    • the company template (CONTEXT.md) ships and is well-formed           ║
# ║                                                                          ║
# ║  Runs anywhere — it only reads files, no running services needed.         ║
# ║  Run:  ./scripts/verify-company.sh    (or: pnpm verify:company)           ║
# ║                                                                          ║
# ║  Exit 0 = company wiring is sound.  Exit 1 = something is broken.         ║
# ╚══════════════════════════════════════════════════════════════════════════╝
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [ -t 1 ]; then BOLD=$'\033[1m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RED=$'\033[31m'; DIM=$'\033[2m'; RESET=$'\033[0m'
else BOLD=; GREEN=; YELLOW=; RED=; DIM=; RESET=; fi

AGENTS_DIR="core/kortix-master/opencode/agents"
OPENCODE_CFG="core/kortix-master/opencode/opencode.jsonc"
TEMPLATE_CONTEXT="core/kortix-master/opencode/workspace-template/.kortix/CONTEXT.md"

# agent names the runtime hands work to — these MUST exist as <name>.md
# (hardcoded in core/kortix-master/src/services/task-service.ts and projects.ts)
REQUIRED_AGENTS=(worker project-maintainer orchestrator)

RESULTS=()        # "name|status|detail"
ANY_FAIL=0
record() { RESULTS+=("$1|$2|$3"); [ "$2" = "FAIL" ] && ANY_FAIL=1; return 0; }

# extract the YAML frontmatter (between the first and second '---')
frontmatter() { awk 'NR==1 && $0!="---"{exit} /^---$/{c++; next} c==1{print} c>=2{exit}' "$1"; }
# everything after the second '---'
body() { awk '/^---$/{c++; next} c>=2{print}' "$1"; }

echo
echo "${BOLD}Company logic check — validating the wiring${RESET}"

# ─── 1. each shipped agent definition is structurally valid ─────────────────
if [ ! -d "$AGENTS_DIR" ]; then
  record "agents dir" "FAIL" "$AGENTS_DIR not found"
else
  for f in "$AGENTS_DIR"/*.md; do
    [ -e "$f" ] || continue
    name="$(basename "$f" .md)"
    fm="$(frontmatter "$f")"
    problem=""
    if [ -z "$fm" ]; then
      problem="no YAML frontmatter (must start with --- ... ---)"
    elif ! echo "$fm" | grep -qE '^description:[[:space:]]*[^[:space:]]'; then
      problem="missing or empty 'description'"
    elif ! echo "$fm" | grep -qE '^mode:[[:space:]]*(primary|subagent|all)[[:space:]]*$'; then
      problem="'mode' missing or not one of primary|subagent|all"
    elif ! echo "$fm" | grep -qE '^permission:[[:space:]]*$'; then
      problem="missing 'permission:' block"
    elif echo "$fm" | grep -qE '^[[:space:]]+[A-Za-z_'"'"'-]+:[[:space:]]*(allow|deny)[[:space:]]*$' \
         && echo "$fm" | grep -E '^[[:space:]]+[A-Za-z_'"'"'-]+:[[:space:]]*[^[:space:]]' \
            | grep -qvE ':[[:space:]]*(allow|deny)[[:space:]]*$'; then
      problem="a 'permission' entry is not allow/deny"
    elif [ -z "$(body "$f" | tr -d '[:space:]')" ]; then
      problem="empty body (no persona prompt after frontmatter)"
    fi
    if [ -n "$problem" ]; then record "agent: $name" "FAIL" "$problem"
    else record "agent: $name" "PASS" "valid definition"; fi
  done
fi

# ─── 2. delegation graph — required agents exist & are enabled ──────────────
for a in "${REQUIRED_AGENTS[@]}"; do
  if [ ! -f "$AGENTS_DIR/$a.md" ]; then
    record "wiring: $a" "FAIL" "runtime delegates to '$a' but $AGENTS_DIR/$a.md is missing"
  elif [ -f "$OPENCODE_CFG" ] && grep -zoE "\"$a\"[[:space:]]*:[[:space:]]*\{[^}]*disable[^}]*true" "$OPENCODE_CFG" >/dev/null 2>&1; then
    record "wiring: $a" "FAIL" "'$a' is disabled in opencode.jsonc — delegation would break"
  else
    record "wiring: $a" "PASS" "exists and enabled"
  fi
done

# orchestrator must actually be allowed to delegate
if [ -f "$AGENTS_DIR/orchestrator.md" ]; then
  if frontmatter "$AGENTS_DIR/orchestrator.md" | grep -qE '^[[:space:]]*task_create:[[:space:]]*allow[[:space:]]*$'; then
    record "wiring: delegation" "PASS" "orchestrator has task_create: allow"
  else
    record "wiring: delegation" "FAIL" "orchestrator cannot delegate (task_create not allowed)"
  fi
fi

# ─── 3. the company template ships and is well-formed ───────────────────────
if [ ! -f "$TEMPLATE_CONTEXT" ]; then
  record "template" "FAIL" "$TEMPLATE_CONTEXT missing — clones get no company definition"
elif [ "$(wc -c < "$TEMPLATE_CONTEXT")" -lt 200 ]; then
  record "template" "FAIL" "CONTEXT.md template is suspiciously small (<200 bytes)"
elif ! grep -q '# The Company' "$TEMPLATE_CONTEXT"; then
  record "template" "FAIL" "CONTEXT.md template missing its heading"
else
  record "template" "PASS" "company CONTEXT.md template present"
fi

# ─── table ──────────────────────────────────────────────────────────────────
echo
printf "  %-26s %-6s %s\n" "CHECK" "STATUS" "DETAIL"
printf "  %-26s %-6s %s\n" "-----" "------" "------"
for r in "${RESULTS[@]}"; do
  IFS='|' read -r name status detail <<< "$r"
  case "$status" in PASS) c="$GREEN" ;; FAIL) c="$RED" ;; *) c="$YELLOW" ;; esac
  printf "  %-26s ${c}%-6s${RESET} ${DIM}%s${RESET}\n" "$name" "$status" "$detail"
done
echo

if [ "$ANY_FAIL" -eq 0 ]; then
  echo "  ${GREEN}${BOLD}✓ Company wiring is sound.${RESET}"
  echo
  exit 0
else
  echo "  ${RED}${BOLD}✗ Company wiring has a problem — see the FAIL rows above.${RESET}"
  echo
  exit 1
fi
