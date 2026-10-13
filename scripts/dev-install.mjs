import { cpSync, existsSync, readFileSync, rmSync, statSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const repositoryRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");

const INSTALLS = [
    { source: join(repositoryRoot, "plugins", "rsprite"), name: "rsprite" },
    { source: join(repositoryRoot, "plugins", "rsprite-finder"), name: "rsprite-finder" },
    { source: join(repositoryRoot, "examples", "basic"), name: "rsprite-example" },
];

const stop = (message) => {
    console.error(`dev-install: ${message}`);
    process.exit(1);
};

const parseTarget = (argv) => {
    let target = process.env.RSPRITE_DEV_PLUGIN_FOLDER ?? null;
    for (let index = 0; index < argv.length; index += 1) {
        if (argv[index] === "--target") {
            target = argv[index + 1] ?? null;
            index += 1;
        } else {
            stop(`Unknown argument ${argv[index]}. Use --target <folder>.`);
        }
    }
    if (target === null || target === "") {
        stop("No target folder. Pass --target <folder> or set RSPRITE_DEV_PLUGIN_FOLDER to the client's dev plugin folder.");
    }
    return resolve(target);
};

const manifestName = (folder) => {
    try {
        return JSON.parse(readFileSync(join(folder, "plugin.json"), "utf8")).name ?? null;
    } catch {
        return null;
    }
};

const target = parseTarget(process.argv.slice(2));
if (!existsSync(target) || !statSync(target).isDirectory()) {
    stop(`${target} is not an existing folder. Point --target at the client's dev plugin folder.`);
}

const refusals = INSTALLS.filter((install) => {
    const destination = join(target, install.name);
    return existsSync(destination) && manifestName(destination) !== install.name;
});
if (refusals.length > 0) {
    stop(
        `These folders exist but are not rsprite's, so nothing was changed:\n${refusals.map((install) => `  ${join(target, install.name)}`).join("\n")}`,
    );
}

for (const install of INSTALLS) {
    const destination = join(target, install.name);
    if (existsSync(destination)) {
        rmSync(destination, { recursive: true, force: true });
    }
    cpSync(install.source, destination, { recursive: true });
    console.log(`dev-install: copied ${install.name} to ${destination}`);
}
console.log("dev-install: done. In game run prf, then prl rsprite, prl rsprite-finder and prl rsprite-example.");
