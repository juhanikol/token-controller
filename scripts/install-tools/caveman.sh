#!/usr/bin/env bash
# Path: scripts/install-tools/caveman.sh
# Usage: bash scripts/install-tools/caveman.sh [--dry-run]
# Installs the Caveman plugin for Claude Code after you confirm. Needs the "claude" command. It does not install Claude Code.
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/common.sh"

it_parse_common "$@"
if [ "${#_REST[@]}" -gt 0 ]; then echo "Error: unknown option: ${_REST[0]}" >&2; echo "Usage: bash scripts/install-tools/caveman.sh [--dry-run]" >&2; exit 2; fi

it_banner Caveman "https://github.com/JuliusBrussee/caveman"
cat <<'PLAN'

It would run (Claude Code plugin commands, user level):
  claude plugin marketplace add JuliusBrussee/caveman
  claude plugin install caveman@caveman

Read this first: a Claude Code plugin can register hooks and skills. This helper cannot see what the plugin contains today,
so look at the upstream repository before you confirm. Caveman shortens assistant replies. It adds input tokens and can cost
more than it saves on short tasks.
Token Controller keeps Caveman OFF. It is blocked in docs, security, db, release, migration, and debug work. Opt in per activation:
  AICONTEXT_CAVEMAN_REQUEST=lite workflow code
PLAN
if ! command -v claude >/dev/null 2>&1; then
  echo
  echo "The claude command was not found. Caveman for Claude Code needs Claude Code first. This helper does not install it."
  [ "$_DRY_RUN" = true ] && exit 0
  exit 1
fi
if [ "$_DRY_RUN" = true ]; then echo "(--dry-run: nothing was run.)"; exit 0; fi
it_confirm "Install the Caveman plugin now?" || exit 0

claude plugin marketplace add JuliusBrussee/caveman
claude plugin install caveman@caveman
echo
echo "Done. Say \"stop caveman\" or \"normal mode\" in a session to turn it off. Check the setup with: workflow doctor"
