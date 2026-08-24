import * as vscode from 'vscode';
import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';
import { exec } from 'child_process';

let statusBarItem: vscode.StatusBarItem;

interface ModeOption extends vscode.QuickPickItem {
    mode: string;
}

// These match the modes defined in your workflow_settings.json
const MODES: ModeOption[] = [
    { label: "$(code) Code", mode: "code", description: "Standard coding, reversible compression, target files raw" },
    { label: "$(bug) Debug", mode: "debug", description: "Bug fixing, raw first failure, suppress repetitive noise" },
    { label: "$(beaker) Test", mode: "test", description: "Unit/integration tests, compress passing logs" },
    { label: "$(beaker-stop) Test-Full", mode: "test-full", description: "Full app / broad automated test routine" },
    { label: "$(milestone) Architect", mode: "architect", description: "Architecture, structure, codebase overview" },
    { label: "$(search) Scope", mode: "scope", description: "Requirements gathering, safe summaries" },
    { label: "$(shield) Security", mode: "security", description: "Vulnerability & secret scans, 100% raw/lossless" },
    { label: "$(database) Database", mode: "db", description: "Migrations & schemas, strictly raw/lossless" },
    { label: "$(server-process) CI/CD", mode: "cicd", description: "Boilerplate strip, preserve exit codes and errors" },
    { label: "$(rocket) Rapid Prototype", mode: "rapid-prototype", description: "Aggressive on success, raw on API/DB fail" },
    { label: "$(eye) Review", mode: "review", description: "Whole repo review, interfaces + diffs" },
    { label: "$(flame) Raw (Lossless)", mode: "raw", description: "Disable all compression across the board" },
    { label: "$(circle-slash) Off", mode: "off", description: "Turn off workflow optimizers" }
];

export function activate(context: vscode.ExtensionContext) {
    const configDir = path.join(os.homedir(), '.config', 'ai-workflow');
    const activeEnvFile = path.join(configDir, 'active_mode.env');

    // Create the Status Bar Item
    statusBarItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, 100);
    statusBarItem.command = 'tokenController.selectMode';
    context.subscriptions.push(statusBarItem);

    // Initial update
    updateStatusBar(activeEnvFile);

    // Watch the file for external changes (like running the script from CLI)
    const fileWatcher = vscode.workspace.createFileSystemWatcher(new vscode.RelativePattern(configDir, 'active_mode.env'));
    fileWatcher.onDidChange(() => updateStatusBar(activeEnvFile));
    fileWatcher.onDidCreate(() => updateStatusBar(activeEnvFile));
    context.subscriptions.push(fileWatcher);

    // Register Mode Selection Command
    const selectModeDisposable = vscode.commands.registerCommand('tokenController.selectMode', async () => {
        const selected = await vscode.window.showQuickPick(MODES, {
            placeHolder: 'Select active AI Context Workflow Mode',
            matchOnDescription: true
        });

        if (selected) {
            await switchMode(selected.mode, activeEnvFile);
        }
    });

    context.subscriptions.push(selectModeDisposable);
}

function updateStatusBar(activeEnvFile: string) {
    let activeProfile = "off";

    if (fs.existsSync(activeEnvFile)) {
        try {
            const content = fs.readFileSync(activeEnvFile, 'utf8');
            const match = content.match(/export AICONTEXT_PROFILE="([^"]+)"/);
            if (match && match[1]) {
                activeProfile = match[1];
            }
        } catch {
            activeProfile = "error";
        }
    }

    statusBarItem.text = `$(zap) AI Context: ${activeProfile}`;
    statusBarItem.tooltip = `Current AI context mode: ${activeProfile}. Click to switch.`;
    statusBarItem.show();
}

async function switchMode(mode: string, activeEnvFile: string) {
    // Resolve the script path globally in ~/projects/token-controller/scripts/workflow.sh as instructed in your README
    // 1. Read the path from VS Code User Settings
    const config = vscode.workspace.getConfiguration('tokenController');
    let scriptPath = config.get<string>('scriptPath');

    if (!scriptPath) {
        vscode.window.showErrorMessage("Workflow script path is not configured.");
        return;
    }
    // 2. Expand the '~' to the actual home directory
    if (scriptPath.startsWith('~')) {
        scriptPath = path.join(os.homedir(), scriptPath.slice(1));
    }
    // 3. Verify it exists
    if (!fs.existsSync(scriptPath)) {
        vscode.window.showErrorMessage(`Workflow script not found at: ${scriptPath}. Please update your settings.`);
        return;
    }

    const command = `bash -c "source \\"${scriptPath}\\" ${mode}"`;

    exec(command, (error) => {
        if (error) {
            vscode.window.showErrorMessage(`Failed to switch mode: ${error.message}`);
            return;
        }

        updateStatusBar(activeEnvFile);
        vscode.window.showInformationMessage(`AI Context switched to: ${mode}`);
    });
}

export function deactivate() {}