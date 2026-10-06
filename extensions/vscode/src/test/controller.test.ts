import * as assert from 'assert';
import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';
import { resolveScriptPath, runModeSwitch } from '../controller';
import { FALLBACK_MODES, isValidModeId, loadModes, parseModes } from '../modes';

// These tests do not use the vscode module. They also run with plain mocha.
suite('Controller and mode helpers', () => {
	let tempDir: string;

	setup(() => {
		tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'tc-ext-test-'));
	});

	teardown(() => {
		fs.rmSync(tempDir, { recursive: true, force: true });
	});

	test('mode ids: accepts config ids, rejects shell syntax', () => {
		for (const id of ['code', 'test-full', 'rapid-prototype', 'micro']) {
			assert.strictEqual(isValidModeId(id), true, id);
		}
		for (const id of ['', 'Code', 'a b', 'code;rm', '$(id)', '`id`', '../x', '-x', 'a'.repeat(41)]) {
			assert.strictEqual(isValidModeId(id), false, id);
		}
	});

	test('parseModes keeps valid modes and drops invalid ids', () => {
		const modes = parseModes({
			modes: {
				code: { risk: 'normal', description: 'Normal work.' },
				'bad id; rm': { risk: 'high' },
				security: { risk: 'CRITICAL!', description: 'a\nb' }
			}
		});
		assert.deepStrictEqual(modes.map((mode) => mode.id), ['code', 'security']);
		assert.strictEqual(modes[0].risk, 'normal');
		assert.strictEqual(modes[1].risk, undefined);
		assert.strictEqual(modes[1].description, 'a b');
		assert.deepStrictEqual(parseModes(null), []);
		assert.deepStrictEqual(parseModes({ modes: [] }), []);
	});

	test('loadModes reads the config beside the script and falls back when it is missing', () => {
		const scriptsDir = path.join(tempDir, 'scripts');
		const configDir = path.join(tempDir, 'config');
		fs.mkdirSync(scriptsDir);
		fs.mkdirSync(configDir);
		fs.writeFileSync(path.join(configDir, 'workflow_settings.json'), JSON.stringify({ modes: { code: { risk: 'normal', description: 'x' }, newmode: { risk: 'high' } } }));
		const loaded = loadModes(path.join(scriptsDir, 'workflow.sh'));
		assert.strictEqual(loaded.source, 'config');
		assert.deepStrictEqual(loaded.modes.map((mode) => mode.id), ['code', 'newmode']);

		const missing = loadModes(path.join(tempDir, 'nowhere', 'scripts', 'workflow.sh'));
		assert.strictEqual(missing.source, 'fallback');
		assert.strictEqual(missing.modes, FALLBACK_MODES);
	});

	test('built-in fallback matches the repository config', () => {
		const repoConfig = path.join(__dirname, '..', '..', '..', '..', 'config', 'workflow_settings.json');
		if (!fs.existsSync(repoConfig)) {
			return; // Running from a packaged copy. Nothing to compare.
		}
		const fromConfig = parseModes(JSON.parse(fs.readFileSync(repoConfig, 'utf8')));
		assert.deepStrictEqual(FALLBACK_MODES, fromConfig);
	});

	test('resolveScriptPath rejects relative paths, wrong names, and missing files', () => {
		assert.strictEqual(resolveScriptPath(undefined).ok, false);
		assert.strictEqual(resolveScriptPath('workflow.sh').ok, false);
		assert.strictEqual(resolveScriptPath(path.join(tempDir, 'evil.sh')).ok, false);
		assert.strictEqual(resolveScriptPath(path.join(tempDir, 'workflow.sh')).ok, false);
		const script = path.join(tempDir, 'workflow.sh');
		fs.writeFileSync(script, '');
		const resolved = resolveScriptPath(script);
		assert.strictEqual(resolved.ok, true);
	});

	test('runModeSwitch passes path and mode as arguments, not as shell text', async function () {
		if (process.platform === 'win32') {
			this.skip();
		}
		// A path with spaces, quotes, and command substitution. If it were put into a shell string it would run "touch".
		const dirName = `a b'"$(touch INJECTED)`;
		const scriptDir = path.join(tempDir, dirName);
		fs.mkdirSync(scriptDir);
		const script = path.join(scriptDir, 'workflow.sh');
		const out = path.join(tempDir, 'args.txt');
		fs.writeFileSync(script, `printf '%s' "$1" > '${out}'\n`);

		await runModeSwitch(script, 'micro');
		assert.strictEqual(fs.readFileSync(out, 'utf8'), 'micro');
		for (const dir of [process.cwd(), scriptDir, tempDir]) {
			assert.strictEqual(fs.existsSync(path.join(dir, 'INJECTED')), false, `path text was run as a command (${dir})`);
		}
	});

	test('runModeSwitch rejects an invalid mode before it starts a process', async () => {
		const script = path.join(tempDir, 'workflow.sh');
		fs.writeFileSync(script, `touch '${path.join(tempDir, 'RAN')}'\n`);
		await assert.rejects(runModeSwitch(script, 'code; touch x'), /Invalid mode id/);
		assert.strictEqual(fs.existsSync(path.join(tempDir, 'RAN')), false);
	});

	test('runModeSwitch reports script failure', async function () {
		if (process.platform === 'win32') {
			this.skip();
		}
		const script = path.join(tempDir, 'workflow.sh');
		fs.writeFileSync(script, 'echo "profile not found" >&2\nreturn 1\n');
		await assert.rejects(runModeSwitch(script, 'code'), /profile not found/);
	});
});
