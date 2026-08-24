# Validation Matrix - Context Profiles and Tool Effects

Use this file to collect real observations. Do not treat tool claims as proof. Measure your own repository and record what evidence was preserved or hidden.

## Decision rule

A profile is acceptable only if it preserves the evidence needed to make the correct engineering decision.

Token savings are useful only after this condition is satisfied:

```text
correctness >= reproducibility >= debuggability >= token savings
```

## Baseline validation without optional tools

| Date | Scenario | Profile | Command | Expected | Result | Notes |
|---|---|---|---|---|---|---|
| 2026-06-18 | shell syntax | n/a | `bash -n scripts/workflow.sh` | no syntax errors | PASS | validated in sandbox |
| 2026-06-18 | JSON syntax | n/a | `jq . config/workflow_settings.json >/dev/null` | valid JSON | PASS | validated in sandbox |
| 2026-06-18 | default status | status | `source scripts/workflow.sh status` | status prints even before profile activation | PASS | validated in sandbox |
| 2026-06-18 | coding profile | code | `source scripts/workflow.sh code && source scripts/workflow.sh status` | code exports safe defaults | PASS | validated in sandbox |
| 2026-06-18 | security profile | security | `source scripts/workflow.sh security && source scripts/workflow.sh status` | raw/lossless policy visible | PASS | validated in sandbox |
| 2026-08-24 | global agent setup | setup | isolated `source scripts/workflow.sh setup` twice | standard VS Code path updated; instructions occur exactly once | PASS | existing settings and permissions preserved |
| 2026-08-24 | project agent initialization | init | isolated `source scripts/workflow.sh init` twice | template creation or managed merge occurs exactly once | PASS | custom content and permissions preserved |

## Tool availability validation

| Date | Tool | Command | Installed? | Version | Notes |
|---|---|---|---|---|---|
| TODO | jq | `jq --version` | TODO | TODO | required |
| TODO | RTK | `rtk --version` | TODO | TODO | optional |
| TODO | Headroom | `headroom --help` | TODO | TODO | optional |
| TODO | LeanCTX | `lean-ctx doctor` | TODO | TODO | optional |
| TODO | MemStack | `python -m memstack_skill_loader --help` | TODO | TODO | optional / Claude Code focused |
| TODO | Caveman | `caveman --help` or agent trigger | TODO | TODO | optional output brevity |

## Scenario validation template

Copy this block for each experiment.

```markdown
### Experiment: <short name>

- Date:
- Repository / branch:
- Scenario:
- Profile:
- Active env file:
- Tools installed:
- Tools missing:
- Command(s):
- Raw output location:
- Compressed output location:
- Raw size / estimated tokens:
- Compressed size / estimated tokens:
- Evidence preserved:
  - command:
  - working directory:
  - exit code:
  - stderr:
  - first error:
  - last relevant lines:
  - file paths:
  - line numbers:
  - versions/environment:
- Evidence lost or possibly hidden:
- Did the agent reach the same conclusion with compressed context?
- Pass/fail:
- Recommended profile change:
```

## Scenario expectations

| Scenario | Profile | Compression allowed | Must preserve | Fail condition |
|---|---|---|---|---|
| Requirements | scope | low | exact user constraints, open questions, acceptance criteria | compression changes meaning |
| Architecture | architect | medium | interfaces, module boundaries, data flow, ADR rationale | agent misses critical dependency |
| Domain models/types | decisions | low-medium | schemas, type definitions, invariants | agent invents or drops field/constraint |
| Coding | code | medium | edited file, nearby tests, compile errors | agent edits based on incomplete target file |
| Rapid prototyping | rapid-prototype | high for successful builds only | backend API integration errors, stderr, exit code, database migration warnings, raw logs | an API error or migration warning is compressed away |
| Snippet review | snippet | none/low | complete snippet/method/file | any omitted line affects judgment |
| Agent governance | agent | low | AGENTS.md and dynamic task-state separation | agent mutates stable instructions unnecessarily |
| Unit tests | test | medium after baseline | failing test name, assertion, stack trace origin, exit code | failure reason hidden |
| Full app tests | test-full | high only after baseline | first failure and final summary | full failure only exists in compressed form |
| Debugging | debug | low-medium | first failure raw, stderr, paths, line numbers | repeated compression hides root cause |
| CI/CD | cicd | medium | YAML/scripts/env/exit/failing lines | hidden env mismatch or runner detail |
| Documentation | docs | medium for inputs, none for final | accurate project behavior and final prose | final docs become terse or inaccurate |
| Security | security | none/lossless | CVEs, secrets, auth, crypto, license findings | any finding dropped or normalized |
| Database migration | db | none/lossless | SQL, constraints, migration order, data-loss warnings | warning hidden |
| Performance | perf | low | numbers, units, sample size, environment | metric rounded/removed |
| Release | release | none/lossless | version, changelog, artifact names, hashes, signing output | artifact or version mismatch hidden |

## Example validation notes

### Example: repeated passing unit tests

- Scenario: full app test routine
- Profile: `test-full`
- Observation: 4,000 lines of repeated pass output were compressed to a test summary.
- Evidence preserved: command, exit code, number of tests, failing tests = none.
- Evidence lost: individual pass lines.
- Decision: acceptable if raw log is retained.

### Example: first failing unit test

- Scenario: bug fixing
- Profile: `debug`
- Observation: first failing assertion shown raw.
- Evidence preserved: stderr, exit code, failing test name, assertion, stack trace origin, line numbers.
- Decision: acceptable.

### Example: vulnerability scan

- Scenario: security review
- Profile: `security`
- Observation: scan output kept raw/lossless.
- Evidence preserved: package names, versions, CVE IDs, severity, remediation advice.
- Decision: required. Do not use destructive compression.

### Experiment: rapid prototype profile activation

- Date: 2026-08-24
- Repository / branch: token-controller / main
- Scenario: aggressive compression for successful prototype builds with guarded backend API and database migration evidence
- Profile: `rapid-prototype`
- Active env file: isolated temporary `active_mode.env`, removed after validation
- Tools installed: jq 1.8.2, RTK 0.42.4, Headroom 0.25.0
- Tools missing: LeanCTX, MemStack, Caveman
- Commands:
  - `jq . config/workflow_settings.json >/dev/null`
  - `source scripts/workflow.sh rapid-prototype`
  - `source scripts/workflow.sh status`
- Raw output location: isolated temporary validation file, removed after measuring
- Compressed output location: not applicable; no build output was compressed during profile activation validation
- Raw size / estimated tokens: 998 bytes / 18 lines
- Compressed size / estimated tokens: not applicable
- Evidence preserved:
  - command: profile activation and status output retained
  - working directory: repository root
  - exit code: JSON parse, activation, and status all returned 0
  - stderr: `AICONTEXT_PRESERVE_STDERR=true`
  - first error: `AICONTEXT_PRESERVE_FIRST_ERROR=true`
  - last relevant lines: full status and active environment cache inspected
  - file paths: backend API targets and migrations selected for full file context
  - line numbers: not applicable; no error was generated
  - versions/environment: jq and optional tool availability recorded above
  - warnings: `AICONTEXT_PRESERVE_WARNINGS=true`
  - raw logs: `AICONTEXT_KEEP_RAW_LOGS=true`
- Evidence lost or possibly hidden: none during activation; end-to-end build compression remains unmeasured
- Did the agent reach the same conclusion with compressed context? Not applicable; compression tools were not invoked
- Pass/fail: PASS for JSON validity, profile activation, exported safeguards, and cache persistence
- Recommended profile change: none; run a representative successful build, failing backend integration, and warning-producing migration before approving end-to-end compression behavior

### Experiment: global VS Code and agent instruction setup

- Date: 2026-08-24
- Repository / branch: token-controller / main
- Scenario: idempotent global instruction setup for Copilot, Gemini Code Assist, and Claude Code
- Profile: `setup` command; no context profile activated
- Active env file: isolated temporary config directory; no profile cache required
- Tools installed: Bash, jq 1.8.2, GNU coreutils
- Tools missing: ShellCheck; Gemini and Claude installations were simulated with isolated extension manifests
- Commands:
  - `bash -n scripts/workflow.sh`
  - isolated `source scripts/workflow.sh setup` twice with an explicit settings path
  - isolated `source scripts/workflow.sh setup` with only a VS Code Server Machine settings path
  - isolated `source scripts/workflow.sh setup` against JSONC/invalid settings
- Raw output location: isolated temporary validation logs, removed after inspection
- Compressed output location: not applicable; setup output was not compressed
- Raw size / estimated tokens: approximately 1.5 KB / 350 tokens across the validation transcript
- Compressed size / estimated tokens: not applicable
- Evidence preserved:
  - command: all setup and assertion commands recorded above
  - working directory: repository root
  - exit code: syntax and valid setup cases returned 0; unsupported JSONC case returned 1
  - stderr: exact JSON-object error and comments/trailing-commas guidance retained
  - first error: `Error: VS Code settings must be a JSON object`
  - last relevant lines: exact-once counts and helper-function leak check retained
  - file paths: explicit settings override, VS Code Server Machine settings, Copilot instructions, and Claude instructions verified
  - line numbers: not applicable; no shell syntax error occurred
  - versions/environment: jq 1.8.2; isolated Linux home
  - existing state: unrelated setting and original `0640` file mode preserved
- Evidence lost or possibly hidden: temporary test files were removed after their contents, hashes, counts, and permissions were checked
- Did the agent reach the same conclusion with compressed context? Not applicable; raw validation evidence was used
- Pass/fail: PASS for syntax, path detection, preservation, exact-once idempotency, Gemini/Claude routing, and safe invalid-input failure
- Recommended profile change: none; consider a dedicated JSONC-preserving editor if comments and trailing commas must be supported automatically

### Experiment: project AGENTS.md initialization

- Date: 2026-08-24
- Repository / branch: token-controller / main
- Scenario: distribute the controller's agent rules into new and existing projects without replacing custom instructions
- Profile: `init` command; no context profile activated
- Active env file: isolated temporary config directory; no profile cache required
- Tools installed: Bash, GNU coreutils, grep
- Tools missing: ShellCheck
- Commands:
  - `bash -n scripts/workflow.sh`
  - compare `templates/AGENTS_base.md` with the former root `AGENTS.md`
  - isolated `source scripts/workflow.sh init` twice in an empty directory
  - isolated `source scripts/workflow.sh init` twice with an existing custom `AGENTS.md`
  - isolated initialization when the active-mode instruction already exists
  - isolated initialization with an incomplete managed block and with an `AGENTS.md` symlink
- Raw output location: isolated temporary validation logs, removed after inspection
- Compressed output location: not applicable; initialization output was not compressed
- Raw size / estimated tokens: approximately 1.7 KB / 400 tokens across functional and safety transcripts; fail-closed transcript was 258 bytes / 4 lines
- Compressed size / estimated tokens: not applicable
- Evidence preserved:
  - command: all initialization and assertion commands recorded above
  - working directory: isolated projects, including paths containing spaces
  - exit code: syntax and valid initialization cases returned 0; malformed-marker and symlink cases returned 1
  - stderr: exact incomplete-block and symlink refusal messages retained
  - first error: `Error: incomplete AI workflow managed block`
  - last relevant lines: content hashes, marker counts, active-mode reference counts, and file modes retained
  - file paths: template, new project, custom project, malformed project, and symlink target verified
  - line numbers: not applicable; no shell syntax error occurred
  - versions/environment: isolated Linux home with repository script sourced by absolute path
  - existing state: custom instruction occurred once and original `0640` mode was preserved
- Evidence lost or possibly hidden: temporary test files were removed after their contents, hashes, markers, reference counts, and permissions were checked
- Did the agent reach the same conclusion with compressed context? Not applicable; raw validation evidence was used
- Pass/fail: PASS for template relocation, creation, smart merge, idempotency, existing-reference detection, permission preservation, malformed-block refusal, and symlink refusal
- Recommended profile change: none

### Experiment: beginner-focused local injection README

- Date: 2026-08-24
- Repository / branch: token-controller / main
- Scenario: rewrite onboarding around one central clone, project-local `workflow init`, and task-specific mode selection
- Profile: docs policy applied manually; no active environment profile was detected
- Active env file: no active values available during the documentation rewrite
- Tools installed: Bash, jq 1.8.2, ripgrep, GNU coreutils
- Tools missing: Markdownlint CLI
- Commands:
  - full read of `README.md`, `scripts/workflow.sh` usage, and configured mode names
  - `bash -n scripts/workflow.sh`
  - `jq . config/workflow_settings.json >/dev/null`
  - validate every backticked `workflow` mode against `config/workflow_settings.json`
  - count Markdown fences and scenario rows
  - scan for removed complex installer commands
  - `git diff --check`
- Raw output location: validation transcript retained in the agent session
- Compressed output location: not applicable; final documentation was written as normal prose
- Raw size / estimated tokens: source README before rewrite was 436 lines
- Compressed size / estimated tokens: rewritten README is 9,080 bytes / 255 lines / 1,329 words
- Evidence preserved:
  - command: clone, alias, `workflow init`, mode selection, status, setup, and validation examples retained
  - working directory: examples explicitly change into the target project before initialization
  - exit code: Bash syntax, JSON syntax, mode validation, and diff checks returned 0
  - stderr: not applicable; no validation error occurred
  - first error: none
  - last relevant lines: development checks and validation-matrix location retained
  - file paths: controller alias path, local `AGENTS.md`, template, and active-mode cache documented
  - line numbers: README line count recorded above
  - versions/environment: jq 1.8.2; WSL/Ubuntu-focused instructions
  - scenario coverage: 21 scenario rows retained, including `rapid-prototype`, `raw`, and `off`
- Evidence lost or possibly hidden: detailed third-party RTK, Headroom, LeanCTX, MemStack, Caveman, Python, and Node installation recipes were intentionally removed; optional-tool purpose and Python virtual-environment paths remain
- Did the agent reach the same conclusion with compressed context? Yes; the shorter README still explains local rule injection, active mode selection, fidelity rules, and optional tooling boundaries
- Pass/fail: PASS
- Recommended profile change: none

### Experiment: missing-tool installation hints

- Date: 2026-08-24
- Repository / branch: token-controller / main
- Scenario: provide a brief installation hint for every command reported missing by `scripts/check-tools.sh`
- Profile: no active environment profile was detected; raw script and output evidence was preserved
- Active env file: isolated temporary home with no active cache
- Tools installed: Bash 5.2.21, jq 1.8.2, LeanCTX 3.9.19, standard GNU utilities
- Tools missing: ShellCheck; all checker targets were intentionally hidden in the isolated missing-tool simulation
- Commands:
  - full read of `scripts/check-tools.sh` and the matching optional installer guidance
  - `bash -n scripts/check-tools.sh`
  - run with `PATH=/nonexistent` under an isolated home to exercise every missing branch
  - assert the exact LeanCTX and Claude hint lines occur once
  - assert no `MISSING` line lacks explanatory text
  - normal environment run to verify installed-tool paths and versions remain unchanged
  - `git diff --check`
- Raw output location: isolated temporary logs, removed after exact line checks
- Compressed output location: LeanCTX inspection transcript in the agent session
- Raw size / estimated tokens: checker is 1,575 bytes / 37 lines; complete missing and normal outputs were retained
- Compressed size / estimated tokens: not measured; successful inspection output only was compacted
- Evidence preserved:
  - command: syntax, isolated missing run, normal run, and exact-line assertions recorded above
  - working directory: repository root
  - exit code: syntax, missing simulation, normal run, and diff checks returned 0
  - stderr: none
  - first error: none
  - last relevant lines: active-cache fallback and exact hint counts retained
  - file paths: `scripts/check-tools.sh` and `scripts/install-optional-tools.sh`
  - line numbers: checker target file fully inspected after editing
  - versions/environment: installed tool paths and versions retained in normal output
  - requested hints: LeanCTX and Claude messages each occurred exactly once
- Evidence lost or possibly hidden: none; temporary logs were removed only after full output and assertions were inspected
- Did the agent reach the same conclusion with compressed context? Yes; raw execution independently verified every missing branch
- Pass/fail: PASS
- Recommended profile change: none

### Experiment: optional tool installation guidance refresh

- Date: 2026-08-24
- Repository / branch: token-controller / main
- Scenario: improve printed LeanCTX, Claude Code, and Caveman installation guidance without automatically installing optional tools
- Profile: no active environment profile was detected; raw/lossless script evidence was preserved
- Active env file: no active values available during validation
- Tools installed: Bash 5.2.21, jq 1.8.2, LeanCTX 3.9.19
- Tools missing: ShellCheck
- Commands:
  - full read of `scripts/install-optional-tools.sh`
  - official-source verification for LeanCTX, Claude Code, and Caveman lifecycle claims
  - `lean-ctx -c "bash -n scripts/install-optional-tools.sh"`
  - raw fallback `bash -n scripts/install-optional-tools.sh`
  - verify each new command and warning is inside the printed `TOOLS` heredoc
  - verify the Claude Code npm command occurs exactly once
  - `git diff --check`
- Raw output location: validation transcript retained in the agent session
- Compressed output location: LeanCTX shell-wrapper transcript in the agent session
- Raw size / estimated tokens: installer is 2,835 bytes / 85 lines; exact first LeanCTX policy failure retained
- Compressed size / estimated tokens: LeanCTX returned the full edited target and compact search locations; no edited-file content was intentionally dropped
- Evidence preserved:
  - command: Cargo and universal LeanCTX methods, optional LSP commands, Claude npm command, and Caveman warning inspected literally
  - working directory: repository root
  - exit code: raw Bash syntax and diff checks returned 0; LeanCTX-wrapped Bash syntax command was blocked by its allowlist
  - stderr: complete LeanCTX allowlist refusal retained before fallback
  - first error: `[BLOCKED — DO NOT RETRY] 'bash' is not in the shell allowlist.`
  - last relevant lines: printed-block boundaries and exact command counts retained
  - file paths: `scripts/install-optional-tools.sh`
  - line numbers: all new commands verified inside the printed `TOOLS` heredoc
  - versions/environment: Bash, jq, and LeanCTX versions recorded above
  - safety: optional install commands remain printed for review rather than executed
- Evidence lost or possibly hidden: none; ShellCheck was unavailable
- Did the agent reach the same conclusion with compressed context? Yes; raw syntax validation independently confirmed the result after LeanCTX policy blocked Bash execution
- Pass/fail: PASS
- Recommended profile change: none

### Experiment: Caveman default-usage phase-out

- Date: 2026-08-24
- Repository / branch: token-controller / main
- Scenario: retain Caveman compatibility fields while disabling Caveman output in every mode profile
- Profile: raw
- Active env file: `~/.config/ai-workflow/active_mode.env`
- Tools installed: Bash 5.2.21, jq 1.8.2
- Tools missing: not applicable
- Commands:
  - full read of `config/workflow_settings.json`
  - search for every `caveman_output` value
  - `jq . config/workflow_settings.json >/dev/null`
  - assert no mode has `caveman_output` set to true or any value other than false
  - `bash -n scripts/workflow.sh`
  - activate representative profiles in an isolated home and verify `AICONTEXT_CAVEMAN_OUTPUT=false`
  - `git diff --check`
- Raw output location: validation transcript retained in the agent session
- Compressed output location: not used because the active profile required raw/lossless evidence
- Raw size / estimated tokens: configuration is 8,336 bytes / 292 lines; all 21 activation results were retained
- Compressed size / estimated tokens: not applicable
- Evidence preserved:
  - command: JSON parsing, exhaustive mode audit, representative activation, shell syntax, and diff checks
  - working directory: repository root
  - exit code: recorded for each validation command
  - stderr: preserved in full
  - first error: preserved in full if encountered
  - last relevant lines: Caveman value counts and representative exported values
  - file paths: `config/workflow_settings.json` and `scripts/workflow.sh`
  - line numbers: compatibility note and Caveman settings located after editing
  - versions/environment: raw profile, Bash, and jq versions recorded above
- Evidence lost or possibly hidden: none
- Did the agent reach the same conclusion with compressed context? Not tested; the raw profile prohibits lossy compression
- Pass/fail: PASS
- Recommended profile change: disable Caveman output in every mode while retaining compatibility variables

### Experiment: VS Code extension button documentation

- Date: 2026-08-24
- Repository / branch: token-controller / main
- Scenario: replace copied controller documentation with focused VS Code extension installation and status-bar button guidance
- Profile: no active environment profile detected
- Active env file: not present
- Tools installed: Node.js, npm, TypeScript, ESLint, esbuild, LeanCTX
- Tools missing: not applicable
- Commands:
  - full read of `extensions/vscode/README.md`, `package.json`, `.gitignore`, and `src/extension.ts`
  - `npm run package`
  - compare the 13 source mode definitions with the 13 documented workflow rows
  - verify Markdown fence count is even
  - `git diff --check`
- Raw output location: validation transcript retained in the agent session
- Compressed output location: LeanCTX inspection transcript in the agent session
- Raw size / estimated tokens: rewritten extension README is 3,828 bytes / 83 lines; source and documentation each contain 13 UI modes
- Compressed size / estimated tokens: not measured
- Evidence preserved:
  - command: extension type check, lint, production build, mode counts, Markdown structure, and diff check
  - working directory: repository root and `extensions/vscode`
  - exit code: build and final validation checks returned 0
  - stderr: first validation-command quoting error retained exactly before the corrected check
  - first error: `/bin/bash: -c: line 1: unexpected EOF while looking for matching \`\``
  - last relevant lines: source mode count 13, README mode-row count 13, fence count 12
  - file paths: `extensions/vscode/README.md`, `package.json`, `.gitignore`, and `src/extension.ts`
  - line numbers: all workflow rows reported at README lines 59-71
  - versions/environment: local installed Node/npm toolchain and VS Code extension package configuration
- Evidence lost or possibly hidden: none relevant; dependency-directory listings were compacted during initial discovery
- Did the agent reach the same conclusion with compressed context? Yes; direct build and exact count checks independently verified the documentation
- Pass/fail: PASS
- Recommended profile change: none

### Experiment: WSL2 environment support documentation

- Date: 2026-08-24
- Repository / branch: token-controller / main
- Scenario: state the currently supported environment and runtime assumptions at the start of both READMEs
- Profile: no active environment profile detected
- Active env file: not present
- Tools installed: Ubuntu 24.04 on WSL2 x86-64, Bash 5.2.21, jq 1.8.2, Node.js/npm extension toolchain
- Tools missing: not applicable
- Commands:
  - inspect the local kernel, Ubuntu release, Bash version, and jq version
  - verify extension home, script, active-mode, and Bash execution paths against `src/extension.ts`
  - verify the VS Code engine requirement against `package.json`
  - `bash -n scripts/workflow.sh`
  - `jq . config/workflow_settings.json >/dev/null`
  - `npm run package` in `extensions/vscode`
  - verify both supported-environment headings appear at line 3 and both notices at line 5
  - verify Markdown fence counts are even
  - `git diff --check`
- Raw output location: validation transcript retained in the agent session
- Compressed output location: LeanCTX build transcript in the agent session
- Raw size / estimated tokens: root README is 13,437 bytes / 304 lines; extension README is 5,146 bytes / 101 lines
- Compressed size / estimated tokens: not measured
- Evidence preserved:
  - command: environment detection, source-path checks, syntax, JSON, extension build, Markdown structure, and diff checks
  - working directory: repository root and `extensions/vscode`
  - exit code: raw validation and extension build returned 0
  - stderr: complete LeanCTX allowlist refusal retained before raw inspection fallback
  - first error: `[BLOCKED — DO NOT RETRY] 'bash' is not in the shell allowlist.`
  - last relevant lines: README sizes and supported-environment notice locations
  - file paths: `README.md`, `extensions/vscode/README.md`, `extensions/vscode/src/extension.ts`, and `extensions/vscode/package.json`
  - line numbers: both environment headings at line 3 and support notices at line 5
  - versions/environment: WSL2 kernel 6.6.87.2, Ubuntu 24.04.4 LTS x86-64, Bash 5.2.21, jq 1.8.2, VS Code engine `^1.134.0`
- Evidence lost or possibly hidden: none; LeanCTX rejected the initial pipeline before execution, then raw read-only commands preserved the full evidence
- Did the agent reach the same conclusion with compressed context? Yes; the extension build used LeanCTX and the environment/source checks were independently verified raw
- Pass/fail: PASS
- Recommended profile change: none

### Experiment: token-saving value proposition

- Date: 2026-08-24
- Repository / branch: token-controller / main
- Scenario: explain the token-saving purpose of Token Controller at the start of both READMEs
- Profile: no active environment profile detected
- Active env file: not present
- Tools installed: Bash 5.2.21, jq 1.8.2, LeanCTX 3.9.19, standard GNU utilities
- Tools missing: Markdownlint CLI
- Commands:
  - inspect both README openings and all existing token/compression claims
  - add benefit-led copy above each supported-environment section
  - verify the main pitch and extension pitch both appear at line 3
  - verify both supported-environment sections remain near the start at line 11
  - search for unsupported percentage or guaranteed-savings claims
  - verify Markdown fence counts are even
  - `bash -n scripts/workflow.sh`
  - `jq . config/workflow_settings.json >/dev/null`
  - `git diff --check`
- Raw output location: validation transcript retained in the agent session
- Compressed output location: LeanCTX README inspection transcript in the agent session
- Raw size / estimated tokens: root README is 14,265 bytes / 310 lines; extension README is 5,774 bytes / 107 lines
- Compressed size / estimated tokens: not measured
- Evidence preserved:
  - command: exact pitch locations, environment heading locations, claim scan, Markdown structure, syntax, JSON, and diff checks
  - working directory: repository root
  - exit code: syntax, JSON, Markdown structure, claim scan, and diff checks returned 0 or the expected no-match status
  - stderr: none
  - first error: none
  - last relevant lines: root fence count 40, extension fence count 12, and no unsupported quantitative saving claim
  - file paths: `README.md` and `extensions/vscode/README.md`
  - line numbers: both pitches at line 3; both supported-environment headings at line 11
  - versions/environment: WSL2 Ubuntu 24.04 x86-64, Bash 5.2.21, jq 1.8.2
- Evidence lost or possibly hidden: none; the copy explicitly states that actual savings depend on connected agents and optional context tools
- Did the agent reach the same conclusion with compressed context? Yes; exact raw checks independently verified placement and claim boundaries
- Pass/fail: PASS
- Recommended profile change: none
