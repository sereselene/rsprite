import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { after, describe, test } from "node:test";
import { fileURLToPath } from "node:url";

const repositoryRoot = resolve(fileURLToPath(new URL("../..", import.meta.url)));
const checker = join(repositoryRoot, "scripts", "check-platform.mjs");
const LEFTHOOK_SYSTEM_NAMES = { win32: "windows" };

const styluaPackage = `@johnnymorganz/stylua-bin-${process.platform}-${process.arch}`;
const lefthookPackage = `lefthook-${LEFTHOOK_SYSTEM_NAMES[process.platform] ?? process.platform}-${process.arch}`;

const workspaces = [];

const newWorkspace = (packageNames) => {
    const root = mkdtempSync(join(tmpdir(), "rsprite-platform-"));
    workspaces.push(root);
    for (const packageName of packageNames) {
        const folder = join(root, "node_modules", ...packageName.split("/"));
        mkdirSync(folder, { recursive: true });
        writeFileSync(join(folder, "package.json"), JSON.stringify({ name: packageName }));
    }
    return root;
};

const runChecker = (...argumentsList) => spawnSync(process.execPath, [checker, ...argumentsList], { encoding: "utf8" });

after(() => {
    for (const root of workspaces) {
        rmSync(root, { recursive: true, force: true });
    }
});

describe("check-platform", () => {
    test("passes when every tool is installed for this platform", () => {
        const root = newWorkspace([styluaPackage, lefthookPackage, "fengari"]);
        const run = runChecker("--root", root);
        assert.equal(run.status, 0, run.stderr);
        assert.match(run.stdout, /StyLua, lefthook and fengari are all installed/);
    });

    test("fails and names the package when the lefthook binary is missing", () => {
        const root = newWorkspace([styluaPackage, "fengari"]);
        const run = runChecker("--root", root);
        assert.equal(run.status, 1);
        assert.ok(run.stderr.includes(`lefthook has no ${process.platform}-${process.arch} package in node_modules (${lefthookPackage})`), run.stderr);
        assert.match(run.stderr, /run npm install from/);
        assert.doesNotMatch(run.stderr, /StyLua has no/);
    });

    test("names every missing tool in an empty node_modules", () => {
        const root = newWorkspace([]);
        const run = runChecker("--root", root);
        assert.equal(run.status, 1);
        for (const tool of ["StyLua", "lefthook", "fengari"]) {
            assert.match(run.stderr, new RegExp(`${tool} has no`));
        }
    });

    test("refuses an unknown argument", () => {
        const run = runChecker("--everything");
        assert.equal(run.status, 1);
        assert.match(run.stderr, /^check-platform: Unknown argument --everything/);
    });
});
