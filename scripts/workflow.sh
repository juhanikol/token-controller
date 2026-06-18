#!/usr/bin/env bash
# Path: scripts/workflow.sh
# Usage: source scripts/workflow.sh <mode>
# Modes: raw scope architect decisions code snippet agent test test-full debug docs cicd review security migration db perf release off status
# Backward-compatible aliases: plan=architect, ci=cicd

# This script is intended to be sourced, because it exports variables to the current shell.
# It does not install token tools and does not invoke AI agents directly.

_ai_workflow_main() {
  local _MODE="${1:-status}"
  local _SCRIPT_SOURCE="${BASH_SOURCE[0]}"
  local _SCRIPT_DIR
  local _PROJECT_ROOT
  local _CONFIG_DIR
  local _SETTINGS_FILE
  local _ACTIVE_ENV_FILE

  _SCRIPT_DIR="$(cd "$(dirname "$_SCRIPT_SOURCE")" && pwd)"
  _PROJECT_ROOT="$(cd "$_SCRIPT_DIR/.." && pwd)"
  _CONFIG_DIR="${AICONTEXT_CONFIG_DIR:-$HOME/.config/ai-workflow}"
  _SETTINGS_FILE="${AICONTEXT_SETTINGS_FILE:-$_PROJECT_ROOT/config/workflow_settings.json}"
  _ACTIVE_ENV_FILE="$_CONFIG_DIR/active_mode.env"

  mkdir -p "$_CONFIG_DIR"

  usage() {
    cat <<USAGE
Usage: source scripts/workflow.sh <mode>

Modes:
  raw          No compression. Highest fidelity.
  scope        Requirements and scope discovery.
  architect    Architecture, structure, codebase overview.
  decisions    ADRs, domain models, schemas, types.
  code         Normal implementation work.
  data-analysis Data analysis, stats, and visualization.
  snippet      Small file/method/snippet review.
  agent        Agent-governance / AGENTS.md workflows.
  test         Unit/integration test runs.
  test-full    Full app / broad automated test routine.
  debug        Failure investigation and bug fixing.
  docs         Documentation creation and README work.
  cicd         CI/CD, Docker, package-manager and runner logs.
  review       Whole-codebase or PR review.
  security     Security, auth, secrets, vulnerability scans.
  migration    Large refactor or legacy migration.
  db           Database/schema/data migration.
  perf         Performance profiling and benchmarking.
  release      Release preparation.
  off          Disable all optimizers.
  status       Show current profile.

Aliases:
  plan -> architect
  ci   -> cicd
USAGE
  }

  need_jq() {
    if ! command -v jq >/dev/null 2>&1; then
      echo "Error: jq is missing. Install it with: sudo apt update && sudo apt install -y jq" >&2
      return 1
    fi
  }

  status() {
    echo "Current AI Context Workflow Status:"
    echo "  AICONTEXT_PROFILE=${AICONTEXT_PROFILE:-unset}"
    echo "  AICONTEXT_RISK=${AICONTEXT_RISK:-unset}"
    echo "  AICONTEXT_COMPRESS_SHELL=${AICONTEXT_COMPRESS_SHELL:-unset}"
    echo "  AICONTEXT_COMPRESS_FILES=${AICONTEXT_COMPRESS_FILES:-unset}"
    echo "  AICONTEXT_CODEBASE_INDEX=${AICONTEXT_CODEBASE_INDEX:-unset}"
    echo "  AICONTEXT_MEMORY_LAYER=${AICONTEXT_MEMORY_LAYER:-unset}"
    echo "  AICONTEXT_HEADROOM_MODE=${AICONTEXT_HEADROOM_MODE:-unset}"
    echo "  AICONTEXT_LEANCTX_MODE=${AICONTEXT_LEANCTX_MODE:-unset}"
    echo "  AICONTEXT_RTK_MODE=${AICONTEXT_RTK_MODE:-unset}"
    echo "  AICONTEXT_CAVEMAN_OUTPUT=${AICONTEXT_CAVEMAN_OUTPUT:-unset}"
    echo "  AICONTEXT_RAW_ON_FAIL=${AICONTEXT_RAW_ON_FAIL:-unset}"
    echo "  AICONTEXT_KEEP_RAW_LOGS=${AICONTEXT_KEEP_RAW_LOGS:-unset}"
    echo "  Active env cache: $_ACTIVE_ENV_FILE"
  }

  case "$_MODE" in
    -h|--help|help)
      usage
      return 0
      ;;
    status|"")
      status
      return 0
      ;;
    plan)
      _MODE="architect"
      ;;
    ci)
      _MODE="cicd"
      ;;
  esac

  if [ ! -f "$_SETTINGS_FILE" ]; then
    echo "Error: settings file not found: $_SETTINGS_FILE" >&2
    echo "Set AICONTEXT_SETTINGS_FILE or keep config/workflow_settings.json beside this script." >&2
    return 1
  fi

  need_jq || return 1

  if ! jq -e ".modes[\"$_MODE\"]" "$_SETTINGS_FILE" >/dev/null 2>&1; then
    echo "Error: profile '$_MODE' not found in $_SETTINGS_FILE" >&2
    usage >&2
    return 1
  fi

  export AICONTEXT_PROFILE="$_MODE"
  export AICONTEXT_RISK="$(jq -r ".modes[\"$_MODE\"].risk // \"normal\"" "$_SETTINGS_FILE")"
  export AICONTEXT_COMPRESS_SHELL="$(jq -r ".modes[\"$_MODE\"].compress_shell // \"safe\"" "$_SETTINGS_FILE")"
  export AICONTEXT_COMPRESS_FILES="$(jq -r ".modes[\"$_MODE\"].compress_files // \"safe\"" "$_SETTINGS_FILE")"
  export AICONTEXT_CODEBASE_INDEX="$(jq -r ".modes[\"$_MODE\"].codebase_index // false" "$_SETTINGS_FILE")"
  export AICONTEXT_MEMORY_LAYER="$(jq -r ".modes[\"$_MODE\"].memory_layer // \"off\"" "$_SETTINGS_FILE")"
  export AICONTEXT_HEADROOM_MODE="$(jq -r ".modes[\"$_MODE\"].headroom_mode // \"off\"" "$_SETTINGS_FILE")"
  export AICONTEXT_LEANCTX_MODE="$(jq -r ".modes[\"$_MODE\"].leanctx_mode // \"off\"" "$_SETTINGS_FILE")"
  export AICONTEXT_RTK_MODE="$(jq -r ".modes[\"$_MODE\"].rtk_mode // \"off\"" "$_SETTINGS_FILE")"
  export AICONTEXT_CAVEMAN_OUTPUT="$(jq -r ".modes[\"$_MODE\"].caveman_output // false" "$_SETTINGS_FILE")"
  export AICONTEXT_CACHE_ALIGN="$(jq -r ".modes[\"$_MODE\"].cache_align // .defaults.cache_align // true" "$_SETTINGS_FILE")"
  export AICONTEXT_RAW_ON_FAIL="$(jq -r ".modes[\"$_MODE\"].raw_on_fail // .defaults.raw_on_fail // true" "$_SETTINGS_FILE")"
  export AICONTEXT_KEEP_RAW_LOGS="$(jq -r ".modes[\"$_MODE\"].keep_raw_logs // .defaults.keep_raw_logs // true" "$_SETTINGS_FILE")"
  export AICONTEXT_AGENTS_MUTATION="$(jq -r ".modes[\"$_MODE\"].agents_mutation // .defaults.agents_mutation // \"deny\"" "$_SETTINGS_FILE")"
  export AICONTEXT_TARGET_FILES_FULL="$(jq -r ".modes[\"$_MODE\"].target_files_full // .defaults.target_files_full // true" "$_SETTINGS_FILE")"
  export AICONTEXT_PRESERVE_STDERR="$(jq -r ".modes[\"$_MODE\"].preserve_stderr // .defaults.preserve_stderr // true" "$_SETTINGS_FILE")"
  export AICONTEXT_PRESERVE_EXIT_CODE="$(jq -r ".modes[\"$_MODE\"].preserve_exit_code // .defaults.preserve_exit_code // true" "$_SETTINGS_FILE")"
  export AICONTEXT_PRESERVE_FIRST_ERROR="$(jq -r ".modes[\"$_MODE\"].preserve_first_error // .defaults.preserve_first_error // true" "$_SETTINGS_FILE")"
  export AICONTEXT_PRESERVE_WARNINGS="$(jq -r ".modes[\"$_MODE\"].preserve_warnings // .defaults.preserve_warnings // true" "$_SETTINGS_FILE")"
  export AICONTEXT_PRESERVE_NUMBERS="$(jq -r ".modes[\"$_MODE\"].preserve_numbers // .defaults.preserve_numbers // true" "$_SETTINGS_FILE")"
  export AICONTEXT_RAW_LOG_DIR="$(jq -r ".modes[\"$_MODE\"].raw_log_dir // .defaults.raw_log_dir // \".ai-context/raw\"" "$_SETTINGS_FILE")"
  export AICONTEXT_COMPRESSED_LOG_DIR="$(jq -r ".modes[\"$_MODE\"].compressed_log_dir // .defaults.compressed_log_dir // \".ai-context/compressed\"" "$_SETTINGS_FILE")"

  if [ "$AICONTEXT_RTK_MODE" = "off" ]; then
    export RTK_HOOK_ENABLED=false
  else
    export RTK_HOOK_ENABLED=true
  fi

  export HEADROOM_COMPRESSION_STRATEGY="$AICONTEXT_HEADROOM_MODE"
  export LEANCTX_ACTIVE="$AICONTEXT_LEANCTX_MODE"
  export MEMSTACK_ACTIVE="$AICONTEXT_CODEBASE_INDEX"
  export CAVEMAN_OUTPUT="$AICONTEXT_CAVEMAN_OUTPUT"

  cat > "$_ACTIVE_ENV_FILE" <<ENV
export AICONTEXT_PROFILE="$AICONTEXT_PROFILE"
export AICONTEXT_RISK="$AICONTEXT_RISK"
export AICONTEXT_COMPRESS_SHELL="$AICONTEXT_COMPRESS_SHELL"
export AICONTEXT_COMPRESS_FILES="$AICONTEXT_COMPRESS_FILES"
export AICONTEXT_CODEBASE_INDEX="$AICONTEXT_CODEBASE_INDEX"
export AICONTEXT_MEMORY_LAYER="$AICONTEXT_MEMORY_LAYER"
export AICONTEXT_HEADROOM_MODE="$AICONTEXT_HEADROOM_MODE"
export AICONTEXT_LEANCTX_MODE="$AICONTEXT_LEANCTX_MODE"
export AICONTEXT_RTK_MODE="$AICONTEXT_RTK_MODE"
export AICONTEXT_CAVEMAN_OUTPUT="$AICONTEXT_CAVEMAN_OUTPUT"
export AICONTEXT_CACHE_ALIGN="$AICONTEXT_CACHE_ALIGN"
export AICONTEXT_RAW_ON_FAIL="$AICONTEXT_RAW_ON_FAIL"
export AICONTEXT_KEEP_RAW_LOGS="$AICONTEXT_KEEP_RAW_LOGS"
export AICONTEXT_AGENTS_MUTATION="$AICONTEXT_AGENTS_MUTATION"
export AICONTEXT_TARGET_FILES_FULL="$AICONTEXT_TARGET_FILES_FULL"
export AICONTEXT_PRESERVE_STDERR="$AICONTEXT_PRESERVE_STDERR"
export AICONTEXT_PRESERVE_EXIT_CODE="$AICONTEXT_PRESERVE_EXIT_CODE"
export AICONTEXT_PRESERVE_FIRST_ERROR="$AICONTEXT_PRESERVE_FIRST_ERROR"
export AICONTEXT_PRESERVE_WARNINGS="$AICONTEXT_PRESERVE_WARNINGS"
export AICONTEXT_PRESERVE_NUMBERS="$AICONTEXT_PRESERVE_NUMBERS"
export AICONTEXT_RAW_LOG_DIR="$AICONTEXT_RAW_LOG_DIR"
export AICONTEXT_COMPRESSED_LOG_DIR="$AICONTEXT_COMPRESSED_LOG_DIR"
export RTK_HOOK_ENABLED="$RTK_HOOK_ENABLED"
export HEADROOM_COMPRESSION_STRATEGY="$HEADROOM_COMPRESSION_STRATEGY"
export LEANCTX_ACTIVE="$LEANCTX_ACTIVE"
export MEMSTACK_ACTIVE="$MEMSTACK_ACTIVE"
export CAVEMAN_OUTPUT="$CAVEMAN_OUTPUT"
ENV

  printf 'Activated AI context profile: %s\n' "$AICONTEXT_PROFILE"
  printf '  risk=%s shell=%s files=%s index=%s memory=%s\n' "$AICONTEXT_RISK" "$AICONTEXT_COMPRESS_SHELL" "$AICONTEXT_COMPRESS_FILES" "$AICONTEXT_CODEBASE_INDEX" "$AICONTEXT_MEMORY_LAYER"
  printf '  rtk=%s headroom=%s leanctx=%s caveman=%s raw_on_fail=%s\n' "$AICONTEXT_RTK_MODE" "$AICONTEXT_HEADROOM_MODE" "$AICONTEXT_LEANCTX_MODE" "$AICONTEXT_CAVEMAN_OUTPUT" "$AICONTEXT_RAW_ON_FAIL"
  printf '  env_cache=%s\n' "$_ACTIVE_ENV_FILE"

  return 0
}

_ai_workflow_main "$@"
