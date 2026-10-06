import * as assert from 'assert';
import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';
import { execFileSync } from 'child_process';
import { CliError, isValidModeId, parseModes, parseStatus, resolveCli, runCli, WorkflowCli } from '../cli';

// These tests do not use the vscode module. They also run with plain mocha.
const REPO_CLI = path.join(__dirname, '..', '..', '..', '..', 'scripts', 'workflow-cli.sh');

function statusJson(overrides: Record<string, unknown> = {}): string {
	return JSON.stringify({
		schema_version: 1, profile: 'code', risk: 'normal', output_style: 'ste-inspired', rtk_mode: 'success-only',
		leanctx_mode: 'auto', headroom_mode: 'reversible', caveman_mode: 'off', source: 'active_env_file',
		active_env_file: '/home/u/.config/ai-workflow/active_mode.env', shell_profile: null, stale_shell: false, ...overrides
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

		test('an unknown mode fails and does not change the active mode', async () => {
			const cli = new WorkflowCli(REPO_CLI, env);
			await cli.setMode('code');
			await assert.rejects(cli.setMode('nosuchmode'), (e: CliError) => e.kind === 'failed');
			assert.strictEqual((await cli.status()).profile, 'code');
		});
	});
});
