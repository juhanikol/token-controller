import * as assert from 'assert';
import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';
import { findProjectControlled } from '../trust';

// These tests do not use the vscode module. They also run with plain mocha.
const EXTENSION_ROOT = path.join(__dirname, '..', '..');

suite('Security model', () => {
	let tempDir: string;

	setup(() => {
		tempDir = fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(), 'tc-ext-trust-')));
	});

	teardown(() => {
		fs.rmSync(tempDir, { recursive: true, force: true });
	});

	function file(...parts: string[]): string {
		const target = path.join(tempDir, ...parts);
		fs.mkdirSync(path.dirname(target), { recursive: true });
		fs.writeFileSync(target, '');
		return target;
	}

	test('a controller outside the workspace is not project-controlled', () => {
		const controller = file('controller', 'scripts', 'workflow.sh');
		const workspace = path.join(tempDir, 'workspace');
		fs.mkdirSync(workspace);
		assert.strictEqual(findProjectControlled([controller], [workspace]).projectControlled, false);
		assert.strictEqual(findProjectControlled([controller], []).projectControlled, false);
	});

	test('a controller inside the workspace is project-controlled', () => {
		const controller = file('workspace', 'scripts', 'workflow.sh');
		const result = findProjectControlled([controller], [path.join(tempDir, 'workspace')]);
		assert.strictEqual(result.projectControlled, true);
		assert.strictEqual(result.file, controller);
	});

	test('a workspace that contains the controller folder is project-controlled', () => {
		const controller = file('projects', 'token-controller', 'scripts', 'workflow.sh');
		assert.strictEqual(findProjectControlled([controller], [path.join(tempDir, 'projects')]).projectControlled, true);
	});

	test('a folder with the same name prefix is not the same folder', () => {
		const controller = file('ws2', 'scripts', 'workflow.sh');
		fs.mkdirSync(path.join(tempDir, 'ws'));
		assert.strictEqual(findProjectControlled([controller], [path.join(tempDir, 'ws')]).projectControlled, false);
	});

	test('a symlink that leads into the workspace is detected', function () {
		const inside = file('workspace', 'inner', 'workflow.sh');
		const link = path.join(tempDir, 'link');
		try {
			fs.symlinkSync(path.dirname(inside), link);
		} catch {
			this.skip();
		}
		// The user setting points at "link/workflow.sh", outside the workspace, but the real file is inside.
		assert.strictEqual(findProjectControlled([path.join(link, 'workflow.sh')], [path.join(tempDir, 'workspace')]).projectControlled, true);
	});

	test('a symlink inside the workspace that leads outside is detected', function () {
		const outside = file('elsewhere', 'workflow.sh');
		const workspace = path.join(tempDir, 'workspace');
		fs.mkdirSync(workspace);
		try {
			fs.symlinkSync(path.dirname(outside), path.join(workspace, 'ctrl'));
		} catch {
			this.skip();
		}
		// The workspace controls the symlink, so the path as given is project-controlled.
		assert.strictEqual(findProjectControlled([path.join(workspace, 'ctrl', 'workflow.sh')], [workspace]).projectControlled, true);
	});

	test('paths that do not exist do not throw', () => {
		assert.strictEqual(findProjectControlled([path.join(tempDir, 'nope', 'workflow.sh')], [path.join(tempDir, 'ws')]).projectControlled, false);
	});

	test('manifest: scriptPath has machine scope and is restricted in untrusted workspaces', () => {
		const manifest = JSON.parse(fs.readFileSync(path.join(EXTENSION_ROOT, 'package.json'), 'utf8'));
		const setting = manifest.contributes.configuration.properties['tokenController.scriptPath'];
		assert.strictEqual(setting.scope, 'machine');
		assert.strictEqual(manifest.capabilities.untrustedWorkspaces.supported, 'limited');
		assert.ok(manifest.capabilities.untrustedWorkspaces.restrictedConfigurations.includes('tokenController.scriptPath'));
		assert.deepStrictEqual(manifest.extensionKind, ['workspace']);
	});

	test('source: processes are started with execFile and an argument array, never a shell string', function () {
		const srcDir = path.join(EXTENSION_ROOT, 'src');
		if (!fs.existsSync(srcDir)) {
			this.skip();
		}
		const sources = fs.readdirSync(srcDir).filter((name) => name.endsWith('.ts')).map((name) => [name, fs.readFileSync(path.join(srcDir, name), 'utf8')]);
		assert.ok(sources.length > 0);
		for (const [name, text] of sources) {
			assert.ok(!/\bexec\s*\(/.test(text), `${name}: exec( builds a shell command`);
			assert.ok(!/\b(execSync|execFileSync|spawnSync|spawn|fork)\s*\(/.test(text), `${name}: unexpected process call`);
			assert.ok(!/shell\s*:\s*(true|['"`])/.test(text), `${name}: shell option`);
			assert.ok(!/['"`]-c['"`]/.test(text), `${name}: bash -c string`);
		}
		const cli = String(sources.find(([name]) => name === 'cli.ts')?.[1]);
		assert.ok(/import \{ execFile \} from 'child_process'/.test(cli));
		assert.ok(/execFile\(\s*'bash',\s*\[cliPath, \.\.\.args\]/.test(cli));
	});

	test('source: only cli.ts starts processes, and the setup code has no shell string, no bash -c, and no install command', function () {
		const srcDir = path.join(EXTENSION_ROOT, 'src');
		if (!fs.existsSync(srcDir)) {
			this.skip();
		}
		for (const name of fs.readdirSync(srcDir).filter((file) => file.endsWith('.ts'))) {
			const text = fs.readFileSync(path.join(srcDir, name), 'utf8');
			if (name !== 'cli.ts') {
				assert.ok(!/child_process/.test(text), `${name}: starts processes outside cli.ts`);
			}
			// The extension never installs a tool or edits agent or MCP settings. The words may appear in texts that explain this.
			assert.ok(!/['"`](rtk|lean-ctx|caveman)['"`]\s*,\s*['"`](init|setup|wrap|onboard|install)['"`]/.test(text), `${name}: runs an optional tool command`);
			assert.ok(!/mcp\.json|writeFileSync|appendFileSync/.test(text), `${name}: writes files or touches MCP config`);
		}
		const manifest = JSON.parse(fs.readFileSync(path.join(EXTENSION_ROOT, 'package.json'), 'utf8'));
		const ids = manifest.contributes.commands.map((command: { command: string }) => command.command);
		for (const id of ['tokenController.setupHelp', 'tokenController.initProject', 'tokenController.checkTools']) {
			assert.ok(ids.includes(id), id);
		}
		assert.strictEqual(manifest.contributes.configuration.properties['tokenController.promptToInitialize'].default, true);
	});

	test('source: the only LeanCTX call is "leanctx status --json" (no read, read-exact, search, or tree)', function () {
		const srcDir = path.join(EXTENSION_ROOT, 'src');
		if (!fs.existsSync(srcDir)) {
			this.skip();
		}
		for (const name of fs.readdirSync(srcDir).filter((file) => file.endsWith('.ts'))) {
			const text = fs.readFileSync(path.join(srcDir, name), 'utf8');
			const calls = text.match(/\[\s*'leanctx'[^\]]*\]/g) ?? [];
			for (const call of calls) {
				assert.strictEqual(call.replace(/\s+/g, ''), "['leanctx','status','--json']", `${name}: unexpected LeanCTX call ${call}`);
			}
			// The codicon name 'search' in extension.ts is not a command, so the word is only checked in cli.ts.
			assert.ok(!/['"`](read-exact|tree)['"`]/.test(text) && (name !== 'cli.ts' || !/['"`]search['"`]/.test(text)), `${name}: a LeanCTX read, search, or tree command`);
		}
		const manifest = JSON.parse(fs.readFileSync(path.join(EXTENSION_ROOT, 'package.json'), 'utf8'));
		const ids = manifest.contributes.commands.map((command: { command: string }) => command.command);
		assert.ok(ids.includes('tokenController.showLeanctxStatus'));
		assert.deepStrictEqual(ids.filter((id: string) => /leanctx/i.test(id)), ['tokenController.showLeanctxStatus']);
	});
});
