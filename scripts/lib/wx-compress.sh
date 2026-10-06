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

export -f _wx_command_matches_policy _wx_select_output_policy _wx_compress_exact_repeats
