#!/usr/bin/env bash

# Opt-in Claude Code PreToolUse example. This hook blocks selected direct Bash
# commands and asks the agent to rerun them through wx; it never rewrites input.

if ! command -v jq >/dev/null 2>&1; then
  printf '%s\n' 'Token Controller hook: jq is required to inspect hook input.' >&2
  exit 1
fi

_WX_HOOK_INPUT="$(command cat)"
if ! jq -e 'type == "object"' >/dev/null 2>&1 <<< "$_WX_HOOK_INPUT"; then
  printf '%s\n' 'Token Controller hook: received invalid JSON input.' >&2
  exit 1
fi

_WX_HOOK_TOOL_NAME="$(jq -r '.tool_name // empty' <<< "$_WX_HOOK_INPUT")"
[ "$_WX_HOOK_TOOL_NAME" = 'Bash' ] || exit 0

_WX_HOOK_COMMAND="$(jq -r '.tool_input.command // empty' <<< "$_WX_HOOK_INPUT")"
[ -n "$_WX_HOOK_COMMAND" ] || exit 0

_WX_HOOK_TRIMMED="$(printf '%s\n' "$_WX_HOOK_COMMAND" | sed 's/^[[:space:]]*//')"
case "$_WX_HOOK_TRIMMED" in
  wx|wx[[:space:]]*)
    exit 0
    ;;
esac

_WX_HOOK_BOUNDARY='(^|[;&|][[:space:]]*)'
_WX_HOOK_PREFIX='(sudo[[:space:]]+)?(env[[:space:]]+)?([[:alpha:]_][[:alnum:]_]*=[^[:space:]]+[[:space:]]+)*'
_WX_HOOK_PACKAGE='(npm|pnpm|yarn|bun)[[:space:]]+(install|ci|test|build|run[[:space:]]+(build|test)(:[^[:space:]]+)?)([[:space:]]|$)'
_WX_HOOK_INSTALL='((pip|pip3)[[:space:]]+install|uv[[:space:]]+pip[[:space:]]+install|apt(-get)?[[:space:]]+install)([[:space:]]|$)'
_WX_HOOK_BUILD_TEST='(pytest|node[[:space:]]+--test|go[[:space:]]+(test|build)|cargo[[:space:]]+(test|build|fetch|install)|dotnet[[:space:]]+(test|build|restore)|cmake[[:space:]]+--build|make|ninja|gradle|(\./)?gradlew|mvn[[:space:]]+(test|package|install))([[:space:]]|$)'
_WX_HOOK_DOCKER='(docker|docker-compose)([[:space:]]|$)'
_WX_HOOK_PATTERN="${_WX_HOOK_BOUNDARY}${_WX_HOOK_PREFIX}(${_WX_HOOK_PACKAGE}|${_WX_HOOK_INSTALL}|${_WX_HOOK_BUILD_TEST}|${_WX_HOOK_DOCKER})"

if ! printf '%s\n' "$_WX_HOOK_COMMAND" | grep -Eiq "$_WX_HOOK_PATTERN"; then
  exit 0
fi

_WX_HOOK_REASON="Token Controller policy: run test, build, install, and Docker commands through the deterministic wrapper. Rerun as: wx $_WX_HOOK_COMMAND"
jq -cn --arg reason "$_WX_HOOK_REASON" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $reason
  }
}'
exit 0
