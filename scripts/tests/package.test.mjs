import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync, mkdtempSync, readdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { after, describe, test } from "node:test";
import { fileURLToPath } from "node:url";

import { unzipSync } from "fflate";

const repositoryRoot = resolve(fileURLToPath(new URL("../..", import.meta.url)));
const packager = join(repositoryRoot, "scripts", "package.mjs");
const PNG_BYTES = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0xff]);

const workspaces = [];

const writeFile = (root, relativePath, contents) => {
    const path = join(root, ...relativePath.split("/"));
    mkdirSync(join(path, ".."), { recursive: true });
    writeFileSync(path, contents);
};

const writePlugin = (root, name, version) => {
    writeFile(root, `plugins/${name}/plugin.json`, JSON.stringify({ name, version }));
    writeFile(root, `plugins/${name}/main.lua`, `return {}\n`);
    writeFile(root, `plugins/${name}/src/app/init.lua`, `return { name = "${name}" }\n`);
    writeFile(root, `plugins/${name}/resources/image.png`, PNG_BYTES);
    writeFile(root, `plugins/${name}/src/empty.lua`, "");
};

const newWorkspace = ({ coreVersion = "0.2.0", finderVersion = "0.2.0" } = {}) => {
    const root = mkdtempSync(join(tmpdir(), "rsprite-package-"));
    workspaces.push(root);
    writePlugin(root, "rsprite", coreVersion);
    writePlugin(root, "rsprite-finder", finderVersion);
    return root;
};

const runPackager = (root) => spawnSync(process.execPath, [packager, "--root", root], { encoding: "utf8" });

const releaseFiles = (root) => (existsSync(join(root, "release")) ? readdirSync(join(root, "release")).sort() : []);

const expectRefusal = (root, message) => {
    const run = runPackager(root);
    assert.equal(run.status, 1, run.stdout);
    assert.match(run.stderr, message);
    assert.doesNotMatch(run.stderr, /\n\s+at /);
    assert.deepEqual(releaseFiles(root), []);
};

after(() => {
    for (const root of workspaces) {
        rmSync(root, { recursive: true, force: true });
    }
});

describe("package", () => {
    test("builds one zip per plugin, named from its own plugin.json version", () => {
        const root = newWorkspace({ finderVersion: "0.3.1" });
        const run = runPackager(root);
        assert.equal(run.status, 0, run.stderr);
        assert.deepEqual(releaseFiles(root), ["rsprite-0.2.0.zip", "rsprite-finder-0.3.1.zip"]);
        assert.match(run.stdout, /package: release\/rsprite-0\.2\.0\.zip, 5 files, \d+\.\d KB/);
        assert.match(run.stdout, /package: release\/rsprite-finder-0\.3\.1\.zip, 5 files, \d+\.\d KB/);
    });

    test("puts every file under one top folder named after the plugin, matching the folder exactly", () => {
        const root = newWorkspace();
        assert.equal(runPackager(root).status, 0);
        const extracted = unzipSync(readFileSync(join(root, "release", "rsprite-finder-0.2.0.zip")));
        assert.deepEqual(Object.keys(extracted), [
            "rsprite-finder/main.lua",
            "rsprite-finder/plugin.json",
            "rsprite-finder/resources/image.png",
            "rsprite-finder/src/app/init.lua",
            "rsprite-finder/src/empty.lua",
        ]);
        assert.deepEqual(Buffer.from(extracted["rsprite-finder/resources/image.png"]), PNG_BYTES);
        assert.equal(Buffer.from(extracted["rsprite-finder/src/app/init.lua"]).toString("utf8"), `return { name = "rsprite-finder" }\n`);
        assert.equal(extracted["rsprite-finder/src/empty.lua"].length, 0);
    });

    test("gives identical bytes every time", () => {
        const root = newWorkspace();
        assert.equal(runPackager(root).status, 0);
        const first = readFileSync(join(root, "release", "rsprite-0.2.0.zip"));
        assert.equal(runPackager(root).status, 0);
        assert.deepEqual(readFileSync(join(root, "release", "rsprite-0.2.0.zip")), first);
    });

    test("refuses a missing plugin folder and writes nothing", () => {
        const root = newWorkspace();
        rmSync(join(root, "plugins", "rsprite-finder"), { recursive: true, force: true });
        expectRefusal(root, /^package: plugins\/rsprite-finder is missing/);
    });

    test("refuses an empty plugin folder and writes nothing", () => {
        const root = newWorkspace();
        rmSync(join(root, "plugins", "rsprite"), { recursive: true, force: true });
        mkdirSync(join(root, "plugins", "rsprite", "src"), { recursive: true });
        expectRefusal(root, /^package: plugins\/rsprite has no files, so its zip would be empty/);
    });

    test("refuses a plugin folder without main.lua and writes nothing", () => {
        const root = newWorkspace();
        rmSync(join(root, "plugins", "rsprite", "main.lua"));
        expectRefusal(root, /^package: plugins\/rsprite has no main\.lua/);
    });

    test("refuses a plugin folder without plugin.json and writes nothing", () => {
        const root = newWorkspace();
        rmSync(join(root, "plugins", "rsprite-finder", "plugin.json"));
        expectRefusal(root, /^package: plugins\/rsprite-finder has no plugin\.json/);
    });

    test("refuses a plugin.json that is not valid JSON and writes nothing", () => {
        const root = newWorkspace();
        writeFile(root, "plugins/rsprite/plugin.json", "{ not json");
        expectRefusal(root, /^package: plugins\/rsprite\/plugin\.json is not valid JSON/);
    });

    test("refuses a plugin.json without a plain version and writes nothing", () => {
        const root = newWorkspace({ coreVersion: "0.2" });
        expectRefusal(root, /^package: plugins\/rsprite\/plugin\.json needs a version such as "0\.1\.0"/);
    });
});

describe("package and the sprite probe", () => {
    test("never zips the sprite probe from the real repository", () => {
        assert.ok(existsSync(join(repositoryRoot, "examples", "sprite-probe", "plugin.json")), "the probe exists to be left out");
        const output = mkdtempSync(join(tmpdir(), "rsprite-package-real-"));
        workspaces.push(output);
        const run = spawnSync(process.execPath, [packager, "--output", output], { encoding: "utf8" });
        assert.equal(run.status, 0, run.stderr);
        const archives = readdirSync(output).sort();
        assert.equal(archives.length, 2, archives.join(", "));
        assert.ok(archives.every((name) => /^rsprite(-finder)?-\d+\.\d+\.\d+\.zip$/.test(name)), archives.join(", "));
        for (const archive of archives) {
            const paths = Object.keys(unzipSync(readFileSync(join(output, archive))));
            const folder = archive.startsWith("rsprite-finder-") ? "rsprite-finder/" : "rsprite/";
            assert.ok(paths.length > 0, archive);
            assert.deepEqual(paths.filter((path) => !path.startsWith(folder)), [], archive);
            assert.deepEqual(paths.filter((path) => /probe|examples/i.test(path)), [], archive);
        }
    });

    test("leaves out a sprite probe folder in any checkout", () => {
        const root = newWorkspace();
        writeFile(root, "examples/sprite-probe/plugin.json", JSON.stringify({ name: "rsprite-sprite-probe", version: "0.0.1" }));
        writeFile(root, "examples/sprite-probe/main.lua", "return {}\n");
        assert.equal(runPackager(root).status, 0);
        assert.deepEqual(releaseFiles(root), ["rsprite-0.2.0.zip", "rsprite-finder-0.2.0.zip"]);
        for (const archive of releaseFiles(root)) {
            const paths = Object.keys(unzipSync(readFileSync(join(root, "release", archive))));
            assert.deepEqual(paths.filter((path) => path.includes("sprite-probe")), [], archive);
        }
    });
});
