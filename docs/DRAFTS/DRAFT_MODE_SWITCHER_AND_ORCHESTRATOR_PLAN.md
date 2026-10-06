# Revised PLAN

Token Controller should primarily be a safe mode switcher and configuration orchestrator for proven context-saving tools. wx should remain as a local safety, measurement, fallback, and integration layer — not as the main replacement for RTK, LeanCTX, Headroom, or Caveman.

So the target architecture should be hybrid:

workflow mode
   -> checks environment/settings conflicts
   -> exports coherent profile
   -> configures/activates proven tools
   -> uses wx for local capture, measurement, fallback, and protected raw evidence

## Revised tool Roles

| Tool / method | Correct role |
|---|---|
| **RTK** | Should return as a first-class dependency for shell/log token saving. Its installation docs explicitly warn not to use plain `cargo install rtk` because of a crate-name collision; use the GitHub install path or install script. ([RTK][1]) |
| **LeanCTX** | Strong fit for context-aware reads, MCP tools, shell hooks, `ctx_read`, `ctx_search`, `ctx_shell`, session/context tools, and native-tool rewrite/deny policies. ([LeanCTX][2]) |
| **Headroom** | Strong fit for proxy/MCP compression, retrieval, observability, and provider/prompt-cache-aware compression profiles. ([Headroom][3]) |
| **Caveman** | Should return for output-token control and possibly shrink/proxy tooling. It has skill, CLI, shrink, proxy, stats, and setup commands; docs also warn that short/simple prompts can become net-negative because the skill itself adds input tokens. ([Caveman docs][4]) |
| **`wx`** | Local deterministic wrapper: raw capture, byte measurement, safe fallback, protected evidence, optional post-capture delegation to RTK/Caveman/LeanCTX. |
| **AGENTS.md / instructions** | Policy guidance only. Useful, but not enforcement. VS Code supports AGENTS/custom instruction discovery, but those can conflict if duplicated. ([Visual Studio Code][5]) |
| **Hooks** | Enforcement layer. Claude Code hooks and Copilot hooks can gate tool calls and force `wx`/RTK/LeanCTX usage. ([Claude][6]) |

[1]: https://www.rtk-ai.app/docs/getting-started/installation/ "Installation | RTK"

[2]: https://leanctx.com/docs/configuration/ "Configuration, without guesswork. — LeanCTX Docs"

[3]: https://docs.headroomlabs.ai/docs/mcp "MCP Tools | Headroom"

[4]: https://docs.caveman.so/docs/quickstart "Quickstart · Caveman docs"

[5]: https://code.visualstudio.com/docs/agent-customization/custom-instructions "Use custom instructions in VS Code"

[6]: https://claude.com/resources/articles/how-to-configure-hooks"Claude Code power user customization: How to configure hooks | Claude by Anthropic"

## Corrected architecture direction

The old mode-switcher idea was good. The project should return to it, but keep the new deterministic wrapper as a guardrail.

### Suggested layers:

Layer 0: environment audit
- WSL distro
- shell
- PATH
- VS Code local vs WSL server settings
- Copilot / Claude / Gemini user-level rules
- MCP config
- existing RTK / LeanCTX / Headroom / Caveman configs
- conflicting AGENTS.md / CLAUDE.md / copilot-instructions.md

Layer 1: mode switcher
- workflow code/debug/test/cicd/docs/security/etc.
- exports coherent AICONTEXT_* state

Layer 2: tool orchestration
- RTK for shell/log output
- LeanCTX for code/context reads and shell hooks
- Headroom for proxy/MCP compression and retrieval
- Caveman for output brevity or shrink/proxy mode

Layer 3: wx fallback and measurement
- captures raw logs
- measures raw vs visible bytes
- preserves protected evidence
- delegates to external tools only after raw capture

Layer 4: IDE/agent enforcement
- Claude hooks / Copilot hooks
- VS Code extension status and warnings

## User settings must become priority

Installation should first inspect and warn, not blindly write.

**Add a command like:**

- workflow doctor
- workflow doctor --json
- workflow doctor --fix

**It should check:**

~/.bashrc
~/.profile
~/.config/ai-workflow/active_mode.env
~/.claude/CLAUDE.md
~/.claude/settings.json
~/.copilot/instructions/
~/.config/Code/User/settings.json
~/.vscode-server/data/Machine/settings.json
project/AGENTS.md
project/.github/copilot-instructions.md
project/.claude/settings.json
MCP config files
PATH entries
WSL distro / hostname / home path

**The rule should be:**

One managed policy block per target, with conflict detection before mutation.

Do not scatter long duplicate policy text everywhere. Prefer short pointers:

Read ~/.config/ai-workflow/active_mode.env.
For this repo, follow AGENTS.md.
Use wx/RTK/LeanCTX according to the active profile.

## Caveman should return

Bring Caveman back, but with a strong safety policy.

Caveman has two relevant roles:
1. Output brevity / style control through skill/rules.
2. Input/tool-output shrinking through CLI/proxy/shrink tooling. Docs describe caveman setup --install, caveman shrink, stats, and recovery-oriented tooling.

### Add modes:

"caveman_mode": "off | brief | ultra | shrink-only | emergency"

But block Caveman automatically for:

- documentation writing
- README editing
- legal/security/db/release work
- precise step-by-step instructions
- user asks "detailed", "exact", "carefully", "full explanation"
- final project documentation
- job applications / human-facing prose

This should be handled by Token Controller policy, not trusted only to Caveman. Current Caveman docs show modes/config and default activation controls, but I would still implement your own profile-level gate because your project knows the engineering scenario.

## Small task / no-tool mode

For tiny changes, tools may cost more tokens than they save. Caveman docs explicitly note the skill can be net-negative for one-line questions because the skill itself consumes input tokens.

### Add:

workflow micro
workflow snippet
workflow off

### Policy:

micro/snippet:
- no RTK unless command output is expected to be huge
- no Caveman
- no Headroom proxy
- no LeanCTX unless agent needs symbol lookup
- read only target file/snippet
- no repo-wide indexing

### Heuristic:

Use micro when:
- expected edit <= 1 file
- expected changed lines <= 30
- no tests/build/install needed
- no architecture/security/db/release impact
- user asks a narrow question about one method/snippet/file

If uncertain, use code, not micro.

## Revised repo actions

1. Restore external-tool-first architecture. 
   - workflow_settings.json should not only describe policies; it should map modes to RTK/LeanCTX/Headroom/Caveman activation.
2. Keep wx, but change its role. wx should become:
   - raw capture
   - measurement
   - safety fallback
   - optional dispatcher to RTK/Caveman/LeanCTX depending on mode
3. Add workflow doctor. This is now the most important missing feature.
4. Add workflow install-tools carefully. It should:
   - install base deps
   - show exact commands
   - verify versions
   - avoid overwriting user config
   - snapshot before mutation
5. Add tool-specific integration docs. Create:
   docs/integrations/RTK.md
   docs/integrations/LEANCTX.md
   docs/integrations/HEADROOM.md
   docs/integrations/CAVEMAN.md
   docs/USER_SETTINGS_AND_CONFLICTS.md
6. Update extension. The extension should show:
   - active profile
   - enabled external tools
   - detected conflicts
   - workflow doctor result
   - last workflow report
   - warning if VS Code is not using the WSL environment expected by the controller

## Documents that likely contradict the new direction

These should be revised or removed after branching:

| File | Problem |
|---|---|
| `.github/copilot-instructions.md` | Says the repo “does not implement compression itself,” which is no longer true after `wx`; it also preserves old backward-compatible variables as central.  |
| `templates/AGENTS_base.md` | Says `wx` directly intercepts commands only for RTK, but current `wx` has built-in deterministic capture/compression.  |
| `extensions/vscode/README.md` | Still overclaims “stops AI coding agents” and “guaranteed fidelity,” unlike the root README.  |
| `docs/OLD/ARCHITECTURE.md` | Old plan is useful historical material, but conflicts with current/next plan if treated as active architecture.  |
| `docs/WX_DETERMINISTIC_WRAPPER_DESIGN.md` | Useful, but must be reframed: `wx` is a safety/measurement/fallback layer, not the whole architecture.  |
| `README.md` | Mostly good and honest, but should later be updated from “policy + wx wrapper” toward “mode switcher/orchestrator + wx safety layer.”  |
| `config/workflow_settings.json` | Already has external-tool concepts, but they are currently more like hints than real orchestration settings.  |
| `docs/VALIDATION_MATRIX.md` | Keep it, but do not make it central yet. Use it later when at least two external tools are integrated. |