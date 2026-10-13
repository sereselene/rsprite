import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { after, describe, test } from "node:test";
import { fileURLToPath } from "node:url";

const repositoryRoot = resolve(fileURLToPath(new URL("../..", import.meta.url)));
const writer = join(repositoryRoot, "scripts", "release-notes.mjs");

const workspaces = [];

const newWorkspace = (changelog, client = "951-2") => {
    const root = mkdtempSync(join(tmpdir(), "rsprite-notes-"));
    workspaces.push(root);
    mkdirSync(join(root, "catalogue"), { recursive: true });
    writeFileSync(join(root, "catalogue", "build.json"), JSON.stringify({ client, count: 1, highestId: 1 }));
    writeFileSync(join(root, "CHANGELOG.md"), changelog);
    return root;
};

const CHANGELOG = [
    "# Changelog",
    "",
    "Intro text.",
    "",
    "## [0.2.0] - 2026-11-01",
    "",
    "### Fixed",
    "",
    "- A fix.",
    "",
    "## [0.1.0] - 2026-10-13",
    "",
    "The first release.",
    "",
    "### Added",
    "",
    "- Everything.",
    "",
    "[0.1.0]: https://example.com/v0.1.0",
    "",
].join("\n");

const runWriter = (root, tag) => spawnSync(process.execPath, [writer, tag, "--root", root], { encoding: "utf8" });

after(() => {
    for (const root of workspaces) {
        rmSync(root, { recursive: true, force: true });
    }
});

describe("release-notes", () => {
    test("starts with the install paragraph naming the version and client build", () => {
        const run = runWriter(newWorkspace(CHANGELOG), "v0.2.0");
        assert.equal(run.status, 0, run.stderr);
        const [paragraph] = run.stdout.split("\n\n");
        assert.match(paragraph, /^rsprite 0\.2\.0 and the rsprite finder, built against client `951-2`\. rsprite is not on the Plugin Hub yet\./);
        assert.match(paragraph, /run `prf` followed by `prl rsprite` and `prl rsprite-finder` in the game's console\./);
        assert.doesNotMatch(paragraph, /\n/);
    });

    test("copies the version's section exactly, stopping at the next heading", () => {
        const run = runWriter(newWorkspace(CHANGELOG), "v0.2.0");
        assert.equal(run.stdout.split("\n\n").slice(1).join("\n\n"), "### Fixed\n\n- A fix.\n");
    });

    test("stops before the link definitions", () => {
        const run = runWriter(newWorkspace(CHANGELOG), "v0.1.0");
        assert.equal(run.status, 0, run.stderr);
        assert.ok(run.stdout.endsWith("The first release.\n\n### Added\n\n- Everything.\n"), run.stdout);
        assert.doesNotMatch(run.stdout, /example\.com/);
    });

    test("refuses a version with no section", () => {
        const run = runWriter(newWorkspace(CHANGELOG), "v0.3.0");
        assert.equal(run.status, 1);
        assert.match(run.stderr, /^release-notes: CHANGELOG\.md has no "## \[0\.3\.0\]" section/);
    });

    test("refuses a heading still marked Unreleased", () => {
        const run = runWriter(newWorkspace(CHANGELOG.replace("## [0.2.0] - 2026-11-01", "## [0.2.0] - Unreleased")), "v0.2.0");
        assert.equal(run.status, 1);
        assert.match(run.stderr, /has no release date/);
    });

    test("refuses an empty section", () => {
        const run = runWriter(newWorkspace(CHANGELOG.replace("### Fixed\n\n- A fix.\n", "")), "v0.2.0");
        assert.equal(run.status, 1);
        assert.match(run.stderr, /section for 0\.2\.0 is empty/);
    });

    test("refuses a tag that is not a plain version", () => {
        const run = runWriter(newWorkspace(CHANGELOG), "v0.2.0-beta");
        assert.equal(run.status, 1);
        assert.match(run.stderr, /is not a release tag/);
    });
});
