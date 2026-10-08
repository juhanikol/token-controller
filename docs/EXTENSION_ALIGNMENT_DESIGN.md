# Extension Alignment Design

Status: design only. Nothing here is implemented.

## Goal

The VS Code extension is the release surface. The CLI is the backend. The extension must not copy CLI knowledge (mode lists, config parsing, env-file parsing). It calls one CLI entry point and shows the JSON result.

## Problems in the current extension

- **Shell string.** `exec("bash -c \"source \\\"${scriptPath}\\\" ${mode}\"")` builds a shell command from a setting.
- **Workspace can set the path.** `tokenController.scriptPath` has the default `window` scope, so a repository's `.vscode/settings.json` can set it. A cloned repo could make the extension run an arbitrary script. The manifest has no Workspace Trust restriction.
- **Mode drift.** The `MODES` array is hard-coded and misses 9 of the 22 profiles (`micro`, `docs`, `release`, `migration`, `perf`, `decisions`, `agent`, `data-analysis`, `snippet`).
- **Fragile parsing.** The profile is read from `active_mode.env` by regex. Risk is not shown.
- **Stale terminals.** See "Open decisions".

## Adapter structure

```text
extensions/vscode/src/
  extension.ts            wiring only
  backend/
    types.ts              JSON types, protocol check, runtime validation
    backend.ts            interface TokenControllerBackend
    processBackend.ts     execFile(file, argv[]), timeout, maxBuffer, no shell
    locator.ts            finds the CLI from settings; the only place for ~ and platform paths
    (later) wslBackend.ts wsl.exe -d <distro> --exec bash <cli> <args>
  env/environment.ts      remoteName, platform, WSL_DISTRO_NAME -> expected or unexpected
  state/store.ts          latest modes/status/doctor/report, debounced refresh, change events
  ui/                     statusBar.ts, modePicker.ts, output channel
```

```ts
interface TokenControllerBackend {
  version(): Promise<VersionInfo>;
  modes(): Promise<ModeInfo[]>;
  status(project?: string): Promise<StatusInfo>;
  setMode(id: string, project?: string): Promise<StatusInfo>;
  doctor(project?: string): Promise<DoctorReport>;
  report(project?: string): Promise<ReportSummary>;
}
```

Rules:
- Process calls use argv arrays only. Never `exec` with a string.
- A mode id is checked against the `modes()` result and `^[a-z0-9-]+$` before use.
- The project directory is passed as `--project <dir>`.
- Every failure becomes a UI state ("unavailable", with a reason). Nothing throws into the UI.
- Extension-facing types hold no OS paths for the CLI. A future backend translates paths (for example `wslpath`).
- Timeouts: 5 s for `version`, `modes`, `status`, `set`, `report`. 15 s for `doctor`. Output size is capped.

## CLI contract

Non-sourced entry point: `scripts/workflow-cli.sh` (**implemented**). It runs `workflow.sh` in its own Bash process and passes arguments through. Today it supports every `workflow.sh` mode and command (`status [--json]`, `<mode>`, `doctor`, `report`, `init`, ...). The dedicated `version`, `modes --json`, `set --json`, and `report --json` commands below are not built. `workflow.sh` stays sourced-only for terminals. JSON on stdout, human text on stderr. Every JSON object has `schema_version`. Exit codes: `0` ok, `1` the command found a problem, `2` usage or internal error.

| Command | Purpose | Status |
|---|---|---|
| `version --json` | `{cli_version, protocol}`. The extension refuses a CLI outside its supported `protocol` range | new |
| `modes --json` | Modes with `name`, `description`, `risk`, tool modes, effective Caveman level, `output_style`, plus `aliases` | **implemented** (`workflow modes --json`). Field names differ from this sketch (`name`, not `id`). Schema: `docs/TECHNICAL_DEBT.md` |
| `status --json` | Profile, risk, tool modes, `source`, `stale_shell` from the env file (not the caller's shell). `profile: null` if none | **implemented** as `workflow status --json` with flat field names (`rtk_mode`, not `tools.rtk`). Schema: `docs/TECHNICAL_DEBT.md`. Not yet behind a non-sourced entry point |
| `set <mode> --json` | Switch without sourcing. Returns the new status. Errors: `{error:{code,message}}` | new. Reuses the existing activation code |
| `doctor --json --project <dir>` | Tools, warnings, environment | exists |
| `report --json --project <dir>` | Commands, raw and visible bytes, reduction %, failures, last run time, or `available: false` | **implemented** (`workflow report --json [--project <dir>]`). Field names in `docs/TECHNICAL_DEBT.md`. All numbers are byte counts |

Examples:

```json
{"schema_version":1,"modes":[{"id":"code","description":"Normal implementation work.","risk":"normal","aliases":[]}]}
```

```json
{"schema_version":1,"profile":"code","risk":"normal",
 "tools":{"rtk":"noisy-success-only","leanctx":"auto","headroom":"reversible","caveman":"off"},
 "env_file":"/home/user/.config/ai-workflow/active_mode.env"}
```

Presentation stays in the extension: an id-to-codicon map with a default icon. A mode the extension does not know is still listed. A new mode in the config needs no extension release.

`status --json` reads the env file, not the calling shell. The existing `workflow status` prints shell variables. Keep both. Name the difference in the help text.

## What the user sees

- **Status bar:** `AI Context: code · normal`. A warning or error background shows when doctor severity or the environment check is bad.
- **Tooltip:** effective tool modes; tool availability (`rtk`, `lean-ctx`, `headroom`, `caveman`, `ccusage`); last report summary (phase 2); environment warning.
- **Picker:** modes from `modes()`, current one marked, extra entries "Show doctor" and "Show report". Doctor and report text go to a "Token Controller" output channel. No webview.
- **Unavailable state:** `AI Context: unavailable`. Tooltip gives the reason. Action: "Set CLI path".

### Environment check

| Situation | Result |
|---|---|
| `remoteName` is `wsl`, platform `linux`, `WSL_DISTRO_NAME` set | expected |
| Local Windows window | warn: CLI backend unavailable. Open the folder in WSL |
| SSH, dev container, Codespaces | info: unverified |
| Extension `$HOME` or distro differs from `doctor.environment` | warn: `active_mode.env` is per distro |

### Refresh

- On activation, on `active_mode.env` change (debounce about 300 ms), on workspace folder change, after `set`.
- On `.ai-context/session.jsonl` change (debounce about 1 s), phase 2.
- Doctor result is cached about 5 minutes and refreshable on demand, because doctor runs `--version` on tools.
- No polling. The watcher triggers a `status` call. The extension does not parse the env file.

## Settings and trust

- `tokenController.scriptPath` stays for compatibility, with `machine` scope.
- Add `tokenController.cliPath` (optional, `machine` scope). If only `scriptPath` is set, use `workflow-cli.sh` in the same directory.
- Add `capabilities.untrustedWorkspaces` with `supported: "limited"` and both settings in `restrictedConfigurations`.
- In an untrusted workspace, do not run a controller that is inside the workspace (implemented in `src/trust.ts`; status bar shows `restricted`). A controller outside the workspace still runs. Never use a workspace-level path (the setting is `machine` scope and workspace values are ignored at run time).

## Implementation status

Done (2026-10-07): `src/cli.ts` adapter (process backend only), `status --json`, `modes --json`, and mode switch through `workflow-cli.sh`; status bar with risk, source, and stale-shell warning; picker from `modes --json` with no fallback list. File layout differs from the sketch above: one `cli.ts` instead of `backend/`, `env/`, `state/`, `ui/`. Not done: environment check, doctor and report in the tooltip, `version`, WSL backend. See `docs/TECHNICAL_DEBT.md`.

## Minimum first implementation

1. **CLI:** `workflow-cli.sh` with `version`, `modes`, `status`, `set`. Add `description` to each mode in the config. Add `tests/cli.test.sh` for the JSON shapes and the error shape.
2. **Extension backend:** `backend/` with `processBackend.ts` and `locator.ts`. Delete the `exec` string and the hard-coded `MODES`. Unit-test with a fake CLI script.
3. **Security fix:** `machine` scope and the untrusted-workspace restriction.
4. **UI:** status bar shows profile and risk from `status()`. Add the unavailable state and the "Set CLI path" action. The picker uses `modes()`.
5. **Environment check:** one warning line in the tooltip.
6. **Doctor in the tooltip:** existing `doctor --json`. Show tool availability and the worst severity.

Validation:

```bash
bash -n scripts/workflow.sh scripts/workflow-cli.sh
jq . config/workflow_settings.json >/dev/null
bash tests/cli.test.sh
cd extensions/vscode && npm ci && npm run compile && npx vsce package
git diff --check
```

## Later

- **Report in the tooltip (phase 2):** the CLI side exists (`report --json --project`). The extension still needs the call, the display, and a `session.jsonl` watcher.
- **Windows:** `WslBackend` or a native backend. A Windows CI job.
- **Bundling the CLI in the VSIX:** removes the dependency on the repository path. It also makes the extension ship the controller. This is a release decision.
- **Doctor webview and quick fixes:** needs a separate `--fix` design. Doctor is read-only until then.
- **Caveman opt-in toggle and per-tool toggles:** depend on the policy implementation.
- **Multi-root workspaces:** one profile per folder.
- **Marketplace publishing.**

## Open decisions

1. **Stale terminals: resolved for `wx`.** `wx` now prefers `active_mode.env` over shell `AICONTEXT_*` variables (escape hatch: `AICONTEXT_USE_SHELL_STATE=true`). An old terminal that kept an old profile no longer changes `wx` behavior after a status-bar switch. Variables read directly from the shell are still stale until the terminal runs `workflow <mode>`. The AGENTS template now tells agents to treat `active_mode.env` as the source of truth, which mitigates this for compliant agents only. Open: set variables for new terminals with `environmentVariableCollection`, or a "restart terminals" prompt.
2. **`status` meaning: resolved.** `status --json` reads the env file. The text `workflow status` still prints shell variables, and now also the env-file profile with a warning when they differ.
3. **Mode descriptions in config.** Each mode needs a `description`. `workflow help` can then be generated from the config, which removes the second copy of the mode list.
4. **Protocol policy.** Decide how the extension and CLI versions are compatible. The VSIX and the controller repository are installed separately.
