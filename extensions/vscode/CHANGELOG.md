# Change Log

All notable changes to the "token-controller-ui" extension will be documented in this file.

Check [Keep a Changelog](http://keepachangelog.com/) for recommendations on how to structure this file.

## [Unreleased]

### Security
- Mode switching no longer builds a `bash -c` string. The script path and mode are passed as separate arguments.
- `tokenController.scriptPath` has `machine` scope. Workspace values are ignored. The file must be named `workflow.sh`.
- Declared limited support for untrusted workspaces.

### Changed
- The mode list is read from `config/workflow_settings.json` (with a temporary built-in fallback that has all 22 current modes).
- The status bar and the mode picker show the risk level.

## [0.0.1 - Initial Release]

- Initial release
