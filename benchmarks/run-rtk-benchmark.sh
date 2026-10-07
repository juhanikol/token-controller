#!/usr/bin/env bash
# RTK pipe benchmark. It measures what `wx` shows when RTK filters the captured stdout, and keeps that apart from
# the built-in exact-repeat reducer. Everything is measured in bytes. Byte reduction is not token savings.
#
# Sections:
#   1. Built-in exact-repeat reducer (reference). Not RTK.
#   2. RTK pipe with the fake RTK from tests/fixtures/bin/rtk. This always runs. It checks the pipeline. The fake
#      RTK's output is not RTK's output, so its byte counts say nothing about RTK itself.
#   3. RTK pipe with a real rtk, only if one is installed. Otherwise this section is skipped.
# Recorded outputs: tests/fixtures/rtk (see PROVENANCE.txt there). No mapping or config is changed.
#
# Usage: bash benchmarks/run-rtk-benchmark.sh [> summary.md]
# Exit code: 0 when every check holds, 1 otherwise.

set -u

_RB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
_RB_FIX="$_RB_ROOT/tests/fixtures"
_RB_REC="$_RB_FIX/rtk"
_RB_BIN="$_RB_FIX/bin"
_RB_TMP="$(mktemp -d /tmp/token-controller-rtk-benchmark.XXXXXX)"
_RB_FAILED=false
trap 'rm -rf -- "$_RB_TMP"' EXIT

for _RB_TOOL in jq awk cmp; do
  if ! command -v "$_RB_TOOL" >/dev/null 2>&1; then
    printf 'RTK benchmark requires %s.\n' "$_RB_TOOL" >&2
    exit 1
  fi
done

# Find a real rtk before the fixture directory is put on the PATH.
_RB_REAL_RTK=""
_RB_OLD_IFS="$IFS"
IFS=:
for _RB_DIR in $PATH; do
  [ "$_RB_DIR" = "$_RB_BIN" ] && continue
  if [ -x "$_RB_DIR/rtk" ] && [ -f "$_RB_DIR/rtk" ]; then
    _RB_REAL_RTK="$_RB_DIR/rtk"
    break
  fi
done
IFS="$_RB_OLD_IFS"

export PATH="$_RB_BIN:$PATH"
export AICONTEXT_CONFIG_DIR="$_RB_TMP/config"
unset AICONTEXT_PROFILE AICONTEXT_USE_SHELL_STATE AICONTEXT_CAVEMAN_REQUEST AICONTEXT_RTK_BIN AICONTEXT_RTK_TIMEOUT
mkdir -p "$_RB_TMP/work"
cd "$_RB_TMP/work" || exit 1

# shellcheck source=../scripts/lib/wx-compress.sh
source "$_RB_ROOT/scripts/lib/wx-compress.sh"

# Strings that must be visible for the runs that have warnings or failures. They are independent of the guard.
markers_for() {
  case "$1" in
    cargo-test/pass-nocapture|go-test/pass-noisy) printf '%s\n' 'warning: slow path taken for large input' ;;
    pytest/pass-warnings) printf '%s\n' 'DeprecationWarning: old_api() is deprecated, use new_api()' ;;
    pytest/fail) printf '%s\n' 'FAILED tests/test_fail.py::test_total' 'tests/test_fail.py:4: AssertionError' ;;
  esac
}

percent() { # raw visible
  LC_ALL=C awk -v raw="$1" -v visible="$2" 'BEGIN { if (raw == 0) printf "n/a"; else printf "%.2f", (raw - visible) * 100 / raw }'
}

dash() { # empty or null becomes a dash
  case "$1" in ''|null) printf -- '-' ;; *) printf '%s' "$1" ;; esac
}

_RB_SECTION_ROWS=0
_RB_SECTION_RAW=0
_RB_SECTION_VISIBLE=0
_RB_SECTION_ACCEPTED=0
_RB_SECTION_FALLBACK=0
_RB_ROW_EXPECT_FAIL=0
_RB_NOTES=''

table_header() {
  printf '%s\n' '| command | profile | raw bytes | visible bytes | byte reduction % | output_policy | rtk_class | compressor | filter | fallback_reason | evidence preserved |'
  printf '%s\n' '| --- | --- | ---: | ---: | ---: | --- | --- | --- | --- | --- | --- |'
}

section_start() {
  _RB_SECTION_ROWS=0
  _RB_SECTION_RAW=0
  _RB_SECTION_VISIBLE=0
  _RB_SECTION_ACCEPTED=0
  _RB_SECTION_FALLBACK=0
  _RB_ROW_EXPECT_FAIL=0
  _RB_NOTES=''
  table_header
}

section_end() {
  [ -z "$_RB_NOTES" ] || printf '\n%s' "$_RB_NOTES"
  printf '\n%s\n' "- Rows: $_RB_SECTION_ROWS. Raw bytes: $_RB_SECTION_RAW. Visible bytes: $_RB_SECTION_VISIBLE. Byte reduction over all rows: $(percent "$_RB_SECTION_RAW" "$_RB_SECTION_VISIBLE")%. RTK or reducer output shown: $_RB_SECTION_ACCEPTED. Raw shown after a fallback: $_RB_SECTION_FALLBACK."
}

activate() { # profile
  if ! source "$_RB_ROOT/scripts/workflow.sh" "$1" >"$_RB_TMP/activation.out" 2>&1; then
    printf 'RTK benchmark could not activate profile %s.\n' "$1" >&2
    exit 1
  fi
}

# Run one recorded fixture through wx and print one table row.
# Args: fixture (<filter>/<case>), profile, rtk binary ("" for the one on the PATH), rtk call log, expected policy,
#       expected fallback reason ("-" for none), enforce (yes or no).
bench_row() {
  local _RB_FIXTURE="$1" _RB_PROFILE="$2" _RB_RTKBIN="$3" _RB_CALLS="$4" _RB_WANT_POLICY="$5" _RB_WANT_REASON="$6" _RB_ENFORCE="$7"
  local _RB_D="$_RB_REC/$_RB_FIXTURE"
  local -a _RB_ARGV
  local _RB_CODE _RB_EXIT _RB_REC_JSON _RB_RAWDIR _RB_STDERR_FILE _RB_EVIDENCE=yes _RB_MARKER
  local _RB_RAW _RB_VISIBLE _RB_POLICY _RB_CLASS _RB_COMP _RB_FILTER _RB_REASON _RB_CALLCOUNT

  read -r -a _RB_ARGV < "$_RB_D/cmd"
  _RB_CODE="$(cat "$_RB_D/exit")"
  _RB_STDERR_FILE="$_RB_D/stderr"
  [ -f "$_RB_STDERR_FILE" ] || _RB_STDERR_FILE=/dev/null
  : > "$_RB_CALLS"

  (
    export FIXTURE_CASE="$_RB_FIXTURE" FAKE_RTK_LOG="$_RB_CALLS" SPY_LOG="$_RB_CALLS"
    [ -n "$_RB_RTKBIN" ] && export AICONTEXT_RTK_BIN="$_RB_RTKBIN"
    wx "${_RB_ARGV[@]}" >"$_RB_TMP/wx.stdout" 2>"$_RB_TMP/wx.stderr"
  )
  _RB_EXIT=$?

  _RB_REC_JSON="$(jq -c -s '.[-1]' .ai-context/session.jsonl)"
  _RB_RAWDIR="$(dirname "$(jq -r '.stdout.path' <<< "$_RB_REC_JSON")")"
  _RB_RAW="$(jq -r '.raw.stdout_bytes + .raw.stderr_bytes' <<< "$_RB_REC_JSON")"
  _RB_VISIBLE="$(jq -r '.visible.stdout_bytes + .visible.stderr_bytes' <<< "$_RB_REC_JSON")"
  _RB_POLICY="$(jq -r '.output_policy' <<< "$_RB_REC_JSON")"
  _RB_CLASS="$(dash "$(jq -r '.rtk_class' <<< "$_RB_REC_JSON")")"
  _RB_COMP="$(dash "$(jq -r '.compressor' <<< "$_RB_REC_JSON")")"
  _RB_FILTER="$(dash "$(jq -r '.filter' <<< "$_RB_REC_JSON")")"
  _RB_REASON="$(dash "$(jq -r '.fallback_reason' <<< "$_RB_REC_JSON")")"
  _RB_CALLCOUNT="$(grep -c . "$_RB_CALLS" 2>/dev/null || true)"

  # Evidence preserved: the exit code, the raw files, stderr as recorded, the evidence-guard lines, and the markers.
  [ "$_RB_EXIT" -eq "$_RB_CODE" ] || _RB_EVIDENCE=no
  cmp -s "$_RB_RAWDIR/stdout.raw" "$_RB_D/stdout" || _RB_EVIDENCE=no
  cmp -s "$_RB_RAWDIR/stderr.raw" "$_RB_STDERR_FILE" || _RB_EVIDENCE=no
  [ "$(cat "$_RB_RAWDIR/exit_code.raw" 2>/dev/null)" = "$_RB_CODE" ] || _RB_EVIDENCE=no
  sed '$d' "$_RB_TMP/wx.stderr" | cmp -s - "$_RB_STDERR_FILE" || _RB_EVIDENCE=no
  _wx_evidence_guard "$_RB_D/stdout" "$_RB_TMP/wx.stdout" || _RB_EVIDENCE=no
  while IFS= read -r _RB_MARKER; do
    [ -n "$_RB_MARKER" ] || continue
    grep -Fq -- "$_RB_MARKER" "$_RB_TMP/wx.stdout" || _RB_EVIDENCE=no
  done < <(markers_for "$_RB_FIXTURE")
  # RTK is called only as --version and pipe -f <filter>.
  if [ "$_RB_CALLCOUNT" -gt 0 ] && grep -Evq -- '^(--version|pipe -f [a-z0-9-]+)$' "$_RB_CALLS"; then
    _RB_EVIDENCE=no
  fi

  _RB_SECTION_ROWS=$((_RB_SECTION_ROWS + 1))
  _RB_SECTION_RAW=$((_RB_SECTION_RAW + _RB_RAW))
  _RB_SECTION_VISIBLE=$((_RB_SECTION_VISIBLE + _RB_VISIBLE))
  case "$_RB_POLICY" in
    compress-rtk-v1|compress-exact-repeats-v1) _RB_SECTION_ACCEPTED=$((_RB_SECTION_ACCEPTED + 1)) ;;
    raw-rtk-fallback) _RB_SECTION_FALLBACK=$((_RB_SECTION_FALLBACK + 1)) ;;
  esac

  printf '| `%s` | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |\n' \
    "${_RB_ARGV[*]}" "$_RB_PROFILE" "$_RB_RAW" "$_RB_VISIBLE" "$(percent "$_RB_RAW" "$_RB_VISIBLE")" \
    "$_RB_POLICY" "$_RB_CLASS" "$_RB_COMP" "$_RB_FILTER" "$_RB_REASON" "$_RB_EVIDENCE"

  if [ "$_RB_EVIDENCE" != yes ]; then
    _RB_FAILED=true
    _RB_NOTES="${_RB_NOTES}- FAIL: evidence not preserved for ${_RB_ARGV[*]} in $_RB_PROFILE."$'\n'
  fi
  case "$_RB_PROFILE" in
    raw|security|db|migration|release)
      # Protected profiles: raw output, no compressor, and RTK is never called.
      if [ "$_RB_POLICY" != raw-protected-profile ] || [ "$_RB_RAW" -ne "$_RB_VISIBLE" ] || [ "$_RB_COMP" != "-" ] || [ "$_RB_CALLCOUNT" -ne 0 ]; then
        _RB_FAILED=true
        _RB_NOTES="${_RB_NOTES}- FAIL: protected profile $_RB_PROFILE did not stay raw (${_RB_ARGV[*]})."$'\n'
      fi
      ;;
  esac
  if [ "$_RB_POLICY" = "compress-rtk-v1" ] && [ "$_RB_VISIBLE" -ge "$_RB_RAW" ]; then
    _RB_FAILED=true
    _RB_NOTES="${_RB_NOTES}- FAIL: RTK output was shown but is not smaller (${_RB_ARGV[*]})."$'\n'
  fi
  if [ "$_RB_ENFORCE" = yes ]; then
    if [ "$_RB_POLICY" != "$_RB_WANT_POLICY" ] || [ "$_RB_REASON" != "$_RB_WANT_REASON" ]; then
      _RB_FAILED=true
      _RB_NOTES="${_RB_NOTES}- FAIL: ${_RB_ARGV[*]} in $_RB_PROFILE: expected $_RB_WANT_POLICY / $_RB_WANT_REASON, got $_RB_POLICY / $_RB_REASON."$'\n'
    fi
  elif [ "$_RB_POLICY" != "$_RB_WANT_POLICY" ] || [ "$_RB_REASON" != "$_RB_WANT_REASON" ]; then
    _RB_ROW_EXPECT_FAIL=$((_RB_ROW_EXPECT_FAIL + 1))
    _RB_NOTES="${_RB_NOTES}- NOTE: ${_RB_ARGV[*]} in $_RB_PROFILE differs from the pinned RTK 0.42.4 outcome ($_RB_WANT_POLICY / $_RB_WANT_REASON): got $_RB_POLICY / $_RB_REASON."$'\n'
  fi
}

# The rows. fixture|profile|expected policy|expected fallback reason
_RB_CODE_ROWS='cargo-test/pass-noisy|code|compress-rtk-v1|-
pytest/pass-noisy|code|compress-rtk-v1|-
go-test/pass-noisy|code|raw-rtk-fallback|evidence-guard
go-build/verbose|code|raw-empty-or-binary-output|-
tsc/pass-noisy|code|compress-rtk-v1|-
vitest/pass-verbose|code|compress-rtk-v1|-'
_RB_GUARD_ROWS='pytest/pass-warnings|code|raw-rtk-fallback|evidence-guard
cargo-test/pass-nocapture|code|raw-rtk-fallback|evidence-guard
pytest/fail|code|raw-nonzero-exit|-'
_RB_PROTECTED_ROWS='pytest/pass-noisy|raw|raw-protected-profile|-
pytest/pass-noisy|security|raw-protected-profile|-
pytest/pass-noisy|db|raw-protected-profile|-
pytest/pass-noisy|migration|raw-protected-profile|-
pytest/pass-noisy|release|raw-protected-profile|-'

run_rtk_rows() { # rtk binary ("" for the one on the PATH), call log, enforce (yes or no)
  local _RB_BIN_ARG="$1" _RB_LOG="$2" _RB_ENF="$3" _RB_PREV="" _RB_F _RB_P _RB_W _RB_R
  local _RB_ALL="$_RB_CODE_ROWS
$_RB_GUARD_ROWS
$_RB_PROTECTED_ROWS"
  while IFS='|' read -r _RB_F _RB_P _RB_W _RB_R; do
    [ "$_RB_P" = "$_RB_PREV" ] || activate "$_RB_P"
    _RB_PREV="$_RB_P"
    bench_row "$_RB_F" "$_RB_P" "$_RB_BIN_ARG" "$_RB_LOG" "$_RB_W" "$_RB_R" "$_RB_ENF"
  done <<< "$_RB_ALL"
}

printf '%s\n' '# RTK pipe benchmark'
printf '\n%s\n' 'Byte counts only. Byte reduction is not token savings, and no token count is measured. `wx` runs each recorded command once, saves the raw output, and only then may run `rtk pipe -f <filter>` on the captured stdout. "raw bytes" are the captured stdout and stderr. "visible bytes" are the stdout and stderr bytes that `wx` shows for the command, without the raw-log pointer line. "evidence preserved" is `yes` when the exit code, the raw files, and stderr match the recording, every evidence line of the raw stdout (the same heuristic `wx` uses) is in the visible stdout, and the independent markers for the run (warnings, failures) are visible. For RTK output that the guard accepted, the guard check passes by construction.'

# ---- 1. Built-in exact-repeat reducer (reference, not RTK) ----
printf '\n%s\n\n' '## 1. Built-in exact-repeat reducer (reference, not RTK)'
printf '%s\n\n' 'The reducer collapses consecutive identical lines, and only for commands on the `noisy_success_can_compress` list. It does not touch the commands in the RTK sections.'
activate code
section_start
_RB_BI_DIR="$_RB_TMP/builtin"
mkdir -p "$_RB_BI_DIR"
{
  wx npm install >"$_RB_BI_DIR/stdout" 2>"$_RB_BI_DIR/stderr"
  _RB_BI_EXIT=$?
} 2>/dev/null
_RB_BI_REC="$(jq -c -s '.[-1]' .ai-context/session.jsonl)"
_RB_BI_RAW="$(jq -r '.raw.stdout_bytes + .raw.stderr_bytes' <<< "$_RB_BI_REC")"
_RB_BI_VIS="$(jq -r '.visible.stdout_bytes + .visible.stderr_bytes' <<< "$_RB_BI_REC")"
_RB_BI_EVIDENCE=yes
cmp -s "$(jq -r '.stdout.path' <<< "$_RB_BI_REC")" <("$_RB_BIN/npm" install 2>/dev/null) || _RB_BI_EVIDENCE=no
[ "$_RB_BI_EXIT" -eq 0 ] || _RB_BI_EVIDENCE=no
[ "$(jq -r '.compressor' <<< "$_RB_BI_REC")" = 'builtin/exact-repeat-v1' ] || _RB_FAILED=true
[ "$(jq -r '.rtk_class' <<< "$_RB_BI_REC")" = null ] || _RB_FAILED=true
[ "$_RB_BI_EVIDENCE" = yes ] || _RB_FAILED=true
[ "$_RB_BI_VIS" -lt "$_RB_BI_RAW" ] || _RB_FAILED=true
_RB_SECTION_ROWS=1
_RB_SECTION_RAW="$_RB_BI_RAW"
_RB_SECTION_VISIBLE="$_RB_BI_VIS"
_RB_SECTION_ACCEPTED=1
printf '| `%s` | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |\n' \
  'npm install' code "$_RB_BI_RAW" "$_RB_BI_VIS" "$(percent "$_RB_BI_RAW" "$_RB_BI_VIS")" \
  "$(jq -r '.output_policy' <<< "$_RB_BI_REC")" "$(dash "$(jq -r '.rtk_class' <<< "$_RB_BI_REC")")" \
  "$(dash "$(jq -r '.compressor' <<< "$_RB_BI_REC")")" "$(dash "$(jq -r '.filter' <<< "$_RB_BI_REC")")" \
  "$(dash "$(jq -r '.fallback_reason' <<< "$_RB_BI_REC")")" "$_RB_BI_EVIDENCE"
section_end

printf '\n%s\n\n' 'What the exact-repeat reducer would do to the raw stdout of the RTK fixtures. This is computed offline. `wx` does not apply it to these commands.'
printf '%s\n' '| fixture | raw stdout bytes | after exact-repeat collapse | byte reduction % |'
printf '%s\n' '| --- | ---: | ---: | ---: |'
for _RB_D in "$_RB_REC"/*/*/; do
  _RB_NAME="${_RB_D%/}"
  _RB_NAME="$(basename "$(dirname "$_RB_NAME")")/$(basename "$_RB_NAME")"
  [ "$(cat "$_RB_D/exit")" = 0 ] || continue
  [ -s "$_RB_D/stdout" ] || continue
  _wx_compress_exact_repeats "$_RB_D/stdout" "$_RB_TMP/repeat.out"
  _RB_RB="$(stat -c '%s' "$_RB_D/stdout")"
  _RB_RV="$(stat -c '%s' "$_RB_TMP/repeat.out")"
  printf '| %s | %s | %s | %s |\n' "$_RB_NAME" "$_RB_RB" "$_RB_RV" "$(percent "$_RB_RB" "$_RB_RV")"
done

# ---- 2. RTK pipe with the fake RTK ----
printf '\n%s\n\n' '## 2. RTK pipe, fake RTK (pipeline check)'
printf '%s\n\n' 'The fake RTK keeps lines that start with warning, error, or panic, plus the last line. Its output is not RTK output. The rows check the pipeline: raw capture first, the one RTK call, the evidence guard, the fallback, and the protected profiles. Outcomes are enforced here.'
section_start
run_rtk_rows "" "$_RB_TMP/fake.calls" yes
section_end
printf '%s\n' "- Fake RTK result: every row matched its expected outcome and kept its evidence: $([ "$_RB_FAILED" = false ] && echo yes || echo no)."

# ---- 3. RTK pipe with a real RTK ----
printf '\n%s\n\n' '## 3. RTK pipe, real RTK'
if [ -n "$_RB_REAL_RTK" ]; then
  _RB_REAL_VERSION="$("$_RB_REAL_RTK" --version 2>/dev/null | head -n 1)"
  printf '%s\n\n' "Real RTK: \`$_RB_REAL_VERSION\` at \`$_RB_REAL_RTK\`, called through a spy script that logs every call. These byte counts are RTK's own output. Outcomes are pinned for 0.42.4 only. A different outcome is a NOTE, and a raw-output, evidence, or protected-profile failure is a FAIL."
  printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >> "$SPY_LOG"\nexec "%s" "$@"\n' "$_RB_REAL_RTK" > "$_RB_TMP/spy-rtk"
  chmod +x "$_RB_TMP/spy-rtk"
  _RB_ENFORCE_REAL=no
  case "$_RB_REAL_VERSION" in *0.42.4*) _RB_ENFORCE_REAL=yes ;; esac
  section_start
  run_rtk_rows "$_RB_TMP/spy-rtk" "$_RB_TMP/real.calls" "$_RB_ENFORCE_REAL"
  section_end
  printf '%s\n' "- Real RTK result: $([ "$_RB_ENFORCE_REAL" = yes ] && echo 'every row matched the pinned 0.42.4 outcome' || echo "$_RB_ROW_EXPECT_FAIL rows differ from the 0.42.4 outcomes (not a failure)")."
else
  printf '%s\n' 'SKIPPED: real RTK is not installed. Section 2 ran with the fake RTK.'
fi

# ---- Verdict ----
printf '\n%s\n\n' '## Result'
if [ "$_RB_FAILED" = false ]; then
  printf '%s\n' '- Result: **PASS.** Every row kept its evidence. Failing runs, empty stdout, evidence-guard fallbacks, and protected profiles showed raw output. RTK was called only as `--version` and `pipe -f <filter>`, and never in a protected profile.'
  printf '%s\n' '- Scope: byte counts on recorded runs. No token count is measured and no token saving is claimed. The `cargo-test` recordings are hand-written.'
  exit 0
fi
printf '%s\n' '- Result: **FAIL.** At least one row lost evidence, did not stay raw, or did not match its expected outcome. See the FAIL comments and the rows marked `no`.'
exit 1
