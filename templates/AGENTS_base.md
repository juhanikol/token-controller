<!-- ai-workflow-controller:start -->
## Execution Rules

- Check `~/.config/ai-workflow/active_mode.env` before broad reads, tests, builds, or code changes.
- Prefix test, build, install, and diagnostic commands with `wx`, for example `wx npm test`.
- `wx` preserves raw stdout/stderr under `.ai-context/raw/`, records byte counts in `.ai-context/session.jsonl`, preserves exit codes, and may only compress successful allowlisted noisy output.
- Direct commands such as `npm test` are not captured by Token Controller unless a separate hook or IDE integration forces `wx`.
- For `raw`, `security`, `db`, `release`, and `migration`, treat context as lossless. Do not summarize away CVEs, secrets, SQL, migration warnings, artifact hashes, auth code, or first failures.
- For `debug`, `test`, and `cicd`, preserve the first failure, stack trace, stderr, exit code, file paths, and line numbers. Summarize only repetitive success noise.
- Optional tools such as LeanCTX, Headroom, RTK, Repomix, or code-memory MCPs may be used only when installed and appropriate. Their output must not override preserved raw evidence.
<!-- ai-workflow-controller:end -->
