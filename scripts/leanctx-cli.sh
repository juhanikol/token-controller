#!/usr/bin/env bash
# Path: scripts/leanctx-cli.sh
# Controlled LeanCTX CLI adapter. Run through: workflow leanctx <command> (or scripts/workflow-cli.sh leanctx ...).
#
#   status                                  Report mode, policy, binary, version, and whether operations are allowed.
#   read <path> [--mode signatures|map|task|reference|auto]   Exploration read (default: signatures). Not exact.
#   search <pattern> [path]                 lean-ctx grep. Fails if LeanCTX has no match but a raw grep has one.
#   tree [path]                             lean-ctx ls.
#   read-exact <path>                       lean-ctx read -m full --fresh. Printed only if it equals the file, byte for byte.
#
# Rules: the active mode comes from active_mode.env (never from shell variables). Modes with AICONTEXT_LEANCTX_MODE off
# and the raw, security, db, migration, release, micro, snippet, and off profiles are refused. The leanctx_policy in the
# settings file must keep shell, wrap, setup, and init off. Only "read", "grep", "ls", and "--version" are ever run.
# Never: wrap, setup, init, onboard, doctor --fix, status, -c, ctx_shell, shell hooks, MCP config changes, or wx.
# Paths must be inside the current directory. Exit codes: 0 ok, 1 refused, 2 usage, 3 verification failed, 4 lean-ctx failed.

set -u

_LC_SELF="$(readlink -f -- "${BASH_SOURCE[0]}" 2>/dev/null || printf '%s' "${BASH_SOURCE[0]}")"
_LC_ROOT="$(cd -- "$(dirname -- "$_LC_SELF")/.." && pwd)"
_LC_CONFIG_DIR="${AICONTEXT_CONFIG_DIR:-$HOME/.config/ai-workflow}"
_LC_ENV_FILE="$_LC_CONFIG_DIR/active_mode.env"
_LC_SETTINGS="${AICONTEXT_SETTINGS_FILE:-$_LC_ROOT/config/workflow_settings.json}"
_LC_TIMEOUT="${AICONTEXT_LEANCTX_TIMEOUT:-30}"
case "$_LC_TIMEOUT" in ''|*[!0-9]*) _LC_TIMEOUT=30 ;; esac
_LC_MAX_EXACT=5242880
_LC_TMP=""
trap '[ -n "$_LC_TMP" ] && rm -rf -- "$_LC_TMP"' EXIT

msg() { printf 'workflow leanctx: %s\n' "$1" >&2; }
refuse() { msg "refused: $1"; exit 1; }
usage_error() { msg "$1"; msg "usage: workflow leanctx status [--json] | read <path> [--mode signatures|map|task|reference|auto] | search <pattern> [path] | tree [path] | read-exact <path>"; exit 2; }

env_value() { sed -n "s/^export $1=\"\\(.*\\)\"\$/\\1/p" "$_LC_ENV_FILE" 2>/dev/null | head -n 1; }

# ---- state: active_mode.env, policy, binary ----
_LC_PROFILE=""
_LC_MODE=""
_LC_REASONS=()   # why LeanCTX operations are not allowed (empty = allowed)
_LC_BIN=""
_LC_BIN_REAL=""
_LC_BIN_KIND=""
_LC_VERSION=""
_LC_POLICY_SHELL="" _LC_POLICY_WRAP="" _LC_POLICY_SETUP="" _LC_POLICY_INIT="" _LC_POLICY_OWNER=""
_LC_OP_READ="" _LC_OP_SEARCH="" _LC_OP_TREE=""

load_state() {
  _LC_REASONS=()
  if [ ! -f "$_LC_ENV_FILE" ]; then
    _LC_REASONS+=("no active mode file ($_LC_ENV_FILE). Run: workflow <mode>")
  else
    _LC_PROFILE="$(env_value AICONTEXT_PROFILE)"
    _LC_MODE="$(env_value AICONTEXT_LEANCTX_MODE)"
    [ -n "$_LC_PROFILE" ] || _LC_REASONS+=("active_mode.env has no profile")
    case "$_LC_PROFILE" in
      raw|security|db|migration|release|micro|snippet|off) _LC_REASONS+=("profile '$_LC_PROFILE' does not use LeanCTX") ;;
    esac
    case "$_LC_MODE" in
      auto|context-read|graph-read|diagnostic|guarded) ;;
      off|'') _LC_REASONS+=("AICONTEXT_LEANCTX_MODE is off for profile '${_LC_PROFILE:-none}'") ;;
      *) _LC_REASONS+=("AICONTEXT_LEANCTX_MODE '$_LC_MODE' is not known") ;;
    esac
  fi
  if ! command -v jq >/dev/null 2>&1; then
    _LC_REASONS+=("jq is missing")
  elif [ ! -r "$_LC_SETTINGS" ] || ! jq -e '.leanctx_policy | type == "object"' "$_LC_SETTINGS" >/dev/null 2>&1; then
    _LC_REASONS+=("no leanctx_policy in the settings file")
  else
    _LC_POLICY_SHELL="$(jq -r '.leanctx_policy.shell_enabled | if type == "boolean" then tostring else "invalid" end' "$_LC_SETTINGS")"
    _LC_POLICY_WRAP="$(jq -r '.leanctx_policy.auto_wrap | if type == "boolean" then tostring else "invalid" end' "$_LC_SETTINGS")"
    _LC_POLICY_SETUP="$(jq -r '.leanctx_policy.auto_setup | if type == "boolean" then tostring else "invalid" end' "$_LC_SETTINGS")"
    _LC_POLICY_INIT="$(jq -r '.leanctx_policy.auto_init | if type == "boolean" then tostring else "invalid" end' "$_LC_SETTINGS")"
    _LC_POLICY_OWNER="$(jq -r '.leanctx_policy.shell_owner | tostring' "$_LC_SETTINGS")"
    _LC_OP_READ="$(jq -r '.leanctx_policy.operations.read.status // "missing"' "$_LC_SETTINGS")"
    _LC_OP_SEARCH="$(jq -r '.leanctx_policy.operations.search.status // "missing"' "$_LC_SETTINGS")"
    _LC_OP_TREE="$(jq -r '.leanctx_policy.operations.tree.status // "missing"' "$_LC_SETTINGS")"
    [ "$_LC_POLICY_SHELL" = false ] || _LC_REASONS+=("leanctx_policy.shell_enabled is not false. Phase one needs wx to own shell output")
    [ "$_LC_POLICY_OWNER" = wx ] || _LC_REASONS+=("leanctx_policy.shell_owner is not wx")
    [ "$_LC_POLICY_WRAP" = false ] || _LC_REASONS+=("leanctx_policy.auto_wrap is not false")
    [ "$_LC_POLICY_SETUP" = false ] || _LC_REASONS+=("leanctx_policy.auto_setup is not false")
    [ "$_LC_POLICY_INIT" = false ] || _LC_REASONS+=("leanctx_policy.auto_init is not false")
  fi
}

# True if path $1 is $2 or inside it.
# The home directory and / are not a project, so an installed ~/.local/bin/lean-ctx is not "inside the project".
inside() {
  local _home_real
  _home_real="$(readlink -f -- "$HOME" 2>/dev/null || printf '%s' "$HOME")"
  [ "$2" = "$HOME" ] || [ "$2" = "$_home_real" ] || [ "$2" = / ] && return 1
  case "$1" in "$2"|"$2"/*) return 0 ;; esac
  return 1
}

load_binary() {
  _LC_BIN=""
  _LC_BIN_REAL=""
  _LC_BIN_KIND=""
  local _cand="" _real _proj_pwd _proj_top="" _wsl=false _mnt="${AICONTEXT_MNT_PREFIX:-/mnt/}" _p
  if [ "${AICONTEXT_LEANCTX_BIN+set}" = set ]; then
    _cand="$AICONTEXT_LEANCTX_BIN"
    case "$_cand" in
      ''|/*) ;;
      *) _LC_REASONS+=("AICONTEXT_LEANCTX_BIN must be an absolute path ($_cand)"); return ;;
    esac
  else
    _cand="$(command -v lean-ctx 2>/dev/null || true)"
    # A relative PATH entry (for example ".") gives a relative result. Make it absolute so the project check sees it.
    case "$_cand" in ''|/*) ;; *) _cand="$PWD/$_cand" ;; esac
  fi
  if [ -z "$_cand" ] || [ ! -f "$_cand" ] || [ ! -x "$_cand" ]; then
    _LC_REASONS+=("lean-ctx was not found")
    return
  fi
  _real="$(readlink -f -- "$_cand" 2>/dev/null || true)"
  [ -n "$_real" ] || _real="$_cand"
  _LC_BIN="$_cand"
  _LC_BIN_REAL="$_real"
  _LC_BIN_KIND=linux
  # A binary inside the project directory is project-controlled code. Checked for the path as given and the real path.
  _proj_pwd="$(realpath -e -- "$PWD" 2>/dev/null || printf '%s' "$PWD")"
  _proj_top="$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null || true)"
  [ -z "$_proj_top" ] || _proj_top="$(realpath -e -- "$_proj_top" 2>/dev/null || printf '%s' "$_proj_top")"
  for _p in "$_cand" "$_real"; do
    if inside "$_p" "$_proj_pwd" || inside "$_p" "$PWD" || { [ -n "$_proj_top" ] && inside "$_p" "$_proj_top"; }; then
      if [ "${AICONTEXT_ALLOW_PROJECT_LEANCTX:-}" = true ]; then
        msg "warning: using a lean-ctx inside the project ($_cand), because AICONTEXT_ALLOW_PROJECT_LEANCTX=true."
      else
        _LC_REASONS+=("lean-ctx is inside the project directory ($_cand). A project can ship its own binary. Use an installed lean-ctx, or set AICONTEXT_ALLOW_PROJECT_LEANCTX=true")
        _LC_BIN=""
      fi
      break
    fi
  done
  # A Windows binary under WSL, as given or after resolving a symlink.
  if [ -n "${WSL_DISTRO_NAME:-}" ] || grep -qi microsoft /proc/version 2>/dev/null; then _wsl=true; fi
  case "$_cand" in "$_mnt"[a-zA-Z]/*) _LC_BIN_KIND=windows ;; esac
  case "$_real" in "$_mnt"[a-zA-Z]/*) _LC_BIN_KIND=windows ;; esac
  if [ "$_wsl" = true ] && [ "$_LC_BIN_KIND" = windows ]; then
    if [ "${AICONTEXT_ALLOW_WINDOWS_LEANCTX:-}" = true ]; then
      msg "warning: using a Windows lean-ctx under WSL ($_cand), because AICONTEXT_ALLOW_WINDOWS_LEANCTX=true."
    else
      _LC_REASONS+=("lean-ctx resolves to a Windows path under WSL ($_real). Install it in WSL, or set AICONTEXT_ALLOW_WINDOWS_LEANCTX=true")
      _LC_BIN=""
    fi
  fi
}

# Run one allowed lean-ctx command. Only read, grep, ls, and --version can be run. Output goes to $_LC_TMP/out and /err.
lc_run() {
  case "${1:-}" in
    read|grep|ls|--version) ;;
    *) msg "internal error: the adapter does not run 'lean-ctx ${1:-}'"; exit 70 ;;
  esac
  timeout -k 1 "$_LC_TIMEOUT" "$_LC_BIN" "$@" </dev/null >"$_LC_TMP/out" 2>"$_LC_TMP/err"
}

# Gate for an operation: state, binary, and the policy status of that operation.
gate() { # operation name (read, search, tree)
  load_state
  load_binary
  local _st=""
  case "$1" in read) _st="$_LC_OP_READ" ;; search) _st="$_LC_OP_SEARCH" ;; tree) _st="$_LC_OP_TREE" ;; esac
  if [ "${#_LC_REASONS[@]}" -eq 0 ] && [ "$_st" != enabled ]; then _LC_REASONS+=("leanctx_policy.operations.$1 is '$_st', not enabled"); fi
  [ "${#_LC_REASONS[@]}" -eq 0 ] || refuse "${_LC_REASONS[0]}"
  _LC_TMP="$(mktemp -d /tmp/token-controller-leanctx.XXXXXX)" || { msg 'cannot create a temporary directory'; exit 4; }
}

# A path argument: not an option, exists, and is inside the current directory. Prints the resolved path.
local_path() { # path
  local _p="$1" _real _here
  case "$_p" in -*) usage_error "a path cannot start with '-': $_p" ;; esac
  [ -e "$_p" ] || usage_error "no such file or directory: $_p"
  _real="$(realpath -e -- "$_p" 2>/dev/null)" || usage_error "cannot resolve: $_p"
  _here="$(realpath -e -- "$PWD")"
  case "$_real" in
    "$_here"|"$_here"/*) printf '%s\n' "$_real" ;;
    *) refuse "path is outside the current directory: $_p" ;;
  esac
}

show_output() { # print stdout, then stderr (visible), then return the lean-ctx exit code handling to the caller
  [ -s "$_LC_TMP/out" ] && cat "$_LC_TMP/out"
  [ -s "$_LC_TMP/err" ] && cat "$_LC_TMP/err" >&2
  return 0
}

cmd_status() {
  local _json=false
  [ "${1:-}" = --json ] && _json=true
  [ "$#" -le 1 ] || usage_error "status takes only --json"
  load_state
  load_binary
  # The version is read only from a binary that passed the checks (not a project-local or Windows one).
  if [ -n "$_LC_BIN" ]; then
    _LC_TMP="$(mktemp -d /tmp/token-controller-leanctx.XXXXXX)" || exit 4
    if lc_run --version; then _LC_VERSION="$(head -n 1 "$_LC_TMP/out" | cut -c1-90)"; else _LC_VERSION=""; fi
  fi
  local _allowed=yes
  [ "${#_LC_REASONS[@]}" -eq 0 ] || _allowed=no
  if [ "$_json" = true ]; then
    jq -n --arg profile "$_LC_PROFILE" --arg mode "$_LC_MODE" --arg bin "$_LC_BIN" --arg real "$_LC_BIN_REAL" --arg kind "$_LC_BIN_KIND" --arg version "$_LC_VERSION" \
      --arg allowed "$_allowed" --arg shell "$_LC_POLICY_SHELL" --arg wrap "$_LC_POLICY_WRAP" --arg setup "$_LC_POLICY_SETUP" --arg init "$_LC_POLICY_INIT" \
      --arg owner "$_LC_POLICY_OWNER" --arg r "$_LC_OP_READ" --arg s "$_LC_OP_SEARCH" --arg t "$_LC_OP_TREE" --arg reasons "$(printf '%s\n' "${_LC_REASONS[@]:-}")" '
      {schema_version: 1, profile: (if $profile == "" then null else $profile end), leanctx_mode: (if $mode == "" then null else $mode end),
       binary: (if $bin == "" then null else $bin end), resolved_path: (if $real == "" then null else $real end), platform_path: (if $kind == "" then null else $kind end), version: (if $version == "" then null else $version end),
       allowed: ($allowed == "yes"), reasons: ($reasons | split("\n") | map(select(. != ""))),
       policy: {shell_enabled: $shell, shell_owner: $owner, auto_wrap: $wrap, auto_setup: $setup, auto_init: $init, operations: {read: $r, search: $s, tree: $t}},
       status_command: "not run: lean-ctx status writes a report file"}'
  else
    printf 'LeanCTX adapter status\n'
    printf '  profile: %s\n' "${_LC_PROFILE:-none}"
    printf '  AICONTEXT_LEANCTX_MODE: %s\n' "${_LC_MODE:-none}"
    printf '  binary: %s\n' "${_LC_BIN:-not found}"
    printf '  version: %s\n' "${_LC_VERSION:-unknown}"
    printf '  policy: shell_enabled=%s shell_owner=%s auto_wrap=%s auto_setup=%s auto_init=%s\n' "${_LC_POLICY_SHELL:-?}" "${_LC_POLICY_OWNER:-?}" "${_LC_POLICY_WRAP:-?}" "${_LC_POLICY_SETUP:-?}" "${_LC_POLICY_INIT:-?}"
    printf '  operations: read=%s search=%s tree=%s\n' "${_LC_OP_READ:-?}" "${_LC_OP_SEARCH:-?}" "${_LC_OP_TREE:-?}"
    printf '  lean-ctx status: not run (it writes a report file)\n'
    if [ "$_allowed" = yes ]; then
      printf '  CLI operations allowed: yes (read, search, tree, read-exact)\n'
    else
      printf '  CLI operations allowed: no\n'
      local _r
      for _r in "${_LC_REASONS[@]}"; do printf '    - %s\n' "$_r"; done
    fi
  fi
  return 0
}

cmd_read() {
  local _path="" _mode=signatures
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --mode|-m) [ "$#" -ge 2 ] || usage_error "--mode needs a value"; _mode="$2"; shift ;;
      --*) usage_error "unknown option: $1" ;;
      *) [ -z "$_path" ] || usage_error "read takes one path"; _path="$1" ;;
    esac
    shift
  done
  [ -n "$_path" ] || usage_error "read needs a path"
  case "$_mode" in
    signatures|map|task|reference|auto) ;;
    *) usage_error "mode '$_mode' is not allowed. Use signatures, map, task, reference, or auto. For an exact read use read-exact" ;;
  esac
  gate read
  local _real
  _real="$(local_path "$_path")" || exit $?
  [ -f "$_real" ] || usage_error "not a file: $_path"
  lc_run read "$_real" -m "$_mode"
  local _rc=$?
  show_output
  [ "$_rc" -eq 0 ] || { msg "lean-ctx read failed (exit $_rc)."; exit 4; }
  return 0
}

cmd_read_exact() {
  [ "$#" -eq 1 ] || usage_error "read-exact takes one path"
  gate read
  local _real _size
  _real="$(local_path "$1")" || exit $?
  [ -f "$_real" ] || usage_error "not a file: $1"
  _size="$(wc -c < "$_real" | tr -d ' ')"
  [ "$_size" -le "$_LC_MAX_EXACT" ] || refuse "file is larger than $_LC_MAX_EXACT bytes. Use a raw file read"
  lc_run read "$_real" -m full --fresh
  local _rc=$?
  if [ "$_rc" -ne 0 ]; then
    [ -s "$_LC_TMP/err" ] && cat "$_LC_TMP/err" >&2
    msg "lean-ctx read failed (exit $_rc)."
    exit 4
  fi
  if cmp -s "$_real" "$_LC_TMP/out"; then
    cat "$_LC_TMP/out"
    return 0
  fi
  # Fail closed. The lossy output is not printed. There is no silent fallback to the raw file.
  printf 'LeanCTX exact read did not match file bytes; use a raw file read.\n' >&2
  exit 3
}

cmd_search() {
  [ "$#" -ge 1 ] && [ "$#" -le 2 ] || usage_error "search takes a pattern and an optional path"
  local _pattern="$1" _path="${2:-.}" _real
  case "$_pattern" in -*|'') usage_error "the pattern cannot be empty or start with '-'" ;; esac
  # No control characters (newline, carriage return, tab, escape, DEL) and at most 512 bytes.
  case "$(printf '%s' "$_pattern" | LC_ALL=C tr -cd '[:cntrl:]' | wc -c | tr -d ' ')" in 0) ;; *) usage_error "the pattern cannot contain control characters" ;; esac
  [ "$(printf '%s' "$_pattern" | wc -c | tr -d ' ')" -le 512 ] || usage_error "the pattern is longer than 512 bytes"
  gate search
  _real="$(local_path "$_path")" || exit $?
  lc_run grep "$_pattern" "$_real"
  local _rc=$?
  if [ "$_rc" -gt 1 ]; then
    [ -s "$_LC_TMP/err" ] && cat "$_LC_TMP/err" >&2
    msg "lean-ctx grep failed (exit $_rc)."
    exit 4
  fi
  # D-39 guard: a raw grep of the same local path. LeanCTX grep takes a regex (it accepts a|b), so the check is an extended regex
  # (grep -E). A pattern that LeanCTX reads differently from POSIX ERE fails closed (exit 3). The raw grep keeps its 10 s timeout. If it finds files that LeanCTX output never names, LeanCTX missed matches.
  local _raw_rc _raw_files _base _seen=false _n=0
  timeout -k 1 10 grep -rlIE --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=.ai-context -e "$_pattern" -- "$_real" </dev/null 2>/dev/null | head -n 20 > "$_LC_TMP/rawfiles"
  _raw_rc="${PIPESTATUS[0]}"
  if [ "$_raw_rc" -gt 1 ]; then
    msg "cannot verify the search: the raw grep failed (is the pattern a valid extended regex?). Use a raw search."
    exit 3
  fi
  if [ -s "$_LC_TMP/rawfiles" ]; then
    while IFS= read -r _raw_files; do
      _n=$((_n + 1))
      _base="$(basename -- "$_raw_files")"
      if grep -Fq -- "$_base" "$_LC_TMP/out"; then _seen=true; break; fi
    done < "$_LC_TMP/rawfiles"
    if [ "$_seen" = false ]; then
      msg "LeanCTX search found no matches, but a raw grep found matches in $(grep -c . "$_LC_TMP/rawfiles") file(s). Use a raw search."
      exit 3
    fi
  fi
  show_output
  return 0
}

cmd_tree() {
  [ "$#" -le 1 ] || usage_error "tree takes an optional path"
  gate tree
  local _real
  _real="$(local_path "${1:-.}")" || exit $?
  lc_run ls "$_real"
  local _rc=$?
  show_output
  [ "$_rc" -eq 0 ] || { msg "lean-ctx ls failed (exit $_rc)."; exit 4; }
  return 0
}

case "${1:-}" in
  status) shift; cmd_status "$@" ;;
  read) shift; cmd_read "$@" ;;
  read-exact) shift; cmd_read_exact "$@" ;;
  search) shift; cmd_search "$@" ;;
  tree) shift; cmd_tree "$@" ;;
  '') usage_error "missing command" ;;
  *) usage_error "unknown command: $1" ;;
esac
exit $?
