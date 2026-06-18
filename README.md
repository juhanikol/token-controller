# AI Context Workflow Controller

A WSL/Ubuntu shell profile switcher for AI-assisted software development. The project does **not** compress tokens by itself. It exports stable environment variables that compatible tools, shell hooks, MCP servers, and VS Code agents can use to decide how much context to preserve, compress, or index for a given engineering scenario.

The goal is to avoid the common mistake of applying one token optimizer everywhere. Requirements, architecture, debugging, security, migrations, and release work have different evidence requirements. This controller maps scenarios to safer context policies.

## What this project is

This project is:

- a local shell state manager
- a profile matrix for engineering scenarios
- a guardrail layer for VS Code agents
- a validation framework for comparing raw vs compressed context behavior
- a place to document measured token savings and risks

This project is **not**:

- RTK, Headroom, LeanCTX, MemStack, or Caveman itself
- a replacement for agent permissions or sandboxing
- a guarantee that compression is safe
- a reason to hide raw logs from the agent

## Core design principle

> Full fidelity for intent, target code, failing evidence, security/compliance output, database migrations, and release artifacts. Compression for repetitive logs, generated files, dependency noise, package-manager output, and already-indexed structure.

## Do you need the token tools installed before developing this project?

No. You can develop and test this repository with only Bash and `jq`.

Minimum useful development stack:

```bash
sudo apt update
sudo apt upgrade -y
sudo apt install -y jq git curl ca-certificates bash coreutils
bash -n scripts/workflow.sh
source scripts/workflow.sh status
source scripts/workflow.sh code
source scripts/workflow.sh status
```

You need the real tools only when validating actual token effects end-to-end:

- RTK: shell command output filtering / compression
- Headroom: prompt, file, log, and tool-output compression
- LeanCTX: broader context runtime with shell hooks, MCP tools, memory, graph/index features
- MemStack: Claude Code skill/memory framework; useful if you actually use Claude Code and want skill/session memory behavior
- Caveman: output brevity mode; useful only for internal low-risk output savings, not professional documentation

## Repository layout

```text
.
├── AGENTS.md
├── README.md
├── config/
│   └── workflow_settings.json
├── docs/
│   └── VALIDATION_MATRIX.md
├── prompts/
│   └── vscode-agent-prompts.md
└── scripts/
    ├── check-tools.sh
    ├── install-optional-tools.sh
    └── workflow.sh
```

## Installation: controller only

Clone or copy this repository into WSL/Ubuntu. Example path:

```bash
mkdir -p ~/projects
cd ~/projects
# git clone <your-repo-url> token-controller
cd token-controller
```

Install minimum dependencies:

```bash
sudo apt update
sudo apt upgrade -y
sudo apt install -y jq git curl ca-certificates bash coreutils
```

Add a shell alias:

```bash
cat >> ~/.bashrc <<'ALIAS_EOF'
alias workflow='source ~/projects/token-controller/scripts/workflow.sh'
ALIAS_EOF
source ~/.bashrc
```

Validate:

```bash
workflow status
workflow code
workflow status
cat ~/.config/ai-workflow/active_mode.env
```

## Optional tool installation

Run the optional installer interactively:

```bash
bash scripts/install-optional-tools.sh
source ~/.bashrc
bash scripts/check-tools.sh
```

The installer is deliberately conservative. It installs basic dependencies and prints tool-specific commands. Review each command before running it.

### RTK

Purpose: terminal command output optimization, especially noisy development commands.

Typical WSL/Linux install:

```bash
curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
rtk --version
rtk init -g --copilot   # VS Code GitHub Copilot-oriented setup, if supported by your installed RTK version
rtk init --show
```

Useful verification:

```bash
rtk gain
rtk git status
```

Safety note: use RTK mainly for noisy successful commands or repeated logs. For first failure, security scans, database migrations, and release output, use raw or lossless mode.

### Headroom

Purpose: compresses tool outputs, logs, files, RAG chunks, and conversation history before model input. It can be used as a Python package, proxy, MCP server, or framework integration.

Recommended isolated Python setup:

```bash
sudo apt install -y python3 python3-pip python3-venv pipx
python3 -m venv ~/.venvs/headroom
source ~/.venvs/headroom/bin/activate
pip install --upgrade pip
pip install "headroom-ai[all]"
python -c "import headroom; print(headroom.__version__)"
headroom proxy --port 8787
```

For another terminal session:

```bash
source ~/.venvs/headroom/bin/activate
headroom --help
```

Safety note: prefer reversible/safe compression for active coding. Do not use aggressive compression for target files, first failures, security, database, or release work.

### LeanCTX

Purpose: local context runtime with shell hooks, MCP server, read modes, caching, memory, code graph, and context observability.

Typical WSL/Linux install options:

```bash
# Universal installer
curl -fsSL https://leanctx.com/install.sh | sh

# Alternative Node-based install, if Node >= 18 is available
npm install -g lean-ctx-bin
```

Then:

```bash
source ~/.bashrc
lean-ctx onboard      # or: lean-ctx setup
lean-ctx doctor
lean-ctx gain
```

Safety note: LeanCTX is the best fit for safe diagnostic/context-runtime behavior when you need more than simple shell-output filtering.

### MemStack

Purpose: Claude Code skill and memory framework. Do not treat it as a generic local vector indexer unless your installed version and license actually provide that feature.

Typical Claude Code-oriented setup:

```bash
python3 -m venv ~/.venvs/memstack
source ~/.venvs/memstack/bin/activate
pip install --upgrade pip
pip install memstack-skill-loader
claude mcp add --scope user memstack-skills -- python -m memstack_skill_loader
```

Then restart Claude Code and verify with its own skill list flow.

Safety note: for generic VS Code agent workflows, LeanCTX or a dedicated codebase-index tool may be a better fit than MemStack. Keep `MEMSTACK_ACTIVE` as a compatibility flag, not as a guarantee that indexing exists.

### Caveman

Purpose: terse output style / output token reduction. This should not be used for final README, customer documentation, professional communication, safety analysis, or architecture decisions.

Typical install:

```bash
# Requires Node >= 18
curl -fsSL https://raw.githubusercontent.com/JuliusBrussee/caveman/main/install.sh | bash
```

Node setup if needed:

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
source ~/.bashrc
nvm install 22
nvm use 22
node --version
npm --version
```

Safety note: in this project, `AICONTEXT_CAVEMAN_OUTPUT=false` is the default for almost every scenario. Prefer normal, clear output unless you are deliberately reducing internal response tokens.

## Profile commands

Use profiles with:

```bash
workflow <mode>
```

Examples:

```bash
workflow scope
workflow architect
workflow code
workflow debug
workflow security
workflow release
workflow off
workflow status
```

Backward-compatible aliases:

```bash
workflow plan   # same as architect
workflow ci     # same as cicd
```

## Scenario matrix


| Scenario                              | Command                                 | Recommended context policy                      | Token-saving tools                                                         | Raw fidelity requirement                                         |
| ------------------------------------- | --------------------------------------- | ----------------------------------------------- | -------------------------------------------------------------------------- | ---------------------------------------------------------------- |
| Scope and requirements                | `workflow scope`                        | Safe summaries, no destructive compression      | Headroom safe, LeanCTX context-read                                        | User intent, constraints, acceptance criteria                    |
| Structure and architecture            | `workflow architect`                    | Codebase map + full-read selected files         | LeanCTX graph/read, Headroom code-safe                                     | Core module boundaries, interfaces, design rationale             |
| Architecture decisions, models, types | `workflow decisions`                    | Interfaces/schemas preserved                    | Headroom code-safe, LeanCTX graph-read                                     | Domain models, API contracts, type definitions                   |
| Actual coding                         | `workflow code`                         | Full target file, dependency signatures         | Headroom reversible, LeanCTX auto, RTK for noisy successful shell commands | Edited files, nearby tests, compiler errors                      |
| Data analysis                         | `workflow data-analysis`                | Preserve numbers, safe compression              | LeanCTX diagnostic, Headroom safe                                          | Numeric data, stats, plots, data sources                         |
| Agent orchestration / AGENTS.md       | `workflow agent`                        | Stable prefix, dynamic task files separate      | Headroom cache-aligner, LeanCTX auto                                       | AGENTS.md, TASK.md, PLAN.md, STATE.md                            |
| Bug fixing                            | `workflow debug`                        | First failure raw, later repetition compressed  | LeanCTX diagnostic, Headroom safe-reversible                               | First error, stderr, exit code, stack trace, paths, line numbers |
| Documentation                         | `workflow docs`                         | Compressed source gathering, normal final prose | Headroom safe, LeanCTX context-read                                        | Final README/docs, factual project behavior                      |
| Unit/integration tests                | `workflow test`                         | Compress pass noise, preserve failures          | RTK tests-safe, LeanCTX diagnostic                                         | Failing assertions, stack traces, test names                     |
| Automated tests for all agent changes | `workflow test` or `workflow test-full` | Raw-on-fail, compressed pass logs               | RTK/LeanCTX after baseline                                                 | First failure and summary                                        |
| Whole codebase examination            | `workflow review`                       | Index first, full-read selected files           | LeanCTX graph-read, Headroom reversible                                    | Diffs, risk areas, public interfaces                             |
| Small snippet/file/method check       | `workflow snippet`                      | Usually raw only                                | None by default                                                            | Entire snippet/method/file                                       |
| Full app test routine                 | `workflow test-full`                    | Aggressive only after baseline                  | RTK success-only, LeanCTX diagnostic                                       | Raw failing logs and summary                                     |
| CI/CD design and implementation       | `workflow cicd`                         | Compress install/fetch boilerplate only         | RTK install-build-noise, LeanCTX diagnostic                                | YAML, scripts, env vars, exit code, failing lines                |
| Security/compliance review            | `workflow security`                     | Raw or lossless only                            | LeanCTX guarded, Headroom lossless-only                                    | CVEs, secrets, auth, crypto, license findings                    |
| Large migration / legacy refactor     | `workflow migration`                    | Indexed global map + full active files          | LeanCTX graph-read, Headroom reversible                                    | Migration rules, compatibility behavior, changed files           |
| Database/schema migration             | `workflow db`                           | Raw/lossless                                    | LeanCTX diagnostic only                                                    | SQL, constraints, migration order, data-loss warnings            |
| Performance profiling                 | `workflow perf`                         | Preserve numbers and environment                | LeanCTX diagnostic, Headroom safe                                          | Timings, percentiles, memory, sample size                        |
| Release preparation                   | `workflow release`                      | Raw/lossless                                    | Usually none                                                               | Version, changelog, artifact names, hashes, signing output       |
| Emergency rate-limit reduction        | not default; manual                     | Output-only brevity                             | Caveman                                                                    | Never for final or high-risk output                              |

## Risk-level rule

The settings file assigns each mode a risk level.

```text
critical -> raw/lossless only
high     -> safe compression only, raw-on-fail required
normal   -> safe/balanced compression allowed
low      -> aggressive compression allowed only for known-noisy output
```

## Command classification rule

Treat command output by evidence type, not only by phase.

Noisy output that can usually be compressed when successful:

```text
npm install
pnpm install
yarn install
docker build
dotnet restore
cargo fetch
pip install
```

Commands that should be raw/lossless by default:

```text
npm audit
govulncheck
trivy
grype
snyk
semgrep
gitleaks
flyway
liquibase
prisma migrate
mysql
psql
```

Test commands:

```text
pytest
go test
npm test
dotnet test
cargo test
```

Test policy: first failure raw; repeated pass/noise output may be compressed.

## Validation workflow

Record results in `docs/VALIDATION_MATRIX.md`.

Basic validation without optional tools:

```bash
bash -n scripts/workflow.sh
jq . config/workflow_settings.json >/dev/null
source scripts/workflow.sh code
source scripts/workflow.sh status
source scripts/workflow.sh security
source scripts/workflow.sh status
```

Optional validation with tools:

```bash
bash scripts/check-tools.sh
workflow test
# run your normal test command
workflow debug
# rerun failing test with raw-on-fail behavior
workflow security
# run security scan raw/lossless
```

For every test case, record:

- scenario
- active profile
- command used
- tools installed/missing
- raw output size or estimated tokens
- compressed output size or estimated tokens
- preserved evidence
- lost/possibly hidden evidence
- pass/fail decision
- recommended profile change

## VS Code / Copilot instructions

For GitHub Copilot in VS Code, keep general repository instructions in:

```text
.github/copilot-instructions.md
```

For multi-agent compatibility, keep core agent instructions in:

```text
AGENTS.md
```

Keep both concise. Do not put long scenario matrices into always-loaded instructions unless necessary. Long context files can increase cost and may reduce task performance if they include irrelevant or conflicting instructions.

Use task-specific prompts from:

```text
prompts/vscode-agent-prompts.md
```

## Design corrections compared with the first draft

The original version was directionally correct, but these changes make it safer:

1. Profiles are based on evidence loss tolerance, not only engineering phase.
2. `safe` behavior is the default for most work.
3. Raw evidence is preserved for failures and high-risk scenarios.
4. LeanCTX is represented explicitly because it covers more than log compression.
5. MemStack is treated as a Claude Code skill/memory framework, not assumed to be a generic indexer.
6. Caveman is constrained to internal low-risk output brevity.
7. `workflow.sh` reads settings relative to the repository instead of a hardcoded home path.
8. `status` works without requiring a JSON profile lookup.
9. JSON is the source of truth; the shell script no longer duplicates all profile values in hardcoded `case` branches.
10. A validation matrix is included so decisions can be based on measured behavior instead of assumptions.
