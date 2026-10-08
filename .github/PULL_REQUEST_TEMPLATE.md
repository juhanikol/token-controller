## Summary

<!-- What does this change, and why? Link related issues, e.g. "Fixes #123". -->

## Type of change

- [ ] Bug fix
- [ ] New feature or behavior change
- [ ] Documentation only
- [ ] Tests or CI only
- [ ] Refactor (no behavior change)
- [ ] Other:

## Safety checklist

- [ ] No secrets, tokens, private repository names, private paths, customer data, or proprietary logs in the diff, commit messages, or description.
- [ ] Optional tools (RTK, LeanCTX, Caveman) are still not required for core startup.
- [ ] Raw command output is still preserved where it was before.
- [ ] No new network calls, installs, or writes outside the project and the documented config locations.
- [ ] Docs describe measured bytes only. They do not promise token, cost, or latency savings.

## Validation

<!-- List the commands you ran and the result. Remove lines that do not apply. -->

```bash
# CLI (the same tests CI runs)
for f in scripts/*.sh scripts/lib/*.sh; do bash -n "$f"; done
jq . config/workflow_settings.json >/dev/null
bash tests/wx-wrapper.test.sh
bash tests/workflow-session.test.sh
bash tests/doctor.test.sh
bash tests/install.test.sh
bash tests/leanctx.test.sh

# VS Code extension (only if extensions/vscode changed)
cd extensions/vscode && npm ci && npm run lint && npx vsce package
```

- [ ] Tests pass locally
- [ ] Not run, because:

## Notes

<!-- Anything reviewers should know: trade-offs, follow-ups, known limits. -->
