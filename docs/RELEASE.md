# Releasing Token Controller

Release from `main`, after the branch is merged and CI is green. Replace `2.0.0` with the version.

## 1. Check the versions

```bash
git switch main && git pull
jq -r .version extensions/vscode/package.json          # extension version
grep '^AIW_CLI_VERSION' scripts/lib/versions.sh         # CLI version
```

Both must match the release. Update `extensions/vscode/CHANGELOG.md` and `RELEASE_NOTES.md`.

## 2. Validate

```bash
jq . config/workflow_settings.json >/dev/null
bash -n scripts/workflow.sh
bash -n scripts/workflow-cli.sh
bash -n scripts/leanctx-cli.sh
bash -n scripts/install-wsl.sh
bash -n scripts/show-optional-tools.sh
bash tests/wx-wrapper.test.sh
bash tests/workflow-session.test.sh
bash tests/doctor.test.sh
bash tests/install.test.sh
AICONTEXT_TEST_SKIP_REAL_LEANCTX=1 bash tests/leanctx.test.sh
bash benchmarks/run-benchmark.sh
git diff --check
```

Also check that GitHub Actions is green for the commit you tag (Actions tab, workflow "CLI CI").

## 3. Package the VSIX

```bash
cd extensions/vscode
npm ci
npm run package
npx vsce package          # writes token-controller-ui-2.0.0.vsix
sha256sum token-controller-ui-2.0.0.vsix > token-controller-ui-2.0.0.vsix.sha256
cd ../..
```

The VSIX is not tracked in git. Test it once: install it in a WSL VS Code window and check the status bar.

## 4. Tag

```bash
git tag -a v2.0.0 -m "Token Controller v2.0.0"
git push origin v2.0.0
```

If the tag already exists and points to the wrong commit, do not move it silently. Decide first. Moving a pushed tag (`git tag -d`, `git push --delete origin`, then tag again) changes what people who already fetched it have.

## 5. GitHub release

```bash
gh release create v2.0.0 \
  --title "Token Controller v2.0.0" \
  --notes-file RELEASE_NOTES.md \
  extensions/vscode/token-controller-ui-2.0.0.vsix \
  extensions/vscode/token-controller-ui-2.0.0.vsix.sha256
```

## Release assets

| Asset | Source |
| --- | --- |
| `token-controller-ui-2.0.0.vsix` | `extensions/vscode`, step 3 |
| `token-controller-ui-2.0.0.vsix.sha256` | step 3 |
| Source code (zip, tar.gz) | added by GitHub for the tag |

The CLI is installed from a git clone (`scripts/install-wsl.sh`). It is not a release asset.
