import { spawnSync } from "node:child_process";
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { createRequire } from "node:module";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const require = createRequire(import.meta.url);
const repositoryRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const runner = join(repositoryRoot, "scripts", "runlua.mjs");
const SOURCE = "scripts/probe-pages.lua";
const OUTPUT = join(repositoryRoot, "examples", "sprite-probe", "src", "data", "pages.lua");
const OUTPUT_NAME = "examples/sprite-probe/src/data/pages.lua";

class ProbePagesError extends Error {}

const luaString = (text) => JSON.stringify(text);

const readPages = () => {
    const run = spawnSync(process.execPath, [runner, SOURCE], { cwd: repositoryRoot, encoding: "utf8", maxBuffer: 64 * 1024 * 1024 });
    if (run.status !== 0) throw new ProbePagesError(`the finder ordering could not be run:\n${run.stderr || run.stdout}`);
    const settings = [];
    let pageCount = null;
    let pageSize = null;
    for (const line of run.stdout.split(/\r?\n/)) {
        const fields = line.split("\t");
        if (fields[0] === "pages") {
            pageCount = Number(fields[1]);
            pageSize = Number(fields[2]);
        } else if (fields[0] === "setting") {
            settings[Number(fields[1]) - 1] = { name: fields[2], pages: [] };
        } else if (fields[0] === "tile") {
            const [, settingPosition, page, position, spriteId, name] = fields;
            const pages = settings[Number(settingPosition) - 1].pages;
            pages[Number(page) - 1] ??= [];
            pages[Number(page) - 1][Number(position) - 1] = { id: Number(spriteId), name };
        }
    }
    if (pageCount === null || settings.length === 0) throw new ProbePagesError("the finder ordering printed no pages.");
    return { pageCount, pageSize, settings };
};

const luaSource = (client, data) => {
    const lines = ["return {", `    client = ${luaString(client)},`, `    pageSize = ${data.pageSize},`, `    pageCount = ${data.pageCount},`, "    settings = {"];
    for (const setting of data.settings) {
        lines.push("        {", `            name = ${luaString(setting.name)},`, "            pages = {");
        for (const page of setting.pages) {
            lines.push("                {");
            for (const entry of page) lines.push(`                    { id = ${entry.id}, name = ${luaString(entry.name)} },`);
            lines.push("                },");
        }
        lines.push("            },", "        },");
    }
    lines.push("    },", "}", "");
    return lines.join("\n");
};

const formatLua = (source) => {
    const run = spawnSync(
        process.execPath,
        [require.resolve("@johnnymorganz/stylua-bin/run.js"), "--config-path", join(repositoryRoot, "stylua.toml"), "--stdin-filepath", OUTPUT, "-"],
        { input: source, encoding: "utf8", maxBuffer: 64 * 1024 * 1024 },
    );
    if (run.status !== 0) throw new ProbePagesError(`StyLua could not format ${OUTPUT_NAME}:\n${run.stderr || run.stdout}`);
    return run.stdout;
};

try {
    const check = process.argv.slice(2).includes("--check");
    const unknown = process.argv.slice(2).filter((argument) => argument !== "--check");
    if (unknown.length > 0) throw new ProbePagesError(`Unknown argument ${unknown[0]}. Use --check to compare without writing.`);
    const client = JSON.parse(readFileSync(join(repositoryRoot, "catalogue", "build.json"), "utf8")).client;
    const data = readPages();
    const text = formatLua(luaSource(client, data));
    const counts = data.settings.map((setting) => `${setting.name} ${setting.pages.length} pages`).join(", ");
    if (check) {
        if (!existsSync(OUTPUT) || readFileSync(OUTPUT, "utf8") !== text) {
            throw new ProbePagesError(`${OUTPUT_NAME} is out of date. Run npm run probe-pages and commit the result.`);
        }
        console.log(`probe-pages: ${OUTPUT_NAME} is up to date for client ${client}: ${counts}.`);
    } else {
        writeFileSync(OUTPUT, text);
        console.log(`probe-pages: wrote ${OUTPUT_NAME} for client ${client}: ${counts}.`);
    }
} catch (error) {
    if (!(error instanceof ProbePagesError)) throw error;
    console.error(`probe-pages: ${error.message}`);
    process.exitCode = 1;
}
