import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { createRequire } from "node:module";
import { dirname, join, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const toolingRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const require = createRequire(import.meta.url);

const NAME_PATTERN = /^[A-Z0-9_]+$/;
const ENTRY_LINE = /^(\d+)[ \t]+(\S+)$/;
const WORDS_PATTERN = /^[a-z0-9]+( [a-z0-9]+)*$/;
const ASCII_LINE = /^[\x20-\x7e\t]*$/;
const LUA_IDENTIFIER = /^[A-Za-z_][A-Za-z0-9_]*$/;
const RULE_MATCHERS = ["prefix", "contains", "suffix"];
const RULE_KEYS = new Set([...RULE_MATCHERS, "tags"]);
const CURATED_KEYS = new Set(["tags", "aliases", "width", "height"]);

class CatalogueError extends Error {}

const parseArguments = (argv) => {
    const options = { dump: null, client: null, acceptOrphans: false, check: false, root: toolingRoot };
    for (let index = 0; index < argv.length; index += 1) {
        const argument = argv[index];
        const takeValue = () => {
            const value = argv[index + 1];
            if (value === undefined || value.startsWith("--")) {
                throw new CatalogueError(`${argument} needs a value.`);
            }
            index += 1;
            return value;
        };
        if (argument === "--dump") options.dump = resolve(takeValue());
        else if (argument === "--client") options.client = takeValue();
        else if (argument === "--root") options.root = resolve(takeValue());
        else if (argument === "--accept-orphans") options.acceptOrphans = true;
        else if (argument === "--check") options.check = true;
        else throw new CatalogueError(`Unknown argument ${argument}. Use --dump, --client, --root, --accept-orphans or --check.`);
    }
    if (options.dump !== null && options.client === null) {
        throw new CatalogueError("--dump needs --client <build> too, for example --dump ../sprite-dumps/950-1.txt --client 950-1.");
    }
    if (options.dump === null && options.client !== null) {
        throw new CatalogueError("--client only goes with --dump. Without a dump the client build comes from catalogue/build.json.");
    }
    return options;
};

const pathsFor = (root) => {
    const catalogue = join(root, "catalogue");
    return {
        root,
        sprites: join(catalogue, "sprites.tsv"),
        build: join(catalogue, "build.json"),
        rules: join(catalogue, "tag-rules.json"),
        curated: join(catalogue, "curated.json"),
        diffs: join(catalogue, "diffs"),
        curation: join(root, "plugins", "rsprite", "src", "data", "curation.lua"),
    };
};

const describe = (paths, path) => relative(paths.root, path).split("\\").join("/");

const readText = (paths, path) => {
    if (!existsSync(path)) {
        throw new CatalogueError(`There is no ${describe(paths, path)} to read.`);
    }
    return readFileSync(path, "utf8");
};

const readJson = (paths, path) => {
    try {
        return JSON.parse(readText(paths, path));
    } catch (error) {
        if (error instanceof CatalogueError) throw error;
        throw new CatalogueError(`${describe(paths, path)} is not valid JSON: ${error.message}`);
    }
};

const parseEntries = (text, source) => {
    const entries = [];
    const lineByName = new Map();
    let previousId = -1;
    text.split(/\r?\n/).forEach((rawLine, index) => {
        const lineNumber = index + 1;
        if (rawLine.trim() === "") return;
        if (!ASCII_LINE.test(rawLine)) {
            throw new CatalogueError(`${source} line ${lineNumber} is not plain ASCII.`);
        }
        const match = ENTRY_LINE.exec(rawLine.trim());
        if (match === null) {
            throw new CatalogueError(`${source} line ${lineNumber} is not "<id> <NAME>": ${rawLine}`);
        }
        const id = Number(match[1]);
        const name = match[2];
        if (!NAME_PATTERN.test(name)) {
            throw new CatalogueError(`${source} line ${lineNumber} has the name ${name}, which is not made of A to Z, 0 to 9 and underscores.`);
        }
        if (id <= previousId) {
            throw new CatalogueError(`${source} line ${lineNumber} has id ${id}, which is not above the previous id ${previousId}.`);
        }
        if (lineByName.has(name)) {
            throw new CatalogueError(`${source} line ${lineNumber} repeats the name ${name} from line ${lineByName.get(name)}.`);
        }
        lineByName.set(name, lineNumber);
        previousId = id;
        entries.push({ id, name });
    });
    if (entries.length === 0) {
        throw new CatalogueError(`${source} has no entries.`);
    }
    return entries;
};

const checkWords = (value, where) => {
    if (!Array.isArray(value) || value.some((item) => typeof item !== "string" || !WORDS_PATTERN.test(item))) {
        throw new CatalogueError(`${where} must be an array of lower case words such as "arrow up".`);
    }
};

const validateRules = (rules) => {
    if (!Array.isArray(rules)) {
        throw new CatalogueError("tag-rules.json must be an array of rules.");
    }
    rules.forEach((rule, index) => {
        const where = `tag-rules.json rule ${index + 1}`;
        if (rule === null || typeof rule !== "object" || Array.isArray(rule)) {
            throw new CatalogueError(`${where} must be an object.`);
        }
        const unknown = Object.keys(rule).filter((key) => !RULE_KEYS.has(key));
        if (unknown.length > 0) {
            throw new CatalogueError(`${where} has unknown keys: ${unknown.join(", ")}.`);
        }
        const matchers = RULE_MATCHERS.filter((key) => rule[key] !== undefined);
        if (matchers.length === 0) {
            throw new CatalogueError(`${where} needs at least one of prefix, contains or suffix.`);
        }
        for (const key of matchers) {
            if (typeof rule[key] !== "string" || !NAME_PATTERN.test(rule[key])) {
                throw new CatalogueError(`${where} ${key} must be upper case letters, digits and underscores.`);
            }
        }
        checkWords(rule.tags, `${where} tags`);
        if (rule.tags.length === 0) {
            throw new CatalogueError(`${where} must give at least one tag.`);
        }
    });
    return rules;
};

const validateCurated = (curated) => {
    if (curated === null || typeof curated !== "object" || Array.isArray(curated)) {
        throw new CatalogueError("curated.json must be an object keyed by sprite name.");
    }
    for (const [name, entry] of Object.entries(curated)) {
        const where = `curated.json ${name}`;
        if (!NAME_PATTERN.test(name)) {
            throw new CatalogueError(`${where} is not a sprite name made of A to Z, 0 to 9 and underscores.`);
        }
        if (entry === null || typeof entry !== "object" || Array.isArray(entry)) {
            throw new CatalogueError(`${where} must be an object.`);
        }
        const unknown = Object.keys(entry).filter((key) => !CURATED_KEYS.has(key));
        if (unknown.length > 0) {
            throw new CatalogueError(`${where} has unknown keys: ${unknown.join(", ")}.`);
        }
        if (Object.keys(entry).length === 0) {
            throw new CatalogueError(`${where} is empty, so it curates nothing.`);
        }
        if (entry.tags !== undefined) checkWords(entry.tags, `${where} tags`);
        if (entry.aliases !== undefined) checkWords(entry.aliases, `${where} aliases`);
        for (const key of ["width", "height"]) {
            if (entry[key] !== undefined && (!Number.isInteger(entry[key]) || entry[key] <= 0)) {
                throw new CatalogueError(`${where} ${key} must be a whole number above 0.`);
            }
        }
    }
    return curated;
};

const ruleMatches = (rule, name) =>
    (rule.prefix === undefined || name.startsWith(rule.prefix)) &&
    (rule.contains === undefined || name.includes(rule.contains)) &&
    (rule.suffix === undefined || name.endsWith(rule.suffix));

const describeRule = (rule) =>
    RULE_MATCHERS.filter((key) => rule[key] !== undefined)
        .map((key) => `${key} ${rule[key]}`)
        .join(", ");

const diffEntries = (previous, next) => {
    const previousIdByName = new Map(previous.map((entry) => [entry.name, entry.id]));
    const nextIdByName = new Map(next.map((entry) => [entry.name, entry.id]));
    const nextNameById = new Map(next.map((entry) => [entry.id, entry.name]));
    const renamed = [];
    const renamedFrom = new Set();
    const renamedTo = new Set();
    for (const entry of previous) {
        if (nextIdByName.has(entry.name)) continue;
        const replacement = nextNameById.get(entry.id);
        if (replacement !== undefined && !previousIdByName.has(replacement)) {
            renamed.push({ id: entry.id, from: entry.name, to: replacement });
            renamedFrom.add(entry.name);
            renamedTo.add(replacement);
        }
    }
    return {
        added: next.filter((entry) => !previousIdByName.has(entry.name) && !renamedTo.has(entry.name)),
        removed: previous.filter((entry) => !nextIdByName.has(entry.name) && !renamedFrom.has(entry.name)),
        moved: previous
            .filter((entry) => nextIdByName.has(entry.name) && nextIdByName.get(entry.name) !== entry.id)
            .map((entry) => ({ name: entry.name, from: entry.id, to: nextIdByName.get(entry.name) })),
        renamed,
    };
};

const diffIsEmpty = (diff) => Object.values(diff).every((list) => list.length === 0);

const diffReport = (previousClient, nextClient, diff) => {
    const section = (title, lines) => [`## ${title}`, "", ...(lines.length === 0 ? ["None."] : lines), ""];
    return [
        `# Sprite changes from ${previousClient} to ${nextClient}`,
        "",
        "| Change | Count |",
        "| --- | --- |",
        `| Added | ${diff.added.length} |`,
        `| Removed | ${diff.removed.length} |`,
        `| Moved | ${diff.moved.length} |`,
        `| Likely renamed | ${diff.renamed.length} |`,
        "",
        ...section("Added", diff.added.map((entry) => `- ${entry.id} ${entry.name}`)),
        ...section("Removed", diff.removed.map((entry) => `- ${entry.id} ${entry.name}`)),
        ...section("Moved", diff.moved.map((entry) => `- ${entry.name}: ${entry.from} to ${entry.to}`)),
        ...section("Likely renamed", diff.renamed.map((entry) => `- ${entry.id}: ${entry.from} to ${entry.to}`)),
    ].join("\n");
};

const luaString = (text) => JSON.stringify(text);
const luaKey = (name) => (LUA_IDENTIFIER.test(name) ? name : `[${luaString(name)}]`);
const luaStrings = (items) => `{ ${items.map(luaString).join(", ")} }`;

const curationSource = (rules, curated) => {
    const ruleLines = rules.map((rule) => {
        const fields = RULE_MATCHERS.filter((key) => rule[key] !== undefined).map((key) => `${key} = ${luaString(rule[key])}`);
        fields.push(`tags = ${luaStrings(rule.tags)}`);
        return `        { ${fields.join(", ")} },`;
    });
    const curatedLines = Object.keys(curated)
        .sort()
        .map((name) => {
            const entry = curated[name];
            const fields = [`tags = ${luaStrings(entry.tags ?? [])}`, `aliases = ${luaStrings(entry.aliases ?? [])}`];
            if (entry.width !== undefined) fields.push(`width = ${entry.width}`);
            if (entry.height !== undefined) fields.push(`height = ${entry.height}`);
            return `        ${luaKey(name)} = { ${fields.join(", ")} },`;
        });
    return ["return {", "    rules = {", ...ruleLines, "    },", "    curated = {", ...curatedLines, "    },", "}", ""].join("\n");
};

const formatLua = (source, outputPath) => {
    const run = spawnSync(
        process.execPath,
        [require.resolve("@johnnymorganz/stylua-bin/run.js"), "--config-path", join(toolingRoot, "stylua.toml"), "--stdin-filepath", outputPath, "-"],
        { input: source, encoding: "utf8" },
    );
    if (run.status !== 0) {
        throw new CatalogueError(`StyLua could not format the generated curation module:\n${run.stderr || run.stdout}\nRun npm install so the pinned StyLua is present, then try again.`);
    }
    return run.stdout;
};

const spritesText = (entries) => entries.map((entry) => `${entry.id}\t${entry.name}\n`).join("");

const buildText = (client, entries) =>
    `${JSON.stringify({ client, count: entries.length, maxId: entries[entries.length - 1].id }, null, 2)}\n`;

const generate = (options) => {
    const paths = pathsFor(options.root);
    const committedSprites = existsSync(paths.sprites) ? parseEntries(readText(paths, paths.sprites), "catalogue/sprites.tsv") : null;
    const committedBuild = existsSync(paths.build) ? readJson(paths, paths.build) : null;

    const fromDump = options.dump !== null;
    let entries;
    let client;
    if (fromDump) {
        if (!existsSync(options.dump)) {
            throw new CatalogueError(`There is no sprite dump at ${options.dump}.`);
        }
        entries = parseEntries(readFileSync(options.dump, "utf8"), options.dump);
        client = options.client ?? committedBuild?.client;
    } else {
        if (committedSprites === null || committedBuild === null) {
            throw new CatalogueError(
                "Without --dump this needs the committed catalogue/sprites.tsv and catalogue/build.json. Run with --dump <path> --client <build> once to create them.",
            );
        }
        entries = committedSprites;
        client = committedBuild.client;
    }
    if (typeof client !== "string" || client === "") {
        throw new CatalogueError("The client build is unknown. Pass --client <build>.");
    }

    const rules = validateRules(readJson(paths, paths.rules));
    const curated = validateCurated(readJson(paths, paths.curated));
    const names = new Set(entries.map((entry) => entry.name));

    const orphans = Object.keys(curated).filter((name) => !names.has(name)).sort();
    if (orphans.length > 0 && !options.acceptOrphans) {
        throw new CatalogueError(
            `These curated names are not in the ${client} sprite list:\n${orphans.map((name) => `  ${name}`).join("\n")}\n` +
                "Fix or remove them in catalogue/curated.json, or pass --accept-orphans to leave them out of the generated module for now.",
        );
    }
    const unmatchedRules = rules.filter((rule) => !entries.some((entry) => ruleMatches(rule, entry.name)));
    if (unmatchedRules.length > 0) {
        throw new CatalogueError(
            `These tag rules match no sprite in ${client}:\n${unmatchedRules.map((rule) => `  ${describeRule(rule)}`).join("\n")}\n` +
                "Fix or remove them in catalogue/tag-rules.json.",
        );
    }

    const liveCurated = Object.fromEntries(Object.entries(curated).filter(([name]) => names.has(name)));
    const outputs = new Map([
        [paths.sprites, spritesText(entries)],
        [paths.build, buildText(client, entries)],
        [paths.curation, formatLua(curationSource(rules, liveCurated), paths.curation)],
    ]);

    if (options.check) {
        const drifted = [...outputs.entries()]
            .filter(([path, text]) => !existsSync(path) || readFileSync(path, "utf8") !== text)
            .map(([path]) => describe(paths, path));
        if (drifted.length > 0) {
            throw new CatalogueError(
                `These generated files are out of date:\n${drifted.map((path) => `  ${path}`).join("\n")}\n` +
                    "Run npm run catalogue, or npm run catalogue -- --dump <path> --client <build> for a new game build, and commit the result.",
            );
        }
        console.log(`catalogue: up to date for client ${client}, ${entries.length} sprites, ${rules.length} rules, ${Object.keys(liveCurated).length} curated names.`);
        return;
    }

    if (!fromDump) {
        writeFileSync(paths.curation, outputs.get(paths.curation));
        for (const orphan of orphans) {
            console.log(`catalogue: left out the orphaned curated name ${orphan}`);
        }
        console.log(
            `catalogue: rebuilt ${describe(paths, paths.curation)} from the committed sprite list for client ${client}, ${rules.length} rules, ${Object.keys(liveCurated).length} curated names. sprites.tsv and build.json are unchanged.`,
        );
        return;
    }

    if (committedSprites !== null) {
        const diff = diffEntries(committedSprites, entries);
        const previousClient = committedBuild?.client ?? "previous";
        if (previousClient !== client || !diffIsEmpty(diff)) {
            mkdirSync(paths.diffs, { recursive: true });
            const reportPath = join(paths.diffs, `${previousClient}-to-${client}.md`);
            writeFileSync(reportPath, diffReport(previousClient, client, diff));
            console.log(
                `catalogue: ${diff.added.length} added, ${diff.removed.length} removed, ${diff.moved.length} moved, ${diff.renamed.length} likely renamed, written to ${describe(paths, reportPath)}`,
            );
        }
    }
    for (const [path, text] of outputs) {
        mkdirSync(dirname(path), { recursive: true });
        writeFileSync(path, text);
    }
    for (const orphan of orphans) {
        console.log(`catalogue: left out the orphaned curated name ${orphan}`);
    }
    console.log(
        `catalogue: client ${client}, ${entries.length} sprites, highest id ${entries[entries.length - 1].id}, ${rules.length} rules, ${Object.keys(liveCurated).length} curated names.`,
    );
};

try {
    generate(parseArguments(process.argv.slice(2)));
} catch (error) {
    if (!(error instanceof CatalogueError)) throw error;
    console.error(`catalogue: ${error.message}`);
    process.exitCode = 1;
}
