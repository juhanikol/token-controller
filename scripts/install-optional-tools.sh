#!/usr/bin/env bash
set -euo pipefail

cat <<'INTRO'
This script installs only basic WSL/Ubuntu prerequisites automatically.
It then prints optional commands for RTK, Headroom, LeanCTX, MemStack, and Caveman.
Review each optional command before running it.
INTRO

sudo apt update
sudo apt upgrade -y
sudo apt install -y jq git curl ca-certificates bash coreutils python3 python3-pip python3-venv pipx build-essential

cat <<'TOOLS'

Optional tool commands
======================

RTK:
  curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
  source ~/.bashrc
  rtk --version
  rtk init -g --copilot
  rtk init --show

Headroom:
  python3 -m venv ~/.venvs/headroom
  source ~/.venvs/headroom/bin/activate
  pip install --upgrade pip
  pip install "headroom-ai[all]"
  python -c "import headroom; print(headroom.__version__)"
  headroom proxy --port 8787

LeanCTX:
  curl -fsSL https://leanctx.com/install.sh | sh
  source ~/.bashrc
  lean-ctx onboard
  lean-ctx doctor

MemStack, Claude Code oriented:
  python3 -m venv ~/.venvs/memstack
  source ~/.venvs/memstack/bin/activate
  pip install --upgrade pip
  pip install memstack-skill-loader
  claude mcp add --scope user memstack-skills -- python -m memstack_skill_loader

Node / Caveman:
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
  source ~/.bashrc
  nvm install 22
  nvm use 22
  curl -fsSL https://raw.githubusercontent.com/JuliusBrussee/caveman/main/install.sh | bash

After installing optional tools:
  source ~/.bashrc
  bash scripts/check-tools.sh
TOOLS
