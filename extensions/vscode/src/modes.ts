import * as fs from 'fs';
import * as path from 'path';

export interface ModeInfo {
    id: string;
    description: string;
    risk?: string;
}

export interface LoadedModes {
    modes: ModeInfo[];
    source: 'config' | 'fallback';
    settingsFile: string;
    error?: string;
}

const MODE_ID = /^[a-z0-9][a-z0-9-]*$/;
const RISK = /^[a-z]{1,16}$/;
const MAX_CONFIG_BYTES = 1024 * 1024;

export function isValidModeId(id: string): boolean {
    return typeof id === 'string' && id.length <= 40 && MODE_ID.test(id);
}

export function isValidRisk(risk: string): boolean {
    return typeof risk === 'string' && RISK.test(risk);
}

/**
 * TEMPORARY. Used only when config/workflow_settings.json cannot be read.
 * Copy of the config modes. It can drift. The planned fix is a CLI command that lists modes
 * (see docs/EXTENSION_ALIGNMENT_DESIGN.md).
 */
export const FALLBACK_MODES: ModeInfo[] = [
    { id: "raw", risk: "critical", description: "No compression. Highest fidelity." },
    { id: "scope", risk: "high", description: "Requirements and scope discovery." },
    { id: "architect", risk: "high", description: "Architecture, structure, and codebase overview." },
    { id: "decisions", risk: "high", description: "ADRs, domain models, schemas, and types." },
    { id: "code", risk: "normal", description: "Normal implementation work." },
    { id: "rapid-prototype", risk: "high", description: "Fast prototyping. Compress successful output only. Keep errors raw." },
    { id: "snippet", risk: "normal", description: "Small file, method, or snippet review." },
    { id: "micro", risk: "normal", description: "Very small task. No context tools. Target file or snippet only." },
    { id: "agent", risk: "high", description: "Agent governance and AGENTS.md work." },
    { id: "test", risk: "high", description: "Unit and integration test runs." },
    { id: "test-full", risk: "high", description: "Full application or broad automated test run." },
    { id: "debug", risk: "high", description: "Failure investigation and bug fixing." },
    { id: "data-analysis", risk: "high", description: "Data analysis, statistics, and visualization." },
    { id: "docs", risk: "normal", description: "Documentation and README work." },
    { id: "cicd", risk: "high", description: "CI/CD, Docker, package-manager, and runner logs." },
    { id: "review", risk: "high", description: "Whole-codebase or pull request review." },
    { id: "security", risk: "critical", description: "Security, auth, secrets, and vulnerability scans." },
    { id: "migration", risk: "critical", description: "Large refactor or legacy migration." },
    { id: "db", risk: "critical", description: "Database, schema, and data migration." },
    { id: "perf", risk: "high", description: "Performance profiling and benchmarking." },
    { id: "release", risk: "critical", description: "Release preparation." },
    { id: "off", risk: "normal", description: "Disable all optimizers." },
];

function cleanText(value: unknown): string {
    if (typeof value !== 'string') {
        return '';
    }
    return value.replace(/[\u0000-\u001f\u007f]/g, ' ').trim().slice(0, 200);
}

/** Read modes from parsed workflow_settings.json. Invalid ids are dropped. */
export function parseModes(settings: unknown): ModeInfo[] {
    if (typeof settings !== 'object' || settings === null) {
        return [];
    }
    const modes = (settings as { modes?: unknown }).modes;
    if (typeof modes !== 'object' || modes === null || Array.isArray(modes)) {
        return [];
    }
    const result: ModeInfo[] = [];
    for (const [id, value] of Object.entries(modes as Record<string, unknown>)) {
        if (!isValidModeId(id) || typeof value !== 'object' || value === null) {
            continue;
        }
        const entry = value as { description?: unknown; risk?: unknown };
        const risk = typeof entry.risk === 'string' && isValidRisk(entry.risk) ? entry.risk : undefined;
        result.push({ id, description: cleanText(entry.description), risk });
    }
    return result;
}

/** The config lives beside the script: <controller>/scripts/workflow.sh -> <controller>/config/. */
export function settingsFileFor(scriptPath: string): string {
    return path.join(path.dirname(scriptPath), '..', 'config', 'workflow_settings.json');
}

export function loadModes(scriptPath: string | undefined): LoadedModes {
    const settingsFile = scriptPath ? settingsFileFor(scriptPath) : '';
    try {
        if (!settingsFile) {
            throw new Error('no script path');
        }
        const stat = fs.statSync(settingsFile);
        if (!stat.isFile() || stat.size > MAX_CONFIG_BYTES) {
            throw new Error('config is not a regular file or is too large');
        }
        const modes = parseModes(JSON.parse(fs.readFileSync(settingsFile, 'utf8')));
        if (modes.length === 0) {
            throw new Error('config has no valid modes');
        }
        return { modes, source: 'config', settingsFile };
    } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        return { modes: FALLBACK_MODES, source: 'fallback', settingsFile, error: message };
    }
}
