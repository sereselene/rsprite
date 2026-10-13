import { spawnSync } from "node:child_process";
import { existsSync, readdirSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

import { describePath, failedCheckLines, repositoryRoot } from "./lua-runner.mjs";

const singleFileRunner = fileURLToPath(new URL("./runlua.mjs", import.meta.url));
const testsRoot = join(repositoryRoot, "tests");

const findSelftests = (directory) => {
    if (!existsSync(directory)) return [];
    return readdirSync(directory, { withFileTypes: true })
        .sort((first, second) => first.name.localeCompare(second.name))
        .flatMap((entry) => {
            const entryPath = join(directory, entry.name);
            if (entry.isDirectory()) return findSelftests(entryPath);
            return entry.name.endsWith("_selftest.lua") ? [describePath(entryPath)] : [];
        });
};

const runSelftest = (relativePath) => {
    const run = spawnSync(process.execPath, [singleFileRunner, relativePath], { cwd: repositoryRoot, encoding: "utf8" });
    const output = `${run.stdout ?? ""}${run.stderr ?? ""}`.split(/\r?\n/);
    const failedChecks = failedCheckLines(output);
    const raised = run.status !== 0;
    return { output, raised, failedChecks, passed: !raised && failedChecks.length === 0 };
};

const selftests = findSelftests(testsRoot);
if (selftests.length === 0) {
    console.error("No files matching *_selftest.lua under tests/, so there is nothing to run.");
    process.exit(1);
}

const failedFiles = [];
for (const selftest of selftests) {
    const result = runSelftest(selftest);
    if (result.passed) {
        console.log(`OK    ${selftest}`);
        continue;
    }
    failedFiles.push(selftest);
    console.log(`FAIL  ${selftest}`);
    if (result.raised) {
        for (const line of result.output.filter((line) => line.trim() !== "").slice(-5)) {
            console.log(`      ${line}`);
        }
    }
    for (const line of result.failedChecks) {
        console.log(`      ${line}`);
    }
}

console.log("");
if (failedFiles.length > 0) {
    console.log(`${failedFiles.length} of ${selftests.length} selftest files failed.`);
    process.exitCode = 1;
} else {
    console.log(`${selftests.length} selftest files passed.`);
}
