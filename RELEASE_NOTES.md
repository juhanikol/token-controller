# Token Controller v2.0.0

Token Controller is a mode switcher for AI coding context. You pick a work mode (`workflow code`, `workflow debug`, `workflow security`, ...). The controller publishes it to your shell, your project's `AGENTS.md`, and the VS Code status bar, and it orchestrates proven external tools (RTK, LeanCTX, Caveman) without replacing them.

## What is included

- **CLI:** `workflow <mode>` with 22 modes, plus `init`, `status`, `modes`, `doctor`, `report`, `reset-session`, `version` (JSON output for tools).
- **`wx` safety layer:** runs a command once, saves raw stdout, stderr, and the exit code first, then may shorten what is shown. Failures and protected modes stay raw.
- **RTK (optional):** after raw capture, `wx` runs `rtk pipe` for common test, build, git, and search commands. Output is shown only if it is smaller and keeps every error and warning line. Otherwise you see the raw output.
- **LeanCTX adapter (optional):** `workflow leanctx status|read|read-exact|search|tree`. It reads the active mode and policy, refuses off and protected modes, and fails closed when LeanCTX output is not exact.
- **Caveman policy (optional):** state and guards only. Off by default, never in documentation, security, database, release, migration, or debug work.
- **`workflow doctor`:** read-only checks of settings, instruction files, hooks, and tools.
- **VS Code extension** `token-controller-ui-2.0.0.vsix`: status-bar mode switcher, and a command to show the LeanCTX adapter status.
- **Install script** `scripts/install-wsl.sh`, and `scripts/show-optional-tools.sh` (prints optional install commands, installs none).
- **Tests and CI:** shell tests, byte-reduction benchmarks, and GitHub Actions on every branch push.

## Install (WSL 2 + Ubuntu)

1. Clone in WSL: `git clone https://github.com/juhanikol/token-controller.git ~/projects/token-controller`
2. Run the install script: `bash ~/projects/token-controller/scripts/install-wsl.sh` (add `--dry-run` to preview). It installs `jq`, `git`, `curl`, adds the `workflow` alias, and installs no optional tool.
3. Open a new terminal and run `workflow status`.
4. In a project: `workflow init`, then `workflow code`.
5. Optional: install the VSIX into the **WSL extension host**: open the project with `code .` from WSL, then Extensions → `…` → **Install from VSIX…**, or `code --install-extension token-controller-ui-2.0.0.vsix`. Reload the window.
6. Optional: install RTK, LeanCTX, or Caveman yourself. `bash scripts/show-optional-tools.sh --print-only` prints the commands. Token Controller works without them.

## Safety model

- Raw output is saved before anything is shortened. The exit code is never changed.
- Nonzero exits are never compressed. `raw`, `security`, `db`, `migration`, and `release` never use compression tools.
- A missing, failing, slow, or lossy tool falls back to raw output, and the reason is recorded.
- Token Controller never runs `rtk init`, `lean-ctx setup`, `wrap`, or `init`, never installs hooks, and never installs optional tools. `workflow doctor` warns about hooks that skip `wx` capture.
- A LeanCTX binary inside the project or a Windows one under WSL is refused. `read-exact` prints only output that equals the file byte for byte.
- Policy for agents (`AGENTS.md`, mode variables) depends on the agent following it. The controller cannot force compliance.

## Known limits

- Tested only on WSL 2 with Ubuntu. Native Windows, macOS, and other Linux setups are not supported yet.
- Only commands run as `wx <command>` are captured. There is no universal interception.
- Reported savings are **byte counts**, not model-token measurements. Token Controller makes no token-saving guarantee. RTK, LeanCTX, and Caveman make their own claims. Small outputs can grow.
- Some RTK filters change or shorten output in ways the guard cannot always see. Commands with known problems (`tsc`, `go test`, `ruff format`, `prettier`, `pytest --collect-only`) are not sent to RTK. See `docs/TECHNICAL_DEBT.md` (D-38).
- The real LeanCTX CLI does not return exact file reads in the tested version (3.9.19), so the adapter refuses them. The LeanCTX MCP `ctx_read` is untested (D-39).
- The VS Code extension has unit tests but was not tested in a real VS Code or WSL window (D-28).
- CI runs on Ubuntu with fake tools. A real RTK or LeanCTX is not used in CI.
- Raw logs in `.ai-context/` are kept on purpose and may contain secrets.
