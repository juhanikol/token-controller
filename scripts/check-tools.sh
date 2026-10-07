#!/usr/bin/env bash
set -u

printf 'AI Context Workflow tool check\n'
printf '================================\n'
printf 'Note: workflow <mode> only exports AICONTEXT_* policy. wx captures raw output first, and then may run rtk pipe on it (only for commands with a pipe entry in the config). wx does not invoke LeanCTX, Headroom, MemStack, or Caveman. workflow leanctx runs bounded lean-ctx CLI commands on request. Each tool needs its own shell/IDE/MCP setup.\n'

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

check_caveman() {
  local claude_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
  local found=""
  local entry

  if command -v caveman >/dev/null 2>&1; then
    check caveman caveman 'Optional.'
    return
  fi
  # Caveman is mainly a Claude Code plugin or skill. Look for its state only. Nothing is run.
  for entry in "$claude_dir"/skills/caveman* "$claude_dir/.caveman-active"; do
    if [ -e "$entry" ]; then
      found="$entry"
      break
    fi
  done
  if [ -n "$found" ]; then
    printf 'OK      %-12s %s (plugin/skill state; no caveman command on PATH)\n' caveman "$found"
  else
    printf 'MISSING caveman. Optional. Off by default in every mode. See scripts/show-optional-tools.sh\n'
  fi
}

check_python_module() {
  local name="$1"
  local python_path="$2"
  local module="$3"
  local hint="$4"
  if [ -x "$python_path" ] && "$python_path" -c "import $module" >/dev/null 2>&1; then
    printf 'OK      %-12s %s\n' "$name" "$python_path -m $module"
  else
    printf 'MISSING %s. %s\n' "$name" "$hint"
  fi
}

check jq jq 'To install: sudo apt install -y jq'
check git git 'To install: sudo apt install -y git'
check curl curl 'To install: sudo apt install -y curl'
check python3 python3 'To install: sudo apt install -y python3'
check pip3 pip3 'To install: sudo apt install -y python3-pip'
check node node 'To install: install Node.js 18+ with nvm (see scripts/show-optional-tools.sh)'
check npm npm 'To install: install Node.js 18+ with nvm (see scripts/show-optional-tools.sh)'
check rtk rtk 'To install: review the RTK commands in scripts/show-optional-tools.sh'
check headroom headroom 'To install: create ~/.venvs/headroom, then run pip install "headroom-ai[all]"'
check lean-ctx lean-ctx 'To install core: cargo install lean-ctx'
check ccusage ccusage 'Optional usage reports. To install: npm install -g ccusage (Token Controller does not install it)'
check claude claude 'To install: npm install -g @anthropic-ai/claude-code'
check_caveman
# MemStack is a legacy integration. Its status is under review.
check_python_module MemStack "$HOME/.venvs/memstack/bin/python" memstack_skill_loader 'To install: create ~/.venvs/memstack, then run pip install memstack-skill-loader'

printf '\nActive AI context env cache:\n'
if [ -f "$HOME/.config/ai-workflow/active_mode.env" ]; then
  cat "$HOME/.config/ai-workflow/active_mode.env"
else
  printf 'No active env cache found. Run: source scripts/workflow.sh code\n'
fi
