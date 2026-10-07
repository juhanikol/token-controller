import * as fs from 'fs';
import * as path from 'path';
import { CliError, CliResolution, WorkflowCli } from './cli';

/**
 * First-run setup helpers. No vscode import, so they can be tested with plain mocha.
 * The extension only calls the CLI. It never installs anything and never edits agent or MCP settings.
 */

export const MANAGED_START = '<!-- ai-workflow-controller:start -->';
export const MANAGED_END = '<!-- ai-workflow-controller:end -->';
export const SETUP_GUIDE_URL = 'https://github.com/juhanikol/token-controller#install-wsl-2--ubuntu';
export const INSTALL_COMMAND =
    'git clone https://github.com/juhanikol/token-controller.git ~/projects/token-controller && bash ~/projects/token-controller/scripts/install-wsl.sh';

export type CliState = { state: 'ready' } | { state: 'setup-needed'; reason: string };

/** A controller CLI that cannot be found or is set wrongly is "setup needed", not a failure. */
export function classifyCli(resolution: CliResolution): CliState {
    if (resolution.ok) {
        return { state: 'ready' };
    }
    return { state: 'setup-needed', reason: resolution.reason };
}

export type ProjectInitState = 'initialized' | 'not-initialized' | 'incomplete' | 'unknown';

export interface ProjectInit {
    state: ProjectInitState;
    detail: string;
}

const MAX_AGENTS_BYTES = 2 * 1024 * 1024;

/**
 * Is the project set up? It looks for the managed block that "workflow init" writes into AGENTS.md. Read only.
 * A missing file or a file without the block is "not-initialized". Only one of the two markers (or the wrong order) is "incomplete".
 * A symbolic link, a non-file, or a very large file is "unknown". "workflow init" refuses a symlink too.
 */
export function readProjectInit(folder: string): ProjectInit {
    const file = path.join(folder, 'AGENTS.md');
    let stat: fs.Stats;
    try {
        stat = fs.lstatSync(file);
    } catch {
        return { state: 'not-initialized', detail: 'No AGENTS.md in this folder.' };
    }
    if (stat.isSymbolicLink() || !stat.isFile() || stat.size > MAX_AGENTS_BYTES) {
        return { state: 'unknown', detail: 'AGENTS.md is a symbolic link, not a regular file, or too large to check.' };
    }
    let text: string;
    try {
        text = fs.readFileSync(file, 'utf8');
    } catch {
        return { state: 'unknown', detail: 'AGENTS.md cannot be read.' };
    }
    const start = text.indexOf(MANAGED_START);
    const end = text.indexOf(MANAGED_END);
    if (start === -1 && end === -1) {
        return { state: 'not-initialized', detail: 'AGENTS.md has no Token Controller block.' };
    }
    if (start === -1 || end === -1 || end < start) {
        return { state: 'incomplete', detail: 'AGENTS.md has an incomplete Token Controller block. Fix it by hand; "workflow init" stops on it.' };
    }
    return { state: 'initialized', detail: 'AGENTS.md has the Token Controller block.' };
}

export interface InitResult {
    output: string;
    project: ProjectInit;
}

/**
 * Initialize a project: "workflow init" with the project folder as the working directory.
 * Refuses an untrusted workspace. The caller asks the user for confirmation before it calls this.
 */
export async function initializeProject(cli: WorkflowCli, folder: string, trusted: boolean): Promise<InitResult> {
    if (!trusted) {
        throw new CliError('The workspace is not trusted. Trust it first, then initialize the project.', 'failed');
    }
    if (typeof folder !== 'string' || !path.isAbsolute(folder)) {
        throw new CliError('The project folder must be an absolute path.', 'failed');
    }
    let isDirectory = false;
    try {
        isDirectory = fs.statSync(folder).isDirectory();
    } catch {
        isDirectory = false;
    }
    if (!isDirectory) {
        throw new CliError(`Not a folder: ${folder}`, 'failed');
    }
    const output = await cli.initProject(folder);
    return { output, project: readProjectInit(folder) };
}

export interface ToolCheck {
    found: string[];
    missing: string[];
    requiredMissing: string[];
    optionalMissing: string[];
}

// jq, git, and curl are the base tools. Everything else that check-tools.sh lists is optional.
const REQUIRED_TOOLS = ['jq', 'git', 'curl'];

/** Read the OK and MISSING lines of check-tools.sh. */
export function parseToolCheck(output: string): ToolCheck {
    const found: string[] = [];
    const missing: string[] = [];
    for (const line of output.split('\n')) {
        const ok = line.match(/^OK\s+(\S+)/);
        if (ok) {
            found.push(ok[1]);
            continue;
        }
        const bad = line.match(/^MISSING\s+(\S+?)\.?(\s|$)/);
        if (bad) {
            missing.push(bad[1]);
        }
    }
    return {
        found,
        missing,
        requiredMissing: missing.filter((name) => REQUIRED_TOOLS.includes(name)),
        optionalMissing: missing.filter((name) => !REQUIRED_TOOLS.includes(name))
    };
}

export interface ToolCheckResult {
    output: string;
    check: ToolCheck;
}

/** Run the tool check. Missing tools are reported in the result, never thrown. Only a script that cannot run throws. */
export async function checkOptionalTools(cli: WorkflowCli): Promise<ToolCheckResult> {
    const output = await cli.checkTools();
    return { output, check: parseToolCheck(output) };
}
