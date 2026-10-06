# Change Log

All notable changes to the "token-controller-ui" extension will be documented in this file.

Check [Keep a Changelog](http://keepachangelog.com/) for recommendations on how to structure this file.

## [Unreleased]

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

## [0.0.1 - Initial Release]

- Initial release
