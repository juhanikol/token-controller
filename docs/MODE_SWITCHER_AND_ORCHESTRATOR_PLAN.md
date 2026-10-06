# Mode Switcher and Orchestrator Plan

## Purpose

Token Controller should return to its original product idea: a controlled mode switcher and orchestrator for already available context-management tools.

The project should not try to replace proven tools with its own wrapper. The deterministic `wx` wrapper remains useful, but its role is safety, measurement, fallback, and raw evidence preservation. The main purpose is to help the user activate the right context-management behavior for the current engineering task.

## Target Direction

The intended solution is a hybrid architecture:

1. **Mode switcher**
   - User selects a work mode such as `code`, `debug`, `test`, `cicd`, `docs`, `security`, `db`, `release`, or `micro`.
   - The selected mode defines the desired token/context policy.

2. **Tool orchestrator**
   - The controller should prefer proven external tools when available.
   - RTK should be treated as a first-class shell/log compression tool.
   - LeanCTX should be considered for context-aware code reading, shell tooling, search, memory, and MCP workflows.
   - Headroom should be considered for proxy/MCP compression, recoverability, and observability.
   - Caveman should return as an output-control and possible shrink/proxy tool, but only under safe conditions.

3. **Deterministic `wx` safety layer**
   - `wx` captures raw stdout/stderr and exit codes before any compression.
   - `wx` records raw and visible byte counts.
   - `wx` preserves protected evidence for high-risk modes.
   - `wx` may delegate to external tools later, but raw capture remains authoritative.

4. **Environment and configuration audit**
   - Installation must check user-level settings, VS Code settings, WSL environment, shell configuration, agent instruction files, and existing tool configs.
   - The controller should warn about duplicated or conflicting policies before writing changes.
   - Global behavior should be managed, but not by scattering large duplicated instructions into many locations.

5. **Extension as final release surface**
   - The VS Code extension is ultimately the user-facing release target.
   - The CLI remains the reliable backend.
   - The extension should eventually show active mode, tool status, warnings, and session/report information.
   - A future Windows version should be considered when designing paths, settings, and tool detection.

## Current Baseline

The `deterministic_wrapper` branch is merged to `main` before starting this architecture work.

That branch provides:
- deterministic `wx` command capture,
- raw stdout/stderr preservation,
- exit-code preservation,
- conservative exact-repeat compression,
- session metadata,
- tests,
- benchmark fixtures.

This baseline is useful and should not be discarded.

## New Branch

Created the next branch from updated `main`:

```bash
git checkout -b mode_switcher_and_orchestrator
```

## Design Principles

- Prefer proven external context-management tools over custom replacements.
- Keep `wx` as the local safety and measurement layer.
- Preserve raw evidence before compression.
- Avoid compression for security, database, release, migration, and first-failing debug evidence.
- Add a `micro` or equivalent mode for very small tasks where tools may cost more than they save.
- Do not make agents read large planning documents during normal coding.
- Keep `AGENTS.md` short and operational.
- Keep long explanations in docs, but use them only when implementing that specific area.
- Do not use `docs/VALIDATION_MATRIX.md` as a required workflow until at least two external tools are integrated.

## Expected Work Packages

1. Audit existing documentation and remove or revise contradictions.
2. Add a concise architecture summary for the new hybrid direction.
3. Add `workflow doctor` design and later implementation.
4. Rework `workflow_settings.json` so modes can express external-tool orchestration.
5. Reintroduce RTK as a first-class optional or recommended dependency.
6. Reintroduce Caveman with clear safe/unsafe usage rules.
7. Add detection of user-level and workspace-level instruction conflicts.
8. Update the VS Code extension so it reflects the same behavior as the CLI.
9. Add external tool installation and configuration docs only when each integration is implemented or actively designed.

## Non-Goals for the First Orchestrator Branch

- Do not rewrite the whole project.
- Do not make the documentation a large book.
- Do not force all external tools to be installed immediately.
- Do not remove `wx`.
- Do not make `AGENTS.md` reference this full plan.
- Do not require validation matrix updates for every early design-only change.

## MORE DETAILED DRAFT 

Only for agent: More detailed draft may contain useful information not stated here but it is not directive. If that is read when unsure about the task in hand, always prompt if its information is correct. Do not read unless asked.

@docs/DRAFTS/DRAFT_MODE_SWITCHER_AND_ORCHESTRATOR_PLAN.md