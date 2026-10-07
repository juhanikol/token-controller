#!/usr/bin/env bash

# Return success when the command argv starts with a configured policy command.
_wx_command_matches_policy() {
  local _WX_SETTINGS_FILE="$1"
  local _WX_POLICY_NAME="$2"
  shift 2

  local -a _WX_COMMAND_ARGV=("$@")
  local -a _WX_POLICY_WORDS
  local _WX_POLICY_COMMAND
  local _WX_INDEX
  local _WX_MATCH

  while IFS= read -r _WX_POLICY_COMMAND; do
    [ -n "$_WX_POLICY_COMMAND" ] || continue
    read -r -a _WX_POLICY_WORDS <<< "$_WX_POLICY_COMMAND"
    [ "${#_WX_POLICY_WORDS[@]}" -gt 0 ] || continue
    [ "${#_WX_COMMAND_ARGV[@]}" -ge "${#_WX_POLICY_WORDS[@]}" ] || continue

    _WX_MATCH=true
    for ((_WX_INDEX = 0; _WX_INDEX < ${#_WX_POLICY_WORDS[@]}; _WX_INDEX++)); do
      if [ "${_WX_COMMAND_ARGV[$_WX_INDEX]}" != "${_WX_POLICY_WORDS[$_WX_INDEX]}" ]; then
        _WX_MATCH=false
        break
      fi
    done
    if [ "$_WX_MATCH" = true ]; then
      return 0
    fi
  done < <(jq -r --arg policy "$_WX_POLICY_NAME" '.command_policy[$policy][]?' "$_WX_SETTINGS_FILE")

  return 1
}

# RTK is allowed when the mode sets rtk_mode to anything except off. Protected profiles and commands,
# and nonzero exits, are handled before this is asked (see _wx_select_output_policy).
_wx_rtk_enabled() {
  case "${AICONTEXT_RTK_MODE:-off}" in
    ''|off|off-*) return 1 ;;
  esac
  return 0
}

# Filters that must not be used yet: their output is evidence (search results, diffs, status).
_wx_rtk_filter_denied() {
  case "$1" in
    grep|rg|find|fd|git-diff|git-status|git-log) return 0 ;;
  esac
  return 1
}

# Print the RTK filter for a command (argv prefix match against command_policy.rtk_filters).
# Prints nothing and returns 1 when the command has no filter, or the filter is denied or not a plain name.
_wx_rtk_filter_for_command() {
  local _WX_SETTINGS_FILE="$1"
  shift

  local -a _WX_COMMAND_ARGV=("$@")
  local -a _WX_KEY_WORDS
  local _WX_KEY
  local _WX_FILTER
  local _WX_INDEX
  local _WX_MATCH

  while IFS=$'\t' read -r _WX_KEY _WX_FILTER; do
    [ -n "$_WX_KEY" ] && [ -n "$_WX_FILTER" ] || continue
    read -r -a _WX_KEY_WORDS <<< "$_WX_KEY"
    [ "${#_WX_KEY_WORDS[@]}" -gt 0 ] || continue
    [ "${#_WX_COMMAND_ARGV[@]}" -ge "${#_WX_KEY_WORDS[@]}" ] || continue

    _WX_MATCH=true
    for ((_WX_INDEX = 0; _WX_INDEX < ${#_WX_KEY_WORDS[@]}; _WX_INDEX++)); do
      if [ "${_WX_COMMAND_ARGV[$_WX_INDEX]}" != "${_WX_KEY_WORDS[$_WX_INDEX]}" ]; then
        _WX_MATCH=false
        break
      fi
    done
    if [ "$_WX_MATCH" = true ]; then
      case "$_WX_FILTER" in
        *[!a-z0-9-]*) return 1 ;;
      esac
      _wx_rtk_filter_denied "$_WX_FILTER" && return 1
      printf '%s\n' "$_WX_FILTER"
      return 0
    fi
  done < <(jq -r '(.command_policy.rtk_filters // {}) | to_entries[] | "\(.key)\t\(.value)"' "$_WX_SETTINGS_FILE" 2>/dev/null)

  return 1
}

# Evidence guard v1. Lines in the raw stdout that look like evidence must still be in the RTK output.
# Evidence lines: start with error: / error[ / warning: / warning[ / warn: / fatal: / panic:, or start with an
# upper-case WARN / WARNING / ERROR / FATAL token, or contain Traceback, FAILED, CVE-, ": error", ": warning",
# "Warning:", " error TS". The match is on the trimmed line as plain text.
# A false alarm only shows raw output. A dropped warning would hide evidence.
# Returns 0 when every evidence line is present, 1 when one is missing.
_wx_evidence_guard() {
  local _WX_RAW_FILE="$1"
  local _WX_VISIBLE_FILE="$2"

  LC_ALL=C awk '
    FILENAME == ARGV[1] { visible = visible $0 "\n"; next }
    {
      line = $0
      sub(/^[ \t]+/, "", line)
      sub(/[ \t\r]+$/, "", line)
      if (line == "") { next }
      lower = tolower(line)
      evidence = 0
      if (lower ~ /^(error|warning|warn|fatal)[:\[]/) { evidence = 1 }
      else if (line ~ /^(WARN|WARNING|ERROR|FATAL)([^A-Za-z]|$)/) { evidence = 1 }
      else if (line ~ /^panic:/) { evidence = 1 }
      else if (index(line, "Traceback") || index(line, "FAILED") || index(line, "CVE-")) { evidence = 1 }
      else if (index(lower, ": error") || index(lower, ": warning") || index(line, "Warning:") || index(line, " error TS")) { evidence = 1 }
      if (evidence && index(visible, line) == 0) { missing = 1; exit }
    }
    END { exit missing ? 1 : 0 }
  ' "$_WX_VISIBLE_FILE" "$_WX_RAW_FILE"
}

# Try an RTK filter on the captured stdout. The raw files already exist and are never changed.
# Only "rtk --version" and "rtk pipe -f <filter>" are run. Never "rtk init". Never touches RTK config.
# Args: raw stdout file, run directory, filter name.
# Sets _WX_FILTER, _WX_COMPRESSOR (rtk when applied), _WX_COMPRESSOR_VERSION, _WX_FALLBACK_REASON.
# Success: the filtered output is in <run dir>/stdout.visible, return 0.
# Fallback: the caller keeps the raw output, return 1. A rejected RTK output stays in <run dir>/rtk.rejected.stdout.
_wx_try_rtk() {
  local _WX_RAW_FILE="$1"
  local _WX_RUN_DIR="$2"
  local _WX_FILTER_NAME="$3"
  local _WX_BIN="${AICONTEXT_RTK_BIN:-rtk}"
  local _WX_TIMEOUT="${AICONTEXT_RTK_TIMEOUT:-10}"
  local _WX_OUT="$_WX_RUN_DIR/stdout.visible"
  local _WX_ERR="$_WX_RUN_DIR/rtk.stderr"
  local _WX_RESOLVED
  local _WX_VERSION
  local _WX_STATUS
  local _WX_RAW_BYTES
  local _WX_OUT_BYTES

  _WX_FILTER="$_WX_FILTER_NAME"
  _WX_COMPRESSOR=""
  _WX_COMPRESSOR_VERSION=""
  _WX_FALLBACK_REASON=""

  case "$_WX_TIMEOUT" in
    ''|*[!0-9]*|0) _WX_TIMEOUT=10 ;;
  esac

  if ! _WX_RESOLVED="$(command -v "$_WX_BIN" 2>/dev/null)" || [ ! -x "$_WX_RESOLVED" ]; then
    _WX_FALLBACK_REASON='rtk-not-installed'
    return 1
  fi

  _WX_VERSION="$(timeout 3 "$_WX_RESOLVED" --version </dev/null 2>/dev/null | head -n 1 |
    sed -n 's/.*\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*[^[:space:]]*\).*/\1/p')"
  if [ -z "$_WX_VERSION" ]; then
    _WX_FALLBACK_REASON='rtk-version-failed'
    return 1
  fi
  _WX_COMPRESSOR_VERSION="$_WX_VERSION"

  timeout "$_WX_TIMEOUT" "$_WX_RESOLVED" pipe -f "$_WX_FILTER_NAME" <"$_WX_RAW_FILE" >"$_WX_OUT" 2>"$_WX_ERR"
  _WX_STATUS=$?

  if [ "$_WX_STATUS" -eq 124 ]; then
    _WX_FALLBACK_REASON='rtk-timeout'
  elif [ "$_WX_STATUS" -ne 0 ]; then
    _WX_FALLBACK_REASON='rtk-nonzero-exit'
  else
    _WX_RAW_BYTES="$(stat -c '%s' "$_WX_RAW_FILE")"
    _WX_OUT_BYTES="$(stat -c '%s' "$_WX_OUT")"
    if [ "$_WX_OUT_BYTES" -eq 0 ]; then
      _WX_FALLBACK_REASON='rtk-empty-output'
    elif [ "$_WX_OUT_BYTES" -ge "$_WX_RAW_BYTES" ]; then
      _WX_FALLBACK_REASON='rtk-not-smaller'
    elif ! _wx_evidence_guard "$_WX_RAW_FILE" "$_WX_OUT"; then
      _WX_FALLBACK_REASON='evidence-guard'
    fi
  fi

  if [ -n "$_WX_FALLBACK_REASON" ]; then
    mv -f -- "$_WX_OUT" "$_WX_RUN_DIR/rtk.rejected.stdout" 2>/dev/null || rm -f -- "$_WX_OUT"
    return 1
  fi

  _WX_COMPRESSOR=rtk
  return 0
}

_wx_select_output_policy() {
  local _WX_SETTINGS_FILE="$1"
  local _WX_EXIT_CODE="$2"
  shift 2

  case "${AICONTEXT_PROFILE:-}" in
    raw|security|db|release|migration)
      printf '%s\n' 'raw-protected-profile'
      return 0
      ;;
  esac

  if _wx_command_matches_policy "$_WX_SETTINGS_FILE" preserve_raw_or_lossless "$@"; then
    printf '%s\n' 'raw-protected-command'
    return 0
  fi

  if [ "$_WX_EXIT_CODE" -ne 0 ]; then
    printf '%s\n' 'raw-nonzero-exit'
    return 0
  fi

  case "${AICONTEXT_COMPRESS_SHELL:-}" in
    ''|off|off-*)
      printf '%s\n' 'raw-compression-disabled'
      return 0
      ;;
  esac

  # RTK: only for a command with a mapped filter, in a mode that allows it. The caller runs RTK after
  # raw capture and falls back to raw output if RTK fails or the evidence guard fails.
  if _wx_rtk_enabled && [ -n "$(_wx_rtk_filter_for_command "$_WX_SETTINGS_FILE" "$@")" ]; then
    printf '%s\n' 'compress-rtk-v1'
    return 0
  fi

  if _wx_command_matches_policy "$_WX_SETTINGS_FILE" noisy_success_can_compress "$@"; then
    printf '%s\n' 'compress-exact-repeats-v1'
  else
    printf '%s\n' 'raw-command-not-eligible'
  fi
}

# Collapse only consecutive identical lines. Unknown content passes through unchanged.
_wx_compress_exact_repeats() {
  local _WX_INPUT_FILE="$1"
  local _WX_OUTPUT_FILE="$2"

  LC_ALL=C awk '
    function flush_run() {
      if (run_count == 0) {
        return
      }
      print previous_line
      if (run_count > 1) {
        printf "[wx] repeated %d additional times: exact line above\n", run_count - 1
      }
    }

    NR == 1 {
      previous_line = $0
      run_count = 1
      next
    }

    $0 == previous_line {
      run_count++
      next
    }

    {
      flush_run()
      previous_line = $0
      run_count = 1
    }

    END {
      flush_run()
    }
  ' "$_WX_INPUT_FILE" > "$_WX_OUTPUT_FILE"
}

export -f _wx_command_matches_policy _wx_rtk_enabled _wx_rtk_filter_denied _wx_rtk_filter_for_command _wx_evidence_guard _wx_try_rtk _wx_select_output_policy _wx_compress_exact_repeats
