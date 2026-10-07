import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';
import { execFile } from 'child_process';

/**
 * The only place that talks to the Token Controller CLI (scripts/workflow-cli.sh).
 * Values go to the process as separate arguments. No shell command string is ever built.
 * Linux and WSL only. A Windows backend should replace runCli (see docs/EXTENSION_ALIGNMENT_DESIGN.md).
 */

export const SUPPORTED_SCHEMA_VERSION = 1;

export type CliErrorKind = 'unavailable' | 'failed' | 'invalid-output' | 'unsupported-schema';

export class CliError extends Error {
    constructor(message: string, readonly kind: CliErrorKind) {
        super(message);
        this.name = 'CliError';
    }
}

export interface CliStatus {
    profile: string | null;
    risk: string | null;
    outputStyle: string | null;
    rtkMode: string | null;
    leanctxMode: string | null;
    headroomMode: string | null;
    cavemanMode: string | null;
    source: 'active_env_file' | 'shell_fallback' | 'unset';
    activeEnvFile: string;
    /** The profile of the process environment, when it differs from `profile`. */
    shellProfile: string | null;
    staleShell: boolean;
}

export interface CliMode {
    name: string;
    description: string | null;
    risk: string;
    rtkMode: string;
    leanctxMode: string;
    headroomMode: string;
    cavemanMode: string;
}

export interface CliModes {
    modes: CliMode[];
    aliases: { alias: string; target: string }[];
}

/** Status of the controller's LeanCTX adapter (workflow leanctx status --json). The adapter runs lean-ctx --version only. */
export interface LeanctxPolicyStatus {
    shellEnabled: string | null;
    shellOwner: string | null;
    autoWrap: string | null;
    autoSetup: string | null;
    autoInit: string | null;
    operations: { read: string | null; search: string | null; tree: string | null };
}

export interface LeanctxStatus {
    profile: string | null;
    leanctxMode: string | null;
    binary: string | null;
    resolvedPath: string | null;
    platformPath: 'linux' | 'windows' | null;
    version: string | null;
    allowed: boolean;
    reasons: string[];
    policy: LeanctxPolicyStatus;
    statusCommand: string | null;
}

const MODE_ID = /^[a-z0-9][a-z0-9-]*$/;
const RISK = /^[a-z]{1,16}$/;

export function isValidModeId(id: unknown): id is string {
    return typeof id === 'string' && id.length <= 40 && MODE_ID.test(id);
}

export function isValidRisk(risk: unknown): risk is string {
    return typeof risk === 'string' && RISK.test(risk);
}

export type CliResolution = { ok: true; cliPath: string; scriptPath: string } | { ok: false; reason: string };

/**
 * Check the configured script path and find workflow-cli.sh beside it.
 * Only the user or machine setting should reach this function. It must be absolute (or start with ~/),
 * name an existing workflow.sh, and have workflow-cli.sh in the same folder.
 */
export function resolveCli(configured: string | undefined): CliResolution {
    if (!configured || configured.trim() === '') {
        return { ok: false, reason: 'tokenController.scriptPath is not set.' };
    }
    let scriptPath = configured.trim();
    if (scriptPath === '~') {
        scriptPath = os.homedir();
    } else if (scriptPath.startsWith('~/')) {
        scriptPath = path.join(os.homedir(), scriptPath.slice(2));
    }
    if (!path.isAbsolute(scriptPath)) {
        return { ok: false, reason: 'tokenController.scriptPath must be an absolute path or start with ~/.' };
    }
    scriptPath = path.normalize(scriptPath);
    if (path.basename(scriptPath) !== 'workflow.sh') {
        return { ok: false, reason: 'tokenController.scriptPath must point to workflow.sh.' };
    }
    const cliPath = path.join(path.dirname(scriptPath), 'workflow-cli.sh');
    for (const file of [scriptPath, cliPath]) {
        try {
            if (!fs.statSync(file).isFile()) {
                return { ok: false, reason: `Not a file: ${file}` };
            }
        } catch {
            return { ok: false, reason: `Not found: ${file}. Update the controller, or fix tokenController.scriptPath.` };
        }
    }
    return { ok: true, cliPath, scriptPath };
}

interface CliResult {
    stdout: string;
    stderr: string;
}

/** Run "bash <cli> <args...>". Bash runs the file, so the executable bit is not needed. */
export function runCli(cliPath: string, args: string[], timeoutMs: number, env?: NodeJS.ProcessEnv, cwd?: string): Promise<CliResult> {
    return new Promise((resolve, reject) => {
        if (process.platform === 'win32') {
            reject(new CliError('The Token Controller CLI needs Linux or WSL. Open the folder in WSL.', 'unavailable'));
            return;
        }
        if (args.some((arg) => typeof arg !== 'string' || arg.includes('\0'))) {
            reject(new CliError('Invalid CLI argument.', 'failed'));
            return;
        }
        execFile(
            'bash',
            [cliPath, ...args],
            { cwd: cwd ?? path.dirname(cliPath), timeout: timeoutMs, maxBuffer: 4 * 1024 * 1024, env: env ?? process.env },
            (error, stdout, stderr) => {
                if (error) {
                    const code = (error as NodeJS.ErrnoException).code;
                    if (code === 'ENOENT') {
                        reject(new CliError('bash was not found.', 'unavailable'));
                    } else if ((error as { killed?: boolean }).killed) {
                        reject(new CliError(`The CLI did not answer within ${Math.round(timeoutMs / 1000)} seconds.`, 'failed'));
                    } else {
                        const detail = (stderr || error.message).trim().slice(0, 300);
                        reject(new CliError(detail || 'The CLI failed.', 'failed'));
                    }
                    return;
                }
                resolve({ stdout, stderr });
            }
        );
    });
}

function parseJson(stdout: string, what: string): Record<string, unknown> {
    let value: unknown;
    try {
        value = JSON.parse(stdout);
    } catch {
        throw new CliError(`The CLI returned invalid JSON for ${what}.`, 'invalid-output');
    }
    if (typeof value !== 'object' || value === null || Array.isArray(value)) {
        throw new CliError(`The CLI returned an unexpected value for ${what}.`, 'invalid-output');
    }
    const object = value as Record<string, unknown>;
    if (object.schema_version !== SUPPORTED_SCHEMA_VERSION) {
        throw new CliError(
            `The CLI ${what} schema_version ${String(object.schema_version)} is not supported (expected ${SUPPORTED_SCHEMA_VERSION}). Update the extension or the controller.`,
            'unsupported-schema'
        );
    }
    return object;
}

function nullableString(value: unknown): string | null {
    return typeof value === 'string' && value !== '' ? value.slice(0, 200) : null;
}

export function parseStatus(stdout: string): CliStatus {
    const o = parseJson(stdout, 'status');
    const source = o.source;
    if (source !== 'active_env_file' && source !== 'shell_fallback' && source !== 'unset') {
        throw new CliError('The CLI status has an unknown source.', 'invalid-output');
    }
    if (typeof o.stale_shell !== 'boolean') {
        throw new CliError('The CLI status has no stale_shell value.', 'invalid-output');
    }
    // Ids are shown in the UI. Anything that is not a plain id is replaced.
    const profile = o.profile === null ? null : isValidModeId(o.profile) ? o.profile : 'unknown';
    const shellProfile = o.shell_profile === null || o.shell_profile === undefined ? null : isValidModeId(o.shell_profile) ? o.shell_profile : 'unknown';
    return {
        profile,
        risk: isValidRisk(o.risk) ? o.risk : null,
        outputStyle: nullableString(o.output_style),
        rtkMode: nullableString(o.rtk_mode),
        leanctxMode: nullableString(o.leanctx_mode),
        headroomMode: nullableString(o.headroom_mode),
        cavemanMode: nullableString(o.caveman_mode),
        source,
        activeEnvFile: typeof o.active_env_file === 'string' ? o.active_env_file : '',
        shellProfile,
        staleShell: o.stale_shell
    };
}

// Text from the CLI is shown in an output channel. Control characters are removed and the length is capped.
function cleanText(value: unknown, max = 300): string | null {
    if (typeof value !== 'string') {
        return null;
    }
    const text = value.replace(/[\u0000-\u001f\u007f]/g, ' ').trim().slice(0, max);
    return text === '' ? null : text;
}

export function parseLeanctxStatus(stdout: string): LeanctxStatus {
    const o = parseJson(stdout, 'leanctx status');
    if (typeof o.allowed !== 'boolean') {
        throw new CliError('The CLI leanctx status has no allowed value.', 'invalid-output');
    }
    if (!Array.isArray(o.reasons) || o.reasons.some((reason) => typeof reason !== 'string')) {
        throw new CliError('The CLI leanctx status has no valid reasons list.', 'invalid-output');
    }
    const reasons = (o.reasons as string[]).map((reason) => cleanText(reason)).filter((reason): reason is string => reason !== null).slice(0, 10);
    // Fail closed: "allowed" must agree with the reasons. A status that says allowed with a reason is not trusted.
    if (o.allowed === (o.reasons as string[]).length > 0) {
        throw new CliError('The CLI leanctx status is inconsistent: allowed and reasons disagree.', 'invalid-output');
    }
    const policyRaw = o.policy;
    if (typeof policyRaw !== 'object' || policyRaw === null || Array.isArray(policyRaw)) {
        throw new CliError('The CLI leanctx status has no policy.', 'invalid-output');
    }
    const p = policyRaw as Record<string, unknown>;
    const ops = typeof p.operations === 'object' && p.operations !== null && !Array.isArray(p.operations) ? p.operations as Record<string, unknown> : {};
    const flag = (value: unknown) => (typeof value === 'boolean' ? String(value) : cleanText(value, 40));
    const profile = o.profile === null || o.profile === undefined ? null : isValidModeId(o.profile) ? o.profile : 'unknown';
    return {
        profile,
        leanctxMode: cleanText(o.leanctx_mode, 40),
        binary: cleanText(o.binary),
        resolvedPath: cleanText(o.resolved_path),
        platformPath: o.platform_path === 'linux' || o.platform_path === 'windows' ? o.platform_path : null,
        version: cleanText(o.version, 90),
        allowed: o.allowed,
        reasons,
        policy: {
            shellEnabled: flag(p.shell_enabled),
            shellOwner: cleanText(p.shell_owner, 40),
            autoWrap: flag(p.auto_wrap),
            autoSetup: flag(p.auto_setup),
            autoInit: flag(p.auto_init),
            operations: { read: cleanText(ops.read, 40), search: cleanText(ops.search, 40), tree: cleanText(ops.tree, 40) }
        },
        statusCommand: cleanText(o.status_command)
    };
}

/** The lines shown in the output channel. */
export function formatLeanctxStatus(status: LeanctxStatus): string[] {
    const policy = status.policy;
    const lines = [
        `LeanCTX adapter: ${status.allowed ? 'allowed' : 'refused'}`,
        `  Mode: ${status.profile ?? 'none'}, LeanCTX mode: ${status.leanctxMode ?? 'none'}`,
        `  Binary: ${status.binary ?? 'none'}${status.platformPath ? ` (${status.platformPath})` : ''}`,
        `  Version: ${status.version ?? 'unknown'}`,
        `  Policy: shell_enabled=${policy.shellEnabled ?? '?'}, shell_owner=${policy.shellOwner ?? '?'}, auto_wrap=${policy.autoWrap ?? '?'}, auto_setup=${policy.autoSetup ?? '?'}, auto_init=${policy.autoInit ?? '?'}`,
        `  Operations: read=${policy.operations.read ?? '?'}, search=${policy.operations.search ?? '?'}, tree=${policy.operations.tree ?? '?'}`
    ];
    if (status.reasons.length > 0) {
        lines.push('  Why not:');
        for (const reason of status.reasons) {
            lines.push(`    - ${reason}`);
        }
    }
    if (status.statusCommand) {
        lines.push(`  lean-ctx status: ${status.statusCommand}`);
    }
    return lines;
}

export function parseModes(stdout: string): CliModes {
    const o = parseJson(stdout, 'modes');
    if (!Array.isArray(o.modes) || o.modes.length === 0) {
        throw new CliError('The CLI returned no modes.', 'invalid-output');
    }
    const modes: CliMode[] = [];
    for (const entry of o.modes as unknown[]) {
        if (typeof entry !== 'object' || entry === null) {
            continue;
        }
        const m = entry as Record<string, unknown>;
        if (!isValidModeId(m.name)) {
            continue;
        }
        modes.push({
            name: m.name,
            description: nullableString(m.description),
            risk: isValidRisk(m.risk) ? m.risk : 'normal',
            rtkMode: nullableString(m.rtk_mode) ?? 'off',
            leanctxMode: nullableString(m.leanctx_mode) ?? 'off',
            headroomMode: nullableString(m.headroom_mode) ?? 'off',
            cavemanMode: nullableString(m.caveman_mode) ?? 'off'
        });
    }
    if (modes.length === 0) {
        throw new CliError('The CLI returned no valid modes.', 'invalid-output');
    }
    const aliases: { alias: string; target: string }[] = [];
    if (Array.isArray(o.aliases)) {
        for (const entry of o.aliases as unknown[]) {
            const a = entry as { alias?: unknown; target?: unknown } | null;
            if (a && isValidModeId(a.alias) && isValidModeId(a.target)) {
                aliases.push({ alias: a.alias, target: a.target });
            }
        }
    }
    return { modes, aliases };
}

/** The adapter. One instance per resolved CLI path. */
export class WorkflowCli {
    constructor(readonly cliPath: string, private readonly env?: NodeJS.ProcessEnv) {}

    async status(): Promise<CliStatus> {
        const { stdout } = await runCli(this.cliPath, ['status', '--json'], 8000, this.env);
        return parseStatus(stdout);
    }

    async modes(): Promise<CliModes> {
        const { stdout } = await runCli(this.cliPath, ['modes', '--json'], 8000, this.env);
        return parseModes(stdout);
    }

    /**
     * Status of the LeanCTX adapter: "workflow leanctx status --json". It reads state and runs lean-ctx --version only.
     * The extension never runs the adapter's read, search, or tree commands. `cwd` is the project folder the adapter checks the binary against.
     */
    async leanctxStatus(cwd?: string): Promise<LeanctxStatus> {
        const { stdout } = await runCli(this.cliPath, ['leanctx', 'status', '--json'], 10000, this.env, cwd);
        return parseLeanctxStatus(stdout);
    }

    /**
     * Run "workflow init" in `folder` (it writes AGENTS.md in the current directory, so the process must start there).
     * The caller checks Workspace Trust and asks the user first. See initializeProject in setup.ts.
     */
    async initProject(folder: string): Promise<string> {
        if (typeof folder !== 'string' || !path.isAbsolute(folder) || folder.includes('\0')) {
            throw new CliError('The project folder must be an absolute path.', 'failed');
        }
        const { stdout } = await runCli(this.cliPath, ['init'], 30000, this.env, folder);
        return stdout.trim().slice(0, 2000);
    }

    /** Run check-tools.sh (beside the CLI). It only reports which tools are installed. A missing optional tool is not a failure. */
    async checkTools(): Promise<string> {
        const script = path.join(path.dirname(this.cliPath), 'check-tools.sh');
        if (!fs.existsSync(script)) {
            throw new CliError(`check-tools.sh was not found beside the CLI (${script}). Update the controller.`, 'unavailable');
        }
        const { stdout } = await runCli(script, [], 20000, this.env);
        return stdout.slice(0, 20000);
    }

    /** Switch the active mode. The id must be a mode from modes(). The CLI writes active_mode.env. */
    async setMode(id: string): Promise<void> {
        if (!isValidModeId(id)) {
            throw new CliError(`Invalid mode id: ${JSON.stringify(String(id)).slice(0, 40)}`, 'failed');
        }
        await runCli(this.cliPath, [id], 15000, this.env);
    }
}
