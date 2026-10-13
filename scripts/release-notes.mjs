import { existsSync, readFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const defaultRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const TAG_PATTERN = /^v(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/;
const SECTION_END = /^(## |\[[^\]]+\]: )/;

class NotesError extends Error {}

const installParagraph = (version, client) =>
    `rsprite ${version} and the rsprite finder, built against client \`${client}\`. ` +
    "rsprite is not on the Plugin Hub yet. To install it by hand, download the zips below and unzip them into the folder your game client loads development plugins from, " +
    "then run `prf` followed by `prl rsprite` and `prl rsprite-finder` in the game's console. See the README for how to add rsprite to your own plugin.";

const parseArguments = (argv) => {
    const options = { tag: null, root: defaultRoot };
    for (let index = 0; index < argv.length; index += 1) {
        const argument = argv[index];
        if (argument === "--root") {
            options.root = resolve(argv[index + 1] ?? ".");
            index += 1;
        } else if (!argument.startsWith("--") && options.tag === null) options.tag = argument;
        else throw new NotesError(`Unknown argument ${argument}. Pass a tag such as v0.1.0.`);
    }
    if (options.tag === null) throw new NotesError("Pass the tag to write notes for, for example node scripts/release-notes.mjs v0.1.0.");
    if (!TAG_PATTERN.test(options.tag)) throw new NotesError(`${options.tag} is not a release tag. Release tags look like v0.1.0.`);
    return options;
};

const readClient = (root) => {
    const buildPath = join(root, "catalogue", "build.json");
    let client;
    try {
        client = JSON.parse(readFileSync(buildPath, "utf8")).client;
    } catch (error) {
        throw new NotesError(`catalogue/build.json could not be read: ${error.message}`);
    }
    if (typeof client !== "string" || client === "") throw new NotesError("catalogue/build.json names no client build.");
    return client;
};

const changelogSection = (root, version) => {
    const changelogPath = join(root, "CHANGELOG.md");
    if (!existsSync(changelogPath)) throw new NotesError("there is no CHANGELOG.md.");
    const lines = readFileSync(changelogPath, "utf8").split(/\r?\n/);
    const headingStart = `## [${version}]`;
    const headingPosition = lines.findIndex((line) => line === headingStart || line.startsWith(`${headingStart} `));
    if (headingPosition === -1) throw new NotesError(`CHANGELOG.md has no "${headingStart}" section.`);
    if (!/^## \[[^\]]+\] - \d{4}-\d{2}-\d{2}$/.test(lines[headingPosition])) {
        throw new NotesError(`the CHANGELOG.md heading for ${version} has no release date.`);
    }
    const bodyLines = [];
    for (const line of lines.slice(headingPosition + 1)) {
        if (SECTION_END.test(line)) break;
        bodyLines.push(line);
    }
    const body = bodyLines.join("\n").trim();
    if (body === "") throw new NotesError(`the CHANGELOG.md section for ${version} is empty.`);
    return body;
};

try {
    const options = parseArguments(process.argv.slice(2));
    const version = options.tag.slice(1);
    const notes = `${installParagraph(version, readClient(options.root))}\n\n${changelogSection(options.root, version)}\n`;
    process.stdout.write(notes);
} catch (error) {
    if (!(error instanceof NotesError)) throw error;
    console.error(`release-notes: ${error.message}`);
    process.exitCode = 1;
}
