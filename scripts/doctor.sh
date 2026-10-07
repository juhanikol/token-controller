#!/usr/bin/env bash
# Path: scripts/doctor.sh
# Usage: bash scripts/doctor.sh [--json] [--project <dir>]
# Read-only. Inspects settings, instruction files, and tools. Never writes or installs.
# It never runs "rtk init" or any tool setup command, and never edits ~/.config/rtk.
# The only tool command it runs is "<tool> --version".
# Skipped on purpose: MCP config files (not implemented).
# Exit code: 0 no error finding, 1 at least one error finding, 2 doctor failed.

set -u
export LC_ALL=C

_DOCTOR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_CONTROLLER_ROOT="$(cd "$_DOCTOR_DIR/.." && pwd)"
_SETTINGS_FILE="${AICONTEXT_SETTINGS_FILE:-$_CONTROLLER_ROOT/config/workflow_settings.json}"
_CONFIG_DIR="${AICONTEXT_CONFIG_DIR:-$HOME/.config/ai-workflow}"
_ACTIVE_ENV_FILE="$_CONFIG_DIR/active_mode.env"
_XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
_MANAGED_START='<!-- ai-workflow-controller:start -->'
_MANAGED_END='<!-- ai-workflow-controller:end -->'
_DEFAULT_SCRIPT_PATH='~/projects/token-controller/scripts/workflow.sh'

_FORMAT=text
_PROJECT="$PWD"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --json) _FORMAT=json ;;
    --project)
      shift
      if [ "$#" -eq 0 ] || [ ! -d "$1" ]; then
        printf 'doctor: --project needs a directory.\n' >&2
        exit 2
      fi
      _PROJECT="$(cd "$1" && pwd)"
      ;;
    -h|--help)
      printf 'Usage: workflow doctor [--json] [--project <dir>]\nRead-only check of context settings and tools.\nscripts/doctor.sh writes nothing. Run through workflow.sh, it can create an empty ~/.config/ai-workflow.\n'
      exit 0
      ;;
    *)
      printf 'doctor: unknown option: %s\n' "$1" >&2
      exit 2
      ;;
  esac
  shift
done

if [ "$_FORMAT" = json ] && ! command -v jq >/dev/null 2>&1; then
  printf 'doctor: --json needs jq.\n' >&2
  exit 2
fi

# ---------- finding store ----------
# One entry per index. Paths are newline-separated inside one string.
_F_GROUP=()
_F_SEV=()
_F_ID=()
_F_MSG=()
_F_PATHS=()
_F_SUGGEST=()
_TOOLS=()      # name|found|path|version
_LOCATIONS=()  # id|path|exists|has_policy

add() { # group severity id message [paths] [suggestion]
  _F_GROUP+=("$1")
  _F_SEV+=("$2")
  _F_ID+=("$3")
  _F_MSG+=("$4")
  _F_PATHS+=("${5:-}")
  _F_SUGGEST+=("${6:-}")
}

short() { # shorten $HOME for display
  local _p="$1"
  case "$_p" in
    "$HOME"/*) printf '~/%s' "${_p#"$HOME"/}" ;;
    "$HOME") printf '~' ;;
    *) printf '%s' "$_p" ;;
  esac
}

expand_tilde() {
  case "$1" in
    "~") printf '%s' "$HOME" ;;
    "~/"*) printf '%s/%s' "$HOME" "${1#\~/}" ;;
    *) printf '%s' "$1" ;;
  esac
}

# Policy text: managed block, or a rule that reads the active mode file.
has_policy() {
  [ -f "$1" ] && grep -Eq 'ai-workflow-controller:start|active_mode\.env' "$1" 2>/dev/null
}

# First line number of policy text in a file. Empty when none.
policy_line() {
  grep -nE 'ai-workflow-controller:start|active_mode\.env' "$1" 2>/dev/null | head -n 1 | cut -d: -f1
}

# Path entry for findings: "path" or "path<TAB>line". Text prints path:line. JSON prints {path, line}.
pl() {
  if [ -n "${2:-}" ]; then
    printf '%s\t%s' "$1" "$2"
  else
    printf '%s' "$1"
  fi
}

fmt_path() {
  local _p="${1%%$'\t'*}"
  local _l=""
  case "$1" in *$'\t'*) _l="${1#*$'\t'}" ;; esac
  printf '%s%s' "$(short "$_p")" "${_l:+:$_l}"
}

_CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

# ---------- environment ----------
_PLATFORM=linux
_DISTRO=""
if [ -n "${WSL_DISTRO_NAME:-}" ] || grep -qi microsoft /proc/version 2>/dev/null; then
  _PLATFORM=wsl
  _DISTRO="${WSL_DISTRO_NAME:-unknown}"
fi
_BASH_VERSION="${BASH_VERSION%%(*}"

if [ "$_PLATFORM" = wsl ]; then
  add Environment ok env.platform "WSL, distro $_DISTRO, bash $_BASH_VERSION."
else
  add Environment info env.platform "Linux, not WSL. Bash $_BASH_VERSION. Only WSL 2 is tested."
fi
for _dep in jq git; do
  if command -v "$_dep" >/dev/null 2>&1; then
    add Environment ok "env.$_dep" "$_dep found."
  else
    add Environment warn "env.$_dep" "$_dep is missing." "" "Install it: sudo apt install -y $_dep"
  fi
done

# ---------- workflow alias ----------
_ALIAS_FILES=()
_ALIAS_LINES=()
_ALIAS_TARGETS=()
for _rc in "$HOME/.bashrc" "$HOME/.profile" "$HOME/.bash_aliases"; do
  [ -f "$_rc" ] || continue
  while IFS= read -r _line; do
    _ALIAS_FILES+=("$_rc")
    _ALIAS_LINES+=("${_line%%:*}")
    _line="${_line#*:}"
    _target="${_line#*source }"
    _target="${_target%%\'*}"
    _target="${_target%%\"*}"
    _ALIAS_TARGETS+=("$_target")
  done < <(grep -nE "^[[:space:]]*alias[[:space:]]+workflow=" "$_rc" 2>/dev/null)
done

if [ "${#_ALIAS_FILES[@]}" -eq 0 ]; then
  add Workflow warn workflow.alias_missing "No workflow alias in ~/.bashrc, ~/.profile, or ~/.bash_aliases." "" "Add: alias workflow='source $(short "$_DOCTOR_DIR")/workflow.sh'"
else
  if [ "${#_ALIAS_FILES[@]}" -gt 1 ]; then
    _alias_paths=""
    for ((_ai = 0; _ai < ${#_ALIAS_FILES[@]}; _ai++)); do
      _alias_paths+="$(pl "${_ALIAS_FILES[$_ai]}" "${_ALIAS_LINES[$_ai]}")"$'\n'
    done
    add Workflow warn workflow.alias_duplicate "Workflow alias is defined ${#_ALIAS_FILES[@]} times." "$_alias_paths" "Keep one alias line."
  else
    add Workflow ok workflow.alias "Workflow alias found." "$(pl "${_ALIAS_FILES[0]}" "${_ALIAS_LINES[0]}")"
  fi
  _first_target="$(expand_tilde "${_ALIAS_TARGETS[0]}")"
  if [ ! -f "$_first_target" ]; then
    add Workflow error workflow.alias_target "Alias target does not exist: $(short "$_first_target")" "$(pl "${_ALIAS_FILES[0]}" "${_ALIAS_LINES[0]}")" "Fix the path in the alias."
  elif [ "$(cd "$(dirname "$_first_target")" && pwd)/$(basename "$_first_target")" != "$_DOCTOR_DIR/workflow.sh" ]; then
    add Workflow warn workflow.alias_other_copy "Alias points to another copy of workflow.sh." "$_first_target" "Use one controller copy."
  fi
fi

# ---------- active mode ----------
_PROFILE=""
_RISK=""
_RTK_MODE=""
_SHELL_MATCH=""
if [ ! -f "$_ACTIVE_ENV_FILE" ]; then
  add "Active mode" info mode.none "No active mode file. Run: workflow <mode>" "$_ACTIVE_ENV_FILE"
else
  # Parse text. Never source the file.
  _PROFILE="$(sed -n 's/^export AICONTEXT_PROFILE="\(.*\)"$/\1/p' "$_ACTIVE_ENV_FILE" | head -n 1)"
  _RISK="$(sed -n 's/^export AICONTEXT_RISK="\(.*\)"$/\1/p' "$_ACTIVE_ENV_FILE" | head -n 1)"
  _RTK_MODE="$(sed -n 's/^export AICONTEXT_RTK_MODE="\(.*\)"$/\1/p' "$_ACTIVE_ENV_FILE" | head -n 1)"
  if [ -z "$_PROFILE" ]; then
    add "Active mode" error mode.unreadable "Active mode file has no profile." "$_ACTIVE_ENV_FILE" "Run: workflow <mode>"
  elif [ -r "$_SETTINGS_FILE" ] && command -v jq >/dev/null 2>&1 &&
    ! jq -e --arg m "$_PROFILE" '.modes[$m]' "$_SETTINGS_FILE" >/dev/null 2>&1; then
    add "Active mode" error mode.unknown "Profile '$_PROFILE' is not in workflow_settings.json." "$_ACTIVE_ENV_FILE" "Run: workflow <mode>"
  else
    add "Active mode" ok mode.active "Profile $_PROFILE, risk ${_RISK:-unknown}." "$_ACTIVE_ENV_FILE"
  fi
  if [ -n "${AICONTEXT_PROFILE:-}" ]; then
    if [ "$AICONTEXT_PROFILE" = "$_PROFILE" ]; then
      _SHELL_MATCH=true
    else
      _SHELL_MATCH=false
      add "Active mode" warn mode.shell_mismatch "This shell has profile '$AICONTEXT_PROFILE'. The file has '$_PROFILE'. wx uses the file." "$_ACTIVE_ENV_FILE" "Run: workflow ${_PROFILE:-<mode>}"
    fi
  fi
fi

# ---------- VS Code settings ----------
_VSCODE_FILES=(
  "$_XDG_CONFIG_HOME/Code/User/settings.json"
  "$_XDG_CONFIG_HOME/Code - Insiders/User/settings.json"
  "$HOME/.vscode-server/data/Machine/settings.json"
  "$HOME/.vscode-server-insiders/data/Machine/settings.json"
  "$HOME/.vscode-remote/data/Machine/settings.json"
  "$_PROJECT/.vscode/settings.json"
)
_VSCODE_FOUND=()
_VSCODE_POLICY=()
_SCRIPT_PATHS=()
_SCRIPT_PATH_FILES=()
for _f in "${_VSCODE_FILES[@]}"; do
  if [ -f "$_f" ]; then
    _VSCODE_FOUND+=("$_f")
    _pol=false
    has_policy "$_f" && { _pol=true; _VSCODE_POLICY+=("$(pl "$_f" "$(policy_line "$_f")")"); }
    _LOCATIONS+=("vscode_settings|$_f|true|$_pol")
    # Text match: settings files may contain comments, so jq may fail.
    _sp="$(sed -n 's/.*"tokenController\.scriptPath"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$_f" | head -n 1)"
    if [ -n "$_sp" ]; then
      _SCRIPT_PATHS+=("$_sp")
      _SCRIPT_PATH_FILES+=("$_f")
    fi
  else
    _LOCATIONS+=("vscode_settings|$_f|false|false")
  fi
done
if [ "${#_VSCODE_FOUND[@]}" -eq 0 ]; then
  add "VS Code" info vscode.none "No VS Code settings file found."
else
  add "VS Code" ok vscode.found "${#_VSCODE_FOUND[@]} VS Code settings file(s) found." "$(printf '%s\n' "${_VSCODE_FOUND[@]}")"
fi

# CLI and extension script path
if [ "${#_SCRIPT_PATHS[@]}" -gt 0 ]; then
  _ext_path_raw="${_SCRIPT_PATHS[${#_SCRIPT_PATHS[@]}-1]}"
  _ext_src="${_SCRIPT_PATH_FILES[${#_SCRIPT_PATH_FILES[@]}-1]}"
else
  _ext_path_raw="$_DEFAULT_SCRIPT_PATH"
  _ext_src=""
fi
_ext_path="$(expand_tilde "$_ext_path_raw")"
if [ ! -f "$_ext_path" ]; then
  _ext_sev=error
  [ -n "$_ext_src" ] || _ext_sev=warn # default path, not set by the user
  add Extension "$_ext_sev" ext.script_missing "Extension script path does not exist: $(short "$_ext_path")" "${_ext_src:-}" "Set tokenController.scriptPath to $(short "$_DOCTOR_DIR")/workflow.sh"
elif [ "$(cd "$(dirname "$_ext_path")" && pwd)/$(basename "$_ext_path")" != "$_DOCTOR_DIR/workflow.sh" ]; then
  add Extension warn ext.script_other_copy "Extension and CLI use different copies of workflow.sh." "$_ext_path" "Set tokenController.scriptPath to $(short "$_DOCTOR_DIR")/workflow.sh"
else
  add Extension ok ext.script "Extension script path matches this CLI." "$_ext_path"
fi

# ---------- agent instruction files ----------
_POLICY_FILES=()
_check_agent_file() { # id path
  local _id="$1" _path="$2" _pol=false
  if [ -f "$_path" ]; then
    if has_policy "$_path"; then
      _pol=true
      _POLICY_FILES+=("$(pl "$_path" "$(policy_line "$_path")")")
    fi
    _LOCATIONS+=("$_id|$_path|true|$_pol")
    # Managed block integrity
    local _s=false _e=false
    grep -Fqx -- "$_MANAGED_START" "$_path" 2>/dev/null && _s=true
    grep -Fqx -- "$_MANAGED_END" "$_path" 2>/dev/null && _e=true
    if [ "$_s" != "$_e" ]; then
      add "Agent files" error policy.incomplete_block "Incomplete managed block." "$(pl "$_path" "$(grep -nFxe "$_MANAGED_START" -e "$_MANAGED_END" "$_path" 2>/dev/null | head -n 1 | cut -d: -f1)")" "Fix or remove the block by hand. Then run: workflow init"
    fi
  else
    _LOCATIONS+=("$_id|$_path|false|false")
  fi
}

_check_agent_file project_agents_md "$_PROJECT/AGENTS.md"
_check_agent_file project_claude_md "$_PROJECT/CLAUDE.md"
_check_agent_file project_copilot_md "$_PROJECT/.github/copilot-instructions.md"
_check_agent_file project_claude_settings "$_PROJECT/.claude/settings.json"
_check_agent_file user_claude_md "$HOME/.claude/CLAUDE.md"
_check_agent_file user_claude_settings "$HOME/.claude/settings.json"
if [ -d "$HOME/.copilot/instructions" ]; then
  for _f in "$HOME/.copilot/instructions/"*.md; do
    [ -f "$_f" ] && _check_agent_file user_copilot_instructions "$_f"
  done
else
  _LOCATIONS+=("user_copilot_instructions|$HOME/.copilot/instructions|false|false")
fi

_found_agent=()
for _loc in "${_LOCATIONS[@]}"; do
  IFS='|' read -r _lid _lpath _lex _lpol <<< "$_loc"
  case "$_lid" in vscode_settings) continue ;; esac
  [ "$_lex" = true ] && _found_agent+=("$_lpath")
done
if [ "${#_found_agent[@]}" -eq 0 ]; then
  add "Agent files" info agents.none "No agent instruction file found."
else
  add "Agent files" ok agents.found "${#_found_agent[@]} agent file(s) found." "$(printf '%s\n' "${_found_agent[@]}")"
fi

# Duplicate policy: every file or VS Code setting that carries the policy.
_ALL_POLICY=("${_POLICY_FILES[@]}" "${_VSCODE_POLICY[@]}")
if [ "${#_ALL_POLICY[@]}" -gt 1 ]; then
  add Policy warn policy.duplicate "Policy text is in ${#_ALL_POLICY[@]} places." "$(printf '%s\n' "${_ALL_POLICY[@]}")" "Keep project AGENTS.md. Remove user-level copies you do not need."
elif [ "${#_ALL_POLICY[@]}" -eq 1 ]; then
  add Policy ok policy.single "Policy text is in 1 place." "${_ALL_POLICY[0]}"
else
  add Policy info policy.none "No policy text found. Run: workflow init"
fi

# RTK global setup. Any hook rewrites commands to run through RTK and skips wx raw capture,
# so this is reported in every mode. Text match only. Doctor never runs "rtk init" or edits RTK config.
_RTK_WORD='(^|[^[:alnum:]_])rtk([^[:alnum:]_]|$)'
_rtk_hook_paths=()
# Where "rtk init" puts things (checked by running it in scratch HOME directories, RTK 0.42.4):
#   Claude:   ~/.claude/settings.json (hook "rtk hook claude"), RTK.md, CLAUDE.md with @RTK.md
#   Copilot:  ~/.copilot/hooks/rtk-rewrite.json, ~/.copilot/copilot-instructions.md
#   Gemini:   ~/.gemini/hooks/rtk-hook-gemini.sh, settings.json, GEMINI.md
#   Cursor:   ~/.cursor/hooks.json        Codex: ~/.codex/RTK.md and AGENTS.md (instructions, no hook)
#   OpenCode: ~/.config/opencode/plugins/rtk.ts   Pi: ~/.pi/agent/extensions/rtk.ts
#   Hermes:   ~/.hermes/plugins/rtk-rewrite/, config.yaml
#   Project:  .windsurfrules, .clinerules, CLAUDE.md, .rtk/filters.toml (project scoped agents)
# Files that may contain the word rtk (hook entries or instructions):
for _f in "$_PROJECT/.claude/settings.json" "$_CLAUDE_DIR/settings.json" \
  "$HOME/.cursor/hooks.json" "$HOME/.gemini/settings.json" "$HOME/.gemini/GEMINI.md" \
  "$HOME/.copilot/copilot-instructions.md" "$HOME/.codex/AGENTS.md" "$HOME/.hermes/config.yaml" \
  "$_PROJECT/.windsurfrules" "$_PROJECT/.clinerules"; do
  if [ -f "$_f" ]; then
    _rl="$(grep -niE "$_RTK_WORD" "$_f" 2>/dev/null | head -n 1 | cut -d: -f1)"
    [ -n "$_rl" ] && _rtk_hook_paths+=("$(pl "$_f" "$_rl")")
  fi
done
# Files and folders that exist only because of RTK:
for _f in "$_CLAUDE_DIR/RTK.md" "$_CLAUDE_DIR"/hooks/*rtk* "$HOME/.codex/RTK.md" \
  "$HOME"/.copilot/hooks/*rtk* "$HOME"/.gemini/hooks/*rtk* "$_XDG_CONFIG_HOME"/opencode/plugins/*rtk* \
  "$HOME"/.pi/agent/extensions/*rtk* "$HOME"/.hermes/plugins/*rtk*; do
  [ -e "$_f" ] && _rtk_hook_paths+=("$(pl "$_f" "")")
done
for _f in "$_CLAUDE_DIR/CLAUDE.md" "$_PROJECT/CLAUDE.md"; do
  if [ -f "$_f" ]; then
    _rl="$(grep -nE '(^|[^[:alnum:]_])@?RTK\.md' "$_f" 2>/dev/null | head -n 1 | cut -d: -f1)"
    [ -n "$_rl" ] && _rtk_hook_paths+=("$(pl "$_f" "$_rl")")
  fi
done
# Project-local RTK filters. RTK documents that they override built-in filters, but only after "rtk trust".
if [ -f "$_PROJECT/.rtk/filters.toml" ]; then
  add Policy info policy.rtk_project_filters "Project-local RTK filters exist. RTK applies them only after rtk trust. wx runs named built-in filters (rtk pipe -f)." "$(pl "$_PROJECT/.rtk/filters.toml" "")" "Do not run rtk trust in a project you do not trust."
fi
if [ "${#_rtk_hook_paths[@]}" -gt 0 ]; then
  _rtk_paths_text="$(printf '%s\n' "${_rtk_hook_paths[@]}")"
  add Policy warn policy.rtk_hook "RTK hook or setup found. Commands it rewrites run through RTK and skip wx raw capture." "$_rtk_paths_text" "Choose one route per command. Doctor does not run rtk init or edit RTK config."
  if [ "$_RTK_MODE" = off ]; then
    add Policy warn policy.rtk_hook_mismatch "RTK setup exists, but mode '$_PROFILE' sets rtk off." "$_rtk_paths_text" "Check the RTK hook, or choose another mode."
  fi
fi

# ---------- tools ----------
# _TOOLS entry: name|found|kind|path|version   (version last, it may contain text)
for _tool in rtk lean-ctx headroom caveman ccusage; do
  _tpath="$(command -v "$_tool" 2>/dev/null || true)"
  if [ -n "$_tpath" ] && [ -x "$_tpath" ]; then
    # --version only. Short timeout. No input.
    _tver="$(timeout 3 "$_tpath" --version </dev/null 2>&1 | head -n 1 | cut -c1-80)"
    _TOOLS+=("$_tool|true|command|$_tpath|$_tver")
    add Tools ok "tool.$_tool" "$_tool: ${_tver:-found}" "$(pl "$_tpath" "")"
    continue
  fi
  _tfound=""
  if [ "$_tool" = caveman ]; then
    # Caveman is mainly a Claude Code skill or plugin. Look for its files. Run nothing.
    for _e in "$_CLAUDE_DIR/skills/caveman" "$_CLAUDE_DIR"/skills/caveman* "$_CLAUDE_DIR"/plugins/*caveman* "$_CLAUDE_DIR/.caveman-active"; do
      if [ -e "$_e" ]; then
        _tfound="$_e"
        break
      fi
    done
  fi
  if [ -n "$_tfound" ]; then
    _TOOLS+=("$_tool|true|claude-skill|$_tfound|")
    add Tools ok "tool.$_tool" "$_tool: Claude Code skill or plugin found. No command on PATH." "$(pl "$_tfound" "")"
  else
    _TOOLS+=("$_tool|false|none||")
    add Tools info "tool.$_tool" "$_tool not found."
  fi
done

# ---------- caveman state ----------
# Doctor only reads the state file. It never changes it. Token Controller's own state comes from the env file.
_CAVE_STATE="$_CLAUDE_DIR/.caveman-active"
_TC_CAVE_MODE=""
[ -f "$_ACTIVE_ENV_FILE" ] && _TC_CAVE_MODE="$(sed -n 's/^export AICONTEXT_CAVEMAN_MODE="\(.*\)"$/\1/p' "$_ACTIVE_ENV_FILE" | head -n 1)"
[ -n "$_TC_CAVE_MODE" ] || _TC_CAVE_MODE=off
_TC_CAVE_MAX=""
_TC_CAVE_REQ=""
if [ -f "$_ACTIVE_ENV_FILE" ]; then
  _TC_CAVE_MAX="$(sed -n 's/^export AICONTEXT_CAVEMAN_MAX="\(.*\)"$/\1/p' "$_ACTIVE_ENV_FILE" | head -n 1)"
  _TC_CAVE_REQ="$(sed -n 's/^export AICONTEXT_CAVEMAN_REQUESTED="\(.*\)"$/\1/p' "$_ACTIVE_ENV_FILE" | head -n 1)"
fi
_CAVE_OPT_IN_HINT="Opt in for one activation with: AICONTEXT_CAVEMAN_REQUEST=lite workflow ${_PROFILE:-<mode>}"

caveman_rank() {
  case "$1" in
    off) echo 0 ;;
    lite) echo 1 ;;
    full) echo 2 ;;
    *) echo 3 ;;
  esac
}

# Same hard-blocked set as workflow.sh. Config may add profiles.
caveman_hard_blocked() {
  case "$1" in
    raw|security|db|release|migration|docs|debug) return 0 ;;
  esac
  [ -r "$_SETTINGS_FILE" ] && command -v jq >/dev/null 2>&1 &&
    jq -e --arg m "$1" '(.caveman_policy.hard_blocked_profiles // []) | index($m) != null' "$_SETTINGS_FILE" >/dev/null 2>&1
}

if [ -e "$_CAVE_STATE" ]; then
  if [ ! -f "$_CAVE_STATE" ] || [ ! -r "$_CAVE_STATE" ]; then
    add Caveman warn caveman.state_unreadable "Caveman state file cannot be read." "$(pl "$_CAVE_STATE" "")"
  else
    _cave_level="$(head -c 64 "$_CAVE_STATE" | tr -d '\r\n\t ' | tr 'A-Z' 'a-z')"
    case "$_cave_level" in
      ''|off|none|false|0)
        add Caveman ok caveman.inactive "Caveman is not active." "$(pl "$_CAVE_STATE" "")"
        ;;
      *[!a-z0-9_-]*)
        add Caveman warn caveman.level_unknown "Caveman state file has an unknown level." "$(pl "$_CAVE_STATE" "")" "Say 'stop caveman' in the agent session."
        ;;
      *)
        _cave_hint="Say 'stop caveman' in the agent session. Doctor does not edit the state file."
        _cave_path="$(pl "$_CAVE_STATE" "")"
        if [ -n "$_PROFILE" ] && caveman_hard_blocked "$_PROFILE"; then
          add Caveman error caveman.active_blocked_profile "Caveman is active (level $_cave_level) in mode '$_PROFILE'. This mode must stay off." "$_cave_path" "$_cave_hint"
        elif [ "$_cave_level" = ultra ] || [ "${_cave_level#wenyan}" != "$_cave_level" ]; then
          add Caveman warn caveman.unsupported_level "Caveman level '$_cave_level' is not supported by Token Controller." "$_cave_path" "Use lite or full, or turn Caveman off. $_cave_hint"
        elif [ "$_TC_CAVE_MODE" = off ]; then
          add Caveman warn caveman.active_no_opt_in "Caveman is active (level $_cave_level), but Token Controller has no Caveman opt-in for mode '${_PROFILE:-none}'." "$_cave_path" "$_cave_hint $_CAVE_OPT_IN_HINT (not allowed in debug, docs, security, db, release, migration)."
        elif [ "$(caveman_rank "$_cave_level")" -gt "$(caveman_rank "$_TC_CAVE_MODE")" ]; then
          add Caveman warn caveman.above_policy "Caveman level '$_cave_level' is above the Token Controller level '$_TC_CAVE_MODE'." "$_cave_path" "$_cave_hint"
        else
          add Caveman ok caveman.active_ok "Caveman level '$_cave_level' matches Token Controller policy." "$_cave_path"
        fi
        ;;
    esac
  fi
fi

# Token Controller's own Caveman state, read from the active mode file. Reported when that file has it.
if [ -f "$_ACTIVE_ENV_FILE" ] && [ -n "$_TC_CAVE_MAX" ]; then
  add Caveman ok caveman.policy "Token Controller Caveman policy: level $_TC_CAVE_MODE, requested ${_TC_CAVE_REQ:-off}, limit $_TC_CAVE_MAX (mode '${_PROFILE:-none}'). Off by default." "$(pl "$_ACTIVE_ENV_FILE" "")"
fi

# ---------- side effect note ----------
# workflow.sh runs mkdir -p on the config directory before it starts any command.
if [ "${AICONTEXT_DOCTOR_VIA_WORKFLOW:-}" = 1 ]; then
  add Doctor info doctor.config_dir "Run through workflow.sh, doctor can create an empty $(short "$_CONFIG_DIR"). scripts/doctor.sh run directly writes nothing." "$(pl "$_CONFIG_DIR" "")"
fi

# ---------- output ----------
_ERRORS=0 _WARNS=0 _INFOS=0
for _s in "${_F_SEV[@]}"; do
  case "$_s" in
    error) _ERRORS=$((_ERRORS + 1)) ;;
    warn) _WARNS=$((_WARNS + 1)) ;;
    info) _INFOS=$((_INFOS + 1)) ;;
  esac
done

print_text() {
  local _i _group _last="" _paths _p
  printf 'workflow doctor (project: %s)\n' "$(short "$_PROJECT")"
  for ((_i = 0; _i < ${#_F_ID[@]}; _i++)); do
    _group="${_F_GROUP[$_i]}"
    if [ "$_group" != "$_last" ]; then
      printf '\n%s\n' "$_group"
      _last="$_group"
    fi
    printf '  %-5s %s\n' "${_F_SEV[$_i]}" "${_F_MSG[$_i]}"
    _paths="${_F_PATHS[$_i]}"
    if [ -n "$_paths" ] && [ "${_F_SEV[$_i]}" != ok ]; then
      while IFS= read -r _p; do
        [ -n "$_p" ] && printf '        %s\n' "$(fmt_path "$_p")"
      done <<< "$_paths"
    fi
    [ -n "${_F_SUGGEST[$_i]}" ] && printf '        -> %s\n' "${_F_SUGGEST[$_i]}"
  done
  printf '\nSummary: %d error, %d warn, %d info.\n' "$_ERRORS" "$_WARNS" "$_INFOS"
}

print_json() {
  local _i _t _l _tname _tfound _tkind _tpath _tver _lid _lpath _lex _lpol
  {
    jq -cn \
      --arg project "$_PROJECT" \
      --arg platform "$_PLATFORM" \
      --arg distro "$_DISTRO" \
      --arg bash_version "$_BASH_VERSION" \
      --arg home "$HOME" \
      --arg profile "$_PROFILE" \
      --arg risk "$_RISK" \
      --arg source "$_ACTIVE_ENV_FILE" \
      --arg shell_match "$_SHELL_MATCH" \
      --arg generated_at "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
      --argjson errors "$_ERRORS" --argjson warns "$_WARNS" --argjson infos "$_INFOS" \
      '{
        schema_version: 1,
        generated_at: $generated_at,
        project: $project,
        environment: {platform: $platform, distro: (if $distro == "" then null else $distro end), shell: "bash", bash_version: $bash_version, home: $home},
        active_mode: {
          profile: (if $profile == "" then null else $profile end),
          risk: (if $risk == "" then null else $risk end),
          source: $source,
          shell_matches: (if $shell_match == "" then null else ($shell_match == "true") end)
        },
        summary: {error: $errors, warn: $warns, info: $infos}
      }'
    for _t in "${_TOOLS[@]}"; do
      IFS='|' read -r _tname _tfound _tkind _tpath _tver <<< "$_t"
      jq -cn --arg name "$_tname" --arg found "$_tfound" --arg kind "$_tkind" --arg path "$_tpath" --arg version "$_tver" \
        '{tool: ({name: $name, found: ($found == "true")}
          + (if $found == "true" then {kind: $kind, path: $path, version: (if $version == "" then null else $version end)} else {} end))}'
    done
    for _l in "${_LOCATIONS[@]}"; do
      IFS='|' read -r _lid _lpath _lex _lpol <<< "$_l"
      jq -cn --arg id "$_lid" --arg path "$_lpath" --arg exists "$_lex" --arg pol "$_lpol" \
        '{location: {id: $id, path: $path, exists: ($exists == "true"), has_policy_block: ($pol == "true")}}'
    done
    for ((_i = 0; _i < ${#_F_ID[@]}; _i++)); do
      jq -cn --arg id "${_F_ID[$_i]}" --arg sev "${_F_SEV[$_i]}" --arg msg "${_F_MSG[$_i]}" \
        --arg paths "${_F_PATHS[$_i]}" --arg suggest "${_F_SUGGEST[$_i]}" --arg group "${_F_GROUP[$_i]}" \
        '{finding: {id: $id, severity: $sev, group: $group, message: $msg,
          paths: ($paths | split("\n") | map(select(. != "")) | map(split("\t") | {path: .[0], line: (if length > 1 then (.[1] | tonumber) else null end)})),
          suggestion: (if $suggest == "" then null else $suggest end)}}'
    done
  } | jq -s '
    (.[0]) + {
      tools: [.[] | select(has("tool")) | .tool],
      locations: [.[] | select(has("location")) | .location],
      findings: [.[] | select(has("finding")) | .finding]
    }'
}

if [ "$_FORMAT" = json ]; then
  print_json || exit 2
else
  print_text
fi

[ "$_ERRORS" -eq 0 ] || exit 1
exit 0
