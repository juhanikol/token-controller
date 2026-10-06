#!/usr/bin/env bash
# Path: scripts/workflow.sh
# Usage: source scripts/workflow.sh <mode>
# Modes (defined in config/workflow_settings.json): raw scope architect decisions code rapid-prototype snippet micro agent test test-full debug data-analysis docs cicd review security migration db perf release off
# Commands: init setup status report doctor reset-session
# Backward-compatible aliases: plan=architect, ci=cicd

# This script is intended to be sourced, because it exports variables to the current shell.
# It does not install token tools and does not invoke AI agents directly.

_AI_WORKFLOW_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/wx.sh
source "$_AI_WORKFLOW_SCRIPT_DIR/lib/wx.sh"
# shellcheck source=lib/wx-session.sh
source "$_AI_WORKFLOW_SCRIPT_DIR/lib/wx-session.sh"
unset _AI_WORKFLOW_SCRIPT_DIR

_ai_workflow_main() {
  local _MODE="${1:-status}"
  local _SCRIPT_SOURCE="${BASH_SOURCE[0]}"
  local _SCRIPT_DIR
  local _PROJECT_ROOT
  local _CONFIG_DIR
  local _SETTINGS_FILE
  local _ACTIVE_ENV_FILE

  _SCRIPT_DIR="$(cd "$(dirname "$_SCRIPT_SOURCE")" && pwd)"
  _PROJECT_ROOT="$(cd "$_SCRIPT_DIR/.." && pwd)"
  _CONFIG_DIR="${AICONTEXT_CONFIG_DIR:-$HOME/.config/ai-workflow}"
  _SETTINGS_FILE="${AICONTEXT_SETTINGS_FILE:-$_PROJECT_ROOT/config/workflow_settings.json}"
  _ACTIVE_ENV_FILE="$_CONFIG_DIR/active_mode.env"

  mkdir -p "$_CONFIG_DIR"

  usage() {
    cat <<USAGE
Usage: ${AICONTEXT_ENTRYPOINT_NAME:-source scripts/workflow.sh} <mode>

Modes:
  init         Initialize AGENTS.md in the current directory.
  setup        Configure global VS Code/agent instructions.
  raw          No compression. Highest fidelity.
  scope        Requirements and scope discovery.
  architect    Architecture, structure, codebase overview.
  decisions    ADRs, domain models, schemas, types.
  code         Normal implementation work.
  rapid-prototype Fast prototyping. Compress successful output only. Keep errors raw.
  data-analysis Data analysis, stats, and visualization.
  snippet      Small file/method/snippet review.
  micro        Very small task. No context tools, target file/snippet only.
  agent        Agent-governance / AGENTS.md workflows.
  test         Unit/integration test runs.
  test-full    Full app / broad automated test routine.
  debug        Failure investigation and bug fixing.
  docs         Documentation creation and README work.
  cicd         CI/CD, Docker, package-manager and runner logs.
  review       Whole-codebase or PR review.
  security     Security, auth, secrets, vulnerability scans.
  migration    Large refactor or legacy migration.
  db           Database/schema/data migration.
  perf         Performance profiling and benchmarking.
  release      Release preparation.
  off          Disable all optimizers.
  status       Show current profile. Option: --json (reads the active mode file)
  modes        List modes and aliases from the settings file. Option: --json
  doctor       Read-only check of settings, instruction files, and tools. Option: --json
               It can create an empty ~/.config/ai-workflow when run through workflow.sh.
  report       Summarize the current project's wx session.
  reset-session Archive the current wx session and start a new one.

Environment:
  AICONTEXT_CAVEMAN_REQUEST=off|lite|full
               Opt in to terse agent output for one activation, for example:
               AICONTEXT_CAVEMAN_REQUEST=lite workflow code
               Caveman is off by default. Blocked modes ignore the request.

Aliases:
  plan -> architect
  ci   -> cicd
USAGE
  }

  need_jq() {
    if ! command -v jq >/dev/null 2>&1; then
      echo "Error: jq is missing. Install it with: sudo apt update && sudo apt install -y jq" >&2
      return 1
    fi
  }

  # Caveman policy helpers. They only resolve state. Nothing here calls Caveman.
  _aiw_caveman_rank() {
    case "$1" in
      off) echo 0 ;;
      lite) echo 1 ;;
      full) echo 2 ;;
      *) return 1 ;;
    esac
  }

  # Hard-blocked profiles stay off even if the config allows a level.
  _aiw_caveman_blocked() {
    case "$1" in
      raw|security|db|release|migration|docs|debug|micro|snippet|off) return 0 ;;
    esac
    jq -e --arg m "$1" '(.caveman_policy.hard_blocked_profiles // []) | index($m) != null' "$_SETTINGS_FILE" >/dev/null 2>&1
  }

  status() {
    echo "Current AI Context Workflow Status:"
    echo "  AICONTEXT_PROFILE=${AICONTEXT_PROFILE:-unset}"
    echo "  AICONTEXT_RISK=${AICONTEXT_RISK:-unset}"
    echo "  AICONTEXT_COMPRESS_SHELL=${AICONTEXT_COMPRESS_SHELL:-unset}"
    echo "  AICONTEXT_COMPRESS_FILES=${AICONTEXT_COMPRESS_FILES:-unset}"
    echo "  AICONTEXT_CODEBASE_INDEX=${AICONTEXT_CODEBASE_INDEX:-unset}"
    echo "  AICONTEXT_MEMORY_LAYER=${AICONTEXT_MEMORY_LAYER:-unset}"
    echo "  AICONTEXT_HEADROOM_MODE=${AICONTEXT_HEADROOM_MODE:-unset}"
    echo "  AICONTEXT_LEANCTX_MODE=${AICONTEXT_LEANCTX_MODE:-unset}"
    echo "  AICONTEXT_RTK_MODE=${AICONTEXT_RTK_MODE:-unset}"
    echo "  AICONTEXT_CAVEMAN_OUTPUT=${AICONTEXT_CAVEMAN_OUTPUT:-unset}"
    echo "  AICONTEXT_CAVEMAN_REQUESTED=${AICONTEXT_CAVEMAN_REQUESTED:-unset}"
    echo "  AICONTEXT_CAVEMAN_MODE=${AICONTEXT_CAVEMAN_MODE:-unset}"
    echo "  AICONTEXT_CAVEMAN_MAX=${AICONTEXT_CAVEMAN_MAX:-unset}"
    echo "  AICONTEXT_CAVEMAN_SHRINK=${AICONTEXT_CAVEMAN_SHRINK:-unset}"
    echo "  AICONTEXT_OUTPUT_STYLE=${AICONTEXT_OUTPUT_STYLE:-unset}"
    echo "  AICONTEXT_RAW_ON_FAIL=${AICONTEXT_RAW_ON_FAIL:-unset}"
    echo "  AICONTEXT_KEEP_RAW_LOGS=${AICONTEXT_KEEP_RAW_LOGS:-unset}"
    echo "  Active env cache: $_ACTIVE_ENV_FILE"
    # The lines above are this shell's state. wx uses the env file, so show that too.
    local _FILE_PROFILE=""
    if [ -f "$_ACTIVE_ENV_FILE" ] && [ -r "$_ACTIVE_ENV_FILE" ]; then
      _FILE_PROFILE="$(sed -n 's/^export AICONTEXT_PROFILE="\(.*\)"$/\1/p' "$_ACTIVE_ENV_FILE" | head -n 1)"
    fi
    echo "  Env file profile (used by wx): ${_FILE_PROFILE:-none}"
    if [ -n "$_FILE_PROFILE" ] && [ -n "${AICONTEXT_PROFILE:-}" ] && [ "$AICONTEXT_PROFILE" != "$_FILE_PROFILE" ]; then
      echo "  Warning: this shell has profile '$AICONTEXT_PROFILE', but the env file has '$_FILE_PROFILE'. wx uses the env file. Run: workflow $_FILE_PROFILE"
    fi
  }

  # JSON status for tools (the VS Code extension, agents). It reads the active mode file as controller
  # state, like wx does. It never changes the caller's shell: values are read in a subshell.
  # Fields: see docs/TECHNICAL_DEBT.md (status --json). Needs jq.
  status_json() {
    need_jq || return 1

    local _SHELL_PROFILE="${AICONTEXT_PROFILE:-}"
    local _USE_SHELL_STATE=false
    local _FILE_USABLE=false

    [ "${AICONTEXT_USE_SHELL_STATE:-}" = true ] && _USE_SHELL_STATE=true
    [ -f "$_ACTIVE_ENV_FILE" ] && [ -r "$_ACTIVE_ENV_FILE" ] && _FILE_USABLE=true

    (
      local _SOURCE=unset

      if [ "$_FILE_USABLE" = true ]; then
        _wx_unset_policy_state
        _wx_apply_env_file "$_ACTIVE_ENV_FILE"
        # A file without a profile is not usable state. wx keeps output raw in that case.
        [ -n "${AICONTEXT_PROFILE:-}" ] && _SOURCE=active_env_file
      elif [ -n "$_SHELL_PROFILE" ]; then
        _SOURCE=shell_fallback
      fi

      jq -n \
        --arg source "$_SOURCE" \
        --arg env_file "$_ACTIVE_ENV_FILE" \
        --arg shell_profile "$_SHELL_PROFILE" \
        --argjson use_shell_state "$_USE_SHELL_STATE" \
        --arg profile "${AICONTEXT_PROFILE:-}" \
        --arg risk "${AICONTEXT_RISK:-}" \
        --arg output_style "${AICONTEXT_OUTPUT_STYLE:-}" \
        --arg raw_on_fail "${AICONTEXT_RAW_ON_FAIL:-}" \
        --arg keep_raw_logs "${AICONTEXT_KEEP_RAW_LOGS:-}" \
        --arg compress_shell "${AICONTEXT_COMPRESS_SHELL:-}" \
        --arg compress_files "${AICONTEXT_COMPRESS_FILES:-}" \
        --arg rtk_mode "${AICONTEXT_RTK_MODE:-}" \
        --arg leanctx_mode "${AICONTEXT_LEANCTX_MODE:-}" \
        --arg headroom_mode "${AICONTEXT_HEADROOM_MODE:-}" \
        --arg caveman_requested "${AICONTEXT_CAVEMAN_REQUESTED:-}" \
        --arg caveman_mode "${AICONTEXT_CAVEMAN_MODE:-}" \
        --arg caveman_max "${AICONTEXT_CAVEMAN_MAX:-}" \
        --arg caveman_output "${AICONTEXT_CAVEMAN_OUTPUT:-}" \
        '
        def s: if . == "" then null else . end;
        def b: if . == "true" then true elif . == "false" then false else null end;
        ($profile | s) as $p
        | {
            schema_version: 1,
            profile: $p,
            risk: ($risk | s),
            output_style: ($output_style | s),
            raw_on_fail: ($raw_on_fail | b),
            keep_raw_logs: ($keep_raw_logs | b),
            compress_shell: ($compress_shell | s),
            compress_files: ($compress_files | s),
            rtk_mode: ($rtk_mode | s),
            leanctx_mode: ($leanctx_mode | s),
            headroom_mode: ($headroom_mode | s),
            caveman_requested: ($caveman_requested | s),
            caveman_mode: ($caveman_mode | s),
            caveman_max: ($caveman_max | s),
            caveman_output: ($caveman_output | b),
            source: $source,
            active_env_file: $env_file,
            shell_profile: (if ($shell_profile != "") and ($shell_profile != $profile) then $shell_profile else null end),
            stale_shell: (($shell_profile != "") and ($source != "shell_fallback") and ($shell_profile != $profile)),
            use_shell_state: $use_shell_state
          }'
    )
  }

  # Machine-readable mode list, read from the settings file. The extension and other tools use it
  # so they do not keep their own copy of the modes. Fields: see docs/TECHNICAL_DEBT.md (modes --json).
  # The Caveman level is the effective one (same rules as activation). tests/workflow-session.test.sh
  # compares this list with the variables each mode exports, so the two cannot drift silently.
  modes_json() {
    need_jq || return 1
    if [ ! -f "$_SETTINGS_FILE" ] || [ ! -r "$_SETTINGS_FILE" ]; then
      echo "Error: settings file not found: $_SETTINGS_FILE" >&2
      return 1
    fi

    jq '
      def rank: if . == "off" then 0 elif . == "lite" then 1 elif . == "full" then 2 else null end;
      def level($v): if ($v | rank) == null then "off" else $v end;
      (.defaults // {}) as $d
      | (.caveman_policy.hard_blocked_profiles // []) as $config_blocked
      | ["raw", "security", "db", "release", "migration", "docs", "debug", "micro", "snippet", "off"] as $blocked
      | {
          schema_version: 1,
          modes: [
            .modes | to_entries[] | .key as $name | .value as $m
            | level($m.caveman_mode // $d.caveman_mode // "off") as $requested
            | (if (($blocked + $config_blocked) | index($name)) != null then "off"
               else level($m.caveman_max // $d.caveman_max // "off") end) as $cap
            | (if ($requested | rank) <= ($cap | rank) then $requested else $cap end) as $effective
            | {
                name: $name,
                description: ($m.description // null),
                risk: ($m.risk // "normal"),
                compress_shell: ($m.compress_shell // "safe"),
                compress_files: ($m.compress_files // "safe"),
                rtk_mode: ($m.rtk_mode // "off"),
                leanctx_mode: ($m.leanctx_mode // "off"),
                headroom_mode: ($m.headroom_mode // "off"),
                caveman_mode: $effective,
                caveman_max: $cap,
                caveman_output: ($effective != "off"),
                output_style: ($d.default_output_style // "ste-inspired")
              }
          ],
          aliases: [
            (if has("aliases") then .aliases else {"plan": "architect", "ci": "cicd"} end)
            | to_entries[] | {alias: .key, target: .value}
          ]
        }' "$_SETTINGS_FILE"
  }

  modes_text() {
    local _MODES_JSON
    _MODES_JSON="$(modes_json)" || return 1
    echo "Modes:"
    jq -r '.modes[] | [.name, .risk, (.description // "")] | @tsv' <<< "$_MODES_JSON" |
      awk -F'\t' '{ printf "  %-16s %-9s %s\n", $1, $2, $3 }'
    local _ALIAS_LINE
    _ALIAS_LINE="$(jq -r '[.aliases[] | "\(.alias) -> \(.target)"] | join(", ")' <<< "$_MODES_JSON")"
    [ -n "$_ALIAS_LINE" ] && echo "Aliases: $_ALIAS_LINE"
    return 0
  }

  case "$_MODE" in
    -h|--help|help)
      usage
      return 0
      ;;
    modes)
      [ "$#" -gt 0 ] && shift
      case "${1:-}" in
        --json)
          modes_json
          return $?
          ;;
        ""|--text)
          modes_text
          return $?
          ;;
        *)
          echo "Error: unknown modes option: $1. Use: workflow modes [--json]" >&2
          return 2
          ;;
      esac
      ;;
    status|"")
      [ "$#" -gt 0 ] && shift
      case "${1:-}" in
        --json)
          status_json
          return $?
          ;;
        "")
          status
          return 0
          ;;
        *)
          echo "Error: unknown status option: $1. Use: workflow status [--json]" >&2
          return 2
          ;;
      esac
      ;;
    doctor)
      shift
      # Read-only check. Runs in a child process so it cannot change this shell.
      AICONTEXT_DOCTOR_VIA_WORKFLOW=1 bash "$_SCRIPT_DIR/doctor.sh" "$@"
      return $?
      ;;
    report)
      need_jq || return 1
      workflow_report "$_ACTIVE_ENV_FILE"
      return $?
      ;;
    reset-session)
      need_jq || return 1
      workflow_reset_session "$_ACTIVE_ENV_FILE"
      return $?
      ;;
    init)
      local _AGENTS_TEMPLATE="$_PROJECT_ROOT/templates/AGENTS_base.md"
      local _TARGET_AGENTS="$PWD/AGENTS.md"
      local _MANAGED_START='<!-- ai-workflow-controller:start -->'
      local _MANAGED_END='<!-- ai-workflow-controller:end -->'
      local _TARGET_DIR
      local _TEMPORARY_AGENTS

      if [ ! -r "$_AGENTS_TEMPLATE" ]; then
        printf 'Error: AGENTS.md template not found or unreadable: %s\n' "$_AGENTS_TEMPLATE" >&2
        return 1
      fi

      if [ -L "$_TARGET_AGENTS" ]; then
        printf 'Error: refusing to replace or follow an AGENTS.md symlink: %s\n' "$_TARGET_AGENTS" >&2
        return 1
      fi

      if [ ! -e "$_TARGET_AGENTS" ]; then
        if cp -- "$_AGENTS_TEMPLATE" "$_TARGET_AGENTS"; then
          printf 'Created AGENTS.md from template: %s\n' "$_TARGET_AGENTS"
          return 0
        fi
        printf 'Error: could not create AGENTS.md: %s\n' "$_TARGET_AGENTS" >&2
        return 1
      fi

      if [ ! -f "$_TARGET_AGENTS" ]; then
        printf 'Error: AGENTS.md exists but is not a regular file: %s\n' "$_TARGET_AGENTS" >&2
        return 1
      fi

      if grep -Fqx -- "$_MANAGED_START" "$_TARGET_AGENTS"; then
        if grep -Fqx -- "$_MANAGED_END" "$_TARGET_AGENTS"; then
          printf 'Already initialized AI workflow rules: %s\n' "$_TARGET_AGENTS"
          return 0
        fi
        printf 'Error: incomplete AI workflow managed block in %s\n' "$_TARGET_AGENTS" >&2
        return 1
      fi
      if grep -Fqx -- "$_MANAGED_END" "$_TARGET_AGENTS"; then
        printf 'Error: incomplete AI workflow managed block in %s\n' "$_TARGET_AGENTS" >&2
        return 1
      fi

      _TARGET_DIR="$(dirname "$_TARGET_AGENTS")"
      _TEMPORARY_AGENTS="$(mktemp "$_TARGET_DIR/.AGENTS.md.ai-workflow.XXXXXX")"
      if ! cp -- "$_TARGET_AGENTS" "$_TEMPORARY_AGENTS"; then
        rm -f -- "$_TEMPORARY_AGENTS"
        printf 'Error: could not stage existing AGENTS.md: %s\n' "$_TARGET_AGENTS" >&2
        return 1
      fi
      chmod --reference="$_TARGET_AGENTS" "$_TEMPORARY_AGENTS"

      if ! {
        printf '\n'
        cat -- "$_AGENTS_TEMPLATE"
      } >> "$_TEMPORARY_AGENTS"; then
        rm -f -- "$_TEMPORARY_AGENTS"
        printf 'Error: could not append AGENTS.md template: %s\n' "$_AGENTS_TEMPLATE" >&2
        return 1
      fi

      if mv -- "$_TEMPORARY_AGENTS" "$_TARGET_AGENTS"; then
        printf 'Appended AI workflow rules without replacing existing instructions: %s\n' "$_TARGET_AGENTS"
        return 0
      fi
      rm -f -- "$_TEMPORARY_AGENTS"
      printf 'Error: could not update AGENTS.md: %s\n' "$_TARGET_AGENTS" >&2
      return 1
      ;;
    setup)
      (
        local _INSTRUCTION
        local _XDG_CONFIG_HOME
        local _DEFAULT_LOCAL_SETTINGS
        local _DEFAULT_SERVER_SETTINGS
        local _ADD_GEMINI=false
        local _ADD_CLAUDE=false
        local _SETTINGS_FILE_PATH
        local -a _SETTINGS_FILES=()

        _INSTRUCTION='Before answering or modifying files, always check ~/.config/ai-workflow/active_mode.env for the active context policy (AICONTEXT_PROFILE, AICONTEXT_RISK, AICONTEXT_RAW_ON_FAIL); use raw lossless context only for raw, security, or db modes, and preserve first failures completely for debug or test modes.'
        _XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
        _DEFAULT_LOCAL_SETTINGS="$_XDG_CONFIG_HOME/Code/User/settings.json"
        _DEFAULT_SERVER_SETTINGS="$HOME/.vscode-server/data/Machine/settings.json"

        add_settings_file() {
          local _candidate="$1"
          local _existing

          for _existing in "${_SETTINGS_FILES[@]}"; do
            if [ "$_existing" = "$_candidate" ]; then
              return 0
            fi
          done
          _SETTINGS_FILES+=("$_candidate")
        }

        extension_installed() {
          local _extension_id="$1"
          local _extension_root
          local _manifest

          for _extension_root in \
            "$HOME/.vscode/extensions" \
            "$HOME/.vscode-server/extensions" \
            "$HOME/.vscode-server-insiders/extensions"; do
            for _manifest in \
              "$_extension_root/$_extension_id-"*/package.json \
              "$_extension_root/$_extension_id/package.json"; do
              if [ -f "$_manifest" ]; then
                return 0
              fi
            done
          done
          return 1
        }

        settings_key_exists() {
          local _key="$1"
          local _settings

          for _settings in "${_SETTINGS_FILES[@]}"; do
            if [ -f "$_settings" ] && jq -e --arg key "$_key" 'has($key)' "$_settings" >/dev/null 2>&1; then
              return 0
            fi
          done
          return 1
        }

        update_settings_file() {
          local _settings_file="$1"
          local _add_gemini="$2"
          local _settings_dir
          local _temporary_file

          _settings_dir="$(dirname "$_settings_file")"
          mkdir -p "$_settings_dir"
          if [ ! -s "$_settings_file" ]; then
            printf '{}\n' > "$_settings_file"
          fi

          if ! jq -e 'type == "object"' "$_settings_file" >/dev/null 2>&1; then
            printf 'Error: VS Code settings must be a JSON object: %s\n' "$_settings_file" >&2
            printf 'Comments and trailing commas must be removed before running setup.\n' >&2
            return 1
          fi

          _temporary_file="$(mktemp "$_settings_dir/.ai-workflow-settings.XXXXXX")"
          chmod --reference="$_settings_file" "$_temporary_file"

          if ! jq --arg instruction "$_INSTRUCTION" --argjson add_gemini "$_add_gemini" '
            .["github.copilot.chat.customInstructions"] = (
              (.["github.copilot.chat.customInstructions"] // []) as $instructions
              | if ($instructions | type) != "array" then
                  error("github.copilot.chat.customInstructions must be an array")
                elif any($instructions[]?; type == "object" and .text? == $instruction) then
                  $instructions
                else
                  $instructions + [{"text": $instruction}]
                end
            )
            | if $add_gemini then
                .["geminicodeassist.rules"] = (
                  (.["geminicodeassist.rules"] // "") as $rules
                  | if ($rules | type) != "string" then
                      error("geminicodeassist.rules must be a string")
                    elif (($rules | split("\n") | index($instruction)) != null) then
                      $rules
                    elif $rules == "" then
                      $instruction
                    elif ($rules | endswith("\n")) then
                      $rules + $instruction
                    else
                      $rules + "\n" + $instruction
                    end
                )
              else
                .
              end
          ' "$_settings_file" > "$_temporary_file"; then
            rm -f -- "$_temporary_file"
            printf 'Error: could not update VS Code settings: %s\n' "$_settings_file" >&2
            return 1
          fi

          if cmp -s "$_settings_file" "$_temporary_file"; then
            rm -f -- "$_temporary_file"
            printf 'Already configured VS Code settings: %s\n' "$_settings_file"
          else
            mv -- "$_temporary_file" "$_settings_file"
            printf 'Updated VS Code settings: %s\n' "$_settings_file"
          fi
        }

        append_instruction_file() {
          local _instruction_file="$1"
          local _with_frontmatter="$2"
          local _instruction_dir

          _instruction_dir="$(dirname "$_instruction_file")"
          mkdir -p "$_instruction_dir"
          if [ -f "$_instruction_file" ] && grep -Fqx -- "$_INSTRUCTION" "$_instruction_file"; then
            printf 'Already configured agent instructions: %s\n' "$_instruction_file"
            return 0
          fi

          if [ ! -s "$_instruction_file" ] && [ "$_with_frontmatter" = true ]; then
            printf '%s\n' '---' 'applyTo: "**"' '---' "$_INSTRUCTION" > "$_instruction_file"
          elif [ ! -s "$_instruction_file" ]; then
            printf '%s\n' "$_INSTRUCTION" > "$_instruction_file"
          else
            printf '\n%s\n' "$_INSTRUCTION" >> "$_instruction_file"
          fi
          printf 'Updated agent instructions: %s\n' "$_instruction_file"
        }

        need_jq || exit 1

        if [ -n "${AICONTEXT_VSCODE_SETTINGS_FILE:-}" ]; then
          add_settings_file "$AICONTEXT_VSCODE_SETTINGS_FILE"
        else
          for _SETTINGS_FILE_PATH in \
            "$_DEFAULT_LOCAL_SETTINGS" \
            "$_XDG_CONFIG_HOME/Code - Insiders/User/settings.json" \
            "$_DEFAULT_SERVER_SETTINGS" \
            "$HOME/.vscode-server-insiders/data/Machine/settings.json" \
            "$HOME/.vscode-remote/data/Machine/settings.json"; do
            if [ -f "$_SETTINGS_FILE_PATH" ]; then
              add_settings_file "$_SETTINGS_FILE_PATH"
            fi
          done

          if [ "${#_SETTINGS_FILES[@]}" -eq 0 ]; then
            if [ -d "$(dirname "$_DEFAULT_SERVER_SETTINGS")" ]; then
              add_settings_file "$_DEFAULT_SERVER_SETTINGS"
            else
              add_settings_file "$_DEFAULT_LOCAL_SETTINGS"
            fi
          fi
        fi

        if extension_installed 'google.geminicodeassist' || settings_key_exists 'geminicodeassist.rules'; then
          _ADD_GEMINI=true
        fi
        if extension_installed 'anthropic.claude-code' || command -v claude >/dev/null 2>&1; then
          _ADD_CLAUDE=true
        fi

        for _SETTINGS_FILE_PATH in "${_SETTINGS_FILES[@]}"; do
          update_settings_file "$_SETTINGS_FILE_PATH" "$_ADD_GEMINI" || exit 1
        done

        append_instruction_file "$HOME/.copilot/instructions/ai-workflow.instructions.md" true || exit 1
        if [ "$_ADD_CLAUDE" = true ]; then
          append_instruction_file "$HOME/.claude/CLAUDE.md" false || exit 1
        else
          printf 'Claude Code not detected; skipped ~/.claude/CLAUDE.md.\n'
        fi
        if [ "$_ADD_GEMINI" = false ]; then
          printf 'Gemini Code Assist not detected; skipped geminicodeassist.rules.\n'
        fi
        printf 'Other extensions require a documented global instruction or user-rules target; no speculative settings were added.\n'
      )
      return $?
      ;;
  esac

  # Mode ids are lowercase words with hyphens. Reject anything else before it reaches a jq program.
  case "$_MODE" in
    ''|-*|*[!a-z0-9-]*)
      echo "Error: profile '$_MODE' not found in $_SETTINGS_FILE" >&2
      return 1
      ;;
  esac

  if [ ! -f "$_SETTINGS_FILE" ]; then
    echo "Error: settings file not found: $_SETTINGS_FILE" >&2
    echo "Set AICONTEXT_SETTINGS_FILE or keep config/workflow_settings.json beside this script." >&2
    return 1
  fi

  need_jq || return 1

  # Aliases come from config ("aliases"). Without that key, the two built-in aliases still work.
  local _ALIAS_TARGET
  _ALIAS_TARGET="$(jq -r --arg m "$_MODE" 'if has("aliases") then (.aliases[$m] // "") else ({"plan": "architect", "ci": "cicd"}[$m] // "") end' "$_SETTINGS_FILE" 2>/dev/null)"
  if [ -n "$_ALIAS_TARGET" ]; then
    case "$_ALIAS_TARGET" in
      -*|*[!a-z0-9-]*) ;;
      *) _MODE="$_ALIAS_TARGET" ;;
    esac
  fi

  if ! jq -e ".modes[\"$_MODE\"]" "$_SETTINGS_FILE" >/dev/null 2>&1; then
    echo "Error: profile '$_MODE' not found in $_SETTINGS_FILE" >&2
    usage >&2
    return 1
  fi

  export AICONTEXT_PROFILE="$_MODE"
  export AICONTEXT_RISK="$(jq -r ".modes[\"$_MODE\"].risk // \"normal\"" "$_SETTINGS_FILE")"
  export AICONTEXT_COMPRESS_SHELL="$(jq -r ".modes[\"$_MODE\"].compress_shell // \"safe\"" "$_SETTINGS_FILE")"
  export AICONTEXT_COMPRESS_FILES="$(jq -r ".modes[\"$_MODE\"].compress_files // \"safe\"" "$_SETTINGS_FILE")"
  export AICONTEXT_CODEBASE_INDEX="$(jq -r ".modes[\"$_MODE\"].codebase_index // false" "$_SETTINGS_FILE")"
  export AICONTEXT_MEMORY_LAYER="$(jq -r ".modes[\"$_MODE\"].memory_layer // \"off\"" "$_SETTINGS_FILE")"
  export AICONTEXT_HEADROOM_MODE="$(jq -r ".modes[\"$_MODE\"].headroom_mode // \"off\"" "$_SETTINGS_FILE")"
  export AICONTEXT_LEANCTX_MODE="$(jq -r ".modes[\"$_MODE\"].leanctx_mode // \"off\"" "$_SETTINGS_FILE")"
  export AICONTEXT_RTK_MODE="$(jq -r ".modes[\"$_MODE\"].rtk_mode // \"off\"" "$_SETTINGS_FILE")"
  export AICONTEXT_OUTPUT_STYLE="$(jq -r '.defaults.default_output_style // "ste-inspired"' "$_SETTINGS_FILE")"

  # Caveman state only. Valid levels are off, lite, full. Anything else (ultra, wenyan) becomes off.
  local _CAVEMAN_REQUESTED
  local _CAVEMAN_REQUEST_FROM=caveman_mode
  local _CAVEMAN_CAP
  local _CAVEMAN_SHRINK
  local _CAVEMAN_EFFECTIVE
  _CAVEMAN_REQUESTED="$(jq -r ".modes[\"$_MODE\"].caveman_mode // .defaults.caveman_mode // \"off\"" "$_SETTINGS_FILE")"
  # Explicit opt-in for this activation: AICONTEXT_CAVEMAN_REQUEST=off|lite|full workflow <mode>.
  # It replaces the config level. It is not saved: the next activation without it uses the config level again.
  if [ -n "${AICONTEXT_CAVEMAN_REQUEST:-}" ]; then
    _CAVEMAN_REQUESTED="$AICONTEXT_CAVEMAN_REQUEST"
    _CAVEMAN_REQUEST_FROM=AICONTEXT_CAVEMAN_REQUEST
  fi
  _CAVEMAN_CAP="$(jq -r ".modes[\"$_MODE\"].caveman_max // .defaults.caveman_max // \"off\"" "$_SETTINGS_FILE")"
  _CAVEMAN_SHRINK="$(jq -r ".modes[\"$_MODE\"].caveman_shrink // .defaults.caveman_shrink // \"off\"" "$_SETTINGS_FILE")"
  if ! _aiw_caveman_rank "$_CAVEMAN_REQUESTED" >/dev/null; then
    printf 'Warning: %s "%s" is not supported. Use off, lite, or full. Using off.\n' "$_CAVEMAN_REQUEST_FROM" "$_CAVEMAN_REQUESTED" >&2
    _CAVEMAN_REQUESTED=off
  fi
  if ! _aiw_caveman_rank "$_CAVEMAN_CAP" >/dev/null; then
    printf 'Warning: caveman_max "%s" is not supported. Using off.\n' "$_CAVEMAN_CAP" >&2
    _CAVEMAN_CAP=off
  fi
  case "$_CAVEMAN_SHRINK" in
    off|experiment) ;;
    *)
      printf 'Warning: caveman_shrink "%s" is not supported. Using off.\n' "$_CAVEMAN_SHRINK" >&2
      _CAVEMAN_SHRINK=off
      ;;
  esac
  if _aiw_caveman_blocked "$_MODE"; then
    _CAVEMAN_CAP=off
    _CAVEMAN_SHRINK=off
  fi
  # Effective level is the lower of the requested level and the cap.
  if [ "$(_aiw_caveman_rank "$_CAVEMAN_REQUESTED")" -le "$(_aiw_caveman_rank "$_CAVEMAN_CAP")" ]; then
    _CAVEMAN_EFFECTIVE="$_CAVEMAN_REQUESTED"
  else
    _CAVEMAN_EFFECTIVE="$_CAVEMAN_CAP"
  fi
  if [ "$_CAVEMAN_REQUEST_FROM" = AICONTEXT_CAVEMAN_REQUEST ] && [ "$_CAVEMAN_REQUESTED" != off ] && [ "$_CAVEMAN_EFFECTIVE" != "$_CAVEMAN_REQUESTED" ]; then
    if [ "$_CAVEMAN_EFFECTIVE" = off ]; then
      printf "Notice: Caveman request '%s' ignored. Mode '%s' does not allow Caveman.\n" "$_CAVEMAN_REQUESTED" "$_MODE" >&2
    else
      printf "Notice: Caveman request '%s' lowered to '%s'. That is the limit for mode '%s'.\n" "$_CAVEMAN_REQUESTED" "$_CAVEMAN_EFFECTIVE" "$_MODE" >&2
    fi
  fi
  export AICONTEXT_CAVEMAN_REQUESTED="$_CAVEMAN_REQUESTED"
  export AICONTEXT_CAVEMAN_MODE="$_CAVEMAN_EFFECTIVE"
  export AICONTEXT_CAVEMAN_MAX="$_CAVEMAN_CAP"
  export AICONTEXT_CAVEMAN_SHRINK="$_CAVEMAN_SHRINK"
  if [ "$_CAVEMAN_EFFECTIVE" = "off" ]; then
    export AICONTEXT_CAVEMAN_OUTPUT=false
  else
    export AICONTEXT_CAVEMAN_OUTPUT=true
  fi
  export AICONTEXT_CACHE_ALIGN="$(jq -r ".modes[\"$_MODE\"].cache_align // .defaults.cache_align // true" "$_SETTINGS_FILE")"
  export AICONTEXT_RAW_ON_FAIL="$(jq -r ".modes[\"$_MODE\"].raw_on_fail // .defaults.raw_on_fail // true" "$_SETTINGS_FILE")"
  export AICONTEXT_KEEP_RAW_LOGS="$(jq -r ".modes[\"$_MODE\"].keep_raw_logs // .defaults.keep_raw_logs // true" "$_SETTINGS_FILE")"
  export AICONTEXT_AGENTS_MUTATION="$(jq -r ".modes[\"$_MODE\"].agents_mutation // .defaults.agents_mutation // \"deny\"" "$_SETTINGS_FILE")"
  export AICONTEXT_TARGET_FILES_FULL="$(jq -r ".modes[\"$_MODE\"].target_files_full // .defaults.target_files_full // true" "$_SETTINGS_FILE")"
  export AICONTEXT_PRESERVE_STDERR="$(jq -r ".modes[\"$_MODE\"].preserve_stderr // .defaults.preserve_stderr // true" "$_SETTINGS_FILE")"
  export AICONTEXT_PRESERVE_EXIT_CODE="$(jq -r ".modes[\"$_MODE\"].preserve_exit_code // .defaults.preserve_exit_code // true" "$_SETTINGS_FILE")"
  export AICONTEXT_PRESERVE_FIRST_ERROR="$(jq -r ".modes[\"$_MODE\"].preserve_first_error // .defaults.preserve_first_error // true" "$_SETTINGS_FILE")"
  export AICONTEXT_PRESERVE_WARNINGS="$(jq -r ".modes[\"$_MODE\"].preserve_warnings // .defaults.preserve_warnings // true" "$_SETTINGS_FILE")"
  export AICONTEXT_PRESERVE_NUMBERS="$(jq -r ".modes[\"$_MODE\"].preserve_numbers // .defaults.preserve_numbers // true" "$_SETTINGS_FILE")"
  export AICONTEXT_RAW_LOG_DIR="$(jq -r ".modes[\"$_MODE\"].raw_log_dir // .defaults.raw_log_dir // \".ai-context/raw\"" "$_SETTINGS_FILE")"
  export AICONTEXT_COMPRESSED_LOG_DIR="$(jq -r ".modes[\"$_MODE\"].compressed_log_dir // .defaults.compressed_log_dir // \".ai-context/compressed\"" "$_SETTINGS_FILE")"

  if [ "$AICONTEXT_RTK_MODE" = "off" ]; then
    export RTK_HOOK_ENABLED=false
  else
    export RTK_HOOK_ENABLED=true
  fi

  export HEADROOM_COMPRESSION_STRATEGY="$AICONTEXT_HEADROOM_MODE"
  export LEANCTX_ACTIVE="$AICONTEXT_LEANCTX_MODE"
  export MEMSTACK_ACTIVE="$AICONTEXT_CODEBASE_INDEX"
  export CAVEMAN_OUTPUT="$AICONTEXT_CAVEMAN_OUTPUT"

  cat > "$_ACTIVE_ENV_FILE" <<ENV
export AICONTEXT_PROFILE="$AICONTEXT_PROFILE"
export AICONTEXT_RISK="$AICONTEXT_RISK"
export AICONTEXT_COMPRESS_SHELL="$AICONTEXT_COMPRESS_SHELL"
export AICONTEXT_COMPRESS_FILES="$AICONTEXT_COMPRESS_FILES"
export AICONTEXT_CODEBASE_INDEX="$AICONTEXT_CODEBASE_INDEX"
export AICONTEXT_MEMORY_LAYER="$AICONTEXT_MEMORY_LAYER"
export AICONTEXT_HEADROOM_MODE="$AICONTEXT_HEADROOM_MODE"
export AICONTEXT_LEANCTX_MODE="$AICONTEXT_LEANCTX_MODE"
export AICONTEXT_RTK_MODE="$AICONTEXT_RTK_MODE"
export AICONTEXT_CAVEMAN_OUTPUT="$AICONTEXT_CAVEMAN_OUTPUT"
export AICONTEXT_CAVEMAN_REQUESTED="$AICONTEXT_CAVEMAN_REQUESTED"
export AICONTEXT_CAVEMAN_MODE="$AICONTEXT_CAVEMAN_MODE"
export AICONTEXT_CAVEMAN_MAX="$AICONTEXT_CAVEMAN_MAX"
export AICONTEXT_CAVEMAN_SHRINK="$AICONTEXT_CAVEMAN_SHRINK"
export AICONTEXT_OUTPUT_STYLE="$AICONTEXT_OUTPUT_STYLE"
export AICONTEXT_CACHE_ALIGN="$AICONTEXT_CACHE_ALIGN"
export AICONTEXT_RAW_ON_FAIL="$AICONTEXT_RAW_ON_FAIL"
export AICONTEXT_KEEP_RAW_LOGS="$AICONTEXT_KEEP_RAW_LOGS"
export AICONTEXT_AGENTS_MUTATION="$AICONTEXT_AGENTS_MUTATION"
export AICONTEXT_TARGET_FILES_FULL="$AICONTEXT_TARGET_FILES_FULL"
export AICONTEXT_PRESERVE_STDERR="$AICONTEXT_PRESERVE_STDERR"
export AICONTEXT_PRESERVE_EXIT_CODE="$AICONTEXT_PRESERVE_EXIT_CODE"
export AICONTEXT_PRESERVE_FIRST_ERROR="$AICONTEXT_PRESERVE_FIRST_ERROR"
export AICONTEXT_PRESERVE_WARNINGS="$AICONTEXT_PRESERVE_WARNINGS"
export AICONTEXT_PRESERVE_NUMBERS="$AICONTEXT_PRESERVE_NUMBERS"
export AICONTEXT_RAW_LOG_DIR="$AICONTEXT_RAW_LOG_DIR"
export AICONTEXT_COMPRESSED_LOG_DIR="$AICONTEXT_COMPRESSED_LOG_DIR"
export RTK_HOOK_ENABLED="$RTK_HOOK_ENABLED"
export HEADROOM_COMPRESSION_STRATEGY="$HEADROOM_COMPRESSION_STRATEGY"
export LEANCTX_ACTIVE="$LEANCTX_ACTIVE"
export MEMSTACK_ACTIVE="$MEMSTACK_ACTIVE"
export CAVEMAN_OUTPUT="$CAVEMAN_OUTPUT"
ENV

  printf 'Activated AI context profile: %s\n' "$AICONTEXT_PROFILE"
  printf '  risk=%s shell=%s files=%s index=%s memory=%s\n' "$AICONTEXT_RISK" "$AICONTEXT_COMPRESS_SHELL" "$AICONTEXT_COMPRESS_FILES" "$AICONTEXT_CODEBASE_INDEX" "$AICONTEXT_MEMORY_LAYER"
  printf '  rtk=%s headroom=%s leanctx=%s caveman=%s raw_on_fail=%s\n' "$AICONTEXT_RTK_MODE" "$AICONTEXT_HEADROOM_MODE" "$AICONTEXT_LEANCTX_MODE" "$AICONTEXT_CAVEMAN_MODE" "$AICONTEXT_RAW_ON_FAIL"
  printf '  output_style=%s caveman_max=%s caveman_shrink=%s\n' "$AICONTEXT_OUTPUT_STYLE" "$AICONTEXT_CAVEMAN_MAX" "$AICONTEXT_CAVEMAN_SHRINK"
  printf '  env_cache=%s\n' "$_ACTIVE_ENV_FILE"

  return 0
}

_ai_workflow_main "$@"
