import { existsSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const repositoryRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const nodeModules = join(repositoryRoot, "node_modules");

const LEFTHOOK_SYSTEM_NAMES = { win32: "windows", linux: "linux", darwin: "darwin", freebsd: "freebsd", openbsd: "openbsd" };
const SIDE_NAMES = { win32: "Windows", linux: "Linux or WSL", darwin: "macOS" };

const platform = process.platform;
const architecture = process.arch;
const side = SIDE_NAMES[platform] ?? platform;

const required = [
    { tool: "StyLua", packageName: `@johnnymorganz/stylua-bin-${platform}-${architecture}` },
    { tool: "lefthook", packageName: `lefthook-${LEFTHOOK_SYSTEM_NAMES[platform] ?? platform}-${architecture}` },
    { tool: "fengari", packageName: "fengari" },
];

const missing = required.filter(({ packageName }) => !existsSync(join(nodeModules, packageName, "package.json")));

if (missing.length === 0) {
    console.log(`check-platform: StyLua, lefthook and fengari are all installed for ${side} (${platform}-${architecture}).`);
} else {
    for (const { tool, packageName } of missing) {
        console.error(`check-platform: ${tool} has no ${platform}-${architecture} package in node_modules (${packageName}).`);
    }
    console.error(
        `check-platform: run npm install from ${side} as well as from the other side. Each side installs only its own binaries, ` +
            "so install once from WSL and once from Windows, and never run npm ci locally because it removes the other side's binaries.",
    );
    process.exitCode = 1;
}
