#!/usr/bin/env bash
# RTK pipe benchmark. It measures what `wx` shows when RTK filters the captured stdout, and keeps that apart from
# the built-in exact-repeat reducer. Everything is measured in bytes. Byte reduction is not token savings.
#
# Sections:
#   1. Built-in exact-repeat reducer (reference). Not RTK.
#   2. RTK pipe with the fake RTK from tests/fixtures/bin/rtk. This always runs. It checks the pipeline. The fake
#      RTK's output is not RTK's output, so its byte counts say nothing about RTK itself.
#   3. RTK pipe with a real rtk, only if one is installed. Otherwise this section is skipped.
# Rows come from the fixture matrix tests/fixtures/rtk/MATRIX: all 18 pipe filters, by group (A built-in tools,
# B code diagnostics, C search/list/history, D generic log). See PROVENANCE.txt there for which outputs are recorded
# and which are hand-written. No mapping or config is changed.
#
# Usage: bash benchmarks/run-rtk-benchmark.sh [> summary.md]
# Exit code: 0 when every hard check and every pinned outcome holds, 1 otherwise. A known loss of evidence in a shown
# RTK output (pinned in the matrix) does not fail the run. It is listed and counted.

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

bash "$_RB_FIX/link-shims.sh" "$_RB_TMP/shims"

# Matrix rows: fixture group kind fake real real_evidence
_RB_MATRIX="$(grep -v '^#' "$_RB_REC/MATRIX" | grep . | awk '$2 != "X"')"
_RB_FILTERS='cargo-test pytest go-build vitest mypy ruff-check grep rg find fd git-log git-status git-diff log'

outcome_policy() { # matrix outcome -> "output_policy|fallback_reason"
  case "$1" in
    accepted) printf '%s' 'compress-rtk-v1|-' ;;
    guard) printf '%s' 'raw-rtk-fallback|evidence-guard' ;;
    smaller) printf '%s' 'raw-rtk-fallback|rtk-not-smaller' ;;
    rtk-empty) printf '%s' 'raw-rtk-fallback|rtk-empty-output' ;;
    nonzero) printf '%s' 'raw-nonzero-exit|-' ;;
    empty) printf '%s' 'raw-empty-or-binary-output|-' ;;
    *) printf '%s' 'unknown|unknown' ;;
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
_RB_LOSSES=''
_RB_LOSS_COUNT=0
declare -A _RB_F_ROWS _RB_F_RAW _RB_F_VIS _RB_F_ACC _RB_F_FALL _RB_F_LOSS

table_header() {
  printf '%s\n' '| command | profile | raw bytes | visible bytes | byte reduction % | output_policy | class | compressor | filter | fallback_reason | evidence preserved | fixture |'
  printf '%s\n' '| --- | --- | ---: | ---: | ---: | --- | --- | --- | --- | --- | --- | --- |'
}

section_start() {
  _RB_SECTION_ROWS=0
  _RB_SECTION_RAW=0
  _RB_SECTION_VISIBLE=0
  _RB_SECTION_ACCEPTED=0
  _RB_SECTION_FALLBACK=0
  _RB_ROW_EXPECT_FAIL=0
  _RB_NOTES=''
  _RB_F_ROWS=(); _RB_F_RAW=(); _RB_F_VIS=(); _RB_F_ACC=(); _RB_F_FALL=(); _RB_F_LOSS=()
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

# Run one fixture through wx and print one table row.
# Args: fixture (<filter>/<case>), profile, rtk binary ("" for the one on the PATH), rtk call log, expected outcome
#       (matrix outcome), expected evidence (yes, no, n/a; "" when not pinned), section (fake or real),
#       enforce (yes or no: pin the outcome).
# "evidence preserved" is yes when: the exit code, the raw files, and stderr match the recording; every evidence line of
# the raw stdout (the guard) is in the visible stdout; and, in the real section or when raw output is shown, every marker
# of the fixture is in the visible stdout. In the fake section a shown RTK output is the fake's, so markers do not apply.
bench_row() {
  local _RB_FIXTURE="$1" _RB_PROFILE="$2" _RB_RTKBIN="$3" _RB_CALLS="$4" _RB_WANT="$5" _RB_WANT_EV="$6" _RB_SECT="$7" _RB_ENFORCE="$8"
  local _RB_D="$_RB_REC/$_RB_FIXTURE" _RB_F="${_RB_FIXTURE%%/*}"
  local -a _RB_ARGV
  local _RB_CODE _RB_EXIT _RB_REC_JSON _RB_RAWDIR _RB_STDERR_FILE _RB_BASE=yes _RB_MARK=yes _RB_EVIDENCE _RB_MARKER
  local _RB_RAW _RB_VISIBLE _RB_POLICY _RB_CLASS _RB_COMP _RB_FILTER _RB_REASON _RB_CALLCOUNT _RB_WANT_POLICY _RB_WANT_REASON _RB_HAS_MARKERS=no

  read -r -a _RB_ARGV < "$_RB_D/cmd"
  _RB_CODE="$(cat "$_RB_D/exit")"
  _RB_STDERR_FILE="$_RB_D/stderr"
  [ -f "$_RB_STDERR_FILE" ] || _RB_STDERR_FILE=/dev/null
  : > "$_RB_CALLS"

  (
    export PATH="$_RB_TMP/shims:$PATH"
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

  # Base evidence: exit code, raw files, stderr, and the guard on the visible stdout.
  [ "$_RB_EXIT" -eq "$_RB_CODE" ] || _RB_BASE=no
  cmp -s "$_RB_RAWDIR/stdout.raw" "$_RB_D/stdout" || _RB_BASE=no
  cmp -s "$_RB_RAWDIR/stderr.raw" "$_RB_STDERR_FILE" || _RB_BASE=no
  [ "$(cat "$_RB_RAWDIR/exit_code.raw" 2>/dev/null)" = "$_RB_CODE" ] || _RB_BASE=no
  sed '$d' "$_RB_TMP/wx.stderr" | cmp -s - "$_RB_STDERR_FILE" || _RB_BASE=no
  _wx_evidence_guard "$_RB_D/stdout" "$_RB_TMP/wx.stdout" || _RB_BASE=no
  # RTK is called only as --version and pipe -f <filter>.
  if [ "$_RB_CALLCOUNT" -gt 0 ] && grep -Evq -- '^(--version|pipe -f [a-z0-9-]+)$' "$_RB_CALLS"; then
    _RB_BASE=no
  fi
  # Markers: the evidence text of the fixture.
  if [ -f "$_RB_D/markers" ]; then
    _RB_HAS_MARKERS=yes
    while IFS= read -r _RB_MARKER; do
      [ -n "$_RB_MARKER" ] || continue
      grep -Fq -- "$_RB_MARKER" "$_RB_TMP/wx.stdout" || _RB_MARK=no
    done < "$_RB_D/markers"
  fi
  if [ "$_RB_SECT" = fake ] && [ "$_RB_POLICY" = compress-rtk-v1 ]; then _RB_MARK=yes; fi
  _RB_EVIDENCE=yes
  [ "$_RB_BASE" = yes ] && [ "$_RB_MARK" = yes ] || _RB_EVIDENCE=no

  _RB_SECTION_ROWS=$((_RB_SECTION_ROWS + 1))
  _RB_SECTION_RAW=$((_RB_SECTION_RAW + _RB_RAW))
  _RB_SECTION_VISIBLE=$((_RB_SECTION_VISIBLE + _RB_VISIBLE))
  case "$_RB_POLICY" in
    compress-rtk-v1|compress-exact-repeats-v1) _RB_SECTION_ACCEPTED=$((_RB_SECTION_ACCEPTED + 1)) ;;
    raw-rtk-fallback) _RB_SECTION_FALLBACK=$((_RB_SECTION_FALLBACK + 1)) ;;
  esac
  if [ "$_RB_PROFILE" = code ]; then
    _RB_F_ROWS[$_RB_F]=$(( ${_RB_F_ROWS[$_RB_F]:-0} + 1 ))
    _RB_F_RAW[$_RB_F]=$(( ${_RB_F_RAW[$_RB_F]:-0} + _RB_RAW ))
    _RB_F_VIS[$_RB_F]=$(( ${_RB_F_VIS[$_RB_F]:-0} + _RB_VISIBLE ))
    case "$_RB_POLICY" in
      compress-rtk-v1) _RB_F_ACC[$_RB_F]=$(( ${_RB_F_ACC[$_RB_F]:-0} + 1 )) ;;
      raw-rtk-fallback) _RB_F_FALL[$_RB_F]=$(( ${_RB_F_FALL[$_RB_F]:-0} + 1 )) ;;
    esac
  fi

  printf '| `%s` | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |\n' \
    "${_RB_ARGV[*]}" "$_RB_PROFILE" "$_RB_RAW" "$_RB_VISIBLE" "$(percent "$_RB_RAW" "$_RB_VISIBLE")" \
    "$_RB_POLICY" "$_RB_CLASS" "$_RB_COMP" "$_RB_FILTER" "$_RB_REASON" "$_RB_EVIDENCE" "$_RB_FIXTURE"

  # Hard checks. They fail the run in every section.
  if [ "$_RB_BASE" != yes ]; then
    _RB_FAILED=true
    _RB_NOTES="${_RB_NOTES}- FAIL: raw capture, exit code, stderr, or an evidence line was lost for $_RB_FIXTURE in $_RB_PROFILE."$'\n'
  fi
  case "$_RB_PROFILE" in
    raw|security|db|migration|release)
      # Protected profiles: raw output, no compressor, and RTK is never called.
      if [ "$_RB_POLICY" != raw-protected-profile ] || [ "$_RB_RAW" -ne "$_RB_VISIBLE" ] || [ "$_RB_COMP" != "-" ] || [ "$_RB_CALLCOUNT" -ne 0 ]; then
        _RB_FAILED=true
        _RB_NOTES="${_RB_NOTES}- FAIL: protected profile $_RB_PROFILE did not stay raw ($_RB_FIXTURE)."$'\n'
      fi
      return
      ;;
  esac
  if [ "$_RB_POLICY" = "compress-rtk-v1" ] && [ "$_RB_VISIBLE" -ge "$_RB_RAW" ]; then
    _RB_FAILED=true
    _RB_NOTES="${_RB_NOTES}- FAIL: RTK output was shown but is not smaller ($_RB_FIXTURE)."$'\n'
  fi
  if [ "$_RB_POLICY" != compress-rtk-v1 ] && [ "$_RB_MARK" != yes ]; then
    _RB_FAILED=true
    _RB_NOTES="${_RB_NOTES}- FAIL: raw output was shown but a marker is missing ($_RB_FIXTURE)."$'\n'
  fi
  # Pinned outcome and pinned evidence result.
  _RB_WANT_POLICY="$(outcome_policy "$_RB_WANT")"
  _RB_WANT_REASON="${_RB_WANT_POLICY#*|}"
  _RB_WANT_POLICY="${_RB_WANT_POLICY%%|*}"
  if [ "$_RB_POLICY" != "$_RB_WANT_POLICY" ] || [ "$_RB_REASON" != "$_RB_WANT_REASON" ]; then
    if [ "$_RB_ENFORCE" = yes ]; then
      _RB_FAILED=true
      _RB_NOTES="${_RB_NOTES}- FAIL: $_RB_FIXTURE expected $_RB_WANT_POLICY / $_RB_WANT_REASON, got $_RB_POLICY / $_RB_REASON."$'\n'
    else
      _RB_ROW_EXPECT_FAIL=$((_RB_ROW_EXPECT_FAIL + 1))
      _RB_NOTES="${_RB_NOTES}- NOTE: $_RB_FIXTURE differs from the pinned RTK 0.42.4 outcome ($_RB_WANT_POLICY / $_RB_WANT_REASON): got $_RB_POLICY / $_RB_REASON."$'\n'
    fi
  fi
  if [ "$_RB_SECT" = real ] && [ -n "$_RB_WANT_EV" ]; then
    _RB_GOT_EV="$_RB_MARK"
    [ "$_RB_HAS_MARKERS" = yes ] || _RB_GOT_EV='n/a'
    if [ "$_RB_GOT_EV" != "$_RB_WANT_EV" ]; then
      if [ "$_RB_ENFORCE" = yes ]; then
        _RB_FAILED=true
        _RB_NOTES="${_RB_NOTES}- FAIL: $_RB_FIXTURE evidence result is $_RB_GOT_EV, pinned $_RB_WANT_EV."$'\n'
      else
        _RB_NOTES="${_RB_NOTES}- NOTE: $_RB_FIXTURE evidence result is $_RB_GOT_EV, pinned for 0.42.4: $_RB_WANT_EV."$'\n'
      fi
    fi
    if [ "$_RB_POLICY" = compress-rtk-v1 ] && [ "$_RB_MARK" = no ]; then
      _RB_LOSS_COUNT=$((_RB_LOSS_COUNT + 1))
      _RB_F_LOSS[$_RB_F]=$(( ${_RB_F_LOSS[$_RB_F]:-0} + 1 ))
      _RB_LOSSES="${_RB_LOSSES}- KNOWN LOSS: \`${_RB_ARGV[*]}\` ($_RB_FIXTURE): $_RB_RAW bytes became $_RB_VISIBLE, text missing from the shown RTK output."$'\n'
    fi
  fi
}

# Rows: every fixture of the matrix in the code profile, then the protected profiles.
run_rtk_rows() { # rtk binary ("" for the one on the PATH), call log, enforce (yes or no), section (fake or real)
  local _RB_BIN_ARG="$1" _RB_LOG="$2" _RB_ENF="$3" _RB_SEC="$4"
  local _RB_C _RB_G _RB_K _RB_FK _RB_RL _RB_EV _RB_WANT _RB_WEV _RB_FIL _RB_PC _RB_P
  activate code
  while read -r _RB_C _RB_G _RB_K _RB_FK _RB_RL _RB_EV; do
    if [ "$_RB_SEC" = fake ]; then _RB_WANT="$_RB_FK"; _RB_WEV=""; else _RB_WANT="$_RB_RL"; _RB_WEV="$_RB_EV"; fi
    bench_row "$_RB_C" code "$_RB_BIN_ARG" "$_RB_LOG" "$_RB_WANT" "$_RB_WEV" "$_RB_SEC" "$_RB_ENF"
  done <<< "$_RB_MATRIX"
  # Protected profiles: the first success fixture of every filter in security, and pytest in the other protected profiles.
  for _RB_P in security raw db migration release; do
    activate "$_RB_P"
    for _RB_FIL in $_RB_FILTERS; do
      if [ "$_RB_P" != security ] && [ "$_RB_FIL" != pytest ]; then continue; fi
      _RB_PC="$(printf '%s\n' "$_RB_MATRIX" | awk -v f="$_RB_FIL" '{ split($1, a, "/"); if (a[1] == f && $3 == "success" && $4 != "nonzero" && $4 != "empty") { print $1; exit } }')"
      [ -n "$_RB_PC" ] || _RB_PC="$(printf '%s\n' "$_RB_MATRIX" | awk -v f="$_RB_FIL" '{ split($1, a, "/"); if (a[1] == f && $3 == "success") { print $1; exit } }')"
      bench_row "$_RB_PC" "$_RB_P" "$_RB_BIN_ARG" "$_RB_LOG" nonzero "" "$_RB_SEC" "$_RB_ENF"
    done
  done
}

filter_summary() { # per-filter table for the section that just ran
  local _RB_FIL _RB_GROUP
  printf '\n%s\n' '| filter | group | rows (code profile) | RTK output shown | raw shown after fallback | raw bytes | visible bytes | byte reduction % | known losses |'
  printf '%s\n' '| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |'
  for _RB_FIL in $_RB_FILTERS; do
    _RB_GROUP="$(printf '%s\n' "$_RB_MATRIX" | awk -v f="$_RB_FIL" '{ split($1, a, "/"); if (a[1] == f) { print $2; exit } }')"
    printf '| %s | %s | %s | %s | %s | %s | %s | %s | %s |\n' "$_RB_FIL" "$_RB_GROUP" "${_RB_F_ROWS[$_RB_FIL]:-0}" "${_RB_F_ACC[$_RB_FIL]:-0}" "${_RB_F_FALL[$_RB_FIL]:-0}" \
      "${_RB_F_RAW[$_RB_FIL]:-0}" "${_RB_F_VIS[$_RB_FIL]:-0}" "$(percent "${_RB_F_RAW[$_RB_FIL]:-0}" "${_RB_F_VIS[$_RB_FIL]:-0}")" "${_RB_F_LOSS[$_RB_FIL]:-0}"
  done
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
printf '| `%s` | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |\n' \
  'npm install' code "$_RB_BI_RAW" "$_RB_BI_VIS" "$(percent "$_RB_BI_RAW" "$_RB_BI_VIS")" \
  "$(jq -r '.output_policy' <<< "$_RB_BI_REC")" "$(dash "$(jq -r '.rtk_class' <<< "$_RB_BI_REC")")" \
  "$(dash "$(jq -r '.compressor' <<< "$_RB_BI_REC")")" "$(dash "$(jq -r '.filter' <<< "$_RB_BI_REC")")" \
  "$(dash "$(jq -r '.fallback_reason' <<< "$_RB_BI_REC")")" "$_RB_BI_EVIDENCE" -
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
printf '%s\n\n' 'The fake RTK keeps lines that start with warning, error, or panic, plus the last line. Its output is not RTK output, so markers are not checked on a shown fake output. The rows check the pipeline for every fixture of the matrix: raw capture first, the one RTK call, the evidence guard, the fallback, and the protected profiles. Outcomes are enforced here.'
section_start
run_rtk_rows "" "$_RB_TMP/fake.calls" yes fake
section_end
filter_summary
printf '\n%s\n' "- Fake RTK result: every row matched its expected outcome and kept its raw evidence: $([ "$_RB_FAILED" = false ] && echo yes || echo no)."

# ---- 3. RTK pipe with a real RTK ----
printf '\n%s\n\n' '## 3. RTK pipe, real RTK'
if [ -n "$_RB_REAL_RTK" ]; then
  _RB_REAL_VERSION="$("$_RB_REAL_RTK" --version 2>/dev/null | head -n 1)"
  printf '%s\n\n' "Real RTK: \`$_RB_REAL_VERSION\` at \`$_RB_REAL_RTK\`, called through a spy script that logs every call. These byte counts are RTK's own output. Outcomes and evidence results are pinned in the matrix for 0.42.4 only. A different outcome is a NOTE. A lost raw capture, exit code, stderr, protected-profile run, or an evidence result that differs from the pin is a FAIL. \"evidence preserved\" is \`no\` when text that the fixture marks as evidence is missing from the shown output."
  printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >> "$SPY_LOG"\nexec "%s" "$@"\n' "$_RB_REAL_RTK" > "$_RB_TMP/spy-rtk"
  chmod +x "$_RB_TMP/spy-rtk"
  _RB_ENFORCE_REAL=no
  case "$_RB_REAL_VERSION" in *0.42.4*) _RB_ENFORCE_REAL=yes ;; esac
  section_start
  run_rtk_rows "$_RB_TMP/spy-rtk" "$_RB_TMP/real.calls" "$_RB_ENFORCE_REAL" real
  section_end
  filter_summary
  if [ -n "$_RB_LOSSES" ]; then
    printf '\n%s\n\n%s' "Known losses: RTK output was shown (the evidence guard accepted it) and text that the fixture marks as evidence is missing. Raw output is kept in \`.ai-context/raw\`. These are pinned, so they do not fail the run." "$_RB_LOSSES"
  fi
  printf '\n%s\n' "- Real RTK result: $([ "$_RB_ENFORCE_REAL" = yes ] && echo 'every row matched the pinned 0.42.4 outcome and evidence result' || echo "$_RB_ROW_EXPECT_FAIL rows differ from the 0.42.4 outcomes (not a failure)"). Known losses in shown output: $_RB_LOSS_COUNT."
else
  printf '%s\n' 'SKIPPED: real RTK is not installed. Section 2 ran with the fake RTK.'
fi

# ---- Verdict ----
printf '\n%s\n\n' '## Result'
if [ "$_RB_FAILED" = false ]; then
  printf '%s\n' '- Result: **PASS.** Raw capture, exit codes, and stderr held in every row. Failing runs, empty stdout, evidence-guard fallbacks, and protected profiles showed raw output. RTK was called only as `--version` and `pipe -f <filter>`, and never in a protected profile. Every pinned outcome held.'
  [ "$_RB_LOSS_COUNT" -eq 0 ] || printf '%s\n' "- **Not clean:** $_RB_LOSS_COUNT shown real-RTK outputs lose text that their fixtures mark as evidence (see Known losses). They are accepted today and tracked in docs/TECHNICAL_DEBT.md."
  printf '%s\n' '- Scope: byte counts on recorded and hand-written runs. No token count is measured and no token saving is claimed. The `cargo-test`, `mypy`, `ruff-check`, `ruff-format`, `prettier`, `rg`, `fd`, and `log` outputs are hand-written, so RTK results on them show how RTK treats that text, not how the tool behaves.'
  exit 0
fi
printf '%s\n' '- Result: **FAIL.** At least one row lost raw evidence, did not stay raw, or did not match its pinned outcome. See the FAIL comments and the rows marked `no`.'
exit 1
