# Token Controller

**Stop burning tokens on noise. Pick the work mode, let the controller guide the tools, and keep the important evidence safe.**

Are your AI-coding tokens disappearing faster than expected?

Maybe you are exploring a large codebase. Maybe your agent just dumped a wall of test output into the context. Maybe you already have a good `AGENTS.md` or `SKILLS.md`, but the context still fills up with logs, file listings, repeated success output, and tool chatter.

You may have tried token-saving tools before. They help, but each one has its own setup, commands, hooks, flags, and risks. Then another promising tool appears next week, and now you have one more thing to configure and remember.

**Token Controller exists to remove that cognitive load.**

## **VS Code control**

The Status Bar dropdown provides another way to select a profile.

![select context](assets/20260824_212040_image.png)

	Impressed already? Looking for quick install? Jump to: [releases](https://github.com/juhanikol/token-controller/releases) and download

It also gives you one simple workflow in CLI for choosing the task you are doing:

```bash
workflow code
workflow debug
workflow architect
workflow review
```

The controller then publishes that mode to your shell, your project instructions, the VS Code status bar, and the supported context tools.

Token Controller does not try to replace your tools. It orchestrates them.

* **RTK** reduces noisy terminal output after raw output has been captured.
* **LeanCTX** helps with controlled codebase exploration, file reads, search, and tree views.
* **Caveman** can reduce assistant response verbosity when explicitly allowed.
* **wx** is the safety layer that keeps raw command output, stderr, and exit codes available.

These are all community praised and respected solutions! Thousands have already tested these! So you know that the tools used are already proven and you might have even used them. Token-controller just orchestrates them so you do not need to worry about them.

The goal is simple: **save context where it is safe**, and keep full evidence where correctness matters.

Failures stay raw. Security, database, migration, and release work stay conservative. If an optional tool is missing, Token Controller falls back to safe behavior instead of breaking your workflow.

For daily use, remember only this:

```bash
workflow init
workflow code
```

Install once. Initialize each project once. Then select the work mode from the terminal or the VS Code status bar.

## Install (WSL 2 + Ubuntu)

Token Controller is tested on **WSL 2 with Ubuntu**, with VS Code connected to the same WSL distro. Native Windows is not supported yet.

1. **Get it.** In a WSL terminal:

   ```bash
   mkdir -p ~/projects
   git clone https://github.com/juhanikol/token-controller.git ~/projects/token-controller
   ```
2. **Run the install script.**

   ```bash
   bash ~/projects/token-controller/scripts/install-wsl.sh
   ```

   It installs `jq`, `git`, and `curl` with apt, adds a `workflow` alias to `~/.bashrc` (only if there is none), runs a tool check, and prints the next steps. It does **not** install RTK, LeanCTX, Caveman, or any other optional tool. Preview it first with `--dry-run`.
3. **Open a new terminal** (or `source ~/.bashrc`) and check:

   ```bash
   workflow status
   ```
4. **Use it in a project:**

   ```bash
   cd ~/projects/my-project
   workflow init     # once per project: adds the rules to AGENTS.md
   workflow code     # choose a mode
   ```
5. **Optional: install the VS Code extension** for the status-bar mode switcher (next section).

That is all. For daily use, remember `workflow init` and `workflow <mode>`.

## VS Code extension (optional)

The extension shows the active mode in the status bar and lets you switch it. It does not compress anything itself.

1. Get `token-controller-ui-2.0.0.vsix` from the [GitHub release](https://github.com/juhanikol/token-controller/releases), or build it ([extensions/vscode/README.md](extensions/vscode/README.md)).
2. Open your project in VS Code **connected to WSL** (the window shows `WSL: Ubuntu` at the bottom left). Run `code .` from a WSL terminal.
3. Open the Extensions view, click `…`, choose **Install from VSIX…**, and pick the file. Or, in a WSL terminal inside that window:

   ```bash
   code --install-extension token-controller-ui-2.0.0.vsix
   ```
4. Reload the window. The status bar shows `AI Context: <mode>`. Click it to switch.

Install it in the **WSL extension host** ("Install in WSL: Ubuntu"), not only in local Windows VS Code. If you cloned the controller somewhere other than `~/projects/token-controller`, set `tokenController.scriptPath` in your user settings.

## Which mode?

| You are...                             | Run                                                       | What it asks for                               |
| -------------------------------------- | --------------------------------------------------------- | ---------------------------------------------- |
| Exploring a codebase                   | `workflow architect`                                    | Map first, then read the important files fully |
| Writing normal code                    | `workflow code`                                         | Target files full; compress successful noise   |
| Fixing a failure                       | `workflow debug`                                        | The first failure stays raw                    |
| Running tests                          | `workflow test`                                         | Compress passing noise only                    |
| Reviewing a change                     | `workflow review`                                       | Index first, then read important files fully   |
| Security, database, release, migration | `workflow security`, `db`, `release`, `migration` | Raw or lossless. No compression.               |
| A tiny edit                            | `workflow micro`                                        | No context tools                               |
| Anything, maximum fidelity             | `workflow raw`                                          | Everything raw                                 |

There are 22 modes. The full list is in [the scenario matrix](#scenario-matrix) below, or run `workflow modes`.

## How it keeps you safe

* **Failures stay raw.** A command that exits with an error is never compressed. The first failure of a debug run keeps its message, stack trace, stderr, paths, and line numbers.
* **Protected modes stay raw.** `raw`, `security`, `db`, `migration`, and `release` never use compression tools.
* **Raw output is always saved first.** `wx <command>` runs your command once, saves the raw stdout, stderr, and exit code under `.ai-context/raw/`, and only then may shorten what is shown. The exit code is never changed.
* **A tool that fails or is missing is not a problem.** If RTK is not installed, times out, or produces something that is not smaller or that drops an error or warning line, you see the raw output and the reason is recorded. Nothing breaks.
* **LeanCTX output is checked.** `workflow leanctx read-exact <file>` prints a file only if the output equals the file byte for byte. Otherwise it refuses. It is refused in the protected modes.

Some of this is policy: agents are *asked* to follow the mode, and the controller cannot force them. The parts that are code (`wx`, the LeanCTX adapter, `workflow doctor`) are tested.

## Optional tools are optional

Token Controller works with none of them installed. Install a tool only if you want its features.

| Tool              | What it does for you                                                                              | How Token Controller uses it                                                |
| ----------------- | ------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------- |
| **RTK**     | Shortens noisy terminal output (tests, builds, git, search)                                       | `wx` runs `rtk pipe` on the saved output, after raw capture             |
| **LeanCTX** | Codebase exploration: file maps, search, tree                                                     | `workflow leanctx status`, `read`, `read-exact`, `search`, `tree` |
| **Caveman** | Shorter assistant replies. Off by default. Never in docs, security, db, release, migration, debug | You opt in per activation:`AICONTEXT_CAVEMAN_REQUEST=lite workflow code`  |

See what is installed (changes nothing):

```bash
workflow doctor
bash ~/projects/token-controller/scripts/check-tools.sh
```

To see how to install them, read the commands (nothing is installed for you):

```bash
bash ~/projects/token-controller/scripts/show-optional-tools.sh --print-only
```

Do not run `rtk init` or `lean-ctx setup/wrap/init` casually. They edit agent or MCP settings and can add hooks that skip `wx` capture. Token Controller never runs them, and `workflow doctor` warns if it finds such a hook.

#### Token controller - as AI Context tool Workflow Controller

**Choose how agents should handle context, while keeping high-risk evidence visible.**

Token Controller is a mode switcher for AI context policy. The goal is to orchestrate proven context tools (RTK, LeanCTX, Headroom, Caveman) per work mode. Today it records the selected profile, installs project guidance for compatible agents, and exports policy variables that those tools may act on. It does not yet launch or configure them.

The `wx` wrapper is the safety and measurement layer: it captures raw output, preserves exit codes, and records byte counts for commands run as `wx <command>`. Its only built-in compression collapses consecutive identical stdout lines for successful allowlisted commands. It is a fallback, not the main token-saving mechanism. Token Controller does not enforce agent compliance, measure model tokens, or guarantee token savings.

## What is measured, and what is not

`wx` records the **byte counts** of raw and shown output in `.ai-context/session.jsonl`. `workflow report` summarizes them.

Byte reduction is not model-token measurement. Token Controller does not promise token savings. RTK, LeanCTX, and Caveman make their own claims, and those claims are theirs. Small outputs can even grow, because `wx` adds a pointer to the raw log. The evidence is in [docs/VALIDATION_MATRIX.md](docs/VALIDATION_MATRIX.md). Run the benchmark yourself:

```bash
bash benchmarks/run-benchmark.sh
```

## Everyday example

```bash
cd ~/projects/my-project
workflow init        # once for this project
workflow architect   # understand the structure
workflow code        # implement
wx npm test          # run through wx: raw saved, noise shortened if safe
workflow debug       # a test failed: keep the first failure raw
workflow report      # byte counts for this session
```

Commands are captured only when you run them as `wx <command>`. A direct `npm test` is not captured.

---

## Scenario matrix

It describes the policy requested from an agent or connected tool, not behavior the controller enforces by itself.

| Scenario                            | Command                      | Requested policy                                 | Evidence requested complete                                 |
| ----------------------------------- | ---------------------------- | ------------------------------------------------ | ----------------------------------------------------------- |
| Requirements and scope              | `workflow scope`           | Summarize carefully                              | User intent, constraints, acceptance criteria               |
| Architecture and structure          | `workflow architect`       | Map the codebase, then read selected files fully | Interfaces, module boundaries, design reasoning             |
| Models, schemas, and decisions      | `workflow decisions`       | Preserve contracts and types                     | Schemas, invariants, API contracts                          |
| Normal coding                       | `workflow code`            | Keep target files full; summarize dependencies   | Edited files, nearby tests, compiler errors                 |
| Rapid prototype                     | `workflow rapid-prototype` | Compress successful build noise aggressively     | Backend API errors, migration warnings, raw failure logs    |
| Small snippet review                | `workflow snippet`         | Use little or no compression                     | The complete snippet, method, or file                       |
| Very small task (one function/file) | `workflow micro`           | No context tools, no compression                 | The complete target file or snippet                         |
| Agent-rule work                     | `workflow agent`           | Keep agent instructions stable                   | `AGENTS.md` and dynamic task-state files                  |
| Data analysis                       | `workflow data-analysis`   | Preserve numeric evidence                        | Numbers, units, statistics, plots, data sources             |
| Bug fixing                          | `workflow debug`           | Keep the first failure raw                       | Error, stderr, exit code, stack origin, paths, line numbers |
| Unit and integration tests          | `workflow test`            | Compress passing noise only                      | Failing tests, assertions, stack traces                     |
| Full test suite                     | `workflow test-full`       | Compress successful repetition                   | First failure and final test summary                        |
| Documentation                       | `workflow docs`            | Gather sources efficiently; write normal prose   | Final documentation and factual behavior                    |
| CI/CD                               | `workflow cicd`            | Compress install and fetch boilerplate           | Workflow files, scripts, environment, failing lines         |
| Codebase or pull-request review     | `workflow review`          | Index first, then read important files fully     | Diffs, public interfaces, risk areas                        |
| Security and compliance             | `workflow security`        | Raw or lossless context only                     | CVEs, secrets, auth, crypto, license findings               |
| Large refactor or legacy migration  | `workflow migration`       | Use a global map and full active files           | Compatibility rules and changed files                       |
| Database migration                  | `workflow db`              | Raw or lossless context only                     | SQL, constraints, ordering, data-loss warnings              |
| Performance work                    | `workflow perf`            | Preserve measurements exactly                    | Timings, percentiles, memory, sample size, environment      |
| Release preparation                 | `workflow release`         | Raw or lossless context only                     | Versions, changelog, artifacts, hashes, signing output      |
| Maximum fidelity                    | `workflow raw`             | Disable compression                              | Everything                                                  |
| Disable optimizers                  | `workflow off`             | Turn optional optimization modes off             | Normal shell output                                         |

Aliases: `workflow plan` is `architect`, and `workflow ci` is `cicd`.

## Policy rules in plain language

* Correctness is more important than saving tokens.
* `raw`, `security`, `db`, `migration`, and `release` use raw or lossless context.
* Risk levels: `normal` is routine work, `high` is evidence-sensitive work that is not necessarily raw, and `critical` is raw or lossless work with protected evidence.
* `debug` and `test` keep the first failure, stderr, exit code, paths, and line numbers.
* Target files being edited should be read in full.
* Repetitive successful output is the safest content to compress.
* Optional tools must be detected before an agent relies on them.

## What `workflow init` adds

`workflow init` creates `AGENTS.md` from [templates/AGENTS_base.md](templates/AGENTS_base.md), or appends a managed block to the one you have. It tells agents to:

* read `~/.config/ai-workflow/active_mode.env` before working;
* follow the selected risk and fidelity policy;
* preserve failures and high-risk evidence;
* not assume optional tools are installed;
* keep your own instructions intact.

Running it again adds nothing twice. If the managed block is incomplete, or `AGENTS.md` is a symbolic link, it stops instead of making a risky change. Commit `AGENTS.md` if you want your team to use the same rules.

Optional: `workflow setup` adds the same rule to global Copilot, Gemini Code Assist, and Claude Code instruction files. Existing settings are kept. It needs a strict JSON `settings.json` (no comments or trailing commas).

## How it works (technical)

* **Profile control:** `workflow <mode>` exports policy variables and writes `~/.config/ai-workflow/active_mode.env`.
* **Project guidance:** `workflow init` writes the agent rules.
* **Capture:** `wx <command>` runs the command once, saves raw stdout, stderr, and the exit code, applies only conservative reduction, and records byte counts. The only built-in reduction collapses consecutive identical lines for successful, allow-listed commands. RTK output replaces it only when it is smaller and keeps every error and warning line.
* **RTK:** `wx` runs `rtk pipe -f <filter>` on the saved stdout, only in modes that allow it and only for commands that have a `pipe` entry in `command_policy.rtk_commands`. It never re-runs your command and never runs `rtk init`. The list of commands and the measured results are in [docs/integrations/RTK.md](docs/integrations/RTK.md).
* **LeanCTX adapter:** `workflow leanctx` reads the mode and `leanctx_policy`, refuses off and protected modes, refuses a lean-ctx binary that is inside the project or a Windows one under WSL, and runs only bounded `read`, `grep`, and `ls` calls. It does not run `lean-ctx status`, `setup`, `wrap`, `init`, a shell, or `wx`. See [docs/integrations/LEAN-CTX.md](docs/integrations/LEAN-CTX.md).
* **Three layers:** policy (profiles, variables, agent rules), mechanical (`wx` capture and the adapters), and measurement (byte counts and benchmarks). Only the second and third are code.

Optional: a Claude Code hook example that tells the agent to retry selected direct test/build commands as `wx <command>` is in [integrations/claude-code/README.md](integrations/claude-code/README.md). It is an example, not installed behavior.

## Useful commands

| Command                                       | Purpose                                                                              |
| --------------------------------------------- | ------------------------------------------------------------------------------------ |
| `workflow init`                             | Create or safely extend the current project's`AGENTS.md`                           |
| `workflow <mode>`                           | Select a context mode                                                                |
| `workflow status`                           | Show the active mode and policy (`--json` for tools)                               |
| `workflow doctor`                           | Read-only check of settings, instruction files, and tools (`--json`)               |
| `wx <command>`                              | Capture, preserve, optionally shorten, and measure output                            |
| `workflow report`                           | Summarize commands, bytes, reduction, and failures (`--json`, `--project <dir>`) |
| `workflow reset-session`                    | Archive session metadata without deleting raw logs                                   |
| `workflow leanctx status`                   | Show whether the LeanCTX adapter is allowed, and why not (`--json`)                |
| `workflow leanctx read-exact <file>`        | Print a file through LeanCTX only if it equals the file byte for byte                |
| `workflow modes`                            | List modes and aliases (`--json`)                                                  |
| `workflow version`                          | Show the CLI version and JSON schema numbers (`--json`)                            |
| `workflow setup`                            | Optional global editor instructions                                                  |
| `workflow off`                              | Turn optional optimization off                                                       |
| `scripts/workflow-cli.sh <mode or command>` | Same commands in a separate process, for tools. Example:`status --json`            |

## Supported environment and limits

* **Tested only on WSL 2 with Ubuntu** (24.04, Bash 5.2, `jq` 1.8), with VS Code connected to the same distro. Native Windows, WSL 1, macOS, native Linux, Dev Containers, SSH remotes, and Codespaces are not verified.
* Run `workflow` in a WSL Bash terminal. Keep the controller and your projects in the Linux filesystem (for example `~/projects`), not under `/mnt/c`. Keep shell scripts in LF format. Each WSL distro has its own home and its own `active_mode.env`.
* The `workflow` alias is added to `~/.bashrc`. Other shells are not documented or tested.
* Savings depend on command coverage. Only commands run through `wx` are captured. There is no universal interception layer.
* Small outputs can get bigger, because of the raw-log pointer. Reported numbers are bytes, not model tokens, latency, or cost.
* Raw logs are kept on purpose and may contain secrets. Protect `.ai-context/`. Add it to `.gitignore`.
* Policy depends on agent compliance. The controller cannot force an agent to follow a mode.
* Known open items are listed in [docs/TECHNICAL_DEBT.md](docs/TECHNICAL_DEBT.md).

## Uninstall

```bash
# 1. Remove the alias line "alias workflow=..." from ~/.bashrc, then reload
nano ~/.bashrc && source ~/.bashrc
# 2. Remove the active-mode cache
rm -rf ~/.config/ai-workflow
# 3. Remove the AGENTS.md rules from a project: delete the block between the
#    "ai-workflow-controller:start" and "ai-workflow-controller:end" comments in AGENTS.md
# 4. Remove the VS Code extension from the Extensions view (in the WSL window)
# 5. Only if you ran "workflow setup": remove the Token Controller rules from the global files it edited
#    (for example ~/.claude/CLAUDE.md or ~/.copilot/instructions/ai-workflow.instructions.md)
# 6. Delete the clone
rm -rf ~/projects/token-controller
```

Raw logs stay in each project's `.ai-context/` until you delete that folder.

## Development

The controller itself needs only Bash and `jq`:

```bash
bash -n scripts/workflow.sh
find scripts -name "*.sh" -print0 | xargs -0 -n1 bash -n
jq . config/workflow_settings.json >/dev/null
bash tests/wx-wrapper.test.sh
bash tests/workflow-session.test.sh
bash tests/doctor.test.sh
bash tests/install.test.sh
AICONTEXT_TEST_SKIP_REAL_LEANCTX=1 bash tests/leanctx.test.sh
bash benchmarks/run-benchmark.sh
```

GitHub Actions runs these checks on every branch push and on pull requests to `main` (`.github/workflows/cli-ci.yml`). It installs no optional tool and uses fake tools from `tests/fixtures`. Releasing: [docs/RELEASE.md](docs/RELEASE.md). Validation results: [docs/VALIDATION_MATRIX.md](docs/VALIDATION_MATRIX.md), and how the benchmarks work: [benchmarks/README.md](benchmarks/README.md).

Build the VS Code extension:

```bash
cd extensions/vscode
npm ci
npm run package
npx vsce package
```

### Repository layout

```text
token-controller/
├── AGENTS.md                      # short development rules for this repository
├── README.md, RELEASE_NOTES.md
├── benchmarks/                    # byte-reduction benchmarks and fixtures
├── config/workflow_settings.json  # source of mode policy
├── docs/                          # design notes, RELEASE.md, TECHNICAL_DEBT.md, VALIDATION_MATRIX.md, integrations/
├── extensions/vscode/             # VS Code status-bar extension (TypeScript)
├── integrations/                  # opt-in examples (Claude Code hook, MCP template)
├── scripts/
│   ├── install-wsl.sh             # WSL setup: prerequisites and the workflow alias, no optional tool
│   ├── show-optional-tools.sh     # prints the optional tools' install commands
│   ├── check-tools.sh             # shows which tools are installed
│   ├── workflow.sh                # sourced: mode switching and commands
│   ├── workflow-cli.sh            # run, not sourced: entry point for tools and the extension
│   ├── leanctx-cli.sh             # the LeanCTX adapter (workflow leanctx)
│   ├── doctor.sh                  # read-only checks (workflow doctor)
│   └── lib/                       # wx, compression, session, version code
├── templates/AGENTS_base.md       # block added by workflow init
└── tests/                         # shell tests and fixtures
```
