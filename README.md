# Token Controller Framework (WSL / Ubuntu Optimization Layer)

A system-level proxy workflow orchestrator to manage local token compression and optimization tools (**RTK**, **Headroom**, **MemStack**, and **Caveman**). It dynamically toggles environment flags across development phases to protect your LLM context window and reduce API billing overhead.

---

## 🏗️ Architecture & Intended Use

This project acts as an external shell state-manager. It updates active environment parameters inside your WSL shell profile. VS Code developer extensions and terminal environments inherit these configurations automatically, aligning local agent token consumption directly to your engineering phase.

**Important Note**: This repository contains only configuration matrices and state switches. The actual optimization binaries are installed globally on your machine, preventing project bloat.

---

## 🛠️ Global Tool Installation Index

Execute these initialization steps in your WSL terminal workspace to load the required global tool suites:

### 1. RTK (Rust Token Killer)
Intercepts terminal command outputs (e.g., git status, npm log strings) and strips boilerplate noise.
```bash
# Verify installation path first
rtk --version && rtk gain

# Install global binary if not present
curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh
rtk init --global
```

### 2. Headroom AI
An intelligent token proxy sitting between developer tools and LLM APIs to handle AST parsing and text compression.
```bash
pip install "headroom-ai[all]"
# Initialize local daemon listening proxy
headroom proxy --port 8787
```

### 3. MemStack
Local vector indexer keeping active repository mappings in memory so agents don't have to re-read your files across steps.
```bash
git clone https://github.com ~/.memstack-core
~/.memstack-core/bin/memstack init
```

### 4. Caveman
A dynamic prompt wrapper used during dense diagnostic workloads to force LLM outputs into highly minimal text fragments.
```bash
npm install -g @caveman/cli
caveman bind --global
```

---

## 🔄 Dynamic Toggle Controls

To control your optimization environment, add this alias definition string directly to your local `~/.bashrc` script file:
```bash
alias workflow="source ~/projects/token-controller/scripts/workflow.sh"
```

### Profile Modes Cheat Sheet

| Command Option | Ideal Engineering Phase | Optimization Objective | Potential Operational Risk |
| :--- | :--- | :--- | :--- |
| `workflow plan` | Scope Gathering, System Design & Architecture Analysis | Keeps repository map cached; maps broad type boundaries. | Context compression can drop inline method comments. |
| `workflow code` | Active Software Writing & Minor Routine Verifications | Code-aware parsing stays reversible using local caches. | Minor latency when pulling raw uncompressed code. |
| `workflow test` | Large Automation Runs & Multi-Suite Evaluations | Shreds thousands of lines of pass/fail validation loops. | May block minor warnings or trace origins. |
| `workflow debug`| Precise Bug Fixing & System Log Fault Analysis | Retains critical runtime exceptions without data loss. | Higher billing costs due to less text compression. |
| `workflow cicd` | Container Assembly & Dependency Script Configuration | Strips boilerplate from curl networks and installation logs. | Hidden environment states can match noise filters. |
| `workflow off`  | Default Execution / Manual Validation | Disables proxies completely; runs vanilla streams. | High token burn rates on repetitive code reading. |

---

## 📊 Core Token Tool Comparison

| Tool Name | Optimization Layer | Core Compression Engine | Key Strengths | Core Architectural Risk |
| :--- | :--- | :--- | :--- | :--- |
| **RTK** | Local Terminal / Shell Tool Execution | Structural string filters & log parsing regex. | Saves up to 90% tokens on heavy build dumps and logs. | Destructive compression; drops text patterns permanently. |
| **Headroom** | Network In-Flight API Payload | AST parsing, structural minification & local text cache. | Content-Conditional Reversibility allows agents to recover code. | Higher API latency on long round-trip recovery loops. |
| **MemStack** | Persistent Local Memory Cache | Workspace directory mapping indexing. | Prevents repetitive filesystem lookups across sessions. | Does not compress individual active payloads. |
| **Caveman** | Prompt Injection Framework | Output generation constraint engineering. | Lowers high-cost model response generation tokens. | Degrades structural and conversational output clarity. |