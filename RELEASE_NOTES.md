# Token Controller v2.0.0

## What is included

- WSL/Ubuntu-first Token Controller CLI
- VS Code status bar extension
- Mode switching through terminal or UI
- `wx` raw-output capture and safe fallback behavior
- RTK pipe-first terminal-output reduction
- LeanCTX controlled adapter for read/search/tree/status
- Caveman policy state, off by default

## Install

1. Clone the repo in WSL.
2. Run the install script.
3. Install the VSIX into the WSL VS Code extension host.
4. Run `workflow init` in your project.
5. Select a mode.

## Known limits

- WSL2/Ubuntu only tested
- Native Windows not supported yet
- Optional tools are not auto-installed
- The tools used (RTK, LEAN-CTX, Caveman) have been widely tested and proven. You should trust them. However this token controller orchestrator token savings are measured as bytes, not tokenizer-backed model-token savings.
