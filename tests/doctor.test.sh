#!/usr/bin/env bash

set -u

_TEST_ROOT="$(mktemp -d /tmp/token-controller-doctor-test.XXXXXX)"
_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
trap 'rm -rf -- "$_TEST_ROOT"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

export HOME="$_TEST_ROOT/home"
export XDG_CONFIG_HOME="$HOME/.config"
export AICONTEXT_CONFIG_DIR="$HOME/.config/ai-workflow"
unset AICONTEXT_PROFILE WSL_DISTRO_NAME
mkdir -p "$HOME/.claude" "$AICONTEXT_CONFIG_DIR" "$_TEST_ROOT/project/.claude"

_DOCTOR="$_REPO_ROOT/scripts/doctor.sh"
_PROJECT="$_TEST_ROOT/project"

snapshot() {
  (cd "$_TEST_ROOT" && find . -type f ! -name rtk-calls.log -print0 | sort -z | xargs -0 sha256sum; find . ! -name rtk-calls.log -print | sort)
}

# 1. Empty home: no error, valid JSON.
out="$(bash "$_DOCTOR" --json --project "$_PROJECT")" || fail "empty home exited nonzero"
jq -e '.schema_version == 1 and .summary.error == 0 and (.tools | length) == 5' <<< "$out" >/dev/null || fail "empty home JSON shape"

# 2. Duplicate policy and a secret in settings. Doctor must not print the secret.
cat > "$AICONTEXT_CONFIG_DIR/active_mode.env" <<'ENV'
export AICONTEXT_PROFILE="code"
export AICONTEXT_RISK="normal"
export AICONTEXT_RTK_MODE="off"
ENV
printf 'Check ~/.config/ai-workflow/active_mode.env first.\n' > "$HOME/.claude/CLAUDE.md"
printf '<!-- ai-workflow-controller:start -->\nrules\n<!-- ai-workflow-controller:end -->\n' > "$_PROJECT/AGENTS.md"
printf '{"hooks":"rtk","apiKey":"SECRET-VALUE-123"}\n' > "$_PROJECT/.claude/settings.json"

before="$(snapshot)"
out="$(bash "$_DOCTOR" --json --project "$_PROJECT")" || fail "duplicate case exited nonzero"
after="$(snapshot)"
[ "$before" = "$after" ] || fail "doctor changed files"
jq -e '.active_mode.profile == "code"' <<< "$out" >/dev/null || fail "profile not read"
jq -e '[.findings[].id] | index("policy.duplicate")' <<< "$out" >/dev/null || fail "duplicate policy not reported"
jq -e '[.findings[].id] | index("policy.rtk_hook_mismatch")' <<< "$out" >/dev/null || fail "rtk mismatch not reported"
case "$out" in *SECRET-VALUE-123*) fail "secret leaked into JSON" ;; esac
bash "$_DOCTOR" --project "$_PROJECT" | grep -q 'Policy text is in 2 places' || fail "text output missing duplicate"

# 3. Incomplete managed block gives an error and exit 1.
printf '<!-- ai-workflow-controller:start -->\nrules\n' > "$_PROJECT/AGENTS.md"
bash "$_DOCTOR" --json --project "$_PROJECT" > "$_TEST_ROOT/out.json"
[ "$?" -eq 1 ] || fail "incomplete block should exit 1"
jq -e '[.findings[] | select(.severity == "error") | .id] | index("policy.incomplete_block")' "$_TEST_ROOT/out.json" >/dev/null || fail "incomplete block not reported"

# 4. Unknown profile gives an error.
printf 'export AICONTEXT_PROFILE="nope"\n' > "$AICONTEXT_CONFIG_DIR/active_mode.env"
bash "$_DOCTOR" --json --project "$_PROJECT" | jq -e '[.findings[].id] | index("mode.unknown")' >/dev/null || fail "unknown profile not reported"

# 4b. Duplicate policy is a warn, not an error. Path entries have path and line fields.
printf 'export AICONTEXT_PROFILE="code"\nexport AICONTEXT_RTK_MODE="off"\n' > "$AICONTEXT_CONFIG_DIR/active_mode.env"
printf '<!-- ai-workflow-controller:start -->\nrules\n<!-- ai-workflow-controller:end -->\n' > "$_PROJECT/AGENTS.md"
out="$(bash "$_DOCTOR" --json --project "$_PROJECT")" || fail "duplicate case exited nonzero"
jq -e '[.findings[] | select(.id == "policy.duplicate")] | length == 1 and .[0].severity == "warn"' <<< "$out" >/dev/null || fail "duplicate policy must be warn"
jq -e '[.findings[].paths[] | select((has("path") and has("line")) | not)] | length == 0' <<< "$out" >/dev/null || fail "path objects need path and line"
jq -e '[.findings[] | select(.id == "policy.duplicate") | .paths[] | .line] | all(type == "number")' <<< "$out" >/dev/null || fail "duplicate paths need line numbers"
bash "$_DOCTOR" --project "$_PROJECT" | grep -q 'AGENTS.md:1' || fail "text output needs path:line"

# 4c. RTK global hook is reported in every mode, and doctor never runs rtk init or edits ~/.config/rtk.
mkdir -p "$_TEST_ROOT/bin" "$HOME/.config/rtk"
printf 'keep\n' > "$HOME/.config/rtk/config.toml"
cat > "$_TEST_ROOT/bin/rtk" <<'RTK'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${RTK_CALL_LOG:?}"
echo "rtk 9.9.9"
RTK
chmod +x "$_TEST_ROOT/bin/rtk"
export RTK_CALL_LOG="$_TEST_ROOT/rtk-calls.log"
: > "$RTK_CALL_LOG"
rm -f "$_PROJECT/.claude/settings.json"
printf '{"hooks":{"PreToolUse":[{"command":"/home/u/.local/bin/rtk hook"}]}}\n' > "$HOME/.claude/settings.json"
printf 'export AICONTEXT_PROFILE="code"\nexport AICONTEXT_RTK_MODE="success-only"\n' > "$AICONTEXT_CONFIG_DIR/active_mode.env"
before="$(snapshot)"
out="$(PATH="$_TEST_ROOT/bin:$PATH" bash "$_DOCTOR" --json --project "$_PROJECT")" || fail "rtk hook case exited nonzero"
[ "$before" = "$(snapshot)" ] || fail "doctor changed files with rtk present"
jq -e '[.findings[] | select(.id == "policy.rtk_hook" and .severity == "warn")] | length == 1' <<< "$out" >/dev/null || fail "rtk hook must warn when rtk mode is on"
jq -e '[.findings[].id] | index("policy.rtk_hook_mismatch") | not' <<< "$out" >/dev/null || fail "no mismatch when rtk mode is on"
jq -e '.tools[] | select(.name == "rtk") | .version == "rtk 9.9.9"' <<< "$out" >/dev/null || fail "rtk version not read"
[ "$(cat "$RTK_CALL_LOG")" = "--version" ] || fail "doctor ran rtk with more than --version: $(cat "$RTK_CALL_LOG")"
[ "$(cat "$HOME/.config/rtk/config.toml")" = "keep" ] || fail "rtk config changed"
printf 'export AICONTEXT_PROFILE="code"\nexport AICONTEXT_RTK_MODE="off"\n' > "$AICONTEXT_CONFIG_DIR/active_mode.env"
PATH="$_TEST_ROOT/bin:$PATH" bash "$_DOCTOR" --json --project "$_PROJECT" | jq -e '[.findings[].id] | (index("policy.rtk_hook") != null and index("policy.rtk_hook_mismatch") != null)' >/dev/null || fail "rtk off should report hook and mismatch"
rm -f "$HOME/.claude/settings.json"

# 4d. Caveman state.
_CAVE="$HOME/.claude/.caveman-active"
cave() { # profile level [tc_caveman_mode]
  printf 'export AICONTEXT_PROFILE="%s"\nexport AICONTEXT_CAVEMAN_MODE="%s"\n' "$1" "${3:-off}" > "$AICONTEXT_CONFIG_DIR/active_mode.env"
  printf '%s\n' "$2" > "$_CAVE"
  bash "$_DOCTOR" --json --project "$_PROJECT" | jq -r '[.findings[] | select(.id | startswith("caveman.")) | "\(.id):\(.severity)"] | join(",")'
}
rm -f "$_CAVE"
[ -z "$(bash "$_DOCTOR" --json --project "$_PROJECT" | jq -r '.findings[] | select(.id | startswith("caveman."))')" ] || fail "no state file should give no caveman finding"
[ "$(cave security full)" = "caveman.active_blocked_profile:error" ] || fail "caveman in security must be error: $(cave security full)"
[ "$(cave docs lite)" = "caveman.active_blocked_profile:error" ] || fail "caveman in docs must be error"
[ "$(cave code full)" = "caveman.active_no_opt_in:warn" ] || fail "caveman without opt-in must be warn"
[ "$(cave code ultra)" = "caveman.unsupported_level:warn" ] || fail "ultra must be warn"
[ "$(cave code wenyan-full)" = "caveman.unsupported_level:warn" ] || fail "wenyan must be warn"
[ "$(cave code full lite)" = "caveman.above_policy:warn" ] || fail "level above policy must be warn"
[ "$(cave code lite lite)" = "caveman.active_ok:ok" ] || fail "matching level should be ok"
[ "$(cave code off)" = "caveman.inactive:ok" ] || fail "off level should be inactive"
[ "$(cave code 'x;y')" = "caveman.level_unknown:warn" ] || fail "odd level should be warn"
bash "$_DOCTOR" --project "$_PROJECT" >/dev/null; [ "$?" -eq 0 ] || fail "caveman warn must not change exit code"
cave security full >/dev/null; bash "$_DOCTOR" --json --project "$_PROJECT" >/dev/null; [ "$?" -eq 1 ] || fail "caveman error should exit 1"
[ "$(cat "$_CAVE")" = "full" ] || fail "doctor changed the caveman state file"
rm -f "$_CAVE"

# 4e. Via workflow.sh, doctor says it can create the config directory. Direct run does not.
AICONTEXT_DOCTOR_VIA_WORKFLOW=1 bash "$_DOCTOR" --json --project "$_PROJECT" | jq -e '[.findings[].id] | index("doctor.config_dir") != null' >/dev/null || fail "missing side effect note via workflow.sh"
bash "$_DOCTOR" --json --project "$_PROJECT" | jq -e '[.findings[].id] | index("doctor.config_dir") == null' >/dev/null || fail "direct run should not show the note"
printf 'export AICONTEXT_PROFILE="code"\n' > "$AICONTEXT_CONFIG_DIR/active_mode.env"

# 5. Bad option.
bash "$_DOCTOR" --bogus >/dev/null 2>&1
[ "$?" -eq 2 ] || fail "bad option should exit 2"

printf 'PASS: doctor tests\n'
