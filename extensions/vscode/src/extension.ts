import * as vscode from 'vscode';
import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';
import { resolveScriptPath, runModeSwitch, ScriptResolution } from './controller';
import { isValidModeId, isValidRisk, loadModes, ModeInfo } from './modes';

let statusBarItem: vscode.StatusBarItem;
let warnedWorkspaceOverride = false;

// Codicon per mode id. Presentation only. A mode without an entry gets the default icon.
const ICONS: Record<string, string> = {
    code: 'code', debug: 'bug', test: 'beaker', 'test-full': 'beaker-stop', architect: 'milestone',
    scope: 'search', security: 'shield', db: 'database', cicd: 'server-process', 'rapid-prototype': 'rocket',
    review: 'eye', raw: 'flame', off: 'circle-slash', micro: 'dash', snippet: 'symbol-snippet',
    docs: 'book', release: 'package', migration: 'arrow-swap', perf: 'dashboard', decisions: 'law',
    agent: 'robot', 'data-analysis': 'graph'
};

interface ActiveState {
    profile: string;
    risk?: string;
}

/**
 * The script path comes from user or machine settings only. A workspace value is ignored, because a
 * cloned repository could otherwise point it at its own script.
 */
function getScriptPath(): ScriptResolution {
    const info = vscode.workspace.getConfiguration('tokenController').inspect<string>('scriptPath');
    if (!warnedWorkspaceOverride && (info?.workspaceValue !== undefined || info?.workspaceFolderValue !== undefined)) {
        warnedWorkspaceOverride = true;
        void vscode.window.showWarningMessage(
            'Token Controller ignores tokenController.scriptPath from workspace settings. Set it in your user settings.'
        );
    }
    return resolveScriptPath(info?.globalValue ?? info?.defaultValue);
}

export function activate(context: vscode.ExtensionContext) {
    const configDir = process.env.AICONTEXT_CONFIG_DIR || path.join(os.homedir(), '.config', 'ai-workflow');
    const activeEnvFile = path.join(configDir, 'active_mode.env');

    statusBarItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, 100);
    statusBarItem.command = 'tokenController.selectMode';
    context.subscriptions.push(statusBarItem);

    updateStatusBar(activeEnvFile);

    // Watch the file for external changes (like running the script from CLI)
    const fileWatcher = vscode.workspace.createFileSystemWatcher(new vscode.RelativePattern(configDir, 'active_mode.env'));
    fileWatcher.onDidChange(() => updateStatusBar(activeEnvFile));
    fileWatcher.onDidCreate(() => updateStatusBar(activeEnvFile));
    context.subscriptions.push(fileWatcher);

    context.subscriptions.push(
        vscode.workspace.onDidChangeConfiguration((event) => {
            if (event.affectsConfiguration('tokenController.scriptPath')) {
                updateStatusBar(activeEnvFile);
            }
        })
    );

    const selectModeDisposable = vscode.commands.registerCommand('tokenController.selectMode', async () => {
        const script = getScriptPath();
        const loaded = loadModes(script.ok ? script.path : undefined);
        const current = readActiveState(activeEnvFile).profile;

        const items = loaded.modes.map((mode) => toQuickPickItem(mode, mode.id === current));
        const note = loaded.source === 'fallback' ? ' (built-in mode list, config not found)' : '';
        const selected = await vscode.window.showQuickPick(items, {
            placeHolder: `Select active AI Context Workflow Mode${note}`,
            matchOnDescription: true
        });

        if (selected) {
            await switchMode(selected.mode, loaded.modes, activeEnvFile);
        }
    });

    context.subscriptions.push(selectModeDisposable);
}

interface ModeQuickPickItem extends vscode.QuickPickItem {
    mode: string;
}

function toQuickPickItem(mode: ModeInfo, isCurrent: boolean): ModeQuickPickItem {
    const icon = ICONS[mode.id] ?? 'symbol-misc';
    const parts = [mode.risk ? `risk: ${mode.risk}` : '', mode.description].filter((part) => part !== '');
    return {
        label: `$(${icon}) ${mode.id}${isCurrent ? ' (current)' : ''}`,
        description: parts.join(' · '),
        mode: mode.id
    };
}

function readActiveState(activeEnvFile: string): ActiveState {
    let profile = 'off';
    let risk: string | undefined;

    if (fs.existsSync(activeEnvFile)) {
        try {
            const content = fs.readFileSync(activeEnvFile, 'utf8');
            const profileMatch = content.match(/^export AICONTEXT_PROFILE="([^"]+)"$/m);
            if (profileMatch && profileMatch[1]) {
                profile = isValidModeId(profileMatch[1]) ? profileMatch[1] : 'unknown';
            }
            const riskMatch = content.match(/^export AICONTEXT_RISK="([^"]+)"$/m);
            if (riskMatch && isValidRisk(riskMatch[1])) {
                risk = riskMatch[1];
            }
        } catch {
            profile = 'error';
        }
    }
    return { profile, risk };
}

function updateStatusBar(activeEnvFile: string) {
    const { profile, risk } = readActiveState(activeEnvFile);
    const script = getScriptPath();
    const description = loadModes(script.ok ? script.path : undefined).modes.find((mode) => mode.id === profile)?.description;

    statusBarItem.text = `$(zap) AI Context: ${profile}${risk ? ` · ${risk}` : ''}`;
    statusBarItem.tooltip = [
        `Current AI context mode: ${profile}${risk ? ` (risk: ${risk})` : ''}.`,
        description ?? '',
        script.ok ? '' : script.reason,
        'Click to switch.'
    ].filter((line) => line !== '').join('\n');
    statusBarItem.backgroundColor = risk === 'critical'
        ? new vscode.ThemeColor('statusBarItem.warningBackground')
        : undefined;
    statusBarItem.show();
}

async function switchMode(mode: string, knownModes: ModeInfo[], activeEnvFile: string) {
    // Only ids from the loaded mode list may reach the shell script.
    if (!knownModes.some((known) => known.id === mode) || !isValidModeId(mode)) {
        vscode.window.showErrorMessage(`Unknown mode: ${mode}`);
        return;
    }
    const script = getScriptPath();
    if (!script.ok) {
        vscode.window.showErrorMessage(`${script.reason} Set tokenController.scriptPath in your user settings.`);
        return;
    }

    try {
        await runModeSwitch(script.path, mode);
    } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        vscode.window.showErrorMessage(`Failed to switch mode: ${message}`);
        return;
    }

    updateStatusBar(activeEnvFile);
    vscode.window.showInformationMessage(`AI Context switched to: ${mode}`);
}

export function deactivate() {}
