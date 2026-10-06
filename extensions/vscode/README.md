# Token Controller UI

VS Code status-bar control for the [Token Controller](https://github.com/juhanikol/token-controller) CLI.

Token Controller is a mode switcher for AI context policy. You select the work mode (`code`, `debug`, `test`, `security`, …), and compatible agents and tools read that policy. This extension shows the active mode and lets you switch it. It does not compress output, run context tools, or measure tokens.

![AI Context status bar item](assets/20260824_212226_image.png)

## What it does

- Shows `AI Context: <mode> · <risk>` in the status bar. A `critical` mode also gets a warning background.
- Click the item, or run **AI Context: Switch Mode**, to select a mode. The list shows each mode's risk and description.
- The mode list is read from `config/workflow_settings.json` beside the script. If that file cannot be read, a built-in list is used (temporary, see Limitations).
- It runs `source <scriptPath> <mode>` in a child Bash. The script path and the mode are passed as arguments, never put into a command string. The CLI writes `~/.config/ai-workflow/active_mode.env`.
- The extension watches that file. The status bar also updates when you switch from a terminal with `workflow <mode>`.

## Requirements

- WSL 2 with Ubuntu, and VS Code connected to the same distro (Remote - WSL). Other environments are not verified yet.
- The Token Controller repository cloned in that distro, with Bash and `jq` installed.
- The extension installed in the **WSL extension host**, not only in local Windows VS Code.

## Install

1. Get `token-controller-ui-<version>.vsix` from `extensions/vscode/`, or build it there with `npx vsce package`.
2. In VS Code connected to WSL, open Extensions → **…** → **Install from VSIX…** and select the file.
3. Reload the window.

## Setting

| Setting | Default | Purpose |
|---|---|---|
| `tokenController.scriptPath` | `~/projects/token-controller/scripts/workflow.sh` | Path to `workflow.sh`. Absolute, or starting with `~/`. The file must be named `workflow.sh`. |

The setting has `machine` scope. Set it in user settings (or remote machine settings in WSL). A value in a workspace's `.vscode/settings.json` is ignored, and the extension shows a warning once. This stops a cloned repository from pointing the extension at its own script.

## Workspace Trust

The extension declares limited support for untrusted workspaces. Mode switching uses only the script path from your user settings, so it works in an untrusted workspace. The workspace cannot change which script runs or which mode ids are accepted.

## Limitations

- The built-in fallback mode list is temporary and can drift from the config. A CLI command that lists modes is planned.
- The mode list is read from the config next to `scriptPath`. A settings file chosen with `AICONTEXT_SETTINGS_FILE` in your shell is not used.
- Mode switching needs Bash. It works on Linux and WSL. On Windows without WSL it shows an error. A Windows backend is planned but not implemented.
- A terminal that already ran `workflow <mode>` keeps its old variables until you switch again there.
- The extension only selects policy. Agent compliance, external context tools, and `wx` capture are separate. See the main README.
