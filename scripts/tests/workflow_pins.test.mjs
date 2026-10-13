import assert from "node:assert/strict";
import { existsSync, readdirSync, readFileSync } from "node:fs";
import { join, resolve } from "node:path";
import { describe, test } from "node:test";
import { fileURLToPath } from "node:url";

const repositoryRoot = resolve(fileURLToPath(new URL("../..", import.meta.url)));
const USES_LINE = /^\s*(?:-\s+)?uses:\s*(\S+)/;
const PINNED_ACTION = /^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.\/-]+@[0-9a-f]{40}$/;
const LOCAL_ACTION = /^\.\//;

const workflowFiles = () => {
    const workflowsFolder = join(repositoryRoot, ".github", "workflows");
    const actionsFolder = join(repositoryRoot, ".github", "actions");
    const workflows = readdirSync(workflowsFolder)
        .filter((name) => /\.ya?ml$/.test(name))
        .map((name) => join(".github", "workflows", name));
    const actions = existsSync(actionsFolder)
        ? readdirSync(actionsFolder)
              .map((name) => join(".github", "actions", name, "action.yml"))
              .filter((path) => existsSync(join(repositoryRoot, path)))
        : [];
    return [...workflows, ...actions];
};

const remoteUses = (relativePath) =>
    readFileSync(join(repositoryRoot, relativePath), "utf8")
        .split(/\r?\n/)
        .map((line, index) => ({ line: index + 1, match: USES_LINE.exec(line) }))
        .filter(({ match }) => match !== null && !LOCAL_ACTION.test(match[1]))
        .map(({ line, match }) => ({ line, action: match[1] }));

describe("workflow pins", () => {
    test("finds the workflows and the composite action", () => {
        const files = workflowFiles().map((path) => path.split("\\").join("/"));
        assert.ok(files.includes(".github/workflows/release.yml"), files.join(", "));
        assert.ok(files.includes(".github/actions/comment-checks-summary/action.yml"), files.join(", "));
    });

    test("pins every action to a full commit SHA", () => {
        const unpinned = workflowFiles().flatMap((path) =>
            remoteUses(path)
                .filter(({ action }) => !PINNED_ACTION.test(action))
                .map(({ line, action }) => `${path.split("\\").join("/")}:${line} ${action}`),
        );
        assert.deepEqual(unpinned, []);
    });
});
