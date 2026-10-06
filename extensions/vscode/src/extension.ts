import * as vscode from 'vscode';
import * as path from 'path';
import * as os from 'os';
import { CliError, CliMode, CliStatus, resolveCli, WorkflowCli } from './cli';
import { findProjectControlled } from './trust';

let statusBarItem: vscode.StatusBarItem;
let output: vscode.OutputChannel;
let warnedWorkspaceOverride = false;
let refreshCounter = 0;
let refreshTimer: NodeJS.Timeout | undefined;
let watcher: vscode.FileSystemWatcher | undefined;
let watchedFile = '';
let lastStatus: CliStatus | undefined;

// Codicon per mode id. Presentation only. A mode without an entry gets the default icon.
const ICONS: Record<string, string> = {
    code: 'code', debug: 'bug', test: 'beaker', 'test-full': 'beaker-stop', architect: 'milestone',
    scope: 'search', security: 'shield', db: 'database', cicd: 'server-process', 'rapid-prototype': 'rocket',
    review: 'eye', raw: 'flame', off: 'circle-slash', micro: 'dash', snippet: 'symbol-snippet',
    docs: 'book', release: 'package', migration: 'arrow-swap', perf: 'dashboard', decisions: 'law',
    agent: 'robot', 'data-analysis': 'graph'
};

const SOURCE_TEXT: Record<CliStatus['source'], string> = {
    active_env_file: 'active mode file (active_mode.env)',
    shell_fallback: 'shell variables (no active mode file)',
    unset: 'none (no mode is set)'
};

function log(message: string) {
    output.appendLine(`[${new Date().toISOString()}] ${message}`);
}

type CliLookup =
    | { ok: true; cli: WorkflowCli }
    | { ok: false; reason: string; restricted?: boolean };

/**
 * How the CLI is found:
 * 1. tokenController.scriptPath, from user or machine settings only. The manifest gives it "machine" scope,
 *    and here the workspace and workspace-folder values are ignored too.
 * 2. workflow-cli.sh in the same folder as that workflow.sh.
 * 3. In an untrusted workspace, a controller that lives inside the workspace is not run, because the
 *    workspace controls those files. A controller outside the workspace is allowed.
 */
function getCli(): CliLookup {
    const info = vscode.workspace.getConfiguration('tokenController').inspect<string>('scriptPath');
    if (!warnedWorkspaceOverride && (info?.workspaceValue !== undefined || info?.workspaceFolderValue !== undefined)) {
        warnedWorkspaceOverride = true;
        void vscode.window.showWarningMessage(
            'Token Controller ignores tokenController.scriptPath from workspace settings. Set it in your user settings.'
        );
    }
    const resolved = resolveCli(info?.globalValue ?? info?.defaultValue);
    if (!resolved.ok) {
        return { ok: false, reason: resolved.reason };
    }

    if (!vscode.workspace.isTrusted) {
        const folders = (vscode.workspace.workspaceFolders ?? [])
            .filter((folder) => folder.uri.scheme === 'file')
            .map((folder) => folder.uri.fsPath);
        const check = findProjectControlled([resolved.scriptPath, resolved.cliPath], folders);
        if (check.projectControlled) {
            const reason = `This workspace is not trusted, and the Token Controller script is inside it (${check.file}). `
                + 'The extension does not run scripts from an untrusted workspace.';
            log(`restricted: ${reason}`);
            return { ok: false, reason, restricted: true };
        }
    }
    return { ok: true, cli: new WorkflowCli(resolved.cliPath) };
}

function errorText(error: unknown): string {
    return error instanceof CliError || error instanceof Error ? error.message : String(error);
}

export function activate(context: vscode.ExtensionContext) {
    output = vscode.window.createOutputChannel('Token Controller');
    context.subscriptions.push(output);

    statusBarItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, 100);
    statusBarItem.command = 'tokenController.selectMode';
    statusBarItem.text = '$(sync~spin) AI Context';
    statusBarItem.show();
    context.subscriptions.push(statusBarItem);

    context.subscriptions.push(
        vscode.workspace.onDidChangeConfiguration((event) => {
            if (event.affectsConfiguration('tokenController.scriptPath')) {
                scheduleRefresh(0);
            }
        }),
        vscode.workspace.onDidGrantWorkspaceTrust(() => scheduleRefresh(0)),
        vscode.workspace.onDidChangeWorkspaceFolders(() => scheduleRefresh(0)),
        { dispose: () => { watcher?.dispose(); if (refreshTimer) { clearTimeout(refreshTimer); } } }
    );

    context.subscriptions.push(
        vscode.commands.registerCommand('tokenController.selectMode', () => selectMode())
    );

    ensureWatcher(defaultActiveEnvFile());
    scheduleRefresh(0);
}

function defaultActiveEnvFile(): string {
    const configDir = process.env.AICONTEXT_CONFIG_DIR || path.join(os.homedir(), '.config', 'ai-workflow');
    return path.join(configDir, 'active_mode.env');
}

/** Watch the active mode file. The file is not read here. A change only triggers a status call. */
function ensureWatcher(activeEnvFile: string) {
    if (!activeEnvFile || activeEnvFile === watchedFile) {
        return;
    }
    watcher?.dispose();
    watchedFile = activeEnvFile;
    watcher = vscode.workspace.createFileSystemWatcher(
        new vscode.RelativePattern(path.dirname(activeEnvFile), path.basename(activeEnvFile))
    );
    watcher.onDidChange(() => scheduleRefresh(300));
    watcher.onDidCreate(() => scheduleRefresh(300));
    watcher.onDidDelete(() => scheduleRefresh(300));
}

function scheduleRefresh(delayMs: number) {
    if (refreshTimer) {
        clearTimeout(refreshTimer);
    }
    refreshTimer = setTimeout(() => {
        refreshTimer = undefined;
        void refreshStatus();
    }, delayMs);
}

async function refreshStatus() {
    const ticket = ++refreshCounter;
    const resolved = getCli();
    if (!resolved.ok) {
        lastStatus = undefined;
        if (resolved.restricted) {
            renderRestricted(resolved.reason);
        } else {
            renderUnavailable(resolved.reason);
        }
        return;
    }
    try {
        const status = await resolved.cli.status();
        if (ticket !== refreshCounter) {
            return; // A newer refresh started.
        }
        lastStatus = status;
        if (status.activeEnvFile) {
            ensureWatcher(status.activeEnvFile);
        }
        renderStatus(status);
    } catch (error) {
        if (ticket !== refreshCounter) {
            return;
        }
        lastStatus = undefined;
        log(`status failed: ${errorText(error)}`);
        renderUnavailable(errorText(error));
    }
}

function renderRestricted(reason: string) {
    statusBarItem.text = '$(shield) AI Context: restricted';
    statusBarItem.tooltip = `${reason}\nTrust the workspace to use it, or use a controller outside this workspace (tokenController.scriptPath in your user settings).`;
    statusBarItem.backgroundColor = new vscode.ThemeColor('statusBarItem.warningBackground');
    statusBarItem.show();
}

function renderUnavailable(reason: string) {
    statusBarItem.text = '$(error) AI Context: unavailable';
    statusBarItem.tooltip = `${reason}\nClick to try again, or set tokenController.scriptPath in your user settings.`;
    statusBarItem.backgroundColor = new vscode.ThemeColor('statusBarItem.errorBackground');
    statusBarItem.show();
}

function renderStatus(status: CliStatus) {
    const name = status.profile ?? 'none';
    const parts = [`$(zap) AI Context: ${name}`];
    if (status.risk) {
        parts.push(`· ${status.risk}`);
    }
    if (status.source === 'shell_fallback') {
        parts.push('(shell)');
    }
    if (status.staleShell) {
        parts.push('$(warning)');
    }
    statusBarItem.text = parts.join(' ');

    const lines = [
        `Current AI context mode: ${name}${status.risk ? ` (risk: ${status.risk})` : ''}.`,
        `Source: ${SOURCE_TEXT[status.source]}.`
    ];
    const tools = [
        status.rtkMode ? `rtk ${status.rtkMode}` : '',
        status.leanctxMode ? `leanctx ${status.leanctxMode}` : '',
        status.headroomMode ? `headroom ${status.headroomMode}` : '',
        status.cavemanMode ? `caveman ${status.cavemanMode}` : ''
    ].filter((item) => item !== '');
    if (tools.length > 0) {
        lines.push(`Tools: ${tools.join(', ')}.`);
    }
    if (status.staleShell) {
        lines.push(
            '',
            `Warning: the environment of VS Code has AICONTEXT_PROFILE='${status.shellProfile ?? 'unknown'}', but the active mode is '${name}'.`,
            'Terminals started by VS Code inherit that value. wx uses the active mode file, so wx is not affected.',
            'Already-open terminals can differ and cannot be checked from here. Run the workflow command in a terminal to update it.'
        );
    }
    lines.push('', 'Click to switch.');
    statusBarItem.tooltip = lines.join('\n');
    statusBarItem.backgroundColor = status.staleShell || status.risk === 'critical'
        ? new vscode.ThemeColor('statusBarItem.warningBackground')
        : undefined;
    statusBarItem.show();
}

interface ModeQuickPickItem extends vscode.QuickPickItem {
    mode: string;
}

function toQuickPickItem(mode: CliMode, isCurrent: boolean): ModeQuickPickItem {
    const icon = ICONS[mode.name] ?? 'symbol-misc';
    const parts = [`risk: ${mode.risk}`, mode.description ?? ''].filter((part) => part !== '');
    return {
        label: `$(${icon}) ${mode.name}${isCurrent ? ' (current)' : ''}`,
        description: parts.join(' · '),
        mode: mode.name
    };
}

async function showCliError(title: string, error: unknown) {
    const message = errorText(error);
    log(`${title}: ${message}`);
    const choice = await vscode.window.showErrorMessage(`${title}: ${message}`, 'Open Settings', 'Show Log');
    if (choice === 'Open Settings') {
        void vscode.commands.executeCommand('workbench.action.openSettings', 'tokenController.scriptPath');
    } else if (choice === 'Show Log') {
        output.show();
    }
}

async function selectMode() {
    const resolved = getCli();
    if (!resolved.ok) {
        if (resolved.restricted) {
            renderRestricted(resolved.reason);
            const choice = await vscode.window.showWarningMessage(resolved.reason, 'Manage Workspace Trust');
            if (choice === 'Manage Workspace Trust') {
                void vscode.commands.executeCommand('workbench.trust.manage');
            }
            return;
        }
        renderUnavailable(resolved.reason);
        await showCliError('Cannot list modes', new CliError(resolved.reason, 'unavailable'));
        return;
    }

    // The list comes from the CLI each time. If it fails, there is no fallback list.
    let modes: CliMode[];
    try {
        modes = (await resolved.cli.modes()).modes;
    } catch (error) {
        await showCliError('Cannot list modes', error);
        scheduleRefresh(0);
        return;
    }

    const current = lastStatus?.profile ?? undefined;
    const selected = await vscode.window.showQuickPick(
        modes.map((mode) => toQuickPickItem(mode, mode.name === current)),
        { placeHolder: 'Select active AI Context Workflow Mode', matchOnDescription: true }
    );
    if (!selected) {
        return;
    }
    // Only ids from the list that the CLI returned may be sent back to it.
    if (!modes.some((mode) => mode.name === selected.mode)) {
        void vscode.window.showErrorMessage(`Unknown mode: ${selected.mode}`);
        return;
    }

    try {
        await resolved.cli.setMode(selected.mode);
    } catch (error) {
        await showCliError('Failed to switch mode', error);
        scheduleRefresh(0);
        return;
    }
    scheduleRefresh(0);
    void vscode.window.showInformationMessage(`AI Context switched to: ${selected.mode}`);
}

export function deactivate() {}
