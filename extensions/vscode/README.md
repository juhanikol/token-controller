# Token Controller UI

VS Code status-bar control for the [Token Controller](https://github.com/juhanikol/token-controller) CLI.

Token Controller is a mode switcher for AI context policy. You select the work mode (`code`, `debug`, `test`, `security`, …), and compatible agents and tools read that policy. This extension shows the active mode and lets you switch it. It does not compress output, run context tools, or measure tokens.

![AI Context status bar item](assets/20260824_212226_image.png)

## What it does

- Shows `AI Context: <mode>` in the status bar.
- Click the item, or run **AI Context: Switch Mode**, to select a mode.
- It runs `source <scriptPath> <mode>` in Bash. The CLI writes `~/.config/ai-workflow/active_mode.env`.
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
| `tokenController.scriptPath` | `~/projects/token-controller/scripts/workflow.sh` | Path to `workflow.sh`. `~` is expanded. |

## Limitations

- The mode list in the picker is a subset of the modes in `config/workflow_settings.json`. To use other modes, run `workflow <mode>` in a terminal.
- Mode switching depends on a Bash/WSL environment. A native Windows backend is planned but not implemented.
- The extension only selects policy. Agent compliance, external context tools, and `wx` capture are separate. See the main README.
