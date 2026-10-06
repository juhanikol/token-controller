# Mode Switcher and Orchestrator Plan

Branch: `mode_switcher_and_orchestrator` (baseline: `main` after the `deterministic_wrapper` merge).
Status: design direction. This is not an operational instruction file. Agents read it only for architecture, orchestration, `workflow doctor`, or extension work.

## Why the direction changes

Token Controller started as a mode switcher for existing context tools. The `deterministic_wrapper` branch built a custom compression path inside `wx`. That path is correct and measured, but it reimplements a small part of what proven tools already do (RTK, LeanCTX, Headroom). Competing with those tools is not the product.

The product is: **the user states intent with `workflow <mode>`; Token Controller activates the right tool behavior for that intent, keeps raw evidence safe, and reports what happened.**

## Target architecture

1. **Mode switcher.** `workflow <mode>` stays the central user action. Modes express intent: `code`, `debug`, `test`, `cicd`, `docs`, `security`, `db`, `release`, and later `micro`.
2. **Tool orchestrator.** Each mode maps to settings for installed external tools. Missing tools degrade to "off" with a warning, never to an error.
3. **`wx` safety and measurement layer.** See below.
4. **Output style policy.** The default user-facing style is short, controlled technical English inspired by ASD-STE100. This is a prompt policy, not deterministic behavior. Do not claim strict ASD-STE100 compliance. Planned setting: `"default_output_style": "ste-inspired"`.
5. **Configuration audit (`workflow doctor`).** This is read-only. It inspects user and workspace settings and reports conflicts. Design it before any installer writes to more locations.
6. **VS Code extension.** This is the release surface. The CLI stays the backend.

## Why `wx` stays, and why it is not the whole solution

`wx` gives guarantees that external tools do not give:

- raw stdout/stderr is captured before any processing,
- the exit code is preserved exactly,
- protected modes and commands always stay raw,
- raw and visible bytes are recorded per run.

These properties make `wx` the correct place for evidence and measurement. If an external tool (for example RTK) compresses output, it must run after `wx` captures the raw output, and `wx` records which tool and version ran. The built-in exact-repeat reducer stays as a fallback when no external tool is installed. It is not the main saving mechanism.

## External tools

Primary candidates. Each one is optional and detected, never required:

| Tool | Expected role | Not for |
|---|---|---|
| RTK | First-class shell/build/test/install log compression | Failing runs, `security`, `db`, `release`, `migration` |
| LeanCTX | Context-aware file/symbol reads, search, shell, memory, MCP | Raw-evidence modes unless lossless |
| Headroom | Proxy/MCP compression, recoverable context, observability | Modes that need byte-exact payloads |
| Caveman | Terse agent output; possibly shrink/proxy | Docs, precise instructions, release text, security findings, user-facing explanations |

MemStack is still exported as `MEMSTACK_ACTIVE`. Decide whether to keep it or replace it with a LeanCTX/memory setting.

Research candidates. Do not install or integrate them yet:

| Candidate | Possible fit | Current state fit |
|---|---|---|
| ASD-STE100-inspired output | Default output style without Caveman | Fits now: policy text and one config key only |
| ccusage | Real token/cost data for `workflow doctor`, `workflow report`, and extension status | Good near-term fit. Read-only and Claude Code only. Gives real token counts, which `wx` bytes cannot give |
| Aider repo map | Concept for `architect`/`scope` repository-map modes | Concept only. Aider is a full agent, not a component. Check if LeanCTX already covers this |
| alexgreensh/token-optimizer | Claude context hygiene | Research only |
| Mibayy/token-savior | MCP navigation and memory | Research only. Its benchmark claims need independent validation. Overlaps LeanCTX and Headroom |

## `micro` mode

For a single snippet or a very small one-file change, context tools can cost more than they save in setup, tool calls, and indirection. `micro` means: no context tool, no compression, read the target directly. The existing `snippet` profile already does this. Rename `snippet` or make it an alias. Do not overbuild.

## Why configuration conflicts matter

Agent behavior comes from many layers, and these layers can disagree:

- shell: `~/.bashrc`, `~/.profile`, `PATH`
- active state: `~/.config/ai-workflow/active_mode.env`
- Claude: `~/.claude/CLAUDE.md`, `~/.claude/settings.json`, `.claude/settings.json`
- Copilot: `~/.copilot/instructions/`, `.github/copilot-instructions.md`
- VS Code: user settings, WSL/server machine settings, workspace settings
- MCP configuration, and the project `AGENTS.md`

`workflow setup` already appends the same instruction to several of these locations. Each external tool also installs its own hooks and instructions (for example `rtk init -g`). This can cause duplicate blocks, contradictory rules, or a mode that one host sees and another host does not (for example Windows VS Code compared with the WSL extension host). `workflow doctor` must report these conflicts before Token Controller writes to more locations. More detail: `docs/USER_SETTINGS_AND_AGENT_CONFIG.md`.

## Why the extension is the release surface

Most users switch modes from the editor, not from a sourced shell function. The extension must show: active mode, detected tools, doctor warnings, and the session report. A Windows release is possible later. For this reason:

- the extension calls the CLI through one adapter (today: `bash -c source ...`; later: possibly `wsl.exe` or a native backend),
- the extension reads mode lists from the CLI or the config, not from a hard-coded copy,
- paths and tool detection are not Linux-only in extension-facing code.

GNU-specific shell code (`stat -c`, `date +%3N`) can stay in the CLI backend.

## Documents to revise

| File | Issue |
|---|---|
| `.github/copilot-instructions.md` | Says the project "implements compression itself". Requires validation-matrix updates for every profile change |
| `README.md` | Positioned as "policy controller plus `wx`". No orchestrator direction. Too long. Duplicated as the extension README |
| `extensions/vscode/README.md` | Identical copy of root README. Needs a short, extension-specific README |
| `docs/WX_DETERMINISTIC_WRAPPER_DESIGN.md` | "Must not depend on RTK" and "RTK experimental". Reframe RTK as a post-capture compressor. `measurements.jsonl` differs from the implemented `session.jsonl` |
| `scripts/check-tools.sh` | Says "wx intercepts RTK" (false). No Caveman check |
| `scripts/install-optional-tools.sh` | No Caveman. MemStack status unclear |
| `config/workflow_settings.json` | No `micro`, `caveman_output`, `default_output_style`, or tool-fallback fields. `rtk_mode` values are policy labels, not RTK options |
| `extensions/vscode/src/extension.ts` | Hard-coded partial mode list. Linux-only `exec` with string-built shell command |

## Work packages

1. Fix the contradictions in the table above (docs and help text only).
2. Add `micro` (alias or rename of `snippet`) and `default_output_style`.
3. Design `workflow doctor` (read-only): tool detection, config locations, duplicate/conflict report.
4. Define a mode → tool mapping schema in `workflow_settings.json` that uses real tool options.
5. Integrate RTK post-capture in `wx`. Record the tool name and version in `session.jsonl`.
6. Reintroduce Caveman with explicit safe/unsafe modes.
7. Integrate a second tool (LeanCTX or Headroom). Then the validation matrix becomes a required workflow.
8. Make the extension show the same behavior as the CLI (modes from config, doctor status, report).
9. Add install/config docs per tool only when that tool is integrated.

## Design principles

- Prefer proven external tools over custom replacements.
- Raw evidence is authoritative. Capture first, then compress.
- Never compress `security`, `db`, `release`, `migration`, or first failing `debug` evidence.
- Keep `AGENTS.md` short and operational. Do not load planning docs in normal sessions.
- `docs/VALIDATION_MATRIX.md` is required only after two external tools are integrated and measurable. Changes to `wx` behavior still need test evidence.

## Non-goals for this branch

- No full rewrite. No removal of `wx`.
- No forced installation of external tools.
- No large documentation set.
- The downstream template `templates/AGENTS_base.md` must not reference this plan.

## Detailed draft

`docs/DRAFTS/DRAFT_MODE_SWITCHER_AND_ORCHESTRATOR_PLAN.md` may contain more detail. It is not directive. Read it only when asked. Confirm its content with the user before acting on it.
