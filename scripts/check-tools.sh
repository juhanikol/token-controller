#!/usr/bin/env bash
set -u

printf 'AI Context Workflow tool check\n'
printf '================================\n'

check() {
  local name="$1"
  local cmd="$2"
  if command -v "$cmd" >/dev/null 2>&1; then
    printf 'OK      %-12s %s\n' "$name" "$(command -v "$cmd")"
    "$cmd" --version 2>/dev/null | head -n 1 || true
  else
    printf 'MISSING %-12s command not found: %s\n' "$name" "$cmd"
  fi
}

check jq jq
check git git
check curl curl
check python3 python3
check pip3 pip3
check node node
check npm npm
check rtk rtk
check headroom headroom
check lean-ctx lean-ctx
check claude claude
check caveman caveman

printf '\nActive AI context env cache:\n'
if [ -f "$HOME/.config/ai-workflow/active_mode.env" ]; then
  cat "$HOME/.config/ai-workflow/active_mode.env"
else
  printf 'No active env cache found. Run: source scripts/workflow.sh code\n'
fi
