#!/usr/bin/env bash

set -u

_WX_TEST_ROOT="$(mktemp -d /tmp/token-controller-session-test.XXXXXX)"
_WX_REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
trap 'rm -rf -- "$_WX_TEST_ROOT"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_file_contains() {
  local _WX_FILE="$1"
  local _WX_TEXT="$2"
  grep -Fq -- "$_WX_TEXT" "$_WX_FILE" || fail "missing '$_WX_TEXT' in $_WX_FILE"
}

export AICONTEXT_CONFIG_DIR="$_WX_TEST_ROOT/config"
export PATH="$_WX_REPOSITORY_ROOT/tests/fixtures/bin:$PATH"
mkdir -p "$_WX_TEST_ROOT/work"
cd "$_WX_TEST_ROOT/work" || exit 1

# shellcheck source=../scripts/workflow.sh
source "$_WX_REPOSITORY_ROOT/scripts/workflow.sh" code >"$_WX_TEST_ROOT/activation.out"

source "$_WX_REPOSITORY_ROOT/scripts/workflow.sh" report >"$_WX_TEST_ROOT/no-session.report"
assert_file_contains "$_WX_TEST_ROOT/no-session.report" 'No workflow session data found'

wx echo hello >"$_WX_TEST_ROOT/one.stdout" 2>"$_WX_TEST_ROOT/one.stderr"
[ "$?" -eq 0 ] || fail 'single-command fixture failed'
jq -e -s 'length == 1 and all(.[]; type == "object")' .ai-context/session.jsonl >/dev/null || fail 'single-command JSONL is invalid'

source "$_WX_REPOSITORY_ROOT/scripts/workflow.sh" report >"$_WX_TEST_ROOT/one.report"
assert_file_contains "$_WX_TEST_ROOT/one.report" 'active profile: code'
assert_file_contains "$_WX_TEST_ROOT/one.report" 'wrapped commands: 1'
assert_file_contains "$_WX_TEST_ROOT/one.report" 'raw bytes total: 6'
assert_file_contains "$_WX_TEST_ROOT/one.report" 'visible/emitted bytes total: 6'
assert_file_contains "$_WX_TEST_ROOT/one.report" 'estimated reduction: 0.00%'
assert_file_contains "$_WX_TEST_ROOT/one.report" 'failures: 0'
assert_file_contains "$_WX_TEST_ROOT/one.report" "raw log directory: $_WX_TEST_ROOT/work/.ai-context/raw"

wx npm install >"$_WX_TEST_ROOT/multiple.stdout" 2>"$_WX_TEST_ROOT/multiple.stderr"
[ "$?" -eq 0 ] || fail 'multiple-command success fixture failed'
wx "$_WX_REPOSITORY_ROOT/tests/fixtures/failing-stack.sh" >"$_WX_TEST_ROOT/failure.stdout" 2>"$_WX_TEST_ROOT/failure.stderr"
_WX_FAILURE_EXIT=$?
[ "$_WX_FAILURE_EXIT" -eq 3 ] || fail "failure fixture exited $_WX_FAILURE_EXIT instead of 3"
jq -e -s 'length == 3 and all(.[]; type == "object")' .ai-context/session.jsonl >/dev/null || fail 'multiple-command JSONL is invalid'

_WX_RAW_BYTES="$(jq -r -s 'map((.raw.stdout_bytes // .stdout.bytes // 0) + (.raw.stderr_bytes // .stderr.bytes // 0)) | add' .ai-context/session.jsonl)"
_WX_VISIBLE_BYTES="$(jq -r -s 'map((.visible.stdout_bytes // .stdout.bytes // 0) + (.visible.stderr_bytes // .stderr.bytes // 0)) | add' .ai-context/session.jsonl)"
_WX_REDUCTION="$(jq -nr --argjson raw "$_WX_RAW_BYTES" --argjson visible "$_WX_VISIBLE_BYTES" '($raw - $visible) * 100 / $raw')"
LC_NUMERIC=C printf -v _WX_REDUCTION_FORMATTED '%.2f%%' "$_WX_REDUCTION"

source "$_WX_REPOSITORY_ROOT/scripts/workflow.sh" report >"$_WX_TEST_ROOT/multiple.report"
assert_file_contains "$_WX_TEST_ROOT/multiple.report" 'wrapped commands: 3'
assert_file_contains "$_WX_TEST_ROOT/multiple.report" "raw bytes total: $_WX_RAW_BYTES"
assert_file_contains "$_WX_TEST_ROOT/multiple.report" "visible/emitted bytes total: $_WX_VISIBLE_BYTES"
assert_file_contains "$_WX_TEST_ROOT/multiple.report" "estimated reduction: $_WX_REDUCTION_FORMATTED"
assert_file_contains "$_WX_TEST_ROOT/multiple.report" 'failures: 1'

_WX_RAW_FILE_COUNT_BEFORE="$(find .ai-context/raw -type f | wc -l)"
source "$_WX_REPOSITORY_ROOT/scripts/workflow.sh" reset-session >"$_WX_TEST_ROOT/reset.out"
assert_file_contains "$_WX_TEST_ROOT/reset.out" 'Archived workflow session:'
assert_file_contains "$_WX_TEST_ROOT/reset.out" 'Raw logs were preserved under:'
[ -f .ai-context/session.jsonl ] || fail 'reset did not create a new session file'
[ ! -s .ai-context/session.jsonl ] || fail 'new session file is not empty'

_WX_ARCHIVE_FILE="$(find .ai-context/archive -type f -name '*.jsonl' -print -quit)"
[ -n "$_WX_ARCHIVE_FILE" ] || fail 'reset did not create a session archive'
jq -e -s 'length == 3 and all(.[]; type == "object")' "$_WX_ARCHIVE_FILE" >/dev/null || fail 'archived JSONL is invalid'
_WX_RAW_FILE_COUNT_AFTER="$(find .ai-context/raw -type f | wc -l)"
[ "$_WX_RAW_FILE_COUNT_AFTER" -eq "$_WX_RAW_FILE_COUNT_BEFORE" ] || fail 'reset removed or added raw log files'

source "$_WX_REPOSITORY_ROOT/scripts/workflow.sh" report >"$_WX_TEST_ROOT/after-reset.report"
assert_file_contains "$_WX_TEST_ROOT/after-reset.report" 'No workflow session data found'
source "$_WX_REPOSITORY_ROOT/scripts/workflow.sh" reset-session >"$_WX_TEST_ROOT/empty-reset.out"
assert_file_contains "$_WX_TEST_ROOT/empty-reset.out" 'Nothing to reset.'

# Stale terminal: the shell says code, the env file says security. The report uses the env file.
source "$_WX_REPOSITORY_ROOT/scripts/workflow.sh" security >"$_WX_TEST_ROOT/activation-security.out"
wx echo hello >/dev/null 2>&1
export AICONTEXT_PROFILE=code
source "$_WX_REPOSITORY_ROOT/scripts/workflow.sh" report >"$_WX_TEST_ROOT/stale.report"
assert_file_contains "$_WX_TEST_ROOT/stale.report" 'active profile: security'
[ "$AICONTEXT_PROFILE" = code ] || fail 'report changed the caller shell profile'

# status --json: controller state comes from the active mode file.
source "$_WX_REPOSITORY_ROOT/scripts/workflow.sh" code >"$_WX_TEST_ROOT/activation-code.out"
source "$_WX_REPOSITORY_ROOT/scripts/workflow.sh" status --json >"$_WX_TEST_ROOT/status-normal.json"
jq -e --arg file "$AICONTEXT_CONFIG_DIR/active_mode.env" '
  .schema_version == 1
  and .profile == "code" and .risk == "normal"
  and .output_style == "ste-inspired"
  and .raw_on_fail == true and .keep_raw_logs == true
  and .rtk_mode == "success-only" and .leanctx_mode == "auto" and .headroom_mode == "reversible"
  and .caveman_mode == "off" and .caveman_output == false
  and .source == "active_env_file" and .active_env_file == $file
  and .shell_profile == null and .stale_shell == false and .use_shell_state == false
' "$_WX_TEST_ROOT/status-normal.json" >/dev/null || fail 'normal status --json is invalid'

# Stale shell: the shell says code, the env file says security.
source "$_WX_REPOSITORY_ROOT/scripts/workflow.sh" security >"$_WX_TEST_ROOT/activation-security2.out"
export AICONTEXT_PROFILE=code AICONTEXT_RISK=normal AICONTEXT_RTK_MODE=success-only
source "$_WX_REPOSITORY_ROOT/scripts/workflow.sh" status --json >"$_WX_TEST_ROOT/status-stale.json"
jq -e '
  .profile == "security" and .risk == "critical" and .rtk_mode == "off"
  and .source == "active_env_file"
  and .shell_profile == "code" and .stale_shell == true
' "$_WX_TEST_ROOT/status-stale.json" >/dev/null || fail 'stale status --json is invalid'
# Reading the status does not change the caller shell.
[ "$AICONTEXT_PROFILE" = code ] && [ "$AICONTEXT_RISK" = normal ] && [ "$AICONTEXT_RTK_MODE" = success-only ] || fail 'status --json changed the caller shell'
# The text status still shows the shell-visible variables.
source "$_WX_REPOSITORY_ROOT/scripts/workflow.sh" status >"$_WX_TEST_ROOT/status-text.out"
assert_file_contains "$_WX_TEST_ROOT/status-text.out" 'AICONTEXT_PROFILE=code'
assert_file_contains "$_WX_TEST_ROOT/status-text.out" 'AICONTEXT_RTK_MODE=success-only'

# Missing env file: shell fallback, then unset.
(
  export AICONTEXT_CONFIG_DIR="$_WX_TEST_ROOT/empty-config"
  mkdir -p "$AICONTEXT_CONFIG_DIR"
  export AICONTEXT_PROFILE=debug AICONTEXT_RISK=high AICONTEXT_RAW_ON_FAIL=true
  source "$_WX_REPOSITORY_ROOT/scripts/workflow.sh" status --json >"$_WX_TEST_ROOT/status-fallback.json"
) || fail 'status --json failed without an env file'
jq -e '
  .profile == "debug" and .risk == "high" and .raw_on_fail == true
  and .source == "shell_fallback" and .shell_profile == null and .stale_shell == false
' "$_WX_TEST_ROOT/status-fallback.json" >/dev/null || fail 'fallback status --json is invalid'
(
  export AICONTEXT_CONFIG_DIR="$_WX_TEST_ROOT/empty-config"
  for _WX_NAME in $(compgen -A variable AICONTEXT_ | grep -v -e AICONTEXT_CONFIG_DIR -e AICONTEXT_SETTINGS_FILE); do
    unset "$_WX_NAME"
  done
  source "$_WX_REPOSITORY_ROOT/scripts/workflow.sh" status --json >"$_WX_TEST_ROOT/status-unset.json"
) || fail 'status --json failed with no state'
jq -e '
  .profile == null and .risk == null and .raw_on_fail == null and .caveman_output == null
  and .source == "unset" and .shell_profile == null and .stale_shell == false
' "$_WX_TEST_ROOT/status-unset.json" >/dev/null || fail 'unset status --json is invalid'

# An env file without a profile is not usable state. It does not fall back to the shell.
mkdir -p "$_WX_TEST_ROOT/noprofile-config"
printf 'export AICONTEXT_RISK="critical"\n' > "$_WX_TEST_ROOT/noprofile-config/active_mode.env"
(
  export AICONTEXT_CONFIG_DIR="$_WX_TEST_ROOT/noprofile-config"
  export AICONTEXT_PROFILE=code
  source "$_WX_REPOSITORY_ROOT/scripts/workflow.sh" status --json >"$_WX_TEST_ROOT/status-noprofile.json"
) || fail 'status --json failed with a profile-less file'
jq -e '.profile == null and .source == "unset" and .shell_profile == "code" and .stale_shell == true' "$_WX_TEST_ROOT/status-noprofile.json" >/dev/null || fail 'profile-less status --json is invalid'

# Unknown option.
source "$_WX_REPOSITORY_ROOT/scripts/workflow.sh" status --bogus >/dev/null 2>&1
[ "$?" -eq 2 ] || fail 'status --bogus should return 2'

# Non-sourced entry point: scripts/workflow-cli.sh.
_WX_CLI="$_WX_REPOSITORY_ROOT/scripts/workflow-cli.sh"
[ -x "$_WX_CLI" ] || fail 'workflow-cli.sh is not executable'

# Activation through the CLI writes active_mode.env and does not change the caller's shell.
export AICONTEXT_PROFILE=debug AICONTEXT_RISK=high AICONTEXT_RTK_MODE=success-only
rm -f "$AICONTEXT_CONFIG_DIR/active_mode.env"
_WX_ENV_BEFORE="$(declare -p $(compgen -A variable AICONTEXT_) 2>/dev/null; declare -p RTK_HOOK_ENABLED CAVEMAN_OUTPUT 2>/dev/null)"
"$_WX_CLI" micro >"$_WX_TEST_ROOT/cli-micro.out" 2>"$_WX_TEST_ROOT/cli-micro.err" || fail 'workflow-cli.sh micro failed'
assert_file_contains "$_WX_TEST_ROOT/cli-micro.out" 'Activated AI context profile: micro'
assert_file_contains "$AICONTEXT_CONFIG_DIR/active_mode.env" 'export AICONTEXT_PROFILE="micro"'
assert_file_contains "$AICONTEXT_CONFIG_DIR/active_mode.env" 'export AICONTEXT_RISK="normal"'
_WX_ENV_AFTER="$(declare -p $(compgen -A variable AICONTEXT_) 2>/dev/null; declare -p RTK_HOOK_ENABLED CAVEMAN_OUTPUT 2>/dev/null)"
[ "$_WX_ENV_BEFORE" = "$_WX_ENV_AFTER" ] || fail 'workflow-cli.sh changed the caller shell'
[ "$AICONTEXT_PROFILE" = debug ] && [ "$AICONTEXT_RISK" = high ] || fail 'workflow-cli.sh changed the caller profile'

# status --json through the CLI reads the file. The caller shell (debug) is reported as stale.
"$_WX_CLI" status --json >"$_WX_TEST_ROOT/cli-status.json" || fail 'workflow-cli.sh status --json failed'
jq -e --arg file "$AICONTEXT_CONFIG_DIR/active_mode.env" '
  .schema_version == 1 and .profile == "micro" and .risk == "normal"
  and .source == "active_env_file" and .active_env_file == $file
  and .shell_profile == "debug" and .stale_shell == true
' "$_WX_TEST_ROOT/cli-status.json" >/dev/null || fail 'workflow-cli.sh status --json is invalid'

# Text status, no arguments, and help work.
"$_WX_CLI" status >"$_WX_TEST_ROOT/cli-status.txt" || fail 'workflow-cli.sh status failed'
assert_file_contains "$_WX_TEST_ROOT/cli-status.txt" 'Current AI Context Workflow Status:'
assert_file_contains "$_WX_TEST_ROOT/cli-status.txt" 'AICONTEXT_PROFILE=debug'
"$_WX_CLI" >"$_WX_TEST_ROOT/cli-noargs.txt" || fail 'workflow-cli.sh without arguments failed'
assert_file_contains "$_WX_TEST_ROOT/cli-noargs.txt" 'Current AI Context Workflow Status:'
"$_WX_CLI" --help >"$_WX_TEST_ROOT/cli-help.txt" || fail 'workflow-cli.sh --help failed'
assert_file_contains "$_WX_TEST_ROOT/cli-help.txt" 'Usage: scripts/workflow-cli.sh <mode>'

# A switch back and a different mode.
"$_WX_CLI" code >/dev/null || fail 'workflow-cli.sh code failed'
"$_WX_CLI" status --json | jq -e '.profile == "code" and .rtk_mode == "success-only"' >/dev/null || fail 'status --json after code is invalid'

# Invalid input returns nonzero. Arguments are not evaluated.
"$_WX_CLI" status --bogus >/dev/null 2>&1
[ "$?" -eq 2 ] || fail 'status --bogus should return 2'
"$_WX_CLI" nosuchmode >/dev/null 2>&1
[ "$?" -ne 0 ] || fail 'unknown mode should fail'
"$_WX_CLI" 'code"] | halt' >/dev/null 2>&1
[ "$?" -ne 0 ] || fail 'jq-style mode id should fail'
"$_WX_CLI" 'micro; touch CLI_INJECTED' >/dev/null 2>&1
[ "$?" -ne 0 ] || fail 'shell-style mode id should fail'
"$_WX_CLI" '$(touch CLI_INJECTED)' >/dev/null 2>&1
[ "$?" -ne 0 ] || fail 'command-substitution mode id should fail'
"$_WX_CLI" -x >/dev/null 2>&1
[ "$?" -ne 0 ] || fail 'option-like mode id should fail'
for _WX_DIR in "$PWD" "$_WX_REPOSITORY_ROOT/scripts" "$_WX_TEST_ROOT"; do
  [ ! -e "$_WX_DIR/CLI_INJECTED" ] || fail "argument text was run as a command ($_WX_DIR)"
done
"$_WX_CLI" status --json | jq -e '.profile == "code"' >/dev/null || fail 'a failed call changed the active mode'

# It works from another directory, through a symlink, and it refuses to be sourced.
ln -s "$_WX_CLI" "$_WX_TEST_ROOT/linked-cli"
(cd / && "$_WX_TEST_ROOT/linked-cli" status --json) | jq -e '.profile == "code"' >/dev/null || fail 'symlinked workflow-cli.sh failed'
(source "$_WX_CLI" status >/dev/null 2>"$_WX_TEST_ROOT/cli-source.err")
[ "$?" -ne 0 ] || fail 'sourcing workflow-cli.sh should fail'
assert_file_contains "$_WX_TEST_ROOT/cli-source.err" 'Do not source it'

printf '%s\n' 'PASS: workflow report and reset-session'
