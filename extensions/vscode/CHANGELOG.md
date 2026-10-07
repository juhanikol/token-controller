# Change Log

All notable changes to the "token-controller-ui" extension will be documented in this file.

Check [Keep a Changelog](http://keepachangelog.com/) for recommendations on how to structure this file.

## [Unreleased]

Planned version: 2.0.0 (set in `package.json`, not released or published). The last release is 1.1.0 (git tag `v1.1.0`).

### Added
- Command **Token Controller: Show LeanCTX Status**: runs `workflow leanctx status --json` and shows the adapter status in the output channel. No LeanCTX read, search, or tree action.

### Breaking
- The extension needs a controller that has `scripts/workflow-cli.sh` with `status --json` and `modes --json` (JSON `schema_version` 1). An older controller shows "unavailable".
- `tokenController.scriptPath` must be an absolute path (or start with `~/`) to a file named `workflow.sh`, with `workflow-cli.sh` in the same folder. It is read from user or machine settings only.

### Security
- Mode switching no longer builds a `bash -c` string. The script path and mode are passed as separate arguments.
- `tokenController.scriptPath` has `machine` scope. Workspace values are ignored. The file must be named `workflow.sh`.
- Declared limited support for untrusted workspaces. In an untrusted workspace the extension does not run a controller that is inside the workspace (status bar: `restricted`). A controller outside the workspace still runs. The check follows symlinks.
- Added tests for the Workspace Trust path check, the manifest scope, and a source scan that forbids shell strings.

### Changed
- All CLI access goes through one adapter (`src/cli.ts`). It calls `workflow-cli.sh status --json`, `modes --json`, and `<mode>` with an argument array.
- The extension no longer parses `active_mode.env` and no longer has a mode list. The picker uses `modes --json`. If that fails, it shows an error and does not use a fallback list.
- The status bar shows the active mode, risk, and a warning when the environment of VS Code has a stale `AICONTEXT_PROFILE`. The tooltip shows source and tool modes.
- Added an output channel, "Token Controller".
- Added a `restricted` status bar state for an untrusted workspace that contains the controller.
- Added a short manual smoke test to the README.

### Packaging
- The built `.vsix` is no longer tracked in git (`*.vsix` is ignored). Build it with `npx vsce package`. The 1.1.0 file stays in git history and under the `v1.1.0` tag.

## [0.0.1 - Initial Release]

- Initial release
