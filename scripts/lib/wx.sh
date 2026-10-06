#!/usr/bin/env bash

# Public command wrapper sourced by scripts/workflow.sh.
# The command runs in a subshell so capture mechanics cannot alter the caller's shell.

_WX_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -z "${AICONTEXT_SETTINGS_FILE:-}" ]; then
  export AICONTEXT_SETTINGS_FILE="$(cd "$_WX_LIB_DIR/../.." && pwd)/config/workflow_settings.json"
fi
# shellcheck source=wx-compress.sh
source "$_WX_LIB_DIR/wx-compress.sh"
unset _WX_LIB_DIR

# Policy state precedence. wx is the safety layer, so the active mode file wins over shell variables.
#   1. active_mode.env ($AICONTEXT_CONFIG_DIR or ~/.config/ai-workflow) when it is a readable file.
#      Stale AICONTEXT_* shell variables are dropped first, so an old terminal cannot keep an old profile.
#   2. Shell AICONTEXT_* variables, when the file is missing or unreadable.
# Escape hatch: AICONTEXT_USE_SHELL_STATE=true keeps the shell variables. The file is read only when no profile is set.
# The file is parsed, not sourced. Only lines like: export AICONTEXT_NAME="plain value" are used.
# Sets _WX_POLICY_SOURCE (active_mode.env or shell) and _WX_STALE_SHELL_PROFILE (the shell profile that was replaced).
_wx_apply_env_file() {
  local _WX_FILE="$1"
  local _WX_LINE
  local _WX_NAME
  local _WX_VALUE
  local _WX_LINE_PATTERN='^export[[:space:]]+(AICONTEXT_[A-Z0-9_]+)="([^"$`\\]*)"[[:space:]]*$'

  while IFS= read -r _WX_LINE || [ -n "$_WX_LINE" ]; do
    if [[ "$_WX_LINE" =~ $_WX_LINE_PATTERN ]]; then
      _WX_NAME="${BASH_REMATCH[1]}"
      _WX_VALUE="${BASH_REMATCH[2]}"
      case "$_WX_NAME" in
        AICONTEXT_SETTINGS_FILE|AICONTEXT_CONFIG_DIR|AICONTEXT_USE_SHELL_STATE) ;;
        *) export "$_WX_NAME=$_WX_VALUE" ;;
      esac
    fi
  done < "$_WX_FILE"
}

# Drop every AICONTEXT_* policy variable. Path and override settings stay. Call it only in a subshell
# or inside wx, never in the caller's own shell.
_wx_unset_policy_state() {
  local _WX_NAME

  while IFS= read -r _WX_NAME; do
    case "$_WX_NAME" in
      AICONTEXT_SETTINGS_FILE|AICONTEXT_CONFIG_DIR|AICONTEXT_USE_SHELL_STATE) ;;
      *) unset "$_WX_NAME" ;;
    esac
  done < <(compgen -A variable AICONTEXT_)
}

_wx_load_policy_state() {
  local _WX_FILE="$1"
  local _WX_SHELL_PROFILE="${AICONTEXT_PROFILE:-}"

  _WX_POLICY_SOURCE=shell
  _WX_STALE_SHELL_PROFILE=""

  if [ "${AICONTEXT_USE_SHELL_STATE:-}" = true ]; then
    if [ -z "$_WX_SHELL_PROFILE" ] && [ -f "$_WX_FILE" ] && [ -r "$_WX_FILE" ]; then
      _wx_apply_env_file "$_WX_FILE"
      _WX_POLICY_SOURCE=active_mode.env
    fi
    return 0
  fi

  if [ ! -f "$_WX_FILE" ] || [ ! -r "$_WX_FILE" ]; then
    return 0
  fi

  _wx_unset_policy_state
  _wx_apply_env_file "$_WX_FILE"
  _WX_POLICY_SOURCE=active_mode.env

  if [ -z "${AICONTEXT_PROFILE:-}" ]; then
    # No usable profile. All policy variables stay unset, so wx emits raw output.
    printf 'wx: warning: %s has no profile. Output stays raw.\n' "$_WX_FILE" >&2
  elif [ -n "$_WX_SHELL_PROFILE" ] && [ "$_WX_SHELL_PROFILE" != "$AICONTEXT_PROFILE" ]; then
    _WX_STALE_SHELL_PROFILE="$_WX_SHELL_PROFILE"
  fi
}

workflow_run() (
  if [ "$#" -eq 0 ]; then
    printf 'Usage: wx <command> [args...]\n' >&2
    return 2
  fi

  if ! command -v jq >/dev/null 2>&1; then
    printf 'wx: jq is required to write session metadata.\n' >&2
    return 125
  fi

  local _WX_CWD="$PWD"
  local _WX_CONTEXT_DIR="$_WX_CWD/.ai-context"
  local _WX_RAW_ROOT="${AICONTEXT_RAW_LOG_DIR:-.ai-context/raw}"
  local _WX_SESSION_FILE="$_WX_CONTEXT_DIR/session.jsonl"
  local _WX_ACTIVE_ENV_FILE="${AICONTEXT_CONFIG_DIR:-$HOME/.config/ai-workflow}/active_mode.env"
  local _WX_SETTINGS_FILE="${AICONTEXT_SETTINGS_FILE}"
  local _WX_STARTED_AT
  local _WX_RUN_STAMP
  local _WX_RUN_DIR
  local _WX_STDOUT_FILE
  local _WX_STDERR_FILE
  local _WX_EXIT_CODE
  local _WX_COMPLETED_AT
  local _WX_COMMAND_JSON
  local _WX_METADATA
  local _WX_STDOUT_BYTES
  local _WX_STDERR_BYTES
  local _WX_VISIBLE_STDOUT_FILE
  local _WX_VISIBLE_STDERR_FILE
  local _WX_VISIBLE_STDOUT_BYTES
  local _WX_VISIBLE_STDERR_BYTES
  local _WX_OUTPUT_POLICY
  local _WX_POLICY_AVAILABLE=true

  _wx_load_policy_state "$_WX_ACTIVE_ENV_FILE"
  # The raw log directory can come from the active mode file, so read it after loading.
  _WX_RAW_ROOT="${AICONTEXT_RAW_LOG_DIR:-.ai-context/raw}"
  if [ -n "$_WX_STALE_SHELL_PROFILE" ]; then
    printf 'wx: note: this shell has profile "%s". Using profile "%s" from active_mode.env.\n' "$_WX_STALE_SHELL_PROFILE" "$AICONTEXT_PROFILE" >&2
  fi

  if [ ! -r "$_WX_SETTINGS_FILE" ] ||
    ! jq -e '.command_policy.noisy_success_can_compress and .command_policy.preserve_raw_or_lossless' "$_WX_SETTINGS_FILE" >/dev/null 2>&1; then
    _WX_POLICY_AVAILABLE=false
  fi

  case "$_WX_RAW_ROOT" in
    /*) ;;
    *) _WX_RAW_ROOT="$_WX_CWD/$_WX_RAW_ROOT" ;;
  esac

  if [ -L "$_WX_CONTEXT_DIR" ] || [ -L "$_WX_RAW_ROOT" ] || [ -L "$_WX_SESSION_FILE" ]; then
    printf 'wx: refusing to write through a symlinked context path.\n' >&2
    return 125
  fi

  umask 077
  if ! mkdir -p -- "$_WX_CONTEXT_DIR" "$_WX_RAW_ROOT"; then
    printf 'wx: could not create raw log directory: %s\n' "$_WX_RAW_ROOT" >&2
    return 125
  fi
  if ! : >> "$_WX_SESSION_FILE"; then
    printf 'wx: could not open session metadata file: %s\n' "$_WX_SESSION_FILE" >&2
    return 125
  fi

  _WX_STARTED_AT="$(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ')" || return 125
  _WX_RUN_STAMP="$(date -u '+%Y%m%dT%H%M%S.%3NZ')" || return 125
  if ! _WX_RUN_DIR="$(mktemp -d "$_WX_RAW_ROOT/${_WX_RUN_STAMP}-$$.XXXXXX")"; then
    printf 'wx: could not create a unique raw log directory under: %s\n' "$_WX_RAW_ROOT" >&2
    return 125
  fi

  _WX_STDOUT_FILE="$_WX_RUN_DIR/stdout.raw"
  _WX_STDERR_FILE="$_WX_RUN_DIR/stderr.raw"

  set +e
  command "$@" >"$_WX_STDOUT_FILE" 2>"$_WX_STDERR_FILE"
  _WX_EXIT_CODE=$?
  _WX_COMPLETED_AT="$(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ')"

  _WX_STDOUT_BYTES="$(stat -c '%s' "$_WX_STDOUT_FILE")"
  _WX_STDERR_BYTES="$(stat -c '%s' "$_WX_STDERR_FILE")"

  _WX_VISIBLE_STDOUT_FILE="$_WX_STDOUT_FILE"
  _WX_VISIBLE_STDERR_FILE="$_WX_STDERR_FILE"
  if [ "$_WX_POLICY_AVAILABLE" = true ]; then
    _WX_OUTPUT_POLICY="$(_wx_select_output_policy "$_WX_SETTINGS_FILE" "$_WX_EXIT_CODE" "$@")"
  else
    _WX_OUTPUT_POLICY='raw-policy-unavailable'
  fi

  if [ "$_WX_OUTPUT_POLICY" = 'compress-exact-repeats-v1' ]; then
    if [ -s "$_WX_STDOUT_FILE" ] && LC_ALL=C grep -Iq . "$_WX_STDOUT_FILE"; then
      _WX_VISIBLE_STDOUT_FILE="$_WX_RUN_DIR/stdout.visible"
      if _wx_compress_exact_repeats "$_WX_STDOUT_FILE" "$_WX_VISIBLE_STDOUT_FILE"; then
        _WX_VISIBLE_STDOUT_BYTES="$(stat -c '%s' "$_WX_VISIBLE_STDOUT_FILE")"
        if [ "$_WX_VISIBLE_STDOUT_BYTES" -ge "$_WX_STDOUT_BYTES" ]; then
          _WX_VISIBLE_STDOUT_FILE="$_WX_STDOUT_FILE"
          _WX_OUTPUT_POLICY='raw-compression-not-smaller'
        fi
      else
        _WX_VISIBLE_STDOUT_FILE="$_WX_STDOUT_FILE"
        _WX_OUTPUT_POLICY='raw-compression-fallback'
      fi
    else
      _WX_OUTPUT_POLICY='raw-empty-or-binary-output'
    fi
  fi

  _WX_VISIBLE_STDOUT_BYTES="$(stat -c '%s' "$_WX_VISIBLE_STDOUT_FILE")"
  _WX_VISIBLE_STDERR_BYTES="$(stat -c '%s' "$_WX_VISIBLE_STDERR_FILE")"
  _WX_COMMAND_JSON="$(jq -cn --args '$ARGS.positional' -- "$@")"
  _WX_METADATA="$(
    jq -cn \
      --arg started_at "$_WX_STARTED_AT" \
      --arg completed_at "$_WX_COMPLETED_AT" \
      --arg cwd "$_WX_CWD" \
      --argjson command "$_WX_COMMAND_JSON" \
      --arg stdout_path "$_WX_STDOUT_FILE" \
      --arg stderr_path "$_WX_STDERR_FILE" \
      --arg visible_stdout_path "$_WX_VISIBLE_STDOUT_FILE" \
      --arg visible_stderr_path "$_WX_VISIBLE_STDERR_FILE" \
      --arg profile "${AICONTEXT_PROFILE:-unset}" \
      --arg output_policy "$_WX_OUTPUT_POLICY" \
      --arg policy_source "$_WX_POLICY_SOURCE" \
      --arg stale_shell_profile "$_WX_STALE_SHELL_PROFILE" \
      --argjson stdout_bytes "$_WX_STDOUT_BYTES" \
      --argjson stderr_bytes "$_WX_STDERR_BYTES" \
      --argjson visible_stdout_bytes "$_WX_VISIBLE_STDOUT_BYTES" \
      --argjson visible_stderr_bytes "$_WX_VISIBLE_STDERR_BYTES" \
      --argjson exit_code "$_WX_EXIT_CODE" \
      '{
        schema_version: 2,
        started_at: $started_at,
        completed_at: $completed_at,
        cwd: $cwd,
        command: $command,
        profile: $profile,
        output_policy: $output_policy,
        policy_source: $policy_source,
        stale_shell_profile: (if $stale_shell_profile == "" then null else $stale_shell_profile end),
        stdout: {path: $stdout_path, bytes: $stdout_bytes},
        stderr: {path: $stderr_path, bytes: $stderr_bytes},
        raw: {
          stdout_bytes: $stdout_bytes,
          stderr_bytes: $stderr_bytes
        },
        visible: {
          stdout_path: $visible_stdout_path,
          stderr_path: $visible_stderr_path,
          stdout_bytes: $visible_stdout_bytes,
          stderr_bytes: $visible_stderr_bytes
        },
        exit_code: $exit_code
      }'
  )"

  if [ -n "$_WX_METADATA" ]; then
    if ! printf '%s\n' "$_WX_METADATA" >> "$_WX_SESSION_FILE"; then
      printf 'wx: warning: could not append session metadata: %s\n' "$_WX_SESSION_FILE" >&2
    fi
  else
    printf 'wx: warning: could not generate session metadata.\n' >&2
  fi

  command cat -- "$_WX_VISIBLE_STDOUT_FILE"
  command cat -- "$_WX_VISIBLE_STDERR_FILE" >&2
  printf '[wx] raw logs: %s\n' "$_WX_RUN_DIR" >&2

  return "$_WX_EXIT_CODE"
)

wx() {
  workflow_run "$@"
}

export -f _wx_apply_env_file _wx_unset_policy_state _wx_load_policy_state workflow_run wx
