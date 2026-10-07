import * as assert from 'assert';
import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';
import { execFileSync } from 'child_process';
import { CliError, formatLeanctxStatus, isValidModeId, parseLeanctxStatus, parseModes, parseStatus, resolveCli, runCli, WorkflowCli } from '../cli';

// These tests do not use the vscode module. They also run with plain mocha.
const REPO_CLI = path.join(__dirname, '..', '..', '..', '..', 'scripts', 'workflow-cli.sh');

function statusJson(overrides: Record<string, unknown> = {}): string {
	return JSON.stringify({
		schema_version: 1, profile: 'code', risk: 'normal', output_style: 'ste-inspired', rtk_mode: 'success-only',
		leanctx_mode: 'auto', headroom_mode: 'reversible', caveman_mode: 'off', source: 'active_env_file',
		active_env_file: '/home/u/.config/ai-workflow/active_mode.env', shell_profile: null, stale_shell: false, ...overrides
	});
}

function leanctxJson(overrides: Record<string, unknown> = {}): string {
	return JSON.stringify({
		schema_version: 1, profile: 'code', leanctx_mode: 'auto', binary: '/home/u/.local/bin/lean-ctx', resolved_path: '/home/u/.local/bin/lean-ctx',
		platform_path: 'linux', version: 'lean-ctx 3.9.19', allowed: true, reasons: [],
		policy: { shell_enabled: 'false', shell_owner: 'wx', auto_wrap: 'false', auto_setup: 'false', auto_init: 'false', operations: { read: 'enabled', search: 'enabled', tree: 'enabled' } },
		status_command: 'not run: lean-ctx status writes a report file', ...overrides
	});
}

suite('CLI adapter', () => {
	let tempDir: string;

	setup(() => {
		tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'tc-ext-test-'));
	});

	teardown(() => {
		fs.rmSync(tempDir, { recursive: true, force: true });
	});

	function makeController(cliBody: string, dirName = 'scripts'): { scriptPath: string; cliPath: string } {
		const dir = path.join(tempDir, dirName);
		fs.mkdirSync(dir, { recursive: true });
		const scriptPath = path.join(dir, 'workflow.sh');
		const cliPath = path.join(dir, 'workflow-cli.sh');
		fs.writeFileSync(scriptPath, '');
		fs.writeFileSync(cliPath, cliBody);
		return { scriptPath, cliPath };
	}

	test('mode ids: accepts config ids, rejects shell syntax', () => {
		for (const id of ['code', 'test-full', 'rapid-prototype', 'micro']) {
			assert.strictEqual(isValidModeId(id), true, id);
		}
		for (const id of ['', 'Code', 'a b', 'code;rm', '$(id)', '`id`', '../x', '-x', 'a'.repeat(41), 5, null]) {
			assert.strictEqual(isValidModeId(id), false, String(id));
		}
	});

	test('resolveCli finds workflow-cli.sh beside workflow.sh and rejects bad paths', () => {
		assert.strictEqual(resolveCli(undefined).ok, false);
		assert.strictEqual(resolveCli('workflow.sh').ok, false);
		assert.strictEqual(resolveCli(path.join(tempDir, 'evil.sh')).ok, false);
		const noCli = path.join(tempDir, 'only', 'workflow.sh');
		fs.mkdirSync(path.dirname(noCli));
		fs.writeFileSync(noCli, '');
		assert.strictEqual(resolveCli(noCli).ok, false, 'missing workflow-cli.sh');
		const { scriptPath, cliPath } = makeController('');
		const resolved = resolveCli(scriptPath);
		assert.strictEqual(resolved.ok, true);
		assert.strictEqual(resolved.ok && resolved.cliPath, cliPath);
	});

	test('parseStatus reads the CLI schema and cleans values', () => {
		const status = parseStatus(statusJson({ profile: 'security', risk: 'critical', shell_profile: 'code', stale_shell: true }));
		assert.strictEqual(status.profile, 'security');
		assert.strictEqual(status.risk, 'critical');
		assert.strictEqual(status.shellProfile, 'code');
		assert.strictEqual(status.staleShell, true);
		assert.strictEqual(status.source, 'active_env_file');
		assert.strictEqual(parseStatus(statusJson({ profile: null, risk: null, source: 'unset' })).profile, null);
		assert.strictEqual(parseStatus(statusJson({ profile: '$(touch x)' })).profile, 'unknown');
		assert.strictEqual(parseStatus(statusJson({ shell_profile: 'a b', stale_shell: true })).shellProfile, 'unknown');
	});

	test('parseStatus and parseModes reject bad output', () => {
		assert.throws(() => parseStatus('not json'), (e: CliError) => e.kind === 'invalid-output');
		assert.throws(() => parseStatus('[]'), (e: CliError) => e.kind === 'invalid-output');
		assert.throws(() => parseStatus(statusJson({ schema_version: 2 })), (e: CliError) => e.kind === 'unsupported-schema');
		assert.throws(() => parseStatus(statusJson({ source: 'other' })), (e: CliError) => e.kind === 'invalid-output');
		assert.throws(() => parseStatus(statusJson({ stale_shell: 'no' })), (e: CliError) => e.kind === 'invalid-output');
		assert.throws(() => parseModes(JSON.stringify({ schema_version: 1, modes: [] })), (e: CliError) => e.kind === 'invalid-output');
		assert.throws(() => parseModes(JSON.stringify({ schema_version: 1, modes: [{ name: 'bad id;' }] })), (e: CliError) => e.kind === 'invalid-output');
		assert.throws(() => parseModes(JSON.stringify({ schema_version: 3, modes: [] })), (e: CliError) => e.kind === 'unsupported-schema');
	});

	test('parseLeanctxStatus reads an allowed status', () => {
		const status = parseLeanctxStatus(leanctxJson());
		assert.strictEqual(status.allowed, true);
		assert.deepStrictEqual(status.reasons, []);
		assert.strictEqual(status.profile, 'code');
		assert.strictEqual(status.leanctxMode, 'auto');
		assert.strictEqual(status.binary, '/home/u/.local/bin/lean-ctx');
		assert.strictEqual(status.platformPath, 'linux');
		assert.strictEqual(status.version, 'lean-ctx 3.9.19');
		assert.strictEqual(status.policy.shellEnabled, 'false');
		assert.strictEqual(status.policy.shellOwner, 'wx');
		assert.strictEqual(status.policy.autoWrap, 'false');
		assert.deepStrictEqual(status.policy.operations, { read: 'enabled', search: 'enabled', tree: 'enabled' });
		const lines = formatLeanctxStatus(status);
		assert.strictEqual(lines[0], 'LeanCTX adapter: allowed');
		assert.ok(lines.some((line) => line.includes('Operations: read=enabled, search=enabled, tree=enabled')));
		assert.ok(!lines.some((line) => line.includes('Why not')));
	});

	test('parseLeanctxStatus reads a refused status with reasons', () => {
		const status = parseLeanctxStatus(leanctxJson({
			profile: 'security', leanctx_mode: 'off', binary: null, resolved_path: null, platform_path: null, version: null, allowed: false,
			reasons: ["profile 'security' does not use LeanCTX", 'AICONTEXT_LEANCTX_MODE is off for profile \'security\'']
		}));
		assert.strictEqual(status.allowed, false);
		assert.strictEqual(status.reasons.length, 2);
		assert.strictEqual(status.binary, null);
		assert.strictEqual(status.platformPath, null);
		const lines = formatLeanctxStatus(status);
		assert.strictEqual(lines[0], 'LeanCTX adapter: refused');
		assert.ok(lines.includes('  Why not:'));
		assert.ok(lines.some((line) => line.includes("profile 'security' does not use LeanCTX")));
		// Odd values are cleaned: control characters are removed, a profile that is not an id becomes "unknown", long text is cut.
		const odd = parseLeanctxStatus(leanctxJson({ profile: '$(id)', allowed: false, reasons: ['line1\nline2\u001b[31m' + 'x'.repeat(500)], platform_path: 'plan9' }));
		assert.strictEqual(odd.profile, 'unknown');
		assert.strictEqual(odd.platformPath, null);
		assert.ok(!/[\u0000-\u001f]/.test(odd.reasons[0]));
		assert.ok(odd.reasons[0].length <= 300);
	});

	test('parseLeanctxStatus rejects bad output and fails closed', () => {
		assert.throws(() => parseLeanctxStatus('not json'), (e: CliError) => e.kind === 'invalid-output');
		assert.throws(() => parseLeanctxStatus('[]'), (e: CliError) => e.kind === 'invalid-output');
		assert.throws(() => parseLeanctxStatus(leanctxJson({ schema_version: 2 })), (e: CliError) => e.kind === 'unsupported-schema');
		assert.throws(() => parseLeanctxStatus(leanctxJson({ schema_version: undefined })), (e: CliError) => e.kind === 'unsupported-schema');
		assert.throws(() => parseLeanctxStatus(leanctxJson({ allowed: 'yes' })), (e: CliError) => e.kind === 'invalid-output');
		assert.throws(() => parseLeanctxStatus(leanctxJson({ reasons: 'no' })), (e: CliError) => e.kind === 'invalid-output');
		assert.throws(() => parseLeanctxStatus(leanctxJson({ reasons: [1] })), (e: CliError) => e.kind === 'invalid-output');
		assert.throws(() => parseLeanctxStatus(leanctxJson({ policy: null })), (e: CliError) => e.kind === 'invalid-output');
		// Allowed with a reason, or refused with no reason, is not trusted.
		assert.throws(() => parseLeanctxStatus(leanctxJson({ allowed: true, reasons: ['mode is off'] })), (e: CliError) => e.kind === 'invalid-output');
		assert.throws(() => parseLeanctxStatus(leanctxJson({ allowed: false, reasons: [] })), (e: CliError) => e.kind === 'invalid-output');
	});

	test('parseModes keeps valid modes and aliases', () => {
		const result = parseModes(JSON.stringify({
			schema_version: 1,
			modes: [{ name: 'code', description: 'Normal.', risk: 'normal' }, { name: 'bad id' }, { name: 'security', risk: 'critical', description: null }],
			aliases: [{ alias: 'plan', target: 'architect' }, { alias: 'x y', target: 'code' }]
		}));
		assert.deepStrictEqual(result.modes.map((mode) => mode.name), ['code', 'security']);
		assert.strictEqual(result.modes[1].description, null);
		assert.deepStrictEqual(result.aliases, [{ alias: 'plan', target: 'architect' }]);
	});

	test('runCli passes path and arguments as arguments, not as shell text', async function () {
		if (process.platform === 'win32') {
			this.skip();
		}
		// A folder name with quotes and command substitution. If it were in a shell string it would run "touch".
		const out = path.join(tempDir, 'args.txt');
		const { cliPath } = makeController(`printf '%s|' "$@" > '${out}'\n`, `a b'"$(touch INJECTED)`);
		await runCli(cliPath, ['status', '--json', 'x y'], 5000);
		assert.strictEqual(fs.readFileSync(out, 'utf8'), 'status|--json|x y|');
		for (const dir of [process.cwd(), path.dirname(cliPath), tempDir]) {
			assert.strictEqual(fs.existsSync(path.join(dir, 'INJECTED')), false, `path text was run as a command (${dir})`);
		}
	});

	test('WorkflowCli.setMode rejects an invalid id before it starts a process', async () => {
		const ran = path.join(tempDir, 'RAN');
		const { cliPath } = makeController(`touch '${ran}'\n`);
		await assert.rejects(new WorkflowCli(cliPath).setMode('code; touch x'), /Invalid mode id/);
		assert.strictEqual(fs.existsSync(ran), false);
	});

	test('WorkflowCli reports CLI failure with the CLI message and no fallback', async function () {
		if (process.platform === 'win32') {
			this.skip();
		}
		const { cliPath } = makeController('echo "jq is missing" >&2\nexit 1\n');
		const cli = new WorkflowCli(cliPath);
		await assert.rejects(cli.modes(), (e: CliError) => e.kind === 'failed' && /jq is missing/.test(e.message));
		await assert.rejects(cli.status(), (e: CliError) => e.kind === 'failed');
	});

	test('WorkflowCli.leanctxStatus calls only "leanctx status --json" and surfaces a CLI failure safely', async function () {
		if (process.platform === 'win32') {
			this.skip();
		}
		const log = path.join(tempDir, 'calls.txt');
		const ok = makeController(`printf '%s|' "$@" >> '${log}'\necho '${leanctxJson()}'\n`, 'ok');
		const status = await new WorkflowCli(ok.cliPath).leanctxStatus();
		assert.strictEqual(status.allowed, true);
		assert.strictEqual(fs.readFileSync(log, 'utf8'), 'leanctx|status|--json|');
		// A failure shows the CLI message (cut to 300 characters), and no status is made up.
		const bad = makeController('echo "jq is missing" >&2\nexit 1\n', 'bad');
		await assert.rejects(new WorkflowCli(bad.cliPath).leanctxStatus(), (e: CliError) => e.kind === 'failed' && /jq is missing/.test(e.message));
		const loud = makeController(`printf 'x%.0s' $(seq 1 1000) >&2\nexit 2\n`, 'loud');
		await assert.rejects(new WorkflowCli(loud.cliPath).leanctxStatus(), (e: CliError) => e.kind === 'failed' && e.message.length <= 300);
		// Valid JSON of the wrong schema, or text instead of JSON, is rejected.
		const wrong = makeController(`echo '${leanctxJson({ schema_version: 9 })}'\n`, 'wrong');
		await assert.rejects(new WorkflowCli(wrong.cliPath).leanctxStatus(), (e: CliError) => e.kind === 'unsupported-schema');
		const text = makeController('echo "LeanCTX adapter status"\n', 'text');
		await assert.rejects(new WorkflowCli(text.cliPath).leanctxStatus(), (e: CliError) => e.kind === 'invalid-output');
	});

	test('WorkflowCli reads status and modes from CLI output', async function () {
		if (process.platform === 'win32') {
			this.skip();
		}
		const modes = JSON.stringify({ schema_version: 1, modes: [{ name: 'code', description: 'Normal.', risk: 'normal' }], aliases: [] });
		const body = `case "$1" in\n  status) echo '${statusJson()}' ;;\n  modes) echo '${modes}' ;;\n  *) echo "mode $1" ;;\nesac\n`;
		const { cliPath } = makeController(body);
		const cli = new WorkflowCli(cliPath);
		assert.strictEqual((await cli.status()).profile, 'code');
		assert.deepStrictEqual((await cli.modes()).modes.map((mode) => mode.name), ['code']);
		await cli.setMode('code');
	});

	suite('against the repository CLI', () => {
		let configDir: string;
		let env: NodeJS.ProcessEnv;

		suiteSetup(function () {
			let hasJq = true;
			try {
				execFileSync('jq', ['--version'], { stdio: 'ignore' });
			} catch {
				hasJq = false;
			}
			if (process.platform === 'win32' || !fs.existsSync(REPO_CLI) || !hasJq) {
				this.skip();
			}
		});

		setup(() => {
			configDir = path.join(tempDir, 'config');
			fs.mkdirSync(configDir);
			const clean: NodeJS.ProcessEnv = {};
			for (const [key, value] of Object.entries(process.env)) {
				if (!key.startsWith('AICONTEXT_')) {
					clean[key] = value;
				}
			}
			env = { ...clean, AICONTEXT_CONFIG_DIR: configDir };
		});

		test('modes --json matches the settings file and has micro, docs, release, security, db', async () => {
			const cli = new WorkflowCli(REPO_CLI, env);
			const { modes, aliases } = await cli.modes();
			const settings = JSON.parse(fs.readFileSync(path.join(path.dirname(REPO_CLI), '..', 'config', 'workflow_settings.json'), 'utf8'));
			assert.deepStrictEqual(modes.map((mode) => mode.name), Object.keys(settings.modes));
			for (const name of ['micro', 'docs', 'release', 'security', 'db']) {
				assert.ok(modes.some((mode) => mode.name === name), name);
			}
			assert.ok(modes.every((mode) => mode.description && mode.description.length > 0));
			assert.ok(aliases.some((alias) => alias.alias === 'plan' && alias.target === 'architect'));
		});

		test('status --json without a mode file, then setMode updates it, and stale shell is reported', async () => {
			const cli = new WorkflowCli(REPO_CLI, env);
			const before = await cli.status();
			assert.strictEqual(before.profile, null);
			assert.strictEqual(before.source, 'unset');

			await cli.setMode('micro');
			const after = await cli.status();
			assert.strictEqual(after.profile, 'micro');
			assert.strictEqual(after.risk, 'normal');
			assert.strictEqual(after.source, 'active_env_file');
			assert.strictEqual(after.staleShell, false);
			assert.strictEqual(after.activeEnvFile, path.join(configDir, 'active_mode.env'));

			const stale = await new WorkflowCli(REPO_CLI, { ...env, AICONTEXT_PROFILE: 'code' }).status();
			assert.strictEqual(stale.profile, 'micro');
			assert.strictEqual(stale.shellProfile, 'code');
			assert.strictEqual(stale.staleShell, true);
		});

		test('leanctx status --json: refused for a protected mode, with reasons, and nothing is read or searched', async () => {
			const cli = new WorkflowCli(REPO_CLI, { ...env, AICONTEXT_LEANCTX_BIN: '' });
			assert.strictEqual((await cli.leanctxStatus(tempDir)).allowed, false, 'no mode file');
			await cli.setMode('security');
			const refused = await cli.leanctxStatus(tempDir);
			assert.strictEqual(refused.allowed, false);
			assert.strictEqual(refused.profile, 'security');
			assert.strictEqual(refused.leanctxMode, 'off');
			assert.ok(refused.reasons.some((reason) => reason.includes('security')), refused.reasons.join(' | '));
			assert.strictEqual(refused.policy.shellEnabled, 'false');
			assert.strictEqual(refused.policy.shellOwner, 'wx');
			assert.deepStrictEqual(refused.policy.operations, { read: 'enabled', search: 'enabled', tree: 'enabled' });
			assert.ok(refused.statusCommand && refused.statusCommand.startsWith('not run'));
			// An allowed mode with no lean-ctx binary is refused for that reason.
			await cli.setMode('code');
			const noBinary = await cli.leanctxStatus(tempDir);
			assert.strictEqual(noBinary.allowed, false);
			assert.strictEqual(noBinary.leanctxMode, 'auto');
			assert.ok(noBinary.reasons.some((reason) => reason.includes('lean-ctx was not found')), noBinary.reasons.join(' | '));
		});

		test('an unknown mode fails and does not change the active mode', async () => {
			const cli = new WorkflowCli(REPO_CLI, env);
			await cli.setMode('code');
			await assert.rejects(cli.setMode('nosuchmode'), (e: CliError) => e.kind === 'failed');
			assert.strictEqual((await cli.status()).profile, 'code');
		});
	});
});
