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

## Architecture & Boundaries

- **Core CLI:** Bash scripts under `scripts/`.
- **Configuration:** `config/workflow_settings.json` is the source of profile policy.
- **Command wrapper:** `wx` is the deterministic execution boundary. Compression and measurement should happen here, not only in prompts.
- **VS Code UI:** TypeScript extension under `extensions/vscode/`. It triggers the CLI and displays/selects modes.
- **Downstream template:** `templates/AGENTS_base.md` is distributed into other projects by `workflow init`. Keep it short, stable, and tool-agnostic.
- **Integrations:** `integrations/` contains examples for Claude Code, Copilot, MCP, or optional tools. Do not present examples as installed behavior.
- **Validation:** `docs/VALIDATION_MATRIX.md` records correctness and measurement evidence.

## Development Rules

- Preserve correctness over token reduction.
- Preserve raw evidence for `security`, `db`, `release`, `migration`, and first failing `debug` runs.
- Do not destructively compress vulnerability findings, SQL/data-loss warnings, auth/crypto code, release artifacts, or first failures.
- Every compression-related change must update or add validation evidence.
- Any README claim about savings must be backed by implemented code and validation data.
- Keep generated/session files out of Git unless they are intentional fixtures.

## Build & Test Commands

Run these before declaring work complete:

```bash
bash -n scripts/workflow.sh
find scripts -name "*.sh" -print0 | xargs -0 -n1 bash -n
jq . config/workflow_settings.json >/dev/null
```

**VS Code Extension Build:**

```bash
cd extensions/vscode
npm run compile
npx vsce package
```
