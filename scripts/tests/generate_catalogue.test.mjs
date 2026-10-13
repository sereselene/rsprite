import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { cpSync, existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { after, describe, test } from "node:test";
import { fileURLToPath } from "node:url";

const repositoryRoot = resolve(fileURLToPath(new URL("../..", import.meta.url)));
const generator = join(repositoryRoot, "scripts", "generate-catalogue.mjs");
const fixtures = join(repositoryRoot, "tests", "fixtures", "catalogue");
const dumpA = join(fixtures, "dump_a.txt");
const dumpB = join(fixtures, "dump_b.txt");

const workspaces = [];

const newWorkspace = () => {
    const root = mkdtempSync(join(tmpdir(), "rsprite-catalogue-"));
    workspaces.push(root);
    cpSync(join(fixtures, "tag-rules.json"), join(root, "catalogue", "tag-rules.json"));
    cpSync(join(fixtures, "curated.json"), join(root, "catalogue", "curated.json"));
    return root;
};

const runGenerator = (root, ...argumentsList) =>
    spawnSync(process.execPath, [generator, "--root", root, ...argumentsList], { encoding: "utf8" });

const read = (root, ...parts) => readFileSync(join(root, ...parts), "utf8");

const generatedFiles = (root) => ({
    sprites: read(root, "catalogue", "sprites.tsv"),
    build: read(root, "catalogue", "build.json"),
    curation: read(root, "plugins", "rsprite", "src", "data", "curation.lua"),
});

after(() => {
    for (const root of workspaces) {
        rmSync(root, { recursive: true, force: true });
    }
});

describe("generate-catalogue", () => {
    test("generates sprites.tsv, build.json and the curation module from a dump", () => {
        const root = newWorkspace();
        const run = runGenerator(root, "--dump", dumpA, "--client", "100-1");
        assert.equal(run.status, 0, run.stderr);
        const files = generatedFiles(root);
        assert.equal(files.sprites, "0\tALPHA_ICON\n1\tBETA_BUTTON\n2\tGAMMA_ICON\n3\tDELTA_OLD\n5\tEPSILON_ICON\n6\tZETA_BUTTON\n");
        assert.deepEqual(JSON.parse(files.build), { client: "100-1", count: 6, highestId: 6 });
        assert.match(files.curation, /ALPHA_ICON = \{/);
        assert.match(files.curation, /width = 16/);
        assert.match(files.curation, /prefix = "ALPHA_"/);
    });

    test("keeps curated.json and tag-rules.json byte identical across a regenerated dump", () => {
        const root = newWorkspace();
        const rulesBefore = read(root, "catalogue", "tag-rules.json");
        const curatedBefore = read(root, "catalogue", "curated.json");
        assert.equal(runGenerator(root, "--dump", dumpA, "--client", "100-1").status, 0);
        const run = runGenerator(root, "--dump", dumpB, "--client", "101-1", "--accept-orphans");
        assert.equal(run.status, 0, run.stderr);
        assert.equal(read(root, "catalogue", "tag-rules.json"), rulesBefore);
        assert.equal(read(root, "catalogue", "curated.json"), curatedBefore);
        assert.doesNotMatch(generatedFiles(root).curation, /EPSILON_ICON/);
    });

    test("fails on orphaned curated names unless they are accepted", () => {
        const root = newWorkspace();
        assert.equal(runGenerator(root, "--dump", dumpA, "--client", "100-1").status, 0);
        const before = generatedFiles(root);
        const run = runGenerator(root, "--dump", dumpB, "--client", "101-1");
        assert.equal(run.status, 1);
        assert.match(run.stderr, /EPSILON_ICON/);
        assert.deepEqual(generatedFiles(root), before);
    });

    test("fails when a tag rule matches nothing", () => {
        const root = newWorkspace();
        const rules = JSON.parse(read(root, "catalogue", "tag-rules.json"));
        rules.push({ prefix: "NOTHING_", tags: ["none"] });
        writeFileSync(join(root, "catalogue", "tag-rules.json"), JSON.stringify(rules));
        const run = runGenerator(root, "--dump", dumpA, "--client", "100-1");
        assert.equal(run.status, 1);
        assert.match(run.stderr, /prefix NOTHING_/);
    });

    test("writes a diff report listing each kind of change", () => {
        const root = newWorkspace();
        assert.equal(runGenerator(root, "--dump", dumpA, "--client", "100-1").status, 0);
        assert.equal(runGenerator(root, "--dump", dumpB, "--client", "101-1", "--accept-orphans").status, 0);
        const report = read(root, "catalogue", "diffs", "100-1-to-101-1.md");
        assert.match(report, /\| Added \| 1 \|/);
        assert.match(report, /- 7 ETA_ICON/);
        assert.match(report, /\| Removed \| 1 \|/);
        assert.match(report, /- 5 EPSILON_ICON/);
        assert.match(report, /\| Moved \| 1 \|/);
        assert.match(report, /- GAMMA_ICON: 2 to 4/);
        assert.match(report, /\| Likely renamed \| 1 \|/);
        assert.match(report, /- 3: DELTA_OLD to DELTA_NEW/);
    });

    test("produces identical output on every run", () => {
        const first = newWorkspace();
        const second = newWorkspace();
        assert.equal(runGenerator(first, "--dump", dumpA, "--client", "100-1").status, 0);
        assert.equal(runGenerator(second, "--dump", dumpA, "--client", "100-1").status, 0);
        assert.equal(runGenerator(second, "--dump", dumpA, "--client", "100-1").status, 0);
        assert.deepEqual(generatedFiles(first), generatedFiles(second));
    });

    test("check passes when up to date and fails on drift", () => {
        const root = newWorkspace();
        assert.equal(runGenerator(root, "--dump", dumpA, "--client", "100-1").status, 0);
        assert.equal(runGenerator(root, "--check").status, 0);

        const curationPath = join(root, "plugins", "rsprite", "src", "data", "curation.lua");
        const curation = readFileSync(curationPath, "utf8");
        writeFileSync(curationPath, curation.replace("first letter", "edited by hand"));
        const curationDrift = runGenerator(root, "--check");
        assert.equal(curationDrift.status, 1);
        assert.match(curationDrift.stderr, /curation\.lua/);
        writeFileSync(curationPath, curation);

        const rules = JSON.parse(read(root, "catalogue", "tag-rules.json"));
        rules[0].tags.push("extra");
        writeFileSync(join(root, "catalogue", "tag-rules.json"), JSON.stringify(rules));
        const rulesDrift = runGenerator(root, "--check");
        assert.equal(rulesDrift.status, 1);
        assert.match(rulesDrift.stderr, /curation\.lua/);
    });

    test("without a dump rebuilds only the curation module from the committed sprite list", () => {
        const root = newWorkspace();
        assert.equal(runGenerator(root, "--dump", dumpA, "--client", "100-1").status, 0);
        const before = generatedFiles(root);
        const curated = JSON.parse(read(root, "catalogue", "curated.json"));
        curated.BETA_BUTTON = { aliases: ["second button"] };
        writeFileSync(join(root, "catalogue", "curated.json"), JSON.stringify(curated));
        const run = runGenerator(root);
        assert.equal(run.status, 0, run.stderr);
        assert.match(run.stdout, /unchanged/);
        const after = generatedFiles(root);
        assert.equal(after.sprites, before.sprites);
        assert.equal(after.build, before.build);
        assert.match(after.curation, /BETA_BUTTON = \{/);
        assert.match(after.curation, /"second button"/);
        assert.equal(existsSync(join(root, "catalogue", "diffs")), false);
        assert.equal(runGenerator(root, "--check").status, 0);
    });

    test("without a dump leaves everything untouched when nothing changed", () => {
        const root = newWorkspace();
        assert.equal(runGenerator(root, "--dump", dumpA, "--client", "100-1").status, 0);
        const before = generatedFiles(root);
        assert.equal(runGenerator(root).status, 0);
        assert.deepEqual(generatedFiles(root), before);
    });

    test("without a dump fails on orphaned curated names unless they are accepted", () => {
        const root = newWorkspace();
        assert.equal(runGenerator(root, "--dump", dumpA, "--client", "100-1").status, 0);
        const before = generatedFiles(root);
        const curated = JSON.parse(read(root, "catalogue", "curated.json"));
        curated.MISSING_SPRITE = { aliases: ["missing"] };
        writeFileSync(join(root, "catalogue", "curated.json"), JSON.stringify(curated));
        const refused = runGenerator(root);
        assert.equal(refused.status, 1);
        assert.match(refused.stderr, /MISSING_SPRITE/);
        assert.deepEqual(generatedFiles(root), before);
        const accepted = runGenerator(root, "--accept-orphans");
        assert.equal(accepted.status, 0, accepted.stderr);
        assert.match(accepted.stdout, /left out the orphaned curated name MISSING_SPRITE/);
        assert.doesNotMatch(generatedFiles(root).curation, /MISSING_SPRITE/);
    });

    test("without a dump fails when a tag rule matches nothing", () => {
        const root = newWorkspace();
        assert.equal(runGenerator(root, "--dump", dumpA, "--client", "100-1").status, 0);
        const before = generatedFiles(root);
        const rules = JSON.parse(read(root, "catalogue", "tag-rules.json"));
        rules.push({ suffix: "_NOWHERE", tags: ["none"] });
        writeFileSync(join(root, "catalogue", "tag-rules.json"), JSON.stringify(rules));
        const run = runGenerator(root);
        assert.equal(run.status, 1);
        assert.match(run.stderr, /suffix _NOWHERE/);
        assert.deepEqual(generatedFiles(root), before);
    });

    test("without a dump needs the committed sprite list", () => {
        const run = runGenerator(newWorkspace());
        assert.equal(run.status, 1);
        assert.match(run.stderr, /committed catalogue\/sprites\.tsv/);
    });

    test("a dump needs a client build, and a client build needs a dump", () => {
        const root = newWorkspace();
        const dumpOnly = runGenerator(root, "--dump", dumpA);
        assert.equal(dumpOnly.status, 1);
        assert.match(dumpOnly.stderr, /--dump needs --client/);
        const clientOnly = runGenerator(root, "--client", "100-1");
        assert.equal(clientOnly.status, 1);
        assert.match(clientOnly.stderr, /--client only goes with --dump/);
    });

    test("rejects a dump with descending ids, duplicate names or bad characters", () => {
        const root = newWorkspace();
        const cases = [
            ["2 ALPHA_ICON\n1 BETA_BUTTON\n", /not above the previous id/],
            ["0 ALPHA_ICON\n1 ALPHA_ICON\n", /repeats the name ALPHA_ICON/],
            ["0 alpha_icon\n", /not made of A to Z/],
            ["0 ALPHA_ICON extra\n", /is not "<id> <NAME>"/],
        ];
        for (const [contents, expected] of cases) {
            const dumpPath = join(root, "broken.txt");
            writeFileSync(dumpPath, contents);
            const run = runGenerator(root, "--dump", dumpPath, "--client", "100-1");
            assert.equal(run.status, 1, contents);
            assert.match(run.stderr, expected);
        }
    });
});
