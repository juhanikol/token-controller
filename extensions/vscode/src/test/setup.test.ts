import * as assert from 'assert';
import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';
import { CliError, resolveCli, WorkflowCli } from '../cli';
import {
	checkOptionalTools, classifyCli, INSTALL_COMMAND, initializeProject, MANAGED_END, MANAGED_START, parseToolCheck, readProjectInit, SETUP_GUIDE_URL
} from '../setup';

// These tests do not use the vscode module. They also run with plain mocha.
const REPO_CLI = path.join(__dirname, '..', '..', '..', '..', 'scripts', 'workflow-cli.sh');

suite('First-run setup', () => {
	let tempDir: string;

	setup(() => {
		tempDir = fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(), 'tc-setup-test-')));
	});

	teardown(() => {
		fs.rmSync(tempDir, { recursive: true, force: true });
	});

	function makeController(cliBody: string, checkToolsBody?: string): string {
		const dir = path.join(tempDir, 'controller', 'scripts');
		fs.mkdirSync(dir, { recursive: true });
		fs.writeFileSync(path.join(dir, 'workflow.sh'), '');
		fs.writeFileSync(path.join(dir, 'workflow-cli.sh'), cliBody);
		fs.rmSync(path.join(dir, 'check-tools.sh'), { force: true });
		if (checkToolsBody !== undefined) {
			fs.writeFileSync(path.join(dir, 'check-tools.sh'), checkToolsBody);
		}
		return path.join(dir, 'workflow-cli.sh');
	}

	function makeProject(name = 'project'): string {
		const dir = path.join(tempDir, name);
		fs.mkdirSync(dir, { recursive: true });
		return dir;
	}

	test('a missing controller CLI maps to the setup-needed state, with the reason', () => {
		const missing = classifyCli(resolveCli(path.join(tempDir, 'nope', 'workflow.sh')));
		assert.strictEqual(missing.state, 'setup-needed');
		assert.ok(missing.state === 'setup-needed' && /Not found/.test(missing.reason), JSON.stringify(missing));
		const unset = classifyCli(resolveCli(undefined));
		assert.strictEqual(unset.state, 'setup-needed');
		assert.strictEqual(classifyCli(resolveCli('relative/workflow.sh')).state, 'setup-needed');
		assert.strictEqual(classifyCli(resolveCli(path.join(tempDir, 'evil.sh'))).state, 'setup-needed');
		// A controller that is there is ready.
		const cli = makeController('');
		assert.strictEqual(classifyCli(resolveCli(path.join(path.dirname(cli), 'workflow.sh'))).state, 'ready');
		// The setup actions point to the install guide and a command that runs install-wsl.sh and installs no optional tool.
		assert.ok(SETUP_GUIDE_URL.startsWith('https://github.com/'));
		assert.ok(INSTALL_COMMAND.includes('scripts/install-wsl.sh') && !/rtk|lean-ctx|caveman|headroom|sudo/.test(INSTALL_COMMAND));
	});

	test('a project without the AGENTS.md marker maps to the uninitialized state', () => {
		const none = makeProject('none');
		assert.strictEqual(readProjectInit(none).state, 'not-initialized');
		const plain = makeProject('plain');
		fs.writeFileSync(path.join(plain, 'AGENTS.md'), '# My own rules\n');
		assert.strictEqual(readProjectInit(plain).state, 'not-initialized');
		const done = makeProject('done');
		fs.writeFileSync(path.join(done, 'AGENTS.md'), `# Mine\n${MANAGED_START}\nrules\n${MANAGED_END}\n`);
		assert.strictEqual(readProjectInit(done).state, 'initialized');
		const half = makeProject('half');
		fs.writeFileSync(path.join(half, 'AGENTS.md'), `${MANAGED_START}\nrules\n`);
		assert.strictEqual(readProjectInit(half).state, 'incomplete');
		const reversed = makeProject('reversed');
		fs.writeFileSync(path.join(reversed, 'AGENTS.md'), `${MANAGED_END}\n${MANAGED_START}\n`);
		assert.strictEqual(readProjectInit(reversed).state, 'incomplete');
		// A symbolic link is not followed ("workflow init" refuses it too).
		const linked = makeProject('linked');
		fs.writeFileSync(path.join(tempDir, 'real.md'), `${MANAGED_START}\n${MANAGED_END}\n`);
		fs.symlinkSync(path.join(tempDir, 'real.md'), path.join(linked, 'AGENTS.md'));
		assert.strictEqual(readProjectInit(linked).state, 'unknown');
		// A folder that does not exist does not throw.
		assert.strictEqual(readProjectInit(path.join(tempDir, 'gone')).state, 'not-initialized');
	});

	test('the initialize command refuses an untrusted workspace and runs nothing', async function () {
		if (process.platform === 'win32') {
			this.skip();
		}
		const ran = path.join(tempDir, 'RAN');
		const cli = new WorkflowCli(makeController(`touch '${ran}'\n`));
		const project = makeProject();
		await assert.rejects(initializeProject(cli, project, false), (e: CliError) => /not trusted/.test(e.message));
		assert.strictEqual(fs.existsSync(ran), false, 'the CLI was started in an untrusted workspace');
		assert.strictEqual(fs.existsSync(path.join(project, 'AGENTS.md')), false);
	});

	test('the initialize command runs "init" with the workspace folder as the working directory', async function () {
		if (process.platform === 'win32') {
			this.skip();
		}
		const log = path.join(tempDir, 'call.txt');
		const body = `printf '%s|%s' "$PWD" "$*" > '${log}'\n`
			+ `if [ "$1" = init ]; then printf '%s\\nrules\\n%s\\n' '${MANAGED_START}' '${MANAGED_END}' > AGENTS.md; echo "Created AGENTS.md from template: $PWD/AGENTS.md"; fi\n`;
		const cliPath = makeController(body);
		const project = makeProject('my project; touch X');
		const result = await initializeProject(new WorkflowCli(cliPath), project, true);
		const [cwd, args] = fs.readFileSync(log, 'utf8').split('|');
		assert.strictEqual(cwd, project, 'the CLI did not start in the project folder');
		assert.notStrictEqual(cwd, path.dirname(cliPath));
		assert.strictEqual(args, 'init');
		assert.ok(result.output.startsWith('Created AGENTS.md'));
		assert.strictEqual(result.project.state, 'initialized');
		assert.strictEqual(fs.existsSync(path.join(project, 'AGENTS.md')), true);
		assert.strictEqual(fs.existsSync(path.join(path.dirname(cliPath), 'AGENTS.md')), false, 'AGENTS.md went to the controller folder');
		assert.strictEqual(fs.existsSync(path.join(project, 'X')), false, 'the folder name was run as a command');
		// Bad folders are refused before a process starts.
		await assert.rejects(initializeProject(new WorkflowCli(cliPath), 'relative/dir', true), /absolute/);
		await assert.rejects(initializeProject(new WorkflowCli(cliPath), path.join(tempDir, 'missing'), true), /Not a folder/);
		await assert.rejects(initializeProject(new WorkflowCli(cliPath), path.join(project, 'AGENTS.md'), true), /Not a folder/);
	});

	test('a failing init is surfaced with the CLI message', async function () {
		if (process.platform === 'win32') {
			this.skip();
		}
		const cli = new WorkflowCli(makeController('echo "Error: refusing to replace or follow an AGENTS.md symlink" >&2\nexit 1\n'));
		await assert.rejects(initializeProject(cli, makeProject(), true), (e: CliError) => e.kind === 'failed' && /symlink/.test(e.message));
	});

	test('parseToolCheck splits base tools from optional tools', () => {
		const text = [
			'AI Context Workflow tool check', 'OK      jq           /usr/bin/jq', 'jq-1.7', 'OK      git          /usr/bin/git',
			'MISSING curl. To install: sudo apt install -y curl', 'MISSING rtk. To install: review the RTK commands',
			'MISSING lean-ctx. To install core: cargo install lean-ctx', 'MISSING caveman. Optional. Off by default', 'MISSING MemStack. Legacy'
		].join('\n');
		const check = parseToolCheck(text);
		assert.deepStrictEqual(check.found, ['jq', 'git']);
		assert.deepStrictEqual(check.requiredMissing, ['curl']);
		assert.deepStrictEqual(check.optionalMissing, ['rtk', 'lean-ctx', 'caveman', 'MemStack']);
		assert.deepStrictEqual(parseToolCheck('nothing useful'), { found: [], missing: [], requiredMissing: [], optionalMissing: [] });
	});

	test('the optional tools check shows the output and does not fail when optional tools are missing', async function () {
		if (process.platform === 'win32') {
			this.skip();
		}
		const checkBody = 'echo "OK      jq /usr/bin/jq"\necho "OK      git /usr/bin/git"\necho "OK      curl /usr/bin/curl"\n'
			+ 'echo "MISSING rtk. Optional."\necho "MISSING lean-ctx. Optional."\nexit 0\n';
		const cli = new WorkflowCli(makeController('', checkBody));
		const result = await checkOptionalTools(cli);
		assert.ok(result.output.includes('MISSING rtk.'));
		assert.deepStrictEqual(result.check.optionalMissing, ['rtk', 'lean-ctx']);
		assert.deepStrictEqual(result.check.requiredMissing, []);
		// A missing base tool is also a result, not a thrown error. Only a script that cannot run is an error.
		const base = await checkOptionalTools(new WorkflowCli(makeController('', 'echo "MISSING jq. Install it"\n')));
		assert.deepStrictEqual(base.check.requiredMissing, ['jq']);
		await assert.rejects(new WorkflowCli(makeController('')).checkTools(), (e: CliError) => e.kind === 'unavailable' && /check-tools\.sh/.test(e.message));
	});

	test('the repository check-tools.sh runs through the adapter and reports tools', async function () {
		this.timeout(30000);
		if (process.platform === 'win32' || !fs.existsSync(REPO_CLI)) {
			this.skip();
		}
		const result = await checkOptionalTools(new WorkflowCli(REPO_CLI));
		assert.ok(result.output.includes('AI Context Workflow tool check'));
		assert.ok(result.check.found.length + result.check.missing.length > 3);
	});

	test('the repository CLI initializes a project folder (AGENTS.md in the folder, not in the controller)', async function () {
		this.timeout(30000);
		if (process.platform === 'win32' || !fs.existsSync(REPO_CLI)) {
			this.skip();
		}
		const env: NodeJS.ProcessEnv = {};
		for (const [key, value] of Object.entries(process.env)) {
			if (!key.startsWith('AICONTEXT_')) {
				env[key] = value;
			}
		}
		env.AICONTEXT_CONFIG_DIR = path.join(tempDir, 'config');
		const controllerAgents = path.join(path.dirname(REPO_CLI), '..', 'AGENTS.md');
		const before = fs.readFileSync(controllerAgents, 'utf8');
		const project = makeProject('real-project');
		fs.writeFileSync(path.join(project, 'AGENTS.md'), '# My own rules\n');
		const cli = new WorkflowCli(REPO_CLI, env);
		assert.strictEqual(readProjectInit(project).state, 'not-initialized');
		const result = await initializeProject(cli, project, true);
		assert.strictEqual(result.project.state, 'initialized');
		const text = fs.readFileSync(path.join(project, 'AGENTS.md'), 'utf8');
		assert.ok(text.startsWith('# My own rules'), 'the project text was not kept');
		assert.strictEqual(text.split(MANAGED_START).length - 1, 1);
		await initializeProject(cli, project, true);
		assert.strictEqual(fs.readFileSync(path.join(project, 'AGENTS.md'), 'utf8').split(MANAGED_START).length - 1, 1, 'init added the block twice');
		assert.strictEqual(fs.readFileSync(controllerAgents, 'utf8'), before, 'the controller AGENTS.md changed');
	});
});
