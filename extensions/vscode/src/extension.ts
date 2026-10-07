import * as vscode from 'vscode';
import * as path from 'path';
import * as os from 'os';
import { CliError, CliMode, CliStatus, formatLeanctxStatus, LeanctxStatus, resolveCli, WorkflowCli } from './cli';
import { findProjectControlled } from './trust';
import { checkOptionalTools, classifyCli, initializeProject, INSTALL_COMMAND, ProjectInit, readProjectInit, SETUP_GUIDE_URL } from './setup';

let statusBarItem: vscode.StatusBarItem;
let output: vscode.OutputChannel;
let warnedWorkspaceOverride = false;
let refreshCounter = 0;
let refreshTimer: NodeJS.Timeout | undefined;
let watcher: vscode.FileSystemWatcher | undefined;
let watchedFile = '';
let lastStatus: CliStatus | undefined;
// The last LeanCTX adapter status. Only set when the user runs "Show LeanCTX Status". Shown in the tooltip while the mode is the same.
let lastLeanctx: LeanctxStatus | undefined;
// The AGENTS.md state of the first workspace folder, and the folders already offered an initialization in this session.
let lastProject: { folder: string; init: ProjectInit } | undefined;
const offeredInit = new Set<string>();

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
    | { ok: false; reason: string; restricted?: boolean; setupNeeded?: boolean };

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
    const classified = classifyCli(resolved);
    if (!resolved.ok || classified.state === 'setup-needed') {
        return { ok: false, reason: classified.state === 'setup-needed' ? classified.reason : 'Setup needed.', setupNeeded: true };
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
        vscode.commands.registerCommand('tokenController.selectMode', () => selectMode()),
        vscode.commands.registerCommand('tokenController.showLeanctxStatus', () => showLeanctxStatus()),
        vscode.commands.registerCommand('tokenController.setupHelp', () => setupHelp()),
        vscode.commands.registerCommand('tokenController.initProject', () => initProject()),
        vscode.commands.registerCommand('tokenController.checkTools', () => checkTools())
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
        } else if (resolved.setupNeeded) {
            renderSetupNeeded(resolved.reason);
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
        const folder = firstFileFolder();
        lastProject = folder ? { folder, init: readProjectInit(folder) } : undefined;
        renderStatus(status);
        void offerInitialize();
    } catch (error) {
        if (ticket !== refreshCounter) {
            return;
        }
        lastStatus = undefined;
        log(`status failed: ${errorText(error)}`);
        renderUnavailable(errorText(error));
    }
}

/** The first workspace folder on disk, or undefined. */
function firstFileFolder(): string | undefined {
    return (vscode.workspace.workspaceFolders ?? []).find((folder) => folder.uri.scheme === 'file')?.uri.fsPath;
}

function renderSetupNeeded(reason: string) {
    statusBarItem.text = '$(tools) AI Context: setup needed';
    statusBarItem.tooltip = [
        'The Token Controller CLI was not found.',
        reason,
        '',
        'Click for help: open the setup guide, copy the install command, or select workflow.sh.',
        'Run the install command in a WSL terminal. The extension itself must be installed in the WSL extension host.'
    ].join('\n');
    statusBarItem.command = 'tokenController.setupHelp';
    statusBarItem.backgroundColor = new vscode.ThemeColor('statusBarItem.warningBackground');
    statusBarItem.show();
}

/** Setup help: three actions, and nothing is installed or changed without a click. */
async function setupHelp() {
    const message = 'The Token Controller CLI was not found. Install it in WSL, or select its workflow.sh.';
    const choice = await vscode.window.showWarningMessage(message, 'Open setup guide', 'Copy install command', 'Select workflow.sh');
    if (choice === 'Open setup guide') {
        void vscode.env.openExternal(vscode.Uri.parse(SETUP_GUIDE_URL));
    } else if (choice === 'Copy install command') {
        await vscode.env.clipboard.writeText(INSTALL_COMMAND);
        void vscode.window.showInformationMessage('Copied. Paste it in a WSL terminal, then reload the window. It installs jq, git, curl, and the workflow alias. It installs no optional tool.');
    } else if (choice === 'Select workflow.sh') {
        await selectWorkflowScript();
    }
}

async function selectWorkflowScript() {
    const picked = await vscode.window.showOpenDialog({
        canSelectFiles: true,
        canSelectFolders: false,
        canSelectMany: false,
        defaultUri: vscode.Uri.file(path.join(os.homedir(), 'projects')),
        openLabel: 'Select workflow.sh',
        title: 'Select workflow.sh of your Token Controller clone'
    });
    if (!picked || picked.length === 0) {
        return;
    }
    const file = picked[0].fsPath;
    const check = resolveCli(file);
    if (!check.ok) {
        void vscode.window.showErrorMessage(`That file cannot be used: ${check.reason}`);
        return;
    }
    // The setting has machine scope, so it is written to the user (remote machine) settings, never to the workspace.
    await vscode.workspace.getConfiguration('tokenController').update('scriptPath', file, vscode.ConfigurationTarget.Global);
    void vscode.window.showInformationMessage(`Token Controller will use ${file}.`);
    scheduleRefresh(0);
}

/** Once per session and folder, offer to initialize a trusted project that has no Token Controller block. Never changes anything by itself. */
async function offerInitialize() {
    if (!lastProject || lastProject.init.state !== 'not-initialized' || !vscode.workspace.isTrusted) {
        return;
    }
    if (!vscode.workspace.getConfiguration('tokenController').get<boolean>('promptToInitialize', true)) {
        return;
    }
    const folder = lastProject.folder;
    if (offeredInit.has(folder)) {
        return;
    }
    offeredInit.add(folder);
    const choice = await vscode.window.showInformationMessage(
        'This project has no Token Controller rules in AGENTS.md yet. Initialize it?',
        'Initialize', 'Not now'
    );
    if (choice === 'Initialize') {
        await initProject();
    }
}

/**
 * Token Controller: Initialize Current Project. Trusted workspace only. Asks first.
 * Runs "workflow-cli.sh init" with the project folder as the working directory, then refreshes the status.
 */
async function initProject() {
    if (!vscode.workspace.isTrusted) {
        const choice = await vscode.window.showWarningMessage(
            'This workspace is not trusted. Token Controller does not change a project in an untrusted workspace.',
            'Manage Workspace Trust'
        );
        if (choice === 'Manage Workspace Trust') {
            void vscode.commands.executeCommand('workbench.trust.manage');
        }
        return;
    }
    const resolved = getCli();
    if (!resolved.ok) {
        if (resolved.setupNeeded) {
            renderSetupNeeded(resolved.reason);
            await setupHelp();
        } else if (resolved.restricted) {
            renderRestricted(resolved.reason);
        } else {
            await showCliError('Cannot initialize the project', new CliError(resolved.reason, 'unavailable'));
        }
        return;
    }
    const folders = (vscode.workspace.workspaceFolders ?? []).filter((folder) => folder.uri.scheme === 'file');
    if (folders.length === 0) {
        void vscode.window.showWarningMessage('Open a project folder first.');
        return;
    }
    let target = folders[0];
    if (folders.length > 1) {
        const picked = await vscode.window.showQuickPick(
            folders.map((folder) => ({ label: folder.name, description: folder.uri.fsPath, folder })),
            { placeHolder: 'Which folder do you want to initialize?' }
        );
        if (!picked) {
            return;
        }
        target = picked.folder;
    }
    const confirm = await vscode.window.showWarningMessage(
        `Add the Token Controller rules to AGENTS.md in ${target.uri.fsPath}?`,
        { modal: true, detail: 'This runs "workflow init". It creates AGENTS.md, or adds a managed block to the existing one and keeps your own text. Nothing else in the project is changed.' },
        'Initialize'
    );
    if (confirm !== 'Initialize') {
        return;
    }
    try {
        const result = await initializeProject(resolved.cli, target.uri.fsPath, vscode.workspace.isTrusted);
        log(`init ${target.uri.fsPath}: ${result.output}`);
        void vscode.window.showInformationMessage(result.output.split('\n')[0] || 'Project initialized.');
    } catch (error) {
        await showCliError('Failed to initialize the project', error);
    }
    scheduleRefresh(0);
}

/** Token Controller: Check Optional Tools. Shows the tool check in the output channel. A missing optional tool is a warning, not an error. */
async function checkTools() {
    const resolved = getCli();
    if (!resolved.ok) {
        if (resolved.setupNeeded) {
            renderSetupNeeded(resolved.reason);
            await setupHelp();
        } else if (resolved.restricted) {
            renderRestricted(resolved.reason);
        } else {
            await showCliError('Cannot check the tools', new CliError(resolved.reason, 'unavailable'));
        }
        return;
    }
    try {
        const { output: text, check } = await checkOptionalTools(resolved.cli);
        output.appendLine(`[${new Date().toISOString()}] Tool check (scripts/check-tools.sh):`);
        output.appendLine(text);
        output.show(true);
        if (check.requiredMissing.length > 0) {
            void vscode.window.showWarningMessage(
                `Base tools are missing: ${check.requiredMissing.join(', ')}. Run scripts/install-wsl.sh in a WSL terminal.`
            );
        } else if (check.optionalMissing.length > 0) {
            void vscode.window.showWarningMessage(
                `Optional tools not found: ${check.optionalMissing.join(', ')}. This is not an error. Token Controller still works and falls back to raw output.`
            );
        } else {
            void vscode.window.showInformationMessage('All tools in the check were found.');
        }
    } catch (error) {
        await showCliError('Cannot check the tools', error);
    }
}

function renderRestricted(reason: string) {
    statusBarItem.text = '$(shield) AI Context: restricted';
    statusBarItem.tooltip = `${reason}\nTrust the workspace to use it, or use a controller outside this workspace (tokenController.scriptPath in your user settings).`;
    statusBarItem.backgroundColor = new vscode.ThemeColor('statusBarItem.warningBackground');
    statusBarItem.show();
}

function renderUnavailable(reason: string) {
    statusBarItem.command = 'tokenController.selectMode';
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
    statusBarItem.command = 'tokenController.selectMode';

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
    if (lastProject && lastProject.init.state !== 'initialized') {
        lines.push(lastProject.init.state === 'not-initialized'
            ? 'Project: not initialized. Run "Token Controller: Initialize Current Project".'
            : `Project: ${lastProject.init.detail}`);
    }
    if (lastLeanctx && lastLeanctx.profile === status.profile && lastLeanctx.leanctxMode === status.leanctxMode) {
        lines.push(`LeanCTX adapter: ${lastLeanctx.allowed ? 'allowed' : 'refused'}`);
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
        if (resolved.setupNeeded) {
            renderSetupNeeded(resolved.reason);
            await setupHelp();
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

/**
 * Show the LeanCTX adapter status in the output channel. This is the only LeanCTX call of the extension.
 * It runs "workflow leanctx status --json", which reads state and runs lean-ctx --version. No read, search, or tree.
 */
async function showLeanctxStatus() {
    const resolved = getCli();
    if (!resolved.ok) {
        if (resolved.restricted) {
            renderRestricted(resolved.reason);
            void vscode.window.showWarningMessage(resolved.reason);
            return;
        }
        if (resolved.setupNeeded) {
            renderSetupNeeded(resolved.reason);
            await setupHelp();
            return;
        }
        renderUnavailable(resolved.reason);
        await showCliError('Cannot show LeanCTX status', new CliError(resolved.reason, 'unavailable'));
        return;
    }
    // The adapter checks that lean-ctx is not inside the project. Use the workspace folder, but only in a trusted workspace.
    const folder = vscode.workspace.isTrusted
        ? (vscode.workspace.workspaceFolders ?? []).find((f) => f.uri.scheme === 'file')?.uri.fsPath
        : undefined;
    try {
        const status = await resolved.cli.leanctxStatus(folder);
        lastLeanctx = status;
        output.appendLine(`[${new Date().toISOString()}] ${formatLeanctxStatus(status).join('\n')}`);
        output.show(true);
        if (lastStatus) {
            renderStatus(lastStatus);
        }
    } catch (error) {
        await showCliError('Cannot show LeanCTX status', error);
    }
}

export function deactivate() {}
