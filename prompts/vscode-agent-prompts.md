# VS Code Agent Prompts

Use these prompts one at a time. Keep the agent focused on one task and one profile. Do not ask the agent to install optional tools unless you are explicitly testing installation.

## 1. Repository assessment prompt

```text
You are reviewing a WSL/Ubuntu shell profile controller for AI context and token-management workflows.

Goal: validate whether this repository correctly acts as a profile/state manager, not as a token optimizer itself.

Read AGENTS.md, README.md, scripts/workflow.sh, and config/workflow_settings.json.

Check:
1. Does workflow.sh use config/workflow_settings.json as the source of truth?
2. Does status work before any profile is activated?
3. Are profile variables exported to the current shell when the script is sourced?
4. Are backward-compatible variables still exported?
5. Are high-risk profiles raw/lossless by default?
6. Are target files and failures protected from destructive compression?
7. Is AGENTS.md concise enough and free from unnecessary context bloat?
8. Are README scenario mappings consistent with config/workflow_settings.json?

Do not install RTK, Headroom, LeanCTX, MemStack, or Caveman.
Do not rewrite the whole project. Propose a minimal patch first.
Run only safe local validation commands such as:
- bash -n scripts/workflow.sh
- jq . config/workflow_settings.json >/dev/null
- source scripts/workflow.sh status
- source scripts/workflow.sh code
- source scripts/workflow.sh security

After validation, update docs/VALIDATION_MATRIX.md with the results.
```

## 2. Implement missing scenario profile prompt

```text
Add a new workflow profile to this AI context controller.

Scenario to add: <describe scenario>
Risk level: <low|normal|high|critical>
Raw fidelity requirements: <list what must never be destructively compressed>
Compression allowed for: <list safe/noisy evidence types>

Rules:
- Update config/workflow_settings.json first.
- Update README.md scenario matrix.
- Update docs/VALIDATION_MATRIX.md expectations.
- Update scripts/workflow.sh usage text only if a new command name is added.
- Keep AGENTS.md stable unless a new general rule is needed.
- Do not install optional tools.
- Validate with bash -n and jq.

Return a short summary of files changed and the exact validation commands run.
```

## 3. Debug workflow behavior prompt

```text
The workflow shell profile controller is not behaving as expected.

Problem: <paste exact terminal output>
Expected behavior: <describe expected profile/status/export result>

Investigate scripts/workflow.sh and config/workflow_settings.json.

Rules:
- Preserve the exact failing terminal output in your analysis.
- Do not compress or summarize away the first error.
- Do not source ~/.bashrc from inside workflow.sh unless there is a very strong reason.
- Keep config/workflow_settings.json as the source of truth.
- Maintain backward-compatible variables: RTK_HOOK_ENABLED, HEADROOM_COMPRESSION_STRATEGY, LEANCTX_ACTIVE, MEMSTACK_ACTIVE, CAVEMAN_OUTPUT.
- Validate with bash -n, jq, and at least three profiles: code, security, status.

Patch the minimal bug only. Update docs/VALIDATION_MATRIX.md with the test result.
```

## 4. README improvement prompt

```text
Improve the README for this AI context workflow controller.

Goal: make the README useful for a beginner using VS Code agents in WSL/Ubuntu, while still being technically precise.

Requirements:
- Explain that this repository only exports profile variables and does not itself compress tokens.
- Explain that optional tools are not required for repository development.
- Keep installation steps complete enough for WSL/Ubuntu: sudo apt update, sudo apt upgrade, jq, git, curl, Python venv, Node/nvm where relevant, source ~/.bashrc.
- Include scenario-to-profile mapping.
- Include safety rules: raw-on-fail, security raw/lossless, database raw/lossless, release raw/lossless.
- Do not recommend Caveman for final documentation.
- Do not claim MemStack is a generic vector indexer unless the installed tool actually provides that.
- Keep the README readable. Avoid marketing claims unless marked as tool-author claims.

Do not install optional tools. Validate markdown structure only by reading it and checking that commands are not accidentally executable in fenced examples.
```

## 5. Optional tool installation validation prompt

```text
Prepare this repository for optional token-tool validation.

Important: do not run install commands yet. First inspect scripts/install-optional-tools.sh and scripts/check-tools.sh.

Check:
1. Does the installer automatically install only safe base WSL dependencies?
2. Does it print optional RTK, Headroom, LeanCTX, MemStack, and Caveman commands instead of blindly installing all of them?
3. Are Python tools isolated in virtual environments?
4. Is Node >= 18 handled before Caveman?
5. Are source ~/.bashrc and verification commands included?
6. Are install commands consistent with README.md?

Then propose any patch needed. After patching, run:
- bash -n scripts/install-optional-tools.sh
- bash -n scripts/check-tools.sh
- bash scripts/check-tools.sh

Update docs/VALIDATION_MATRIX.md with the results.
```

## 6. Tool-effect measurement prompt

```text
Measure token/context effects for one scenario in this repository.

Scenario: <scope|architect|code|debug|test|test-full|cicd|security|db|perf|release>
Command to run: <exact command>
Tool expected: <RTK|Headroom|LeanCTX|MemStack|Caveman|none>

Rules:
- Activate the matching workflow profile first.
- Save raw output to .ai-context/raw/ with timestamped filename.
- Save compressed or summarized output to .ai-context/compressed/ with timestamped filename.
- Estimate raw and compressed size using bytes, lines, and approximate tokens if exact token count is unavailable.
- Verify preserved evidence: command, working directory, exit code, stderr, first error, last relevant lines, file paths, line numbers, versions/environment.
- If the command relates to security, database migration, or release, do not use destructive compression.
- Update docs/VALIDATION_MATRIX.md with the experiment result.

Return only:
1. active profile
2. command run
3. raw output path
4. compressed output path
5. evidence preserved
6. evidence possibly lost
7. pass/fail decision
8. recommended profile change
```

## 7. AGENTS.md smell review prompt

```text
Review AGENTS.md for coding-agent instruction quality.

Look specifically for:
- context bloat
- conflicting instructions
- rules that belong in README instead of AGENTS.md
- instructions that force unnecessary file traversal or testing
- tool-specific assumptions that may be false when the tool is not installed
- unclear permission boundaries
- unstable task-specific content that should be moved to TASK.md, PLAN.md, STATE.md, or docs/VALIDATION_MATRIX.md

Do not rewrite AGENTS.md immediately. First produce a short findings list and a minimal proposed patch.
If patching, keep AGENTS.md concise and stable.
```

## 8. Safe release-readiness prompt

```text
Perform release-readiness review for this repository.

Activate or assume workflow release profile.

Check:
- scripts/workflow.sh syntax
- config/workflow_settings.json validity
- README command examples are fenced and not malformed
- no accidental hardcoded local paths except documented defaults
- no install script runs risky remote curl commands automatically without user decision
- AGENTS.md does not instruct agents to mutate workflow.sh or AGENTS.md without permission
- docs/VALIDATION_MATRIX.md exists and has templates
- prompts/vscode-agent-prompts.md exists and is task-oriented

Use raw/lossless evidence. Do not use destructive compression. Produce a concise release checklist and list blocking issues first.
```
