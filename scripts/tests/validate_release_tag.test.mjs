import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { after, describe, test } from "node:test";
import { fileURLToPath } from "node:url";

const repositoryRoot = resolve(fileURLToPath(new URL("../..", import.meta.url)));
const validator = join(repositoryRoot, "scripts", "validate-release-tag.mjs");

const workspaces = [];

const writeManifest = (root, plugin, version) => {
    mkdirSync(join(root, "plugins", plugin), { recursive: true });
    writeFileSync(join(root, "plugins", plugin, "plugin.json"), JSON.stringify({ name: plugin, version }));
};

const newWorkspace = ({ changelog, pluginVersion = "0.1.0", luaVersion = "0.1.0" }) => {
    const root = mkdtempSync(join(tmpdir(), "rsprite-release-"));
    workspaces.push(root);
    writeManifest(root, "rsprite", pluginVersion);
    writeManifest(root, "rsprite-finder", "0.1.0");
    mkdirSync(join(root, "plugins", "rsprite", "src", "app"), { recursive: true });
    writeFileSync(join(root, "plugins", "rsprite", "src", "app", "init.lua"), `local rsprite = {\n    version = "${luaVersion}",\n}\n`);
    writeFileSync(join(root, "CHANGELOG.md"), changelog);
    return root;
};

const changelogWith = (heading) => `# Changelog\n\n${heading}\n\nBuilt against client 950-1.\n\n### Added\n\n- Everything.\n`;

const runValidator = (root, tag, existingTags = "") =>
    spawnSync(process.execPath, [validator, tag, "--root", root, "--existing-tags", existingTags], { encoding: "utf8" });

after(() => {
    for (const root of workspaces) {
        rmSync(root, { recursive: true, force: true });
    }
});

describe("validate-release-tag", () => {
    test("accepts a dated heading for the tagged version", () => {
        const root = newWorkspace({ changelog: changelogWith("## [0.1.0] - 2026-10-10") });
        const run = runValidator(root, "v0.1.0");
        assert.equal(run.status, 0, run.stderr);
        assert.match(run.stdout, /v0\.1\.0 matches/);
    });

    test("refuses a heading still marked Unreleased", () => {
        const root = newWorkspace({ changelog: changelogWith("## [0.1.0] - Unreleased") });
        const run = runValidator(root, "v0.1.0");
        assert.equal(run.status, 1);
        assert.match(run.stderr, /without a release date/);
    });

    test("refuses a changelog with no heading for the version", () => {
        const root = newWorkspace({ changelog: changelogWith("## [0.0.9] - 2026-01-01") });
        const run = runValidator(root, "v0.1.0");
        assert.equal(run.status, 1);
        assert.match(run.stderr, /no "## \[0\.1\.0\] - YYYY-MM-DD" heading/);
    });

    test("refuses a plugin on another version", () => {
        const root = newWorkspace({ changelog: changelogWith("## [0.1.0] - 2026-10-10"), pluginVersion: "0.2.0" });
        const run = runValidator(root, "v0.1.0");
        assert.equal(run.status, 1);
        assert.match(run.stderr, /plugins\/rsprite\/plugin\.json says version 0\.2\.0/);
    });

    test("refuses an rsprite.version that differs", () => {
        const root = newWorkspace({ changelog: changelogWith("## [0.1.0] - 2026-10-10"), luaVersion: "0.0.1" });
        const run = runValidator(root, "v0.1.0");
        assert.equal(run.status, 1);
        assert.match(run.stderr, /rsprite\.version/);
    });

    test("refuses a tag that is not higher than an existing one", () => {
        const root = newWorkspace({ changelog: changelogWith("## [0.1.0] - 2026-10-10") });
        const run = runValidator(root, "v0.1.0", "v0.2.0");
        assert.equal(run.status, 1);
        assert.match(run.stderr, /not higher than the existing v0\.2\.0/);
    });

    test("refuses a tag that is not a plain version", () => {
        const root = newWorkspace({ changelog: changelogWith("## [0.1.0] - 2026-10-10") });
        const run = runValidator(root, "v0.1.0-beta");
        assert.equal(run.status, 1);
        assert.match(run.stderr, /is not a release tag/);
    });

    test("refuses a plugin folder without a plugin.json, with a clear message", () => {
        const root = newWorkspace({ changelog: changelogWith("## [0.1.0] - 2026-10-10") });
        mkdirSync(join(root, "plugins", "stray"), { recursive: true });
        const run = runValidator(root, "v0.1.0");
        assert.equal(run.status, 1);
        assert.match(run.stderr, /^validate-release-tag: plugins\/stray has no plugin\.json/);
        assert.doesNotMatch(run.stderr, /\n\s+at /);
    });

    test("refuses a plugin.json that is not valid JSON, with a clear message", () => {
        const root = newWorkspace({ changelog: changelogWith("## [0.1.0] - 2026-10-10") });
        writeFileSync(join(root, "plugins", "rsprite-finder", "plugin.json"), "{ not json");
        const run = runValidator(root, "v0.1.0");
        assert.equal(run.status, 1);
        assert.match(run.stderr, /^validate-release-tag: plugins\/rsprite-finder\/plugin\.json is not valid JSON/);
        assert.doesNotMatch(run.stderr, /\n\s+at /);
    });
});

const LOCAL_SHA = "1111111111111111111111111111111111111111";
const DELETED_SHA = "0000000000000000000000000000000000000000";

const pushLine = (localReference, localSha = LOCAL_SHA) => `${localReference} ${localSha} ${localReference} ${DELETED_SHA}`;

const runPushed = (root, lines, existingTags = "") =>
    spawnSync(process.execPath, [validator, "--pushed", "--root", root, "--existing-tags", existingTags], {
        encoding: "utf8",
        input: lines.map((line) => `${line}\n`).join(""),
    });

describe("validate-release-tag --pushed", () => {
    test("checks a pushed tag read from the hook's input", () => {
        const root = newWorkspace({ changelog: changelogWith("## [0.1.0] - 2026-10-10") });
        const run = runPushed(root, [pushLine("refs/tags/v0.1.0")]);
        assert.equal(run.status, 0, run.stderr);
        assert.match(run.stdout, /validate-release-tag: v0\.1\.0 matches/);
    });

    test("refuses a pushed tag that does not match, with its message", () => {
        const root = newWorkspace({ changelog: changelogWith("## [0.1.0] - 2026-10-10") });
        const run = runPushed(root, [pushLine("refs/tags/v0.2.0")]);
        assert.equal(run.status, 1);
        assert.match(run.stderr, /^validate-release-tag: plugins\/rsprite\/plugin\.json says version 0\.1\.0, not 0\.2\.0/);
    });

    test("skips a tag that is being deleted", () => {
        const root = newWorkspace({ changelog: changelogWith("## [0.1.0] - 2026-10-10") });
        const run = runPushed(root, [pushLine("refs/tags/v9.9.9", DELETED_SHA)]);
        assert.equal(run.status, 0, run.stderr);
        assert.equal(run.stdout, "");
    });

    test("ignores branches pushed alongside", () => {
        const root = newWorkspace({ changelog: changelogWith("## [0.1.0] - 2026-10-10") });
        const run = runPushed(root, [pushLine("refs/heads/main"), pushLine("refs/heads/v9.9.9")]);
        assert.equal(run.status, 0, run.stderr);
        assert.equal(run.stdout, "");
    });

    test("checks every pushed tag and stops at the first that fails", () => {
        const root = newWorkspace({ changelog: changelogWith("## [0.1.0] - 2026-10-10") });
        const run = runPushed(root, [pushLine("refs/heads/main"), pushLine("refs/tags/v0.1.0"), pushLine("refs/tags/v0.3.0")]);
        assert.equal(run.status, 1);
        assert.match(run.stdout, /v0\.1\.0 matches/);
        assert.match(run.stderr, /not 0\.3\.0/);
    });

    test("does nothing for a push with no input", () => {
        const root = newWorkspace({ changelog: changelogWith("## [0.1.0] - Unreleased") });
        const run = runPushed(root, []);
        assert.equal(run.status, 0, run.stderr);
        assert.equal(run.stdout, "");
        assert.equal(run.stderr, "");
    });
});
