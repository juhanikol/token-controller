# Optional tool helpers

Convenience scripts for the optional tools. Token Controller works without any of them.

```bash
bash scripts/install-tools/rtk.sh        # RTK: shortens noisy terminal output (used by wx after raw capture)
bash scripts/install-tools/leanctx.sh    # LeanCTX: controlled file, search, and tree exploration
bash scripts/install-tools/caveman.sh    # Caveman: shorter assistant replies (Claude Code plugin, off by default)
```

Each helper prints the upstream source, says it may be out of date, and asks you to confirm before it downloads or installs anything. `--dry-run` shows what it would do and runs nothing.

Rules: one tool per helper. No `rtk init`. No `lean-ctx setup`, `wrap`, `init`, or `onboard`. No edit of agent settings, MCP config, shell startup files, or hooks. `install-wsl.sh` never runs these helpers. Read the upstream page before you install, because upstream installers change.

The upstream LeanCTX installer runs `lean-ctx onboard` (it edits your agents' MCP config) and appends to `~/.bashrc` unless told not to. The LeanCTX helper turns both off with `LEAN_CTX_NO_ONBOARD=1` and `LEAN_CTX_NO_PATH_FIX=1`.
