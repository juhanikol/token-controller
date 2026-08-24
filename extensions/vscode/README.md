# AI Context Workflow Controller for VS Code

**Switch token-saving strategies without leaving your editor.**

The **AI Context** status-bar button lets you match agent context to the work in front of you. Use compact modes for routine coding and successful test output, then switch to lossless modes when debugging failures, reviewing security findings, or changing databases. Compatible agents and context tools can use the selected policy to spend fewer tokens on noise while keeping important evidence complete.

One click updates the active workflow policy file in WSL, so you can keep agent sessions focused without remembering terminal commands.

The extension selects and publishes the policy; it does not compress context by itself. Actual token savings depend on the agents and optional context tools connected to Token Controller.

## Supported environment

> **Currently supported and tested only in VS Code connected to an Ubuntu WSL 2 distro through the WSL extension.** The current validation environment is Ubuntu 24.04 x86-64 on WSL2.

Install and run this extension in the **WSL extension host**. A local Windows-only VS Code window is not supported because the extension invokes `bash`, reads the Linux home directory, and watches `~/.config/ai-workflow/active_mode.env` inside WSL.

Requirements and assumptions:

- VS Code 1.134.0 or newer, as required by the extension manifest.
- WSL 2 with Ubuntu and a VS Code window connected to that same distro.
- A separate controller installation for each WSL distro you use; Linux home directories and active-mode files are not shared between distros.
- Bash and `jq` installed inside WSL.
- Node.js and npm inside WSL when building the VSIX from source.
- The repository cloned inside the WSL Linux filesystem at `~/tools/token-controller`. This exact path is currently required by the button implementation.
- The generated VSIX installed into the WSL extension host.

Native Windows, WSL 1, macOS, native Linux, Dev Containers, SSH remotes, Codespaces, other Linux distributions, and repositories under `/mnt/c/...` have not been verified. They may work, but they are not currently supported.

## Install

The extension currently expects the controller at:

```text
~/tools/token-controller/scripts/workflow.sh
```

Clone the repository to that location:

```bash
git clone https://github.com/juhanikol/token-controller.git ~/tools/token-controller
```

Build the VSIX:

```bash
cd ~/tools/token-controller/extensions/vscode
npm install
npx @vscode/vsce package
```

Install the generated VSIX from the command line:

```bash
code --install-extension token-controller-ui-0.0.1.vsix
```

Alternatively, open the VS Code Extensions view, choose **Views and More Actions (...) > Install from VSIX...**, and select the generated `token-controller-ui-0.0.1.vsix` file.

Reload VS Code after installation. The **AI Context: off** button should appear on the right side of the status bar.

The controller requires Bash and `jq`. On Ubuntu or WSL, install `jq` with:

```bash
sudo apt install -y jq
```

## What the button does

1. Click **AI Context: current-mode** in the status bar.
2. Select a workflow type from the menu.
3. The extension runs the matching workflow mode.
4. The selected policy is saved to `~/.config/ai-workflow/active_mode.env`.
5. The status-bar text updates and VS Code confirms the new mode.

The button also updates when the mode is changed outside VS Code with the `workflow` command.

The extension only switches context modes. It does not install optional tools, modify project files, or run `workflow init`.

## Workflow types

| Workflow type | Use it for | Context behavior |
|---|---|---|
| **Code** | Normal implementation work | Keeps target files complete and uses safe compression for supporting context. |
| **Debug** | Investigating bugs | Preserves the first failure, stderr, exit code, paths, and stack origin. |
| **Test** | Unit and integration tests | Compresses passing noise while preserving failures. |
| **Test-Full** | Full or broad test suites | Compresses repetitive successful output and keeps failure evidence. |
| **Architect** | Understanding structure and planning architecture | Builds a codebase overview before selected files are read fully. |
| **Scope** | Gathering requirements and constraints | Uses careful summaries while preserving intent and acceptance criteria. |
| **Security** | Vulnerability, secret, authentication, or compliance work | Uses raw or lossless context only. |
| **Database** | Schemas and database migrations | Preserves SQL, ordering, constraints, and data-loss warnings without lossy compression. |
| **CI/CD** | Build and deployment pipelines | Reduces install boilerplate but preserves scripts, errors, and exit codes. |
| **Rapid Prototype** | Fast experimental builds | Compresses successful build noise aggressively but preserves API errors, migration warnings, and failures. |
| **Review** | Repository or pull-request review | Focuses on interfaces, diffs, and risk areas. |
| **Raw (Lossless)** | Maximum-fidelity work | Disables compression and preserves all available evidence. |
| **Off** | Turning workflow optimizers off | Returns to normal shell output without an active optimization strategy. |

When unsure, choose **Code** for everyday work. Switch to **Debug**, **Security**, **Database**, or **Raw (Lossless)** whenever exact failure or high-risk evidence matters.

## Troubleshooting

If VS Code reports that the workflow script was not found, confirm this file exists:

```text
~/tools/token-controller/scripts/workflow.sh
```

If the displayed mode is `off` after installation, select a workflow type from the button. If it shows `error`, check that `~/.config/ai-workflow/active_mode.env` is readable.
