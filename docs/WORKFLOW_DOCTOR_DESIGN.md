# `workflow doctor` Design

Status: implemented in `scripts/doctor.sh` (v1, read-only). The section "Implemented differences" at the end lists what differs from this design.

## Purpose

Show which settings and tools affect agent context behavior, and warn about duplicated or conflicting policy. Run it before any installer writes to more locations.

## Rules

- **Read-only.** The first implementation never creates, edits, or deletes a file. No `--fix`.
- **No network and no tool execution** except `<tool> --version` with a timeout. Never run `rtk init`, `lean-ctx setup`, or similar.
- **No secrets in output.** Settings and MCP files can contain tokens. Report key names, file paths, and counts. Never print values from `env`, `headers`, `args`, or `*key*`, `*token*`, `*secret*` fields.
- **Always exits normally when a file is missing.** Missing is a finding (`info`), not an error.
- **Works without `jq`.** If `jq` is missing, report that and skip JSON checks. Do not fail.
- **Platform-isolated.** All path lookup lives in one "locations" function, so a Windows backend can replace it. The extension consumes `--json` only.

## Command

```bash
workflow doctor            # human-readable
workflow doctor --json     # machine-readable, for the extension
workflow doctor --project <dir>   # default: current directory
```

`doctor` must also run as a standalone script (`scripts/doctor.sh`), because `workflow` is a sourced function and must not alter the caller's shell.

Exit code: `0` no `error`; `1` at least one `error`; `2` doctor itself failed. Warnings do not change the exit code.

## Checks

| Group | What is checked |
|---|---|
| Environment | WSL distro (`WSL_DISTRO_NAME`), `$HOME`, shell, `jq`/`git` present |
| Workflow | `workflow` alias or function defined in `~/.bashrc`/`~/.profile`; `wx` function; script path exists |
| Active mode | `~/.config/ai-workflow/active_mode.env` exists, parses, profile exists in `config/workflow_settings.json`; matches current shell `AICONTEXT_PROFILE` |
| VS Code | Local user settings, WSL/server machine settings, workspace `.vscode/settings.json`: Copilot instruction keys, `tokenController.scriptPath` |
| Agent files | `AGENTS.md`, `.github/copilot-instructions.md`, `~/.copilot/instructions/`, `~/.claude/CLAUDE.md`, `~/.claude/settings.json`, `.claude/settings.json` |
| MCP | Discoverable config files: `.mcp.json`, `.vscode/mcp.json`, VS Code user `mcp.json`, `~/.claude.json` (server names only) |
| Tools | `rtk`, `lean-ctx`, `headroom`, `caveman`, `ccusage`: on `PATH`, path, version |
| Policy blocks | Managed block markers and known instruction text across all files above |

## Conflict detection

Policy block identity:
- the managed block `<!-- ai-workflow-controller:start -->` … `end`,
- the exact `workflow setup` instruction line,
- mentions of `active_mode.env`, `wx`, `rtk init` output blocks, and Caveman/terse-output rules.

Rules:
1. Same block in more than one user-level and project-level file → duplicate.
2. Incomplete managed block (start without end) → broken.
3. One file tells agents to compress or be terse, another says raw/lossless for the same scope → conflict.
4. Tool hook installed (for example RTK in `.claude/settings.json`) while the active mode has that tool `off` → mismatch.
5. Active mode file is not readable from where the agent runs (other WSL distro, Windows-side VS Code) → unreachable.
6. Active profile is unknown, or env file disagrees with the shell → stale.
7. `tokenController.scriptPath` does not exist.

## Severity levels

| Level | Meaning | Examples |
|---|---|---|
| `error` | Policy is broken or unsafe. Fix before relying on modes. | Incomplete managed block; unknown active profile; Caveman or compression instruction active in a high-risk mode; `scriptPath` missing |
| `warn` | Likely wrong or contradictory. Behavior is uncertain. | Duplicate policy blocks; tool hook active while mode says `off`; active mode file not visible to the VS Code host |
| `info` | Useful fact, no action required. | Optional tool not installed; `micro` mode active; file absent |
| `ok` | Check passed. | Shown only in verbose mode |

## Output shape (human)

```text
workflow doctor  (project: ~/projects/demo)

Environment
  ok    WSL2 Ubuntu-24.04, bash 5.2, jq 1.8
Active mode
  ok    code (risk=normal) from ~/.config/ai-workflow/active_mode.env
Tools
  ok    rtk 0.x       ~/.local/bin/rtk
  info  lean-ctx      not found
  info  headroom      not found
  info  caveman       not found
  info  ccusage       not found
Policy
  warn  duplicate policy block
        ~/.claude/CLAUDE.md:12
        ./AGENTS.md:40 (managed block)
        -> keep the project block; remove the user-level copy
  warn  rtk hook in .claude/settings.json, but rtk_mode=off for 'code'

Summary: 0 error, 2 warn, 4 info
```

Each finding has an id, a path (with line when known), and one suggested manual action. Doctor never runs the action.

## Output shape (JSON)

```json
{
  "schema_version": 1,
  "generated_at": "2026-10-07T10:00:00Z",
  "project": "/home/user/projects/demo",
  "environment": {
    "platform": "wsl2",
    "distro": "Ubuntu-24.04",
    "shell": "bash",
    "home": "/home/user"
  },
  "active_mode": {
    "profile": "code",
    "risk": "normal",
    "source": "/home/user/.config/ai-workflow/active_mode.env",
    "shell_matches": true
  },
  "tools": [
    {"name": "rtk", "found": true, "path": "/home/user/.local/bin/rtk", "version": "0.x"},
    {"name": "lean-ctx", "found": false}
  ],
  "locations": [
    {"id": "claude_user_md", "path": "/home/user/.claude/CLAUDE.md", "exists": true, "has_policy_block": true}
  ],
  "findings": [
    {
      "id": "policy.duplicate_block",
      "severity": "warn",
      "message": "Policy block appears in 2 files",
      "paths": [
        {"path": "/home/user/.claude/CLAUDE.md", "line": 12},
        {"path": "/home/user/projects/demo/AGENTS.md", "line": 40}
      ],
      "suggestion": "Keep the project block; remove the user-level copy."
    }
  ],
  "summary": {"error": 0, "warn": 1, "info": 4}
}
```

Rules for the schema: stable `id` strings; `severity` is one of `error|warn|info|ok`; paths are absolute; no values from settings files; `schema_version` increments on breaking change.

## Files doctor may read

- `~/.bashrc`, `~/.profile`
- `~/.config/ai-workflow/active_mode.env`
- `<controller>/config/workflow_settings.json`
- `~/.config/Code/User/settings.json` and `Code - Insiders` equivalent
- `~/.vscode-server/data/Machine/settings.json` (and insiders / `.vscode-remote` equivalents)
- `<project>/.vscode/settings.json`, `<project>/.vscode/mcp.json`
- `<project>/AGENTS.md`, `<project>/.github/copilot-instructions.md`
- `~/.copilot/instructions/*.md`
- `~/.claude/CLAUDE.md`, `~/.claude/settings.json`, `<project>/.claude/settings.json`, `<project>/CLAUDE.md`
- `<project>/.mcp.json`, `~/.claude.json` (server names only)
- `.ai-context/session.jsonl` (existence and last profile only)
- `PATH` directory listings, `<tool> --version`

Symlinks: report them, do not follow outside the home directory or project.

## Files doctor must not modify

Everything. In particular:

- all files listed above,
- `.ai-context/raw/` and `.ai-context/session.jsonl` (raw evidence),
- `~/.config/ai-workflow/active_mode.env`,
- tool configs (`~/.config/rtk`, LeanCTX, Headroom, Caveman, ccusage data),
- the project's git state.

Doctor must not create new files, not even a cache or log. Output goes to stdout only.

## Out of scope for the first version

- `--fix` or any write path. A later `workflow doctor --fix` needs its own design and backups.
- Semantic analysis of free-text instructions beyond the known patterns above.
- Windows-native path discovery. Keep the locations function replaceable.
- Token and cost data (`ccusage`). Report only whether it is installed.

## Implementation notes

1. Add the locations function and tool detection first. They also feed `check-tools.sh` and the extension status.
2. Add `tests/doctor.test.sh` with fixture home directories (set `HOME`, `XDG_CONFIG_HOME`, `AICONTEXT_CONFIG_DIR`). Cover: empty home, duplicate block, incomplete block, JSON validity, secret redaction, and a read-only check that compares file hashes before and after.
3. The extension reads `workflow doctor --json` and shows the worst severity in the status bar tooltip.

## Implemented differences

- **MCP config checks are not implemented.** They stay out until they are designed and tested.
- **RTK:** any RTK hook or setup is a `warn` (`policy.rtk_hook`) in every mode. Doctor looks at `settings.json` (project and `~/.claude`), `RTK.md`, `hooks/*rtk*`, and `RTK.md` includes in `CLAUDE.md`. It never runs `rtk init` and never touches `~/.config/rtk`. `policy.rtk_hook_mismatch` is an extra `warn` when the mode sets rtk `off`.
- **Caveman:** reads `${CLAUDE_CONFIG_DIR:-~/.claude}/.caveman-active`. Active in `raw`, `security`, `db`, `release`, `migration`, `docs` (or a profile in `caveman_policy.hard_blocked_profiles`) is an `error`. Level `ultra` or `wenyan*`, no Token Controller opt-in, or a level above the Token Controller level is a `warn`. Opt-in today means a non-`off` `AICONTEXT_CAVEMAN_MODE` in the env file (set through the config). Doctor never edits the state file.
- **Duplicate policy text** is a `warn`, never an `error`. An incomplete managed block is an `error`.
- **Side effect note:** `workflow.sh` runs `mkdir -p ~/.config/ai-workflow` before any command. Through `workflow doctor` the directory can be created (empty). Doctor says so as an `info` finding (`doctor.config_dir`). `scripts/doctor.sh` run directly writes nothing.
- **JSON paths:** every `paths` entry is `{path, line}`. `line` is a number or `null`. Text output prints `path:line`.
- **Tools:** each tool has a `kind` (`command` or `claude-skill`). Caveman can be found as a Claude Code skill without a command on `PATH`.
