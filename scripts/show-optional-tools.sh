#!/usr/bin/env bash
set -euo pipefail

# Path: scripts/show-optional-tools.sh
# Usage: bash scripts/show-optional-tools.sh [--print-only]
#
# Installs the basic WSL/Ubuntu prerequisites (apt: jq, git, curl, ca-certificates, python3, pipx, build tools),
# then prints the install commands of the optional tools for you to read.
#   --print-only   do not run apt. Only print the commands.
# It never installs or runs an optional tool: not RTK, LeanCTX, Headroom, Caveman, ccusage, Claude Code, or MemStack.
# It never runs "rtk init", "lean-ctx setup", "lean-ctx wrap", or "lean-ctx init", and it never installs a hook.
# (Those commands are shown below only as text, with the reason they are not recommended.)
# For the basic setup without the optional-tool list, use scripts/install-wsl.sh.

_PRINT_ONLY=false
case "${1:-}" in
  --print-only) _PRINT_ONLY=true ;;
  '') ;;
  -h|--help) sed -n '4,13p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) echo "Error: unknown option: $1" >&2; exit 2 ;;
esac

cat <<'INTRO'
Optional tools for Token Controller
===================================
Token Controller works without any of them. If one is missing, it falls back to raw output.
This script does NOT install them. It prints the commands. Read each one before you run it.
INTRO

if [ "$_PRINT_ONLY" = true ]; then
  echo "(--print-only: apt is not run.)"
else
  echo "Installing the basic prerequisites with apt (no optional tool)..."
  _sudo=""
  [ "$(id -u)" -eq 0 ] || _sudo="sudo"
  $_sudo apt-get update
  $_sudo apt-get install -y jq git curl ca-certificates bash coreutils python3 python3-pip python3-venv pipx build-essential
fi

cat <<'TOOLS'

Optional tool commands (text only, nothing below is run by this script)
=======================================================================

RTK:
  curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
  source ~/.bashrc
  rtk --version

  # NOT RECOMMENDED with wx. "rtk init" installs hooks or instructions that make agents run commands
  # through RTK directly, so wx raw capture is skipped for those commands.
  # Token Controller never runs it. "workflow doctor" warns if a hook exists.
  # rtk init -g --copilot
  # rtk init --show

Headroom:
  python3 -m venv ~/.venvs/headroom
  source ~/.venvs/headroom/bin/activate
  pip install --upgrade pip
  pip install "headroom-ai[all]"
  python -c "import headroom; print(headroom.__version__)"
  headroom proxy --port 8787

LeanCTX (choose one installation method; do not run both):
  # Cargo is the primary choice when a Rust toolchain is already installed.
  cargo install lean-ctx

  # OR use the universal installer when Rust is not installed.
  curl -fsSL https://leanctx.com/install.sh | sh

  source ~/.bashrc
  lean-ctx doctor
  # Token Controller never runs lean-ctx setup, wrap, or init. They edit host and MCP config and can add a shell hook
  # that conflicts with wx. Run them yourself only after you read what they change.

  # OPTIONAL: language servers are needed only for the ctx_refactor feature.
  # Core LeanCTX features do not require rust-analyzer or other LSP servers.
  rustup component add rust-analyzer
  npm install -g typescript-language-server typescript
  pip install python-lsp-server
  go install golang.org/x/tools/gopls@latest

Caveman (optional output-style skill; off by default in every Token Controller mode):
  # Claude Code plugin:
  claude plugin marketplace add JuliusBrussee/caveman && claude plugin install caveman@caveman
  # OR other agents (global; omit -g for one project):
  npx skills add JuliusBrussee/caveman -g
  # In a session, say "stop caveman" or "normal mode" to turn it off.
  # It adds input tokens and can cost more than it saves on short tasks.

ccusage (optional usage reports from local Claude Code logs; Token Controller does not install or run it):
  npm install -g ccusage
  ccusage --version

Node.js 18+ (needed for Claude Code):
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
  source ~/.bashrc
  nvm install 22
  nvm use 22

Claude Code:
  npm install -g @anthropic-ai/claude-code
  claude --version

MemStack (legacy, under review), Claude Code oriented:
  python3 -m venv ~/.venvs/memstack
  source ~/.venvs/memstack/bin/activate
  pip install --upgrade pip
  pip install memstack-skill-loader
  claude mcp add --scope user memstack-skills -- python -m memstack_skill_loader

After installing optional tools:
  source ~/.bashrc
  bash scripts/check-tools.sh
TOOLS
