import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync, mkdtempSync, readdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { after, describe, test } from "node:test";
import { fileURLToPath } from "node:url";

const repositoryRoot = resolve(fileURLToPath(new URL("../..", import.meta.url)));
const installer = join(repositoryRoot, "scripts", "dev-install.mjs");
const INSTALLED_FOLDERS = ["rsprite", "rsprite-example", "rsprite-finder", "rsprite-sprite-probe"];

const workspaces = [];

const newTarget = () => {
    const target = mkdtempSync(join(tmpdir(), "rsprite-dev-install-"));
    workspaces.push(target);
    return target;
};

const environmentWithoutTarget = (extra = {}) => {
    const environment = { ...process.env, ...extra };
    if (extra.RSPRITE_DEV_PLUGIN_FOLDER === undefined) delete environment.RSPRITE_DEV_PLUGIN_FOLDER;
    return environment;
};

const runInstaller = (argumentsList, extraEnvironment) =>
    spawnSync(process.execPath, [installer, ...argumentsList], { encoding: "utf8", env: environmentWithoutTarget(extraEnvironment) });

const writeFolder = (target, folder, files) => {
    mkdirSync(join(target, folder), { recursive: true });
    for (const [name, contents] of Object.entries(files)) {
        writeFileSync(join(target, folder, name), contents);
    }
};

const snapshot = (folder) =>
    readdirSync(folder, { withFileTypes: true, recursive: true })
        .filter((entry) => entry.isFile())
        .map((entry) => {
            const path = join(entry.parentPath ?? entry.path, entry.name);
            return `${path.slice(folder.length)}=${readFileSync(path, "utf8")}`;
        })
        .sort();

after(() => {
    for (const target of workspaces) {
        rmSync(target, { recursive: true, force: true });
    }
});

describe("dev-install", () => {
    test("copies rsprite, the finder and the example into an empty target", () => {
        const target = newTarget();
        const run = runInstaller(["--target", target]);
        assert.equal(run.status, 0, run.stderr);
        assert.deepEqual(readdirSync(target).sort(), INSTALLED_FOLDERS);
        for (const folder of INSTALLED_FOLDERS) {
            assert.equal(JSON.parse(readFileSync(join(target, folder, "plugin.json"), "utf8")).name, folder);
        }
        assert.ok(existsSync(join(target, "rsprite", "src", "app", "init.lua")));
        assert.match(run.stdout, /dev-install: done/);
    });

    test("replaces its own folder completely, so stale files go", () => {
        const target = newTarget();
        writeFolder(target, "rsprite", { "plugin.json": JSON.stringify({ name: "rsprite" }), "stale.lua": "return {}\n" });
        const run = runInstaller(["--target", target]);
        assert.equal(run.status, 0, run.stderr);
        assert.equal(existsSync(join(target, "rsprite", "stale.lua")), false);
        assert.ok(existsSync(join(target, "rsprite", "main.lua")));
    });

    test("leaves folders it does not install alone", () => {
        const target = newTarget();
        writeFolder(target, "someone-else", { "plugin.json": JSON.stringify({ name: "someone-else" }), "main.lua": "return {}\n" });
        const before = snapshot(join(target, "someone-else"));
        assert.equal(runInstaller(["--target", target]).status, 0);
        assert.deepEqual(snapshot(join(target, "someone-else")), before);
        assert.deepEqual(readdirSync(target).sort(), [...INSTALLED_FOLDERS, "someone-else"].sort());
    });

    test("refuses a folder of the same name that belongs to another plugin, and changes nothing", () => {
        const target = newTarget();
        writeFolder(target, "rsprite-finder", { "plugin.json": JSON.stringify({ name: "another-finder" }), "main.lua": "return {}\n" });
        const before = snapshot(target);
        const run = runInstaller(["--target", target]);
        assert.equal(run.status, 1);
        assert.match(run.stderr, /These folders exist but are not rsprite's, so nothing was changed/);
        assert.ok(run.stderr.includes(join(target, "rsprite-finder")), run.stderr);
        assert.deepEqual(snapshot(target), before);
        assert.deepEqual(readdirSync(target), ["rsprite-finder"]);
    });

    test("refuses a folder of the same name with no plugin.json, and changes nothing", () => {
        const target = newTarget();
        writeFolder(target, "rsprite-example", { "notes.txt": "mine" });
        const before = snapshot(target);
        const run = runInstaller(["--target", target]);
        assert.equal(run.status, 1);
        assert.ok(run.stderr.includes(join(target, "rsprite-example")), run.stderr);
        assert.deepEqual(snapshot(target), before);
    });

    test("refuses a target folder that does not exist", () => {
        const missing = join(newTarget(), "not-there");
        const run = runInstaller(["--target", missing]);
        assert.equal(run.status, 1);
        assert.match(run.stderr, /is not an existing folder/);
        assert.equal(existsSync(missing), false);
    });

    test("stops when there is no target at all", () => {
        const run = runInstaller([]);
        assert.equal(run.status, 1);
        assert.match(run.stderr, /^dev-install: No target folder/);
    });

    test("reads the target from RSPRITE_DEV_PLUGIN_FOLDER", () => {
        const target = newTarget();
        const run = runInstaller([], { RSPRITE_DEV_PLUGIN_FOLDER: target });
        assert.equal(run.status, 0, run.stderr);
        assert.deepEqual(readdirSync(target).sort(), INSTALLED_FOLDERS);
    });

    test("refuses an unknown argument", () => {
        const target = newTarget();
        const run = runInstaller(["--target", target, "--everywhere"]);
        assert.equal(run.status, 1);
        assert.match(run.stderr, /Unknown argument --everywhere/);
        assert.deepEqual(readdirSync(target), []);
    });
});
