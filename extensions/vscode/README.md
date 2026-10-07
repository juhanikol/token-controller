# Token Controller UI

VS Code status-bar control for the [Token Controller](https://github.com/juhanikol/token-controller) CLI.

Token Controller is a mode switcher for AI context policy. You select the work mode (`code`, `debug`, `test`, `security`, …), and compatible agents and tools read that policy. This extension shows the active mode and lets you switch it. It does not compress output, run context tools, or measure tokens.

![AI Context status bar item](assets/20260824_212226_image.png)

## What it does

- Shows the active mode in the status bar, for example `AI Context: debug · high`.
- Click the item, or run **AI Context: Switch Mode**, to select a mode. The list shows each mode's risk and description.
- The status, the mode list, and the mode switch all come from the Token Controller CLI (`scripts/workflow-cli.sh`). The extension does not read the config file or `active_mode.env` itself, and it keeps no mode list of its own.

### CLI calls

| Purpose | Call |
|---|---|
| Show the active mode | `workflow-cli.sh status --json` |
| Fill the mode picker | `workflow-cli.sh modes --json` |
| Switch mode | `workflow-cli.sh <mode>` |

The extension runs `bash <path>/workflow-cli.sh <arguments>` without a shell command string. The path and every argument are passed as separate arguments. A mode id must match `^[a-z0-9][a-z0-9-]*$` and be in the list the CLI just returned. The extension accepts only `schema_version` 1 from the CLI.

### Status bar

| Display | Meaning |
|---|---|
| `AI Context: code · normal` | Active mode and risk, from `active_mode.env` |
| `AI Context: none` | No mode is set |
| `… (shell)` | No mode file. The profile comes from shell variables |
| `… $(warning)` and a warning background | `stale_shell`: the environment of VS Code has a different `AICONTEXT_PROFILE`. The tooltip explains. `wx` is not affected, because it uses the mode file |
| warning background | The mode has `critical` risk |
| `$(error) AI Context: unavailable` | The CLI could not be run. The tooltip gives the reason |

The tooltip also shows the source and the tool modes (rtk, leanctx, headroom, caveman). The status refreshes when `active_mode.env` changes (so also when you run `workflow <mode>` in a terminal) and when the setting changes. The extension watches the file but does not parse it.

### Mode picker

The picker calls `modes --json` every time it opens, marks the current mode, and shows risk and description. If that call fails, the extension shows the error with **Open Settings** and **Show Log**. It does **not** fall back to a built-in list, because a stale list could offer modes the controller does not have.

The "stale shell" warning only covers the environment of VS Code. Terminals that are already open can have their own old `AICONTEXT_*` variables. The extension cannot check them.

## Requirements

- WSL 2 with Ubuntu, and VS Code connected to the same distro (Remote - WSL). Other environments are not verified yet.
- The Token Controller repository cloned in that distro, with Bash and `jq` installed.
- The extension installed in the **WSL extension host**, not only in local Windows VS Code.

## Install

1. Build it: `cd extensions/vscode && npm ci && npx vsce package`. This writes `token-controller-ui-<version>.vsix` there. No built VSIX is kept in git. Older ones are under the git tags (for example `v1.1.0`).
2. In VS Code connected to WSL, open Extensions → **…** → **Install from VSIX…** and select the file.
3. Reload the window.

## Setting

| Setting | Default | Purpose |
|---|---|---|
| `tokenController.scriptPath` | `~/projects/token-controller/scripts/workflow.sh` | Path to `workflow.sh`. Absolute, or starting with `~/`. The file must be named `workflow.sh`. |

## Security model

The extension runs a shell script (the Token Controller CLI) with your user rights. These rules decide which script that is and when it may run.

**How the script is found**
1. `tokenController.scriptPath` is read from **user or machine settings only**. The setting has `machine` scope, so VS Code does not accept it from a workspace's `.vscode/settings.json`.
2. At run time the extension also inspects the setting and **ignores the workspace and workspace-folder values**. It shows one warning if it finds one.
3. The path must be absolute (or start with `~/`), name an existing `workflow.sh`, and have `workflow-cli.sh` in the same folder. If the setting is not set, the default `~/projects/token-controller/scripts/workflow.sh` is used.

**Workspace Trust**
- The extension declares limited support for untrusted workspaces, and `tokenController.scriptPath` is a restricted setting.
- In an **untrusted workspace**, the extension does **not** run the controller if the script is inside an open workspace folder. It checks the path as given and its real path, so symlinks in either direction do not hide it. The status bar shows `AI Context: restricted`, and clicking it shows a warning with **Manage Workspace Trust**.
- A controller **outside** the workspace still runs in an untrusted workspace, because the workspace cannot change it.
- When you trust the workspace, the extension refreshes and runs the controller.
- Example: opening the controller's own clone (the default path) as an untrusted workspace shows `restricted` until you trust it.

**How processes are started**
- Every call is `execFile('bash', [cliPath, ...args])`. There is no shell command string, no `exec`, and no `bash -c`.
- The CLI path and each argument are separate arguments. A mode id must match `^[a-z0-9][a-z0-9-]*$` and be in the list the CLI just returned.
- Tests scan the source for `exec(`, `spawn`, `shell:` options, and `-c` strings, and check the manifest scope.

**Remaining risk**
- The script you configure runs with your user rights, and so does every file it loads from its own folder. Keep the controller somewhere you trust. The extension does not verify the script's content.
- In a **trusted** workspace the controller may be inside the workspace and runs. Trusting a workspace means trusting that code.
- A user-level setting is trusted. Anything that can write your user settings can change the script.
- The CLI inherits the environment of the VS Code extension host.
- Workspace Trust and `inspect()` behavior were tested with unit tests of the path logic only. They were not tested in a real VS Code or WSL window.

## Manual smoke test

Do this in a WSL window with `jq` installed, and note any step that fails in `docs/TECHNICAL_DEBT.md` (D-28).

1. **Install:** `npx vsce package`, then Extensions → **…** → **Install from VSIX…**, then reload. The extension is listed under "WSL: <distro>", not only locally.
2. **Status bar:** it shows `AI Context: <mode> · <risk>`. The mode equals `scripts/workflow-cli.sh status --json | jq -r .profile`.
3. **Picker:** click the item. The names equal `scripts/workflow-cli.sh modes --json | jq -r '.modes[].name'`. Risk and description are shown, and the current mode is marked.
4. **Switch:** pick `micro`. `grep AICONTEXT_PROFILE ~/.config/ai-workflow/active_mode.env` shows `micro`, and the status bar shows `micro · normal`.
5. **Stale shell:** close all windows for this distro, then run `AICONTEXT_PROFILE=code code .` while the mode is `micro`. The status bar shows a warning icon and background, and the tooltip names `code`.
6. **Untrusted workspace:** open the controller's own clone in Restricted Mode. The status bar shows `restricted`, and clicking it offers **Manage Workspace Trust**. In another folder in Restricted Mode, status and switching still work.
7. **Missing path:** set `tokenController.scriptPath` in user settings to `~/nope/workflow.sh`. The status bar shows `unavailable` with the reason, and the picker shows an error with **Open Settings**. The same setting in a workspace `.vscode/settings.json` is ignored with one warning.

## Limitations

- The extension needs a controller that has `workflow-cli.sh` with `status --json` and `modes --json`, and answers with `schema_version` 1. An older controller shows "unavailable".
- The CLI needs `jq`. Without it, the status shows "unavailable" with the CLI message.
- The CLI call needs Bash. It works on Linux and WSL. On Windows without WSL it shows an error. A Windows backend is planned but not implemented.
- The environment of the extension host decides what the CLI sees. A settings file chosen with `AICONTEXT_SETTINGS_FILE` in your terminal is used only if VS Code was started with it.
- A terminal that already ran `workflow <mode>` keeps its old variables until you switch again there.
- The extension only selects policy. Agent compliance, external context tools, and `wx` capture are separate. See the main README.
