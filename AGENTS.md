# Token Controller Development Context

**Project Type:** Bash CLI and VS Code Extension Monorepo
**Primary Goal:** Manage AI agent context policies safely across different user projects.

## Product Truth Boundary

This repository must distinguish between three capability levels:

1. **Policy layer:** exports active profile variables, initializes AGENTS.md rules, and tells agents how to behave.
2. **Mechanical layer:** wraps commands, captures raw output, emits compressed output, and preserves raw evidence.
3. **Proven savings layer:** records before/after measurements and shows reproducible benchmark results.

Do not claim guaranteed token savings unless the relevant behavior is implemented by deterministic code and measured in validation data.

Current claims must be worded conservatively:

- Say “manages context policy” when behavior depends on agent compliance.
- Say “wraps and compresses command output” only for implemented `wx` behavior.
- Say “measured reduction” only when raw and compressed sizes are recorded.

## Current Direction

Branch `mode_switcher_and_orchestrator`: Token Controller is a **mode switcher and orchestrator for proven external context tools** (RTK, LeanCTX, Headroom, Caveman). It is not a replacement for them. `wx` stays as the raw-capture, exit-code, measurement, and fallback layer. It is not the whole token-saving solution.

Read `docs/MODE_SWITCHER_AND_ORCHESTRATOR_PLAN.md` only when the task touches architecture, tool orchestration, `workflow doctor`, config conflicts, or the VS Code extension. Do not read `docs/DRAFTS/` unless asked.

## Architecture & Boundaries

- **Core CLI:** Bash scripts under `scripts/`.
- **Configuration:** `config/workflow_settings.json` is the source of profile policy.
- **Command wrapper:** `wx` captures raw evidence and measures. External compressors run only after raw capture.
- **VS Code UI:** TypeScript extension under `extensions/vscode/`. It is the eventual release surface. It calls the CLI. Avoid Linux-only assumptions in extension-facing code (a Windows release is possible).
- **Downstream template:** `templates/AGENTS_base.md` is distributed into other projects by `workflow init`. Keep it short and stable. Name tools only as optional. Never reference `docs/`.
- **Integrations:** `integrations/` contains examples for Claude Code, Copilot, MCP, or optional tools. Do not present examples as installed behavior.
- **Validation:** `docs/VALIDATION_MATRIX.md` records measurement evidence. It becomes required after two external tools are integrated.

## Development Rules

- Preserve correctness over token reduction.
- Preserve raw evidence for `security`, `db`, `release`, `migration`, and first failing `debug` runs.
- Do not destructively compress vulnerability findings, SQL/data-loss warnings, auth/crypto code, release artifacts, or first failures.
- Changes to `wx` capture or compression behavior must update tests (`tests/wx-wrapper.test.sh`).
- Any README claim about savings must be backed by implemented code and validation data.
- Keep generated/session files out of Git unless they are intentional fixtures.
- Keep docs short. Do not install or integrate external tools without an explicit task.

## Build & Test Commands

Run these before declaring work complete:

```bash
bash -n scripts/workflow.sh
git diff --check
```

**VS Code Extension Build:**

```bash
cd extensions/vscode
npm ci
npm run compile
npx vsce package
```
