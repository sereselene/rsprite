import { spawnSync } from "node:child_process";
import { existsSync, readFileSync, readdirSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const defaultRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const TAG_PATTERN = /^v(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/;
const DELETED_REFERENCE = /^0+$/;
const LUA_VERSION = /^\s*version\s*=\s*"([^"]+)"/m;
const RELEASE_DATE = String.raw`\d{4}-\d{2}-\d{2}`;

class TagError extends Error {}

const parseArguments = (argv) => {
    const options = { tag: null, pushed: false, existingTags: null, root: defaultRoot };
    for (let index = 0; index < argv.length; index += 1) {
        const argument = argv[index];
        if (argument === "--pushed") options.pushed = true;
        else if (argument === "--existing-tags") {
            options.existingTags = (argv[index + 1] ?? "").split(",").filter((tag) => tag !== "");
            index += 1;
        } else if (argument === "--root") {
            options.root = resolve(argv[index + 1] ?? ".");
            index += 1;
        } else if (!argument.startsWith("--") && options.tag === null) options.tag = argument;
        else throw new TagError(`Unknown argument ${argument}. Pass a tag such as v0.1.0, or --pushed from the pre-push hook.`);
    }
    return options;
};

const versionOf = (tag) => TAG_PATTERN.exec(tag).slice(1).map(Number);

const isHigher = (first, second) => {
    for (let index = 0; index < 3; index += 1) {
        if (first[index] !== second[index]) return first[index] > second[index];
    }
    return false;
};

const readManifest = (pluginsRoot, pluginName) => {
    const manifestPath = join(pluginsRoot, pluginName, "plugin.json");
    if (!existsSync(manifestPath)) throw new TagError(`plugins/${pluginName} has no plugin.json. Every folder under plugins must be a plugin.`);
    try {
        return JSON.parse(readFileSync(manifestPath, "utf8"));
    } catch (error) {
        throw new TagError(`plugins/${pluginName}/plugin.json is not valid JSON: ${error.message}`);
    }
};

const listExistingTags = (repositoryRoot) => {
    const run = spawnSync("git", ["tag", "--list", "v*"], { cwd: repositoryRoot, encoding: "utf8" });
    if (run.status !== 0) throw new TagError(`Could not list the existing tags: ${run.stderr || run.stdout}`);
    return run.stdout.split(/\r?\n/).filter((tag) => tag !== "");
};

const validate = (tag, existingTags, repositoryRoot) => {
    if (!TAG_PATTERN.test(tag)) throw new TagError(`${tag} is not a release tag. Release tags look like v0.1.0, with no pre-release suffix.`);
    const version = tag.slice(1);

    const pluginsRoot = join(repositoryRoot, "plugins");
    for (const plugin of readdirSync(pluginsRoot, { withFileTypes: true }).filter((entry) => entry.isDirectory())) {
        const manifest = readManifest(pluginsRoot, plugin.name);
        if (manifest.version !== version) {
            throw new TagError(`plugins/${plugin.name}/plugin.json says version ${manifest.version}, not ${version}. Every plugin in this repository ships on the same version.`);
        }
    }

    const initPath = join(pluginsRoot, "rsprite", "src", "app", "init.lua");
    const luaVersion = LUA_VERSION.exec(readFileSync(initPath, "utf8"))?.[1];
    if (luaVersion !== version) {
        throw new TagError(`rsprite.version in plugins/rsprite/src/app/init.lua is ${luaVersion}, not ${version}.`);
    }

    const changelogPath = join(repositoryRoot, "CHANGELOG.md");
    const changelog = existsSync(changelogPath) ? readFileSync(changelogPath, "utf8") : "";
    const escapedVersion = version.replaceAll(".", "\\.");
    const anyHeading = new RegExp(`^##\\s+\\[${escapedVersion}\\]`, "m");
    const datedHeading = new RegExp(`^## \\[${escapedVersion}\\] - ${RELEASE_DATE}$`, "m");
    if (!anyHeading.test(changelog)) {
        throw new TagError(`CHANGELOG.md has no "## [${version}] - YYYY-MM-DD" heading. Add one above this release's notes before tagging.`);
    }
    if (!datedHeading.test(changelog)) {
        throw new TagError(`CHANGELOG.md has a "## [${version}]" heading without a release date. Change it to "## [${version}] - YYYY-MM-DD", using the day you tag.`);
    }

    const previous = existingTags.filter((existing) => existing !== tag && TAG_PATTERN.test(existing)).map(versionOf);
    const highest = previous.reduce((best, candidate) => (best === null || isHigher(candidate, best) ? candidate : best), null);
    if (highest !== null && !isHigher(versionOf(tag), highest)) {
        throw new TagError(`${tag} is not higher than the existing v${highest.join(".")}.`);
    }
    console.log(`validate-release-tag: ${tag} matches every plugin.json, rsprite.version and CHANGELOG.md, and is the highest release.`);
};

const pushedTags = () =>
    readFileSync(0, "utf8")
        .split(/\r?\n/)
        .map((line) => line.trim().split(/\s+/))
        .filter(([localReference, localSha]) => localReference?.startsWith("refs/tags/v") && !DELETED_REFERENCE.test(localSha ?? ""))
        .map(([localReference]) => localReference.slice("refs/tags/".length));

try {
    const options = parseArguments(process.argv.slice(2));
    const tags = options.pushed ? pushedTags() : [options.tag];
    if (tags.includes(null)) throw new TagError("Pass the tag to check, for example npm run validate-tag -- v0.1.0.");
    if (tags.length > 0) {
        const existingTags = options.existingTags ?? listExistingTags(options.root);
        for (const tag of tags) validate(tag, existingTags, options.root);
    }
} catch (error) {
    if (!(error instanceof TagError)) throw error;
    console.error(`validate-release-tag: ${error.message}`);
    process.exitCode = 1;
}
