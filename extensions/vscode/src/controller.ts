import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';
import { execFile } from 'child_process';
import { isValidModeId } from './modes';

export type ScriptResolution = { ok: true; path: string } | { ok: false; reason: string };

/**
 * Check the configured script path. Only the user or machine setting should reach this function.
 * It must be absolute (or start with ~/), and it must name an existing workflow.sh.
 */
export function resolveScriptPath(configured: string | undefined): ScriptResolution {
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
    try {
        if (!fs.statSync(scriptPath).isFile()) {
            return { ok: false, reason: `Not a file: ${scriptPath}` };
        }
    } catch {
        return { ok: false, reason: `Workflow script not found: ${scriptPath}` };
    }
    return { ok: true, path: scriptPath };
}

/**
 * Run "source <script> <mode>" in a child bash.
 * Linux and WSL only. Values are passed as separate arguments ($1 and $2), never put into the command string,
 * so quotes, spaces, and $() in a path or mode cannot run extra commands.
 * A Windows backend should replace this function (see docs/EXTENSION_ALIGNMENT_DESIGN.md).
 */
export function runModeSwitch(scriptPath: string, mode: string): Promise<void> {
    return new Promise((resolve, reject) => {
        if (process.platform === 'win32') {
            reject(new Error('Mode switching needs Linux or WSL. Open the folder in WSL.'));
            return;
        }
        if (!isValidModeId(mode)) {
            reject(new Error(`Invalid mode id: ${JSON.stringify(mode).slice(0, 40)}`));
            return;
        }
        execFile(
            'bash',
            ['-c', 'source "$1" "$2"', 'bash', scriptPath, mode],
            { cwd: path.dirname(scriptPath), timeout: 15000, maxBuffer: 1024 * 1024 },
            (error, _stdout, stderr) => {
                if (error) {
                    const detail = (stderr || error.message).trim().slice(0, 300);
                    reject(new Error(detail));
                    return;
                }
                resolve();
            }
        );
    });
}
