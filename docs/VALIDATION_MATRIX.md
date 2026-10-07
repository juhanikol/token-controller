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

### Experiment: init template reuse

- Date: 2026-08-24
- Repository / branch: token-controller / main
- Scenario: append the canonical `AGENTS_base.md` template during `workflow init` without duplicating its managed block
- Profile: no active environment profile detected; raw/lossless script evidence was preserved
- Active env file: not present
- Tools installed: Bash 5.2.21, LeanCTX 3.9.19, standard GNU utilities
- Tools missing: ShellCheck
- Commands:
  - full raw read of `scripts/workflow.sh` and `templates/AGENTS_base.md`
  - `bash -n scripts/workflow.sh`
  - run `init` against an existing marker-free `AGENTS.md` fixture
  - compare the appended content byte-for-byte with `templates/AGENTS_base.md`
  - run `init` again and verify the existing-marker path returns without appending
  - `git diff --check`
- Raw output location: validation transcript retained in the agent session
- Compressed output location: LeanCTX validation transcript in the agent session
- Raw size / estimated tokens: workflow script is 20,208 bytes / 478 lines; template is 1,019 bytes / 14 lines
- Compressed size / estimated tokens: not measured; successful command output was compacted
- Evidence preserved: syntax exit code 0, exact template comparison exit code 0, first-init append message, and second-init duplicate-marker message
- Evidence lost or possibly hidden: none; the complete edited script and first LeanCTX allowlist refusal were retained
- Did the agent reach the same conclusion with compressed context? Yes; raw syntax and byte-for-byte comparison independently verified the behavior
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

### Experiment: deterministic conservative wx compression

- Date: 2026-10-06
- Repository / branch: token-controller / current working tree
- Scenario: compress repeated successful boilerplate while preserving raw logs and all failure or protected evidence
- Profile: `code`, followed by `security`, `db`, `release`, and `migration` protection checks
- Tools installed: Bash, jq, awk, grep, sed, standard GNU utilities
- Command(s):
  - `bash tests/wx-wrapper.test.sh`
  - fixture `wx npm install` with 12 consecutive identical pass lines
  - fixture failure with stderr, two stack frames, file paths, line numbers, and exit code 3
  - protected `wx npm audit` and noisy-success fixtures under each protected profile
- Raw output location: isolated `.ai-context/raw/` test directory removed by the fixture cleanup trap
- Compressed output location: emitted stdout captured by the test fixture
- Raw size / estimated tokens: successful fixture stdout 336 bytes; tokens not measured
- Compressed size / estimated tokens: successful visible stdout 102 bytes; tokens not measured
- Evidence preserved:
  - raw stdout and stderr files remained byte-for-byte complete
  - failure exit code remained 3
  - complete failure stderr, first error, stack trace origins, paths, line numbers, cause, and last relevant line remained visible
  - `npm audit`, `security`, `db`, `release`, and `migration` outputs remained uncompressed
  - every JSONL record contained raw and visible byte counts
- Evidence lost or possibly hidden: eleven redundant visible copies of one successful pass line; the visible marker recorded the exact omitted count
- Did the agent reach the same conclusion with compressed context? Yes; the success summary retained the pass identity and count, while all failure/protected evidence remained raw
- Pass/fail: PASS
- Recommended profile change: none

### Experiment: workflow session reporting and reset

- Date: 2026-10-06
- Repository / branch: token-controller / current working tree
- Scenario: report aggregate wrapper measurements and safely start a new session without deleting raw evidence
- Profile: `code`
- Command(s):
  - `bash tests/workflow-session.test.sh`
  - `workflow report` with no session, one command, and three commands including one failure
  - `workflow reset-session` with populated and empty sessions
- Raw output location: isolated `.ai-context/raw/` test directory removed by the fixture cleanup trap
- Compressed output location: fixture-visible stdout/stderr captured by the test
- Evidence preserved:
  - every live and archived JSONL record parsed with `jq`
  - report totals matched independently aggregated raw and visible byte counts
  - one-command report showed 6 raw and 6 visible bytes with 0.00% reduction
  - multiple-command report showed three commands and one failure
  - reset produced a valid three-record archive and a new empty session
  - raw-log file count was identical before and after reset
- Evidence lost or possibly hidden: none; reset archived metadata and did not alter raw logs
- Pass/fail: PASS
- Recommended profile change: none

### Experiment: practical `wx` context-reduction benchmark

- Date: 2026-10-06
- Repository / branch: token-controller / current working tree
- Scenario: compare normal-shell output with total `wx` emitted output while preserving authoritative raw evidence
- Profiles: `code`, `debug`, `security`, and `db`
- Command: `bash benchmarks/run-benchmark.sh`
- Optional tools active: none; the suite uses Bash, `jq`, `awk`, `grep`, `cmp`, and standard Ubuntu utilities
- Results:

| Fixture | Profile | Exit | Raw bytes | Visible command bytes | Emitted bytes | Practical reduction | Evidence |
| --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
| noisy-pass | `code` | 0 | 5430 | 110 | 219 | 95.97% | PASS |
| failing-stacktrace | `debug` | 7 | 293 | 293 | 402 | -37.20% | PASS |
| security | `security` | 0 | 407 | 407 | 516 | -26.78% | PASS |
| db | `db` | 0 | 391 | 391 | 500 | -27.88% | PASS |

- Aggregate raw bytes: 6521
- Aggregate emitted bytes: 1637
- Aggregate practical reduction: 74.90%
- Evidence preserved: command exit codes, raw stdout/stderr, failure stack paths and line numbers, security findings, and database migration warnings
- Evidence lost or possibly hidden: none in the protected fixtures; the noisy-success fixture intentionally collapses exact consecutive repetitions
- Pass/fail: PASS
- Interpretation: proves practical byte reduction for this noisy-success fixture, including wrapper overhead, but does not establish universal or tokenizer-backed token savings. Protected short outputs grow because the mandatory raw-log pointer is included.
- Coverage condition: these measurements apply only when commands run through `wx`, whether explicitly or because a configured integration requires a retry through `wx`.
- Recommended profile change: none

### Experiment: opt-in Claude Code `PreToolUse` example

- Date: 2026-10-06
- Repository / branch: token-controller / current working tree
- Scenario: require selected direct Claude Code Bash commands to be retried through `wx` without silently rewriting tool input
- Files: `integrations/claude-code/settings.example.json`, `integrations/claude-code/hooks/pretooluse-bash-policy.sh`, and `integrations/claude-code/README.md`
- Commands:
  - `bash -n integrations/claude-code/hooks/pretooluse-bash-policy.sh`
  - `jq . integrations/claude-code/settings.example.json >/dev/null`
  - pipe the documented `npm test` and `wx npm test` JSON samples into the hook
- Expected behavior: direct `npm test` returns a Claude Code deny decision with `wx npm test` guidance; an already wrapped command produces no output; both hook invocations exit 0
- Installation behavior: example only; nothing installs or enables the hook automatically
- Evidence preserved: original command text appears in the retry guidance; the hook does not emit `updatedInput` or mutate the command
- Limitation: matcher coverage is conservative and host-specific; it does not cover every nested shell form or any non-Claude host
- Pass/fail: PASS
- Recommended profile change: none

### Experiment: profile/state manager review (eight checks)

- Date: 2026-10-07
- Repository / branch: token-controller / `mode_switcher_and_orchestrator` (HEAD `0b5f823` plus an uncommitted working tree)
- Scenario: check that the repository acts as a profile/state manager (plus the `wx` wrapper as the only mechanical layer), and not as a token optimizer by itself
- Profiles: all 22 modes; `code` and `security` in detail
- Active env file: an isolated directory (`AICONTEXT_CONFIG_DIR`). The real `~/.config/ai-workflow/active_mode.env` was not changed.
- Tools installed: Bash 5.2.21, jq 1.8.2. RTK 0.42.4 and LeanCTX are installed on this machine, but nothing was installed or configured for this review, and only `tests/wx-wrapper.test.sh` calls RTK (through its fake RTK and one real-RTK check).
- Tools missing: Headroom, Caveman, MemStack were not used
- Commands:
  - `bash -n scripts/workflow.sh`, `bash -n scripts/lib/*.sh`, `jq . config/workflow_settings.json >/dev/null`
  - `source scripts/workflow.sh status` (clean environment, no mode file), `status --json`
  - `source scripts/workflow.sh code` and `security`, then `declare -p`, `env`, and a child process
  - a loop over all 22 modes comparing exported values with `jq` on the config
  - a copy of the config with a new mode and a changed risk (`AICONTEXT_SETTINGS_FILE`)
  - `scripts/workflow-cli.sh modes --json`
  - `grep` for code that reads the protection flags
  - `wc` on `templates/AGENTS_base.md`
  - README scenario table compared with the config (`comm` on the mode names, plus the values of the protected rows)
  - `bash tests/wx-wrapper.test.sh`, `bash benchmarks/run-benchmark.sh`
- Results:

| # | Check | Result | Evidence |
| ---: | --- | --- | --- |
| 1 | `workflow.sh` uses the config as the source of truth | PASS, with notes | All 22 modes export exactly the config values for risk, shell, files, index, memory, headroom, leanctx, and rtk. A new mode and a changed risk in a copied config were picked up with no script change. An unknown mode returns 1. Not config-driven: the Caveman blocked-profile list (a code copy beside the config list), the built-in alias fallback, and the usage text (debt D-16, D-18). |
| 2 | `status` works before any profile is activated | PASS | Clean environment, no mode file: text status prints `unset` for every variable and returns 0. `status --json` returns `profile: null`, `source: "unset"`, `stale_shell: false`. |
| 3 | Variables are exported to the current shell when sourced | PASS | `declare -x` for `AICONTEXT_PROFILE` and `AICONTEXT_RISK`, a child process sees `code/normal` and `security/critical`, and 29 `AICONTEXT_*` variables are exported. |
| 4 | Backward-compatible variables are exported | PASS | `RTK_HOOK_ENABLED`, `HEADROOM_COMPRESSION_STRATEGY`, `LEANCTX_ACTIVE`, `MEMSTACK_ACTIVE`, `CAVEMAN_OUTPUT`: exported, non-empty, and mapped correctly in all 22 modes (110 checks). All five are in the mode file. |
| 5 | High-risk profiles are raw/lossless by default | PASS for `critical`. Not for `high`, by design. See finding F3 and F4. | `critical`: `raw`, `security`, `migration`, `db`, `release`. All five have shell compression `off` or `off-or-lossless-only`, `rtk_mode off`, Caveman `off`, Headroom `off` or `lossless-only`. The `high` modes (12) are not raw: 11 allow shell compression or RTK on successful output (for example `debug`, `test`, `cicd`, `rapid-prototype`). |
| 6 | Target files and failures are protected from destructive compression | Failures: PASS (mechanical). Target files: policy only. See finding F2. | All 22 modes export `raw_on_fail`, `keep_raw_logs`, `preserve_*`, and `target_files_full` as `true`. Nothing in `scripts/lib`, `doctor.sh`, or the extension reads those flags or `AICONTEXT_COMPRESS_FILES`. Failures are protected because `wx` always keeps raw output on a nonzero exit (`raw-nonzero-exit`), keeps stderr verbatim, and keeps raw logs. `tests/wx-wrapper.test.sh` passes, and the benchmark keeps failure, security, and database evidence. |
| 7 | `AGENTS_base.md` is concise and free from context bloat | PASS | 19 lines, 224 words, 1,586 bytes (about 400 tokens, estimated as bytes/4, not tokenizer-measured). No references to `docs/`. Longest line is 298 characters (the Caveman bullet). It names four optional tools. |
| 8 | README scenario mappings match the config | PASS, with one finding. See finding F1. | The 22 modes in the README table and the 22 in the config are the same set. Aliases match (`plan`, `ci`). "Raw or lossless" rows (`security`, `db`, `release`) have `off-or-lossless-only` and RTK `off`. "Little or no / disable" rows (`snippet`, `micro`, `raw`, `off`) have shell compression `off`. |

- Findings and minimal patches (proposed, not applied):
  - **F1 (README, check 8).** "Policy rules in plain language" says `raw`, `security`, `db`, and `release` use raw or lossless context. The config marks `migration` as `critical` too, and `wx` treats it as protected. Patch: add `migration` to that line.
  - **F2 (check 6).** The flags `raw_on_fail`, `keep_raw_logs`, `preserve_stderr`, `preserve_exit_code`, `preserve_first_error`, `preserve_warnings`, `target_files_full`, and `compress_files` are exported state that nothing reads. `wx` hard-wires the safe behavior, so setting a flag to `false` changes nothing (the safe direction). Keeping target files full is only a request to the agent. Patch (docs only): add one sentence to the README policy rules, "These flags are state for agents and tools. `wx` always keeps raw output on failure, stderr, and raw logs." Recorded as debt D-33. Do not make `wx` read `raw_on_fail=false`, because that would weaken the safety layer.
  - **F3 (check 5).** `leanctx_mode` on critical modes is `guarded` (`security`, `release`), `diagnostic` (`db`), and `graph-read` (`migration`), and `memory_layer` and `codebase_index` are on for `security`, `db`, and `migration`. These labels are free text and LeanCTX is not integrated, so "lossless" cannot be asserted for them. Patch (decision for you): either set `leanctx_mode` to `off` for the critical modes until LeanCTX is designed, or keep the labels and accept that they are intent only. Covered by debt D-01 and D-03.
  - **F4 (check 5).** `risk: high` does not mean raw. Only `critical` is raw or lossless. Patch (docs only): define the three levels in one README sentence.
  - **F5 (check 7, optional).** Shorten the Caveman bullet in the template (298 characters) if the template should be smaller. No change is needed to pass.
  - **F6 (check 1).** The Caveman blocked list and the aliases exist outside the config. The existing tests guard the Caveman copies.
- Evidence preserved: raw stdout and stderr, exit codes, first failures, security and database output (shown by the existing `wx` tests and the benchmark, run again for this review)
- Evidence lost or possibly hidden: none in the checks. The benchmark's noisy-success fixture still collapses exact repeated lines on purpose.
- Mechanical results re-run for this review: `tests/wx-wrapper.test.sh` PASS (including the real-RTK check); `benchmarks/run-benchmark.sh` PASS (aggregate emitted bytes 1641, practical reduction 74.84%, byte reduction only).
- Pass/fail: PASS. The repository acts as a profile/state manager. The only mechanical layer is `wx`. File and mode-level protection beyond `wx` is policy for agents and tools. No check found a mode that exports a value different from the config.
- Interpretation: this review checks state and wording. It does not show token savings, agent compliance, or any behavior of LeanCTX, Headroom, or Caveman.
- Recommended profile change: none. Apply F1 and F4 (docs) first. Decide F3. F2 is recorded as debt D-33.
- Update (2026-10-07): F1, F3, and F4 were applied (README wording and `leanctx_mode` `off` in critical modes). F2 stays open as debt D-33. After the change: `bash -n`, `jq`, `workflow-cli.sh modes --json`, and `tests/workflow-session.test.sh` passed.

### Experiment: RTK pipe filters, recorded fixtures

- Date: 2026-10-07
- Repository / branch: token-controller / `mode_switcher_and_orchestrator` (working tree)
- Scenario: replay recorded command output through `wx` and check what `rtk pipe` does with it, for the six enabled filters
- Profile: `code`
- Tools: RTK 0.42.4 (real, through a spy script), a fake RTK for the deterministic checks. Recordings from go 1.27.0, pytest 9.1.1, TypeScript 7.0.2, vitest 5.0.3. The `cargo-test` recordings are hand-written (cargo is not installed)
- Command: `bash tests/wx-wrapper.test.sh` (fixtures in `tests/fixtures/rtk`)
- Results: 25 recorded runs. 7 failing runs stayed raw and never reached RTK. 3 runs had empty stdout, so RTK was not called (`go build`, quiet `tsc`). 15 runs reached RTK. With real RTK: 11 accepted (smaller, guard passed), 4 fell back to raw with `evidence-guard`.

| Run | Raw bytes | RTK output bytes | Real-RTK result |
| --- | ---: | ---: | --- |
| cargo-test, 40 tests | 1308 | 39 | accepted |
| pytest, 32 tests | 2874 | 17 | accepted |
| tsc `--extendedDiagnostics` | 322 | 32 | accepted |
| vitest default / verbose / with warnings | 218 / 4192 / 271 | 31 / 31 / 31 | accepted |
| cargo test `--nocapture`, go test `-v`, go test `-json`, pytest with warnings | 514 / 2074 / 17859 / 3445 | 38 / 23 / 32 / 17 | raw shown (`evidence-guard`) |

- Evidence preserved: for every run, `stdout.raw`, `stderr.raw`, and `exit_code.raw` equal the recording and are on disk before RTK starts. stderr is shown as recorded. Exit codes are unchanged. Failing output is shown raw.
- Evidence lost or possibly hidden: 5 accepted runs lose information or state something false, and the guard does not catch it: plain `go test` ("Go test: No tests found"), `go test -bench` (benchmark numbers), `pytest --collect-only` ("No tests collected"), `tsc --listFiles` and `tsc --showConfig` ("TypeScript compilation completed"). The `go-build` filter never receives input.
- Pass/fail: PASS for the `wx` behavior checks. FINDING for three filters (D-38).
- Interpretation: sizes are bytes of RTK output on 25 recordings, not token counts and not a general saving. The `cargo-test` recordings are less reliable than the others. RTK versions other than 0.42.4 are not pinned.
- Recommended profile change: none yet. Recommended config change: narrow `go test` to `go test -json`, and set `go build` and `tsc` to `never` (D-38).

### Experiment: RTK pipe benchmark (bytes)

- Date: 2026-10-07
- Repository / branch: token-controller / `mode_switcher_and_orchestrator` (working tree)
- Command: `bash benchmarks/run-rtk-benchmark.sh` (14 rows per RTK section: 9 recorded runs in profile `code`, and one of them again in each of the five protected profiles; recordings from `tests/fixtures/rtk`)
- Tools: fake RTK (pipeline check) and real RTK 0.42.4 through a spy script. The `cargo-test` recordings are hand-written
- Result: PASS. Fake RTK: every row matched its expected outcome. Real RTK: every row matched the pinned 0.42.4 outcome. Protected profiles (`raw`, `security`, `db`, `migration`, `release`): raw output, no compressor, 0 RTK calls, in both sections.
- Real RTK, `code` profile, bytes of stdout plus stderr (stderr is shown unchanged and counted):

| Run | Raw | Visible | Reduction | `output_policy` |
| --- | ---: | ---: | ---: | --- |
| `cargo test` | 1794 | 525 | 70.74% | `compress-rtk-v1` |
| `pytest -v` (no warnings) | 2874 | 17 | 99.41% | `compress-rtk-v1` |
| `tsc --extendedDiagnostics` | 322 | 32 | 90.06% | `compress-rtk-v1` |
| `vitest --reporter=verbose` | 4192 | 31 | 99.26% | `compress-rtk-v1` |
| `go test -v` (warning lines) | 2074 | 2074 | 0% | `raw-rtk-fallback`, `evidence-guard` |
| `pytest -v` (warnings) | 3445 | 3445 | 0% | `raw-rtk-fallback`, `evidence-guard` |
| `cargo test -- --nocapture` (warning lines) | 1000 | 1000 | 0% | `raw-rtk-fallback`, `evidence-guard` |
| `go build -v` | 16 | 16 | 0% | `raw-empty-or-binary-output` (stdout is empty, RTK not called) |

- Of the 7 runs that reached RTK, 4 were accepted and 3 fell back to raw. Together: 15701 bytes shown as 7124 (54.63%). The 4 accepted runs alone: 9182 bytes shown as 605 (93.41%).
- Built-in exact-repeat reducer, for reference: `npm install` fixture 336 bytes to 102 (69.64%). On the raw stdout of the 15 successful RTK recordings it gave 0.00% for 13 and a small increase for 2 (`cargo-test/pass-noisy` -3.82%, `tsc/showconfig` -0.19%). `wx` does not apply it to those commands.
- Evidence preserved: yes in all rows (exit code, raw files, stderr as recorded, guard lines, and markers for warnings and failures). For accepted RTK output the guard check passes by construction.
- Interpretation: byte counts on 14 rows (9 recorded runs), one RTK version. Not token counts, not a general saving. Runs with warning lines got no reduction. The five informational runs in D-38 are not in this benchmark.
- Pass/fail: PASS

### Experiment: RTK fixture matrix, all 18 pipe filters (bytes)

- Date: 2026-10-07
- Repository / branch: token-controller / `mode_switcher_and_orchestrator` (working tree)
- Command: `bash benchmarks/run-rtk-benchmark.sh`. 59 fixtures in `tests/fixtures/rtk/MATRIX` (group A cargo-test, pytest, go-test, go-build, tsc, vitest; B mypy, ruff-check, ruff-format, prettier; C grep, rg, find, fd, git-log, git-status, git-diff; D log), plus 22 protected-profile rows (first success fixture of every filter in `security`, `pytest` in the other four protected profiles)
- Tools: fake RTK (pipeline check) and real RTK 0.42.4 through a spy script. Recorded with real tools: go, pytest, tsc, vitest, git, grep, find. Hand-written: cargo-test, mypy, ruff-check, ruff-format, prettier, rg, fd, log (see `tests/fixtures/rtk/PROVENANCE.txt`)
- Result: PASS, with 12 pinned known losses. Raw capture, exit codes, and stderr held in all 81 rows per section. Protected profiles: raw output, no RTK call. Every outcome matched the pin in the matrix.
- Real RTK, `code` profile, 59 rows: 24 RTK outputs shown, 10 raw after `rtk-not-smaller`, 5 after `evidence-guard`, 1 after `rtk-empty-output` (`git diff --stat`), 14 failing runs raw (RTK not called), 5 empty stdout (RTK not called).
- Bytes (stdout plus stderr): the 24 shown RTK outputs 28675 to 5914. Of those, 12 keep every marked evidence text (13794 to 2822) and 12 do not. All 40 runs that reached RTK: 68216 to 45455.
- Known losses (shown RTK output, evidence guard accepted it, marked text missing): `pytest --collect-only`, `go test -bench`, plain `go test`, `tsc --listFiles`, `--extendedDiagnostics`, `--showConfig`, `ruff format` (changed count), `prettier --write` (changed file names), `find` and `fd` on 30 directories (RTK prints "+10 more dirs", 40 files not shown), `git log` and `git log --oneline` (RTK drops commits).
- Not lost in this matrix: all `grep`/`rg` runs fell back (RTK output was larger), `git diff` kept every changed line (it drops context and headers), `git status` kept every path, `log` kept the ERROR and WARN lines, and Traceback runs fell back through the guard.
- Evidence preserved: raw files, stderr, and exit codes: yes in every row. Marked evidence text in shown output: no in the 12 rows above.
- Interpretation: byte counts on 59 fixtures, one RTK version, 8 filters with hand-written input. Not token counts, not a general saving. Small outputs often grow under RTK and fall back to raw.
- Pass/fail: PASS (the 12 losses are pinned in the matrix, so a change of RTK output fails the run; see D-38)

### Experiment: RTK matrix after fixes (bytes)

- Date: 2026-10-07
- Command: `bash benchmarks/run-rtk-benchmark.sh` (42 `code` rows from `tests/fixtures/rtk/MATRIX`, 18 protected-profile rows), real RTK 0.42.4 through a spy script, fake RTK for the pipeline
- Changes since the previous matrix entry: guard rejects RTK omission markers; `tsc`, `go test`, `ruff format`, `prettier`, `pytest --collect-only` are `recognized-only` (14 pipe filters left)
- Result: PASS. Known losses in shown output: 0 (was 12). Real RTK, `code` rows: 11 RTK outputs shown (13728 to 2783 bytes), 7 evidence-guard fallbacks, 10 not-smaller fallbacks, 1 empty RTK output, 9 failing runs and 4 empty-stdout runs raw without an RTK call. Protected profiles raw, no RTK call.
- Interpretation: byte counts, one RTK version, hand-written input for 7 filters. The guard only sees omission markers, errors, and warnings. No token saving is claimed.
- Pass/fail: PASS
