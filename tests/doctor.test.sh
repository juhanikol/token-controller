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
  (cd "$_TEST_ROOT" && find . -type f -print0 | sort -z | xargs -0 sha256sum; find . -print | sort)
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

# 5. Bad option.
bash "$_DOCTOR" --bogus >/dev/null 2>&1
[ "$?" -eq 2 ] || fail "bad option should exit 2"

printf 'PASS: doctor tests\n'
