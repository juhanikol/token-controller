import * as fs from 'fs';
import * as path from 'path';

/**
 * Workspace Trust helpers. No vscode import, so they can be tested with plain mocha.
 *
 * The script path comes from user or machine settings, but it can still point into the open workspace
 * (for example when the workspace is the controller clone). Then the workspace controls the code that would run.
 */

export interface ProjectControlled {
    projectControlled: boolean;
    file?: string;
    folder?: string;
}

function realOrResolved(target: string): string {
    try {
        return fs.realpathSync(target);
    } catch {
        return path.resolve(target);
    }
}

function isInside(file: string, folder: string): boolean {
    const relative = path.relative(folder, file);
    return relative === '' || (relative !== '..' && !relative.startsWith('..' + path.sep) && !path.isAbsolute(relative));
}

/**
 * True when any controller file is inside any workspace folder. The check runs on the path as given
 * and on its real path, so a symlink in either direction cannot hide it.
 */
export function findProjectControlled(controllerFiles: string[], workspaceFolders: string[]): ProjectControlled {
    for (const folder of workspaceFolders) {
        const folderVariants = new Set([path.resolve(folder), realOrResolved(folder)]);
        for (const file of controllerFiles) {
            const fileVariants = new Set([path.resolve(file), realOrResolved(file)]);
            for (const folderVariant of folderVariants) {
                for (const fileVariant of fileVariants) {
                    if (isInside(fileVariant, folderVariant)) {
                        return { projectControlled: true, file, folder };
                    }
                }
            }
        }
    }
    return { projectControlled: false };
}
