#!/usr/bin/env bash
# Path: scripts/workflow-cli.sh
# Usage: scripts/workflow-cli.sh <mode|command> [options]
# Examples: workflow-cli.sh status --json | workflow-cli.sh code | workflow-cli.sh doctor --json
#
# Non-sourced entry point for tools (the VS Code extension, agents, scripts).
# It runs scripts/workflow.sh inside this Bash process and passes the arguments as they are (no eval).
# Because it is a separate process, it never changes the caller's shell variables.
# A mode switch writes ~/.config/ai-workflow/active_mode.env. wx and "status --json" read that file.
# Exit code: the exit code of the workflow command (0 ok, 1 failed, 2 usage error).

# This file must be run, not sourced. Sourcing would change the caller's shell.
if [ "${BASH_SOURCE[0]}" != "$0" ]; then
  printf 'Error: run scripts/workflow-cli.sh. Do not source it. To switch modes in this shell, source scripts/workflow.sh.\n' >&2
  return 2 2>/dev/null || exit 2
fi

# Follow symlinks so the CLI can be linked into a PATH directory.
_WORKFLOW_CLI_SELF="$(readlink -f -- "${BASH_SOURCE[0]}" 2>/dev/null)" || _WORKFLOW_CLI_SELF="${BASH_SOURCE[0]}"
_WORKFLOW_CLI_DIR="$(cd -- "$(dirname -- "$_WORKFLOW_CLI_SELF")" 2>/dev/null && pwd)" || {
  printf 'Error: cannot find the directory of workflow-cli.sh.\n' >&2
  exit 2
}
_WORKFLOW_CLI_TARGET="$_WORKFLOW_CLI_DIR/workflow.sh"

if [ ! -f "$_WORKFLOW_CLI_TARGET" ] || [ ! -r "$_WORKFLOW_CLI_TARGET" ]; then
  printf 'Error: workflow.sh not found beside workflow-cli.sh: %s\n' "$_WORKFLOW_CLI_TARGET" >&2
  exit 2
fi

# Used by workflow.sh in its usage text. Not exported.
AICONTEXT_ENTRYPOINT_NAME="scripts/workflow-cli.sh"

# shellcheck source=workflow.sh
source "$_WORKFLOW_CLI_TARGET" "$@"
exit $?
