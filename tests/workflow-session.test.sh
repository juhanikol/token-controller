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

# modes --json: the mode list comes from the settings file.
_WX_SETTINGS="$_WX_REPOSITORY_ROOT/config/workflow_settings.json"
"$_WX_CLI" modes --json >"$_WX_TEST_ROOT/modes.json" || fail 'modes --json failed'
jq -e . "$_WX_TEST_ROOT/modes.json" >/dev/null || fail 'modes --json is not valid JSON'
jq -e --slurpfile cfg "$_WX_SETTINGS" '
  .schema_version == 1
  and (.modes | length) == ($cfg[0].modes | keys | length)
  and (.modes | length) >= 22
  and ([.modes[].name] | sort) == ($cfg[0].modes | keys | sort)
' "$_WX_TEST_ROOT/modes.json" >/dev/null || fail 'modes --json does not match the settings file'
for _WX_MODE in micro docs release security db code debug; do
  jq -e --arg m "$_WX_MODE" '[.modes[].name] | index($m) != null' "$_WX_TEST_ROOT/modes.json" >/dev/null || fail "modes --json is missing $_WX_MODE"
done
jq -e '
  all(.modes[]; (.description | type) == "string" and (.description | length) > 0)
  and all(.modes[]; .name | test("^[a-z0-9][a-z0-9-]*$"))
  and all(.modes[]; .risk | IN("normal", "high", "critical"))
  and all(.modes[]; (.caveman_output | type) == "boolean" and (.compress_shell | type) == "string" and (.rtk_mode | type) == "string")
' "$_WX_TEST_ROOT/modes.json" >/dev/null || fail 'modes --json has a missing or invalid field'
jq -e '
  (.modes[] | select(.name == "micro") | .rtk_mode == "off" and .leanctx_mode == "off" and .caveman_mode == "off")
  and (.modes[] | select(.name == "security") | .risk == "critical")
  and ([.aliases[] | "\(.alias)>\(.target)"] | sort) == ["ci>cicd", "plan>architect"]
  and all(.aliases[]; .target as $t | [$modes[]] | index($t) != null)
' --argjson modes "$(jq -c '[.modes[].name]' "$_WX_TEST_ROOT/modes.json")" "$_WX_TEST_ROOT/modes.json" >/dev/null || fail 'modes --json aliases or key modes are invalid'

# Each listed mode matches what activating it exports (the list cannot drift from activation).
_WX_PARITY_SETTINGS="$_WX_TEST_ROOT/parity-settings.json"
jq '.modes.code.caveman_mode = "full" | .modes.security.caveman_mode = "full" | .modes["rapid-prototype"].caveman_mode = "lite" | .modes.debug.caveman_mode = "ultra"
  | .modes.security.caveman_max = "full" | .modes.docs.caveman_mode = "full" | .modes.docs.caveman_max = "full"
  | .modes.micro.caveman_mode = "lite" | .modes.micro.caveman_max = "lite"' "$_WX_SETTINGS" > "$_WX_PARITY_SETTINGS"
for _WX_SETTINGS_CASE in "$_WX_SETTINGS" "$_WX_PARITY_SETTINGS"; do
  AICONTEXT_SETTINGS_FILE="$_WX_SETTINGS_CASE" "$_WX_CLI" modes --json >"$_WX_TEST_ROOT/modes-case.json" 2>/dev/null || fail 'modes --json failed for a settings case'
  for _WX_MODE in $(jq -r '.modes[].name' "$_WX_TEST_ROOT/modes-case.json"); do
    _WX_ACTUAL="$(
      export AICONTEXT_SETTINGS_FILE="$_WX_SETTINGS_CASE"
      source "$_WX_REPOSITORY_ROOT/scripts/workflow.sh" "$_WX_MODE" >/dev/null 2>&1 || exit 1
      jq -cn --arg risk "$AICONTEXT_RISK" --arg shell "$AICONTEXT_COMPRESS_SHELL" --arg files "$AICONTEXT_COMPRESS_FILES" \
        --arg rtk "$AICONTEXT_RTK_MODE" --arg leanctx "$AICONTEXT_LEANCTX_MODE" --arg headroom "$AICONTEXT_HEADROOM_MODE" \
        --arg cmode "$AICONTEXT_CAVEMAN_MODE" --arg cmax "$AICONTEXT_CAVEMAN_MAX" --arg cout "$AICONTEXT_CAVEMAN_OUTPUT" --arg style "$AICONTEXT_OUTPUT_STYLE" \
        '{risk: $risk, compress_shell: $shell, compress_files: $files, rtk_mode: $rtk, leanctx_mode: $leanctx, headroom_mode: $headroom,
          caveman_mode: $cmode, caveman_max: $cmax, caveman_output: ($cout == "true"), output_style: $style}'
    )" || fail "activating $_WX_MODE failed"
    _WX_LISTED="$(jq -c --arg m "$_WX_MODE" '.modes[] | select(.name == $m) | del(.name, .description)' "$_WX_TEST_ROOT/modes-case.json")"
    [ "$_WX_ACTUAL" = "$_WX_LISTED" ] || fail "modes --json differs from activation for $_WX_MODE: $_WX_LISTED vs $_WX_ACTUAL"
  done
done
# The parity settings request Caveman levels. Hard-blocked and capped modes stay off or lower.
AICONTEXT_SETTINGS_FILE="$_WX_PARITY_SETTINGS" "$_WX_CLI" modes --json 2>/dev/null | jq -e '
  (.modes[] | select(.name == "code") | .caveman_mode == "lite")
  and (.modes[] | select(.name == "security") | .caveman_mode == "off")
  and (.modes[] | select(.name == "debug") | .caveman_mode == "off")
  and (.modes[] | select(.name == "docs") | .caveman_mode == "off")
  and (.modes[] | select(.name == "micro") | .caveman_mode == "off")
  and (.modes[] | select(.name == "rapid-prototype") | .caveman_mode == "lite" and .caveman_output == true)
' >/dev/null || fail 'Caveman levels in modes --json are not capped'

# Aliases still work (from config, and the built-in fallback when the config has no aliases key).
"$_WX_CLI" plan >/dev/null || fail 'alias plan failed'
"$_WX_CLI" status --json | jq -e '.profile == "architect"' >/dev/null || fail 'alias plan did not activate architect'
"$_WX_CLI" ci >/dev/null || fail 'alias ci failed'
"$_WX_CLI" status --json | jq -e '.profile == "cicd"' >/dev/null || fail 'alias ci did not activate cicd'
jq 'del(.aliases)' "$_WX_SETTINGS" > "$_WX_TEST_ROOT/no-aliases.json"
AICONTEXT_SETTINGS_FILE="$_WX_TEST_ROOT/no-aliases.json" "$_WX_CLI" plan >/dev/null || fail 'built-in alias plan failed without an aliases key'
AICONTEXT_SETTINGS_FILE="$_WX_TEST_ROOT/no-aliases.json" "$_WX_CLI" modes --json | jq -e '[.aliases[].alias] | sort == ["ci", "plan"]' >/dev/null || fail 'built-in aliases are not listed'
jq '.aliases.fast = "code"' "$_WX_SETTINGS" > "$_WX_TEST_ROOT/custom-alias.json"
AICONTEXT_SETTINGS_FILE="$_WX_TEST_ROOT/custom-alias.json" "$_WX_CLI" modes --json | jq -e '[.aliases[] | select(.alias == "fast" and .target == "code")] | length == 1' >/dev/null || fail 'a config alias is not listed'
AICONTEXT_SETTINGS_FILE="$_WX_TEST_ROOT/custom-alias.json" "$_WX_CLI" fast >/dev/null || fail 'a config alias does not activate'
AICONTEXT_SETTINGS_FILE="$_WX_TEST_ROOT/custom-alias.json" "$_WX_CLI" status --json | jq -e '.profile == "code"' >/dev/null || fail 'a config alias activated the wrong mode'

# Text form, shell-sourced form, and errors.
"$_WX_CLI" modes >"$_WX_TEST_ROOT/modes.txt" || fail 'modes (text) failed'
assert_file_contains "$_WX_TEST_ROOT/modes.txt" 'micro'
assert_file_contains "$_WX_TEST_ROOT/modes.txt" 'Aliases: plan -> architect, ci -> cicd'
source "$_WX_REPOSITORY_ROOT/scripts/workflow.sh" modes --json | jq -e '.modes | length >= 22' >/dev/null || fail 'sourced modes --json failed'
"$_WX_CLI" modes --bogus >/dev/null 2>&1
[ "$?" -eq 2 ] || fail 'modes --bogus should return 2'
AICONTEXT_SETTINGS_FILE="$_WX_TEST_ROOT/missing.json" "$_WX_CLI" modes --json >/dev/null 2>&1
[ "$?" -ne 0 ] || fail 'modes --json should fail without a settings file'

# Caveman policy state. Caveman is off by default. AICONTEXT_CAVEMAN_REQUEST=off|lite|full opts in for one activation.
# Nothing here runs Caveman. Only the exported state is checked.
unset AICONTEXT_CAVEMAN_REQUEST
caveman_state() { # mode [request]. Prints: requested/mode/max/output. Notices go to $_WX_TEST_ROOT/caveman.err
  (
    if [ -n "${2:-}" ]; then export AICONTEXT_CAVEMAN_REQUEST="$2"; fi
    source "$_WX_REPOSITORY_ROOT/scripts/workflow.sh" "$1" >/dev/null 2>"$_WX_TEST_ROOT/caveman.err" || exit 1
    printf '%s/%s/%s/%s' "$AICONTEXT_CAVEMAN_REQUESTED" "$AICONTEXT_CAVEMAN_MODE" "$AICONTEXT_CAVEMAN_MAX" "$AICONTEXT_CAVEMAN_OUTPUT"
  )
}
# Default: off in every mode, with no request.
for _WX_MODE in $("$_WX_CLI" modes --json | jq -r '.modes[].name'); do
  [ "$(caveman_state "$_WX_MODE" | cut -d/ -f1,2,4)" = "off/off/false" ] || fail "Caveman is not off by default in $_WX_MODE"
done
# Opt-in: the level is capped by the mode.
[ "$(caveman_state code lite)" = "lite/lite/lite/true" ] || fail "request lite in code: $(caveman_state code lite)"
[ "$(caveman_state code full)" = "full/lite/lite/true" ] || fail "request full in code should be capped to lite"
assert_file_contains "$_WX_TEST_ROOT/caveman.err" "lowered to 'lite'"
[ "$(caveman_state rapid-prototype full)" = "full/full/full/true" ] || fail "request full in rapid-prototype"
[ "$(caveman_state cicd lite)" = "lite/lite/lite/true" ] || fail "request lite in cicd"
[ "$(caveman_state code off)" = "off/off/lite/false" ] || fail "request off in code"
# Hard-blocked and no-Caveman modes ignore the request, with a notice.
for _WX_MODE in docs security db release migration debug raw micro snippet off test; do
  [ "$(caveman_state "$_WX_MODE" full | cut -d/ -f2,3,4)" = "off/off/false" ] || fail "request full in $_WX_MODE was not blocked: $(caveman_state "$_WX_MODE" full)"
  assert_file_contains "$_WX_TEST_ROOT/caveman.err" "ignored. Mode '$_WX_MODE' does not allow Caveman"
done
# Unsupported values become off with a warning. Activation still works.
for _WX_VALUE in ultra wenyan FULL yes 1 'lite;touch X'; do
  [ "$(caveman_state code "$_WX_VALUE" | cut -d/ -f1,2,4)" = "off/off/false" ] || fail "unsupported request '$_WX_VALUE' was not turned off"
  assert_file_contains "$_WX_TEST_ROOT/caveman.err" 'is not supported. Use off, lite, or full'
done
[ ! -e X ] || fail 'a request value was executed'
# Config invariants: Caveman is off by default, only four modes have a limit, and ultra/wenyan appear only as unsupported.
jq -e '.defaults.caveman_mode == "off" and .defaults.caveman_max == "off" and .defaults.caveman_shrink == "off"' "$_WX_SETTINGS" >/dev/null || fail 'config defaults for Caveman are not off'
jq -e '[.modes[] | .caveman_mode // "off"] | all(. == "off")' "$_WX_SETTINGS" >/dev/null || fail 'a mode starts with Caveman on'
jq -e '[.modes[] | .caveman_shrink // "off"] | all(. == "off")' "$_WX_SETTINGS" >/dev/null || fail 'a mode turns shrink on'
jq -e '[.modes | to_entries[] | select(.value.caveman_max != null) | .key] | sort == ["cicd", "code", "rapid-prototype", "test-full"]' "$_WX_SETTINGS" >/dev/null || fail 'the set of modes with a Caveman limit changed'
jq -e '[.modes[] | .caveman_max // "off"] | all(IN("off", "lite", "full"))' "$_WX_SETTINGS" >/dev/null || fail 'a Caveman limit is not off, lite, or full'
jq -e '[del(.caveman_policy.unsupported_levels) | .. | strings | select(test("^(ultra|wenyan)"))] | length == 0' "$_WX_SETTINGS" >/dev/null || fail 'ultra or wenyan appears as a config value'
jq -e '.caveman_policy.unsupported_levels == ["ultra", "wenyan"] and .caveman_policy.supported_levels == ["lite", "full"]' "$_WX_SETTINGS" >/dev/null || fail 'supported and unsupported Caveman levels changed'
jq -e '.caveman_policy.hard_blocked_profiles | (index("raw") != null and index("docs") != null and index("security") != null and index("db") != null and index("release") != null and index("migration") != null and index("debug") != null)' "$_WX_SETTINGS" >/dev/null || fail 'config hard_blocked_profiles is incomplete'
# The request is per activation: the next activation without it goes back to off. The mode file shows it.
AICONTEXT_CAVEMAN_REQUEST=lite "$_WX_CLI" code >/dev/null 2>&1 || fail 'workflow-cli.sh with a request failed'
grep -Fq 'export AICONTEXT_CAVEMAN_MODE="lite"' "$AICONTEXT_CONFIG_DIR/active_mode.env" || fail 'the effective level is not in the mode file'
grep -Fq 'export AICONTEXT_CAVEMAN_REQUESTED="lite"' "$AICONTEXT_CONFIG_DIR/active_mode.env" || fail 'the request is not in the mode file'
"$_WX_CLI" status --json | jq -e '.caveman_mode == "lite" and .caveman_requested == "lite" and .caveman_output == true' >/dev/null || fail 'status --json does not show the request'
"$_WX_CLI" code >/dev/null 2>&1
"$_WX_CLI" status --json | jq -e '.caveman_mode == "off" and .caveman_requested == "off" and .caveman_output == false' >/dev/null || fail 'the request was kept for the next activation'
# The request overrides a config level, and a config level is an opt-in too.
jq '.modes.code.caveman_mode = "lite"' "$_WX_SETTINGS" > "$_WX_TEST_ROOT/cave-config.json"
[ "$(AICONTEXT_SETTINGS_FILE="$_WX_TEST_ROOT/cave-config.json" caveman_state code | cut -d/ -f1,2)" = "lite/lite" ] || fail 'a config caveman_mode is not used'
[ "$(AICONTEXT_SETTINGS_FILE="$_WX_TEST_ROOT/cave-config.json" caveman_state code off | cut -d/ -f1,2)" = "off/off" ] || fail 'request off does not override the config level'
# A config that tries to allow a hard-blocked mode does not work.
# The config list is removed here, so only the list in the code can block these modes.
jq 'del(.caveman_policy.hard_blocked_profiles) | .modes.debug.caveman_mode = "lite" | .modes.debug.caveman_max = "full" | .modes.security.caveman_max = "full" | .modes.docs.caveman_max = "full" | .modes.db.caveman_max = "full" | .modes.release.caveman_max = "full" | .modes.migration.caveman_max = "full"
  | .modes.security.caveman_mode = "lite" | .modes.docs.caveman_mode = "lite" | .modes.db.caveman_mode = "lite" | .modes.release.caveman_mode = "lite" | .modes.migration.caveman_mode = "lite"' "$_WX_SETTINGS" > "$_WX_TEST_ROOT/cave-blocked.json"
for _WX_MODE in debug security docs db release migration; do
  [ "$(AICONTEXT_SETTINGS_FILE="$_WX_TEST_ROOT/cave-blocked.json" caveman_state "$_WX_MODE" full | cut -d/ -f2,3,4)" = "off/off/false" ] || fail "config allowed Caveman in $_WX_MODE"
done
AICONTEXT_SETTINGS_FILE="$_WX_TEST_ROOT/cave-blocked.json" "$_WX_CLI" modes --json | jq -e '[.modes[] | select(.name | IN("debug", "docs", "security", "db", "release", "migration")) | .caveman_mode] | all(. == "off")' >/dev/null || fail 'modes --json allows Caveman in a blocked mode when the config list is missing'
jq -e '.caveman_policy.hard_blocked_profiles | (index("debug") != null and index("docs") != null and index("security") != null and index("db") != null and index("release") != null and index("migration") != null)' "$_WX_SETTINGS" >/dev/null || fail 'config hard_blocked_profiles is incomplete'
"$_WX_CLI" modes --json | jq -e '[.modes[] | select(.name | IN("debug", "docs", "security", "db", "release", "migration")) | .caveman_max] | all(. == "off")' >/dev/null || fail 'modes --json shows a blocked mode with a Caveman limit'
"$_WX_CLI" code >/dev/null 2>&1

# version and schema numbers. Each number in `version --json` must equal the number the matching output really carries.
"$_WX_CLI" version --json >"$_WX_TEST_ROOT/version.json" || fail 'version --json failed'
jq -e '
  .schema_version == 1
  and (.cli_version | test("^[0-9]+\\.[0-9]+\\.[0-9]+$"))
  and (.config_schema_version | type) == "number"
  and (.status_schema_version | type) == "number" and (.modes_schema_version | type) == "number"
  and (.doctor_schema_version | type) == "number" and (.session_schema_version | type) == "number"
' "$_WX_TEST_ROOT/version.json" >/dev/null || fail 'version --json is invalid'
[ "$(jq -r '.config_schema_version' "$_WX_TEST_ROOT/version.json")" = "$(jq -r '.schema_version' "$_WX_SETTINGS")" ] || fail 'config_schema_version differs from the settings file'
[ "$(jq -r '.status_schema_version' "$_WX_TEST_ROOT/version.json")" = "$("$_WX_CLI" status --json | jq -r '.schema_version')" ] || fail 'status_schema_version differs from status --json'
[ "$(jq -r '.modes_schema_version' "$_WX_TEST_ROOT/version.json")" = "$("$_WX_CLI" modes --json | jq -r '.schema_version')" ] || fail 'modes_schema_version differs from modes --json'
[ "$(jq -r '.doctor_schema_version' "$_WX_TEST_ROOT/version.json")" = "$("$_WX_CLI" doctor --json --project "$_WX_TEST_ROOT" 2>/dev/null | jq -r '.schema_version')" ] || fail 'doctor_schema_version differs from doctor --json'
wx echo version-check >/dev/null 2>&1
[ "$(jq -r '.session_schema_version' "$_WX_TEST_ROOT/version.json")" = "$(jq -s -r '.[-1].schema_version' .ai-context/session.jsonl)" ] || fail 'session_schema_version differs from a session record'
# Git fields: both set in a git checkout and equal to git, or both null. A caller GIT_DIR does not change them.
if [ -e "$_WX_REPOSITORY_ROOT/.git" ] && command -v git >/dev/null 2>&1; then
  [ "$(jq -r '.git_commit' "$_WX_TEST_ROOT/version.json")" = "$(git -C "$_WX_REPOSITORY_ROOT" rev-parse --short=12 HEAD)" ] || fail 'git_commit differs from git'
  [ "$(GIT_DIR=/nonexistent "$_WX_CLI" version --json | jq -r '.git_commit')" = "$(git -C "$_WX_REPOSITORY_ROOT" rev-parse --short=12 HEAD)" ] || fail 'a caller GIT_DIR changed git_commit'
else
  jq -e '.git_commit == null and .git_branch == null' "$_WX_TEST_ROOT/version.json" >/dev/null || fail 'git fields should be null outside a git checkout'
fi
# The config schema is read from whatever settings file is used. A missing file gives null, not an error.
jq '.schema_version = 7' "$_WX_SETTINGS" > "$_WX_TEST_ROOT/schema7.json"
AICONTEXT_SETTINGS_FILE="$_WX_TEST_ROOT/schema7.json" "$_WX_CLI" version --json | jq -e '.config_schema_version == 7' >/dev/null || fail 'config_schema_version ignores the settings file'
AICONTEXT_SETTINGS_FILE="$_WX_TEST_ROOT/no-such-settings.json" "$_WX_CLI" version --json | jq -e '.config_schema_version == null' >/dev/null || fail 'a missing settings file should give a null config schema'
# Text form, aliases, sourced form, and errors.
"$_WX_CLI" version >"$_WX_TEST_ROOT/version.txt" || fail 'version (text) failed'
assert_file_contains "$_WX_TEST_ROOT/version.txt" "Token Controller CLI $(jq -r '.cli_version' "$_WX_TEST_ROOT/version.json")"
assert_file_contains "$_WX_TEST_ROOT/version.txt" "status schema:   $(jq -r '.status_schema_version' "$_WX_TEST_ROOT/version.json")"
[ "$("$_WX_CLI" --version | head -n 1)" = "$("$_WX_CLI" version | head -n 1)" ] || fail '--version differs from version'
[ "$("$_WX_CLI" -V | head -n 1)" = "$("$_WX_CLI" version | head -n 1)" ] || fail '-V differs from version'
source "$_WX_REPOSITORY_ROOT/scripts/workflow.sh" version --json | jq -e '.schema_version == 1' >/dev/null || fail 'sourced version --json failed'
"$_WX_CLI" version --bogus >/dev/null 2>&1
[ "$?" -eq 2 ] || fail 'version --bogus should return 2'
# The compatibility rule is written next to the numbers.
grep -q 'Adding a field does not change the schema number' "$_WX_REPOSITORY_ROOT/scripts/lib/versions.sh" || fail 'the compatibility rule is missing from versions.sh'
grep -q 'Renaming or removing a field' "$_WX_REPOSITORY_ROOT/scripts/lib/versions.sh" || fail 'the rename/remove rule is missing from versions.sh'

# report --json: a stable interface for tools. All numbers are byte counts, not token counts.
source "$_WX_REPOSITORY_ROOT/scripts/workflow.sh" code >/dev/null 2>&1
_WX_REPORT_REQUIRED='["schema_version","available","profile","command_count","failure_count","raw_stdout_bytes_total","raw_stderr_bytes_total","visible_stdout_bytes_total","visible_stderr_bytes_total","raw_bytes_total","visible_bytes_total","byte_reduction_percent","session_file","raw_log_dir","last_run_at"]'
report_checks() { # json file: required keys, types, no "token" in any key
  jq -e --argjson req "$_WX_REPORT_REQUIRED" '
    . as $r | ($req | all(. as $k | $r | has($k)))
    and .schema_version == 1 and (.available | type) == "boolean"
    and ([.command_count, .failure_count, .raw_stdout_bytes_total, .raw_stderr_bytes_total, .visible_stdout_bytes_total, .visible_stderr_bytes_total, .raw_bytes_total, .visible_bytes_total] | all(type == "number" and . >= 0))
    and (.byte_reduction_percent == null or (.byte_reduction_percent | type) == "number")
    and (.session_file | type) == "string" and (.raw_log_dir | type) == "string"
    and (.last_run_at == null or (.last_run_at | type) == "string")
    and (keys | all(test("token") | not))
  ' "$1" >/dev/null
}

# 1. No session.
_WX_RP_EMPTY="$_WX_TEST_ROOT/rp-empty"
mkdir -p "$_WX_RP_EMPTY"
"$_WX_CLI" report --json --project "$_WX_RP_EMPTY" >"$_WX_TEST_ROOT/rp-empty.json" || fail 'report --json failed without a session'
jq -e . "$_WX_TEST_ROOT/rp-empty.json" >/dev/null || fail 'report --json (no session) is not valid JSON'
report_checks "$_WX_TEST_ROOT/rp-empty.json" || fail "report --json (no session) has a missing or wrong field: $(cat "$_WX_TEST_ROOT/rp-empty.json")"
jq -e --arg f "$_WX_RP_EMPTY/.ai-context/session.jsonl" --arg r "$_WX_RP_EMPTY/.ai-context/raw" '
  .available == false and .command_count == 0 and .failure_count == 0 and .raw_bytes_total == 0 and .visible_bytes_total == 0
  and .byte_reduction_percent == null and .last_run_at == null and .session_file == $f and .raw_log_dir == $r
' "$_WX_TEST_ROOT/rp-empty.json" >/dev/null || fail 'report --json (no session) has wrong values'
"$_WX_CLI" report --project "$_WX_RP_EMPTY" | grep -q 'No workflow session data found' || fail 'text report changed for no session'
[ ! -e "$_WX_RP_EMPTY/.ai-context" ] || fail 'report created files in the project'

# 2. One command.
_WX_RP_ONE="$_WX_TEST_ROOT/rp-one"
mkdir -p "$_WX_RP_ONE"
(cd "$_WX_RP_ONE" && wx echo hello >/dev/null 2>&1) || fail 'wx fixture failed'
"$_WX_CLI" report --json --project "$_WX_RP_ONE" >"$_WX_TEST_ROOT/rp-one.json" || fail 'report --json failed for one command'
report_checks "$_WX_TEST_ROOT/rp-one.json" || fail "report --json (one command) has a missing or wrong field: $(cat "$_WX_TEST_ROOT/rp-one.json")"
jq -e --arg f "$_WX_RP_ONE/.ai-context/session.jsonl" '
  .available == true and .profile == "code" and .command_count == 1 and .failure_count == 0
  and .raw_stdout_bytes_total == 6 and .raw_stderr_bytes_total == 0 and .visible_stdout_bytes_total == 6 and .visible_stderr_bytes_total == 0
  and .raw_bytes_total == 6 and .visible_bytes_total == 6 and .byte_reduction_percent == 0
  and .session_file == $f and (.last_run_at | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T"))
' "$_WX_TEST_ROOT/rp-one.json" >/dev/null || fail 'report --json (one command) has wrong values'
_WX_RP_SHA="$(sha256sum "$_WX_RP_ONE/.ai-context/session.jsonl")"
"$_WX_CLI" report --json --project "$_WX_RP_ONE" >/dev/null
[ "$(sha256sum "$_WX_RP_ONE/.ai-context/session.jsonl")" = "$_WX_RP_SHA" ] || fail 'report changed the session file'

# 3. Mixed success and failure, with one compressed run. Totals must match the session file.
_WX_RP_MIX="$_WX_TEST_ROOT/rp-mix"
mkdir -p "$_WX_RP_MIX"
(cd "$_WX_RP_MIX" && wx echo hello >/dev/null 2>&1; wx bash -c 'echo out; echo err >&2; exit 3' >/dev/null 2>&1; wx npm install >/dev/null 2>&1)
"$_WX_CLI" report --json --project "$_WX_RP_MIX" >"$_WX_TEST_ROOT/rp-mix.json" || fail 'report --json failed for mixed runs'
report_checks "$_WX_TEST_ROOT/rp-mix.json" || fail "report --json (mixed) has a missing or wrong field: $(cat "$_WX_TEST_ROOT/rp-mix.json")"
jq -e '
  .command_count == 3 and .failure_count == 1
  and .raw_bytes_total == (.raw_stdout_bytes_total + .raw_stderr_bytes_total)
  and .visible_bytes_total == (.visible_stdout_bytes_total + .visible_stderr_bytes_total)
  and .raw_stderr_bytes_total >= 4 and .visible_bytes_total < .raw_bytes_total
  and .byte_reduction_percent > 0 and .byte_reduction_percent < 100
  and .byte_reduction_percent == ((((.raw_bytes_total - .visible_bytes_total) * 10000 / .raw_bytes_total) | round) / 100)
' "$_WX_TEST_ROOT/rp-mix.json" >/dev/null || fail "report --json (mixed) numbers are inconsistent: $(cat "$_WX_TEST_ROOT/rp-mix.json")"
# An independent sum straight from the session records.
jq -s -c '{c: length, f: (map(select(.exit_code != 0)) | length), rs: (map(.raw.stdout_bytes) | add), re: (map(.raw.stderr_bytes) | add), vs: (map(.visible.stdout_bytes) | add), ve: (map(.visible.stderr_bytes) | add), last: (.[-1].completed_at)}' "$_WX_RP_MIX/.ai-context/session.jsonl" >"$_WX_TEST_ROOT/rp-mix.sum"
jq -e --slurpfile sum "$_WX_TEST_ROOT/rp-mix.sum" '
  .command_count == $sum[0].c and .failure_count == $sum[0].f
  and .raw_stdout_bytes_total == $sum[0].rs and .raw_stderr_bytes_total == $sum[0].re
  and .visible_stdout_bytes_total == $sum[0].vs and .visible_stderr_bytes_total == $sum[0].ve
  and .last_run_at == $sum[0].last
' "$_WX_TEST_ROOT/rp-mix.json" >/dev/null || fail 'report --json differs from a sum of the session records'
# The text report shows the same numbers.
"$_WX_CLI" report --project "$_WX_RP_MIX" >"$_WX_TEST_ROOT/rp-mix.txt" || fail 'text report failed'
assert_file_contains "$_WX_TEST_ROOT/rp-mix.txt" 'Workflow session report:'
assert_file_contains "$_WX_TEST_ROOT/rp-mix.txt" "wrapped commands: $(jq -r '.command_count' "$_WX_TEST_ROOT/rp-mix.json")"
assert_file_contains "$_WX_TEST_ROOT/rp-mix.txt" "raw bytes total: $(jq -r '.raw_bytes_total' "$_WX_TEST_ROOT/rp-mix.json")"
assert_file_contains "$_WX_TEST_ROOT/rp-mix.txt" "visible/emitted bytes total: $(jq -r '.visible_bytes_total' "$_WX_TEST_ROOT/rp-mix.json")"
assert_file_contains "$_WX_TEST_ROOT/rp-mix.txt" "failures: $(jq -r '.failure_count' "$_WX_TEST_ROOT/rp-mix.json")"
assert_file_contains "$_WX_TEST_ROOT/rp-mix.txt" "raw log directory: $(jq -r '.raw_log_dir' "$_WX_TEST_ROOT/rp-mix.json")"
assert_file_contains "$_WX_TEST_ROOT/rp-mix.txt" "$(printf 'estimated reduction: %.2f%%' "$(jq -r '.byte_reduction_percent' "$_WX_TEST_ROOT/rp-mix.json")")"
"$_WX_CLI" report --text --project "$_WX_RP_MIX" | cmp -s - "$_WX_TEST_ROOT/rp-mix.txt" || fail 'report --text differs from report'

# 4. Old records without raw/visible fields use the stdout/stderr bytes. Missing times give a null last_run_at.
_WX_RP_OLD="$_WX_TEST_ROOT/rp-old"
mkdir -p "$_WX_RP_OLD/.ai-context"
printf '{"stdout":{"bytes":5},"stderr":{"bytes":1},"exit_code":0}\n' > "$_WX_RP_OLD/.ai-context/session.jsonl"
"$_WX_CLI" report --json --project "$_WX_RP_OLD" | jq -e '.command_count == 1 and .raw_bytes_total == 6 and .visible_bytes_total == 6 and .last_run_at == null' >/dev/null || fail 'old session records are not handled'

# 5. A broken session file is an error: nothing on stdout, exit code 1. Raw bytes of zero give a null percent.
_WX_RP_BAD="$_WX_TEST_ROOT/rp-bad"
mkdir -p "$_WX_RP_BAD/.ai-context"
printf 'not json\n' > "$_WX_RP_BAD/.ai-context/session.jsonl"
"$_WX_CLI" report --json --project "$_WX_RP_BAD" >"$_WX_TEST_ROOT/rp-bad.out" 2>"$_WX_TEST_ROOT/rp-bad.err"
[ "$?" -eq 1 ] || fail 'report --json should return 1 for invalid JSONL'
[ ! -s "$_WX_TEST_ROOT/rp-bad.out" ] || fail 'report --json wrote to stdout for invalid JSONL'
assert_file_contains "$_WX_TEST_ROOT/rp-bad.err" 'invalid JSONL'
printf '{"exit_code":0,"raw":{"stdout_bytes":0,"stderr_bytes":0},"visible":{"stdout_bytes":0,"stderr_bytes":0}}\n' > "$_WX_RP_BAD/.ai-context/session.jsonl"
"$_WX_CLI" report --json --project "$_WX_RP_BAD" | jq -e '.command_count == 1 and .raw_bytes_total == 0 and .byte_reduction_percent == null' >/dev/null || fail 'zero raw bytes should give a null percent'

# 6. Options, entry points, and the schema number in version --json.
"$_WX_CLI" report --json --bogus >/dev/null 2>&1
[ "$?" -eq 2 ] || fail 'report --bogus should return 2'
"$_WX_CLI" report --json --project "$_WX_TEST_ROOT/no-such-dir" >/dev/null 2>&1
[ "$?" -eq 2 ] || fail 'report --project with a missing directory should return 2'
"$_WX_CLI" report --project >/dev/null 2>&1
[ "$?" -eq 2 ] || fail 'report --project without a value should return 2'
(cd "$_WX_RP_MIX" && source "$_WX_REPOSITORY_ROOT/scripts/workflow.sh" report --json | jq -e '.command_count == 3' >/dev/null) || fail 'sourced report --json failed'
(cd "$_WX_RP_MIX" && "$_WX_CLI" report --json | jq -e '.command_count == 3' >/dev/null) || fail 'report --json without --project should use the current directory'
[ "$(jq -r '.report_schema_version' "$_WX_TEST_ROOT/version.json")" = "$(jq -r '.schema_version' "$_WX_TEST_ROOT/rp-mix.json")" ] || fail 'report_schema_version differs from report --json'

printf '%s\n' 'PASS: workflow report and reset-session'
