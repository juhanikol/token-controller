#!/usr/bin/env bash
set -u

printf 'AI Context Workflow tool check\n'
printf '================================\n'

check() {
  local name="$1"
  local cmd="$2"
  local hint="$3"
  if command -v "$cmd" >/dev/null 2>&1; then
    printf 'OK      %-12s %s\n' "$name" "$(command -v "$cmd")"
    "$cmd" --version 2>/dev/null | head -n 1 || true
  else
    printf 'MISSING %s. %s\n' "$name" "$hint"
  fi
}

check jq jq 'To install: sudo apt install -y jq'
check git git 'To install: sudo apt install -y git'
check curl curl 'To install: sudo apt install -y curl'
check python3 python3 'To install: sudo apt install -y python3'
check pip3 pip3 'To install: sudo apt install -y python3-pip'
check node node 'To install: install Node.js 18+ with nvm (see scripts/install-optional-tools.sh)'
check npm npm 'To install: install Node.js 18+ with nvm (see scripts/install-optional-tools.sh)'
check rtk rtk 'To install: review the RTK commands in scripts/install-optional-tools.sh'
check headroom headroom 'To install: create ~/.venvs/headroom, then run pip install "headroom-ai[all]"'
check lean-ctx lean-ctx 'To install core: cargo install lean-ctx'
check claude claude 'To install: npm install -g @anthropic-ai/claude-code'
check caveman caveman 'Optional tool: review the August 2026 warning in scripts/install-optional-tools.sh before installing'

printf '\nActive AI context env cache:\n'
if [ -f "$HOME/.config/ai-workflow/active_mode.env" ]; then
  cat "$HOME/.config/ai-workflow/active_mode.env"
else
  printf 'No active env cache found. Run: source scripts/workflow.sh code\n'
fi
