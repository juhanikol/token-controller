# User-level settings to account for

These can affect agent behavior

| Location | Purpose | Risk |
|---|---|---|
| `~/.config/ai-workflow/active_mode.env` | Active profile source | If VS Code/agent runs in another WSL distro or host, it may not see it. |
| `~/.bashrc` | `workflow` alias | Only affects shells that source Bash config. |
| `~/.copilot/instructions/ai-workflow.instructions.md` | User-level Copilot instruction | Can conflict with repo instructions. |
| `.github/copilot-instructions.md` | Project-wide Copilot instruction | Should not duplicate AGENTS content too much. |
| `AGENTS.md` | Codex/Copilot/agent project guidance | Best place for concise repo rules. |
| `~/.claude/CLAUDE.md` | Claude user/global guidance | Can override or confuse project rules if too broad. |
| `.claude/settings.json` | Claude Code hooks/permissions | Best place to force `wx` through hooks later. Claude docs recommend permissions/hooks for repeatable behavior. ([Claude Help Center][1]) |
| VS Code User/Machine `settings.json` | Copilot/custom instruction settings and extension path | In WSL, local Windows VS Code and WSL extension host may differ. |
| Extension setting `tokenController.scriptPath` | Path to `workflow.sh` | Currently default path can drift from README/install location.  |

[1]: https://support.claude.com/en/articles/14554000-claude-code-power-user-tips "Claude Code power user tips | Claude Help Center"

## Short list to remember for settings

* ~/.bashrc
* ~/.profile
* ~/.config/ai-workflow/active_mode.env
* ~/.claude/CLAUDE.md
* ~/.claude/settings.json
* ~/.copilot/instructions/
* ~/.config/Code/User/settings.json
* ~/.vscode-server/data/Machine/settings.json
* project/AGENTS.md
* project/.github/copilot-instructions.md
* project/.claude/settings.json
* MCP config files
* PATH entries
* WSL distro / hostname / home path

ADD more to the list and create architecture of these.