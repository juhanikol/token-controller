#!/usr/bin/env bash
# Path: scripts/workflow.sh
# Usage: source scripts/workflow.sh <mode>
# Modes: init setup raw scope architect decisions code snippet agent test test-full debug docs cicd review security migration db perf release off status
# Backward-compatible aliases: plan=architect, ci=cicd

# This script is intended to be sourced, because it exports variables to the current shell.
# It does not install token tools and does not invoke AI agents directly.

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
Usage: source scripts/workflow.sh <mode>

Modes:
  init         Initialize AGENTS.md in the current directory.
  setup        Configure global VS Code/agent instructions.
  raw          No compression. Highest fidelity.
  scope        Requirements and scope discovery.
  architect    Architecture, structure, codebase overview.
  decisions    ADRs, domain models, schemas, types.
  code         Normal implementation work.
  data-analysis Data analysis, stats, and visualization.
  snippet      Small file/method/snippet review.
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
  status       Show current profile.

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
    echo "  AICONTEXT_RAW_ON_FAIL=${AICONTEXT_RAW_ON_FAIL:-unset}"
    echo "  AICONTEXT_KEEP_RAW_LOGS=${AICONTEXT_KEEP_RAW_LOGS:-unset}"
    echo "  Active env cache: $_ACTIVE_ENV_FILE"
  }

  case "$_MODE" in
    -h|--help|help)
      usage
      return 0
      ;;
    status|"")
      status
      return 0
      ;;
    init)
      local _AGENTS_TEMPLATE="$_PROJECT_ROOT/templates/AGENTS_base.md"
      local _TARGET_AGENTS="$PWD/AGENTS.md"
      local _MANAGED_START='<!-- ai-workflow-controller:start -->'
      local _MANAGED_END='<!-- ai-workflow-controller:end -->'
      local _ACTIVE_MODE_REFERENCE='~/.config/ai-workflow/active_mode.env'
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

      {
        printf '\n%s\n' "$_MANAGED_START"
        printf '%s\n\n' '## AI Context Workflow Rules'
        if ! grep -Fq -- "$_ACTIVE_MODE_REFERENCE" "$_TARGET_AGENTS"; then
          printf '%s\n\n' 'Before answering or modifying files, always check `~/.config/ai-workflow/active_mode.env` for the active context policy (`AICONTEXT_PROFILE`, `AICONTEXT_RISK`, and `AICONTEXT_RAW_ON_FAIL`).'
        fi
        printf '%s\n' '- Correctness and reproducibility take priority over token savings.'
        printf '%s\n' '- For `raw`, `security`, `db`, and `release` modes, use raw or lossless context only.'
        printf '%s\n' '- For `debug` and `test` modes, preserve the first failure, stderr, exit code, paths, and line numbers completely.'
        printf '%s\n' '- Do not assume optional context tools are installed; detect them before relying on them.'
        printf '%s\n' "$_MANAGED_END"
      } >> "$_TEMPORARY_AGENTS"

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
    plan)
      _MODE="architect"
      ;;
    ci)
      _MODE="cicd"
      ;;
  esac

  if [ ! -f "$_SETTINGS_FILE" ]; then
    echo "Error: settings file not found: $_SETTINGS_FILE" >&2
    echo "Set AICONTEXT_SETTINGS_FILE or keep config/workflow_settings.json beside this script." >&2
    return 1
  fi

  need_jq || return 1

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
  export AICONTEXT_CAVEMAN_OUTPUT="$(jq -r ".modes[\"$_MODE\"].caveman_output // false" "$_SETTINGS_FILE")"
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
  printf '  rtk=%s headroom=%s leanctx=%s caveman=%s raw_on_fail=%s\n' "$AICONTEXT_RTK_MODE" "$AICONTEXT_HEADROOM_MODE" "$AICONTEXT_LEANCTX_MODE" "$AICONTEXT_CAVEMAN_OUTPUT" "$AICONTEXT_RAW_ON_FAIL"
  printf '  env_cache=%s\n' "$_ACTIVE_ENV_FILE"

  return 0
}

_ai_workflow_main "$@"
