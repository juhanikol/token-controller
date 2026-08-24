# Token Controller Development Context
**Project Type:** Bash CLI and VS Code Extension Monorepo
**Primary Goal:** Manage AI agent context policies safely across different user projects.

## Project Architecture & Boundaries
- **Core CLI:** Written in Bash (`scripts/workflow.sh`). Uses `jq` to parse `config/workflow_settings.json`.
- **VS Code UI:** Written in TypeScript (`extensions/vscode/`). Acts as a client that triggers the CLI via `wx` and reads VS Code settings.
- **The Template Boundary:** `templates/AGENTS_base.md` is the downstream template distributed to *other* user projects via `workflow init`. **Do not edit this template** unless specifically instructed to change the behavior of downstream consumer projects.
- **State Management:** The CLI writes the active mode to `~/.config/ai-workflow/active_mode.env`. 

## Build & Test Commands
Always verify your work before declaring a task complete:
- **Bash Validation:** `bash -n scripts/workflow.sh`
- **JSON Validation:** `jq . config/workflow_settings.json > /dev/null`
- **VS Code Extension Build:** 
  ```bash
  cd extensions/vscode
  npm run compile
  npx vsce package