import { existsSync, mkdirSync, readFileSync, readdirSync, statSync, writeFileSync } from "node:fs";
import { dirname, join, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import zlib from "node:zlib";

import { unzipSync, zipSync } from "fflate";

const defaultRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const PLUGIN_NAMES = ["rsprite", "rsprite-finder"];
const REQUIRED_FILES = ["main.lua", "plugin.json"];
const VERSION_PATTERN = /^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/;
const FIXED_MODIFIED_TIME = new Date(1980, 0, 1, 0, 0, 0);
const COMPRESSION_LEVEL = 9;
const END_OF_CENTRAL_DIRECTORY_SIGNATURE = 0x06054b50;
const END_OF_CENTRAL_DIRECTORY_LENGTH = 22;
const CENTRAL_DIRECTORY_SIGNATURE = 0x02014b50;
const CENTRAL_DIRECTORY_HEADER_LENGTH = 46;
const BYTES_PER_KILOBYTE = 1024;

class PackageError extends Error {}

const forwardSlashes = (path) => path.split("\\").join("/");

const parseArguments = (argv) => {
    const options = { root: defaultRoot, output: null };
    for (let index = 0; index < argv.length; index += 1) {
        const argument = argv[index];
        if (argument === "--root") {
            options.root = resolve(argv[index + 1] ?? ".");
            index += 1;
        } else if (argument === "--output") {
            options.output = resolve(argv[index + 1] ?? ".");
            index += 1;
        } else {
            throw new PackageError(`Unknown argument ${argument}. Use --root <folder> or --output <folder>.`);
        }
    }
    options.output ??= join(options.root, "release");
    return options;
};

const byCodePoint = (first, second) => (first < second ? -1 : first > second ? 1 : 0);

const listFiles = (folder) =>
    readdirSync(folder, { withFileTypes: true })
        .map((entry) => entry.name)
        .sort(byCodePoint)
        .flatMap((name) => {
            const path = join(folder, name);
            return statSync(path).isDirectory() ? listFiles(path) : [path];
        });

const readManifest = (pluginName, pluginFolder) => {
    const manifestPath = join(pluginFolder, "plugin.json");
    let manifest;
    try {
        manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
    } catch (error) {
        throw new PackageError(`plugins/${pluginName}/plugin.json is not valid JSON: ${error.message}`);
    }
    if (typeof manifest.version !== "string" || !VERSION_PATTERN.test(manifest.version)) {
        throw new PackageError(`plugins/${pluginName}/plugin.json needs a version such as "0.1.0", not ${JSON.stringify(manifest.version)}.`);
    }
    return manifest;
};

const collectPlugin = (root, pluginName) => {
    const pluginFolder = join(root, "plugins", pluginName);
    if (!existsSync(pluginFolder) || !statSync(pluginFolder).isDirectory()) {
        throw new PackageError(`plugins/${pluginName} is missing, so there is nothing to package.`);
    }
    const paths = listFiles(pluginFolder);
    if (paths.length === 0) {
        throw new PackageError(`plugins/${pluginName} has no files, so its zip would be empty.`);
    }
    const relativePaths = paths.map((path) => forwardSlashes(relative(pluginFolder, path)));
    const missing = REQUIRED_FILES.filter((required) => !relativePaths.includes(required));
    if (missing.length > 0) {
        throw new PackageError(`plugins/${pluginName} has no ${missing.join(" or ")}, and the client needs both to load a plugin.`);
    }
    const manifest = readManifest(pluginName, pluginFolder);
    const files = paths.map((path, position) => ({
        path: `${pluginName}/${relativePaths[position]}`,
        contents: new Uint8Array(readFileSync(path)),
    }));
    return { name: pluginName, version: manifest.version, files };
};

const buildArchive = (plugin) => {
    const entries = {};
    for (const file of plugin.files) {
        entries[file.path] = file.contents;
    }
    return zipSync(entries, { level: COMPRESSION_LEVEL, mtime: FIXED_MODIFIED_TIME });
};

const storedChecksums = (archive) => {
    const view = new DataView(archive.buffer, archive.byteOffset, archive.byteLength);
    const endOffset = archive.byteLength - END_OF_CENTRAL_DIRECTORY_LENGTH;
    if (endOffset < 0 || view.getUint32(endOffset, true) !== END_OF_CENTRAL_DIRECTORY_SIGNATURE) {
        throw new PackageError("the archive has no end of central directory record where expected.");
    }
    const entryCount = view.getUint16(endOffset + 10, true);
    let offset = view.getUint32(endOffset + 16, true);
    const checksums = new Map();
    for (let entry = 0; entry < entryCount; entry += 1) {
        if (view.getUint32(offset, true) !== CENTRAL_DIRECTORY_SIGNATURE) {
            throw new PackageError(`central directory entry ${entry + 1} has the wrong signature.`);
        }
        const checksum = view.getUint32(offset + 16, true);
        const nameLength = view.getUint16(offset + 28, true);
        const extraLength = view.getUint16(offset + 30, true);
        const commentLength = view.getUint16(offset + 32, true);
        const nameStart = offset + CENTRAL_DIRECTORY_HEADER_LENGTH;
        const name = new TextDecoder().decode(archive.subarray(nameStart, nameStart + nameLength));
        checksums.set(name, checksum);
        offset = nameStart + nameLength + extraLength + commentLength;
    }
    return checksums;
};

const checksumOf = (contents) => zlib.crc32(contents);

const sameBytes = (first, second) => first.length === second.length && first.every((value, index) => value === second[index]);

const verifyArchive = (plugin, archive, archiveName) => {
    const fail = (problem) => {
        throw new PackageError(`${archiveName} did not read back correctly: ${problem}`);
    };
    const extracted = unzipSync(archive);
    const checksums = storedChecksums(archive);
    const expectedPaths = plugin.files.map((file) => file.path);
    const extractedPaths = Object.keys(extracted);
    if (extractedPaths.join("\n") !== expectedPaths.join("\n")) fail("its file list differs from the plugin folder.");
    if (extractedPaths.some((path) => !path.startsWith(`${plugin.name}/`))) fail(`not every file is inside one ${plugin.name} folder.`);
    for (const required of REQUIRED_FILES) {
        if (extracted[`${plugin.name}/${required}`] === undefined) fail(`it has no ${plugin.name}/${required}.`);
    }
    for (const file of plugin.files) {
        const expectedChecksum = checksumOf(file.contents);
        if (checksums.get(file.path) !== expectedChecksum) fail(`the stored checksum of ${file.path} is wrong.`);
        if (checksumOf(extracted[file.path]) !== expectedChecksum || !sameBytes(extracted[file.path], file.contents)) {
            fail(`the contents of ${file.path} differ.`);
        }
    }
};

const describeSize = (bytes) => `${(bytes / BYTES_PER_KILOBYTE).toFixed(1)} KB`;

try {
    if (typeof zlib.crc32 !== "function") {
        throw new PackageError(`this needs Node 22.12 or later, and this is Node ${process.versions.node}.`);
    }
    const options = parseArguments(process.argv.slice(2));
    const plugins = PLUGIN_NAMES.map((pluginName) => collectPlugin(options.root, pluginName));
    const packages = plugins.map((plugin) => {
        const archiveName = `${plugin.name}-${plugin.version}.zip`;
        const archive = buildArchive(plugin);
        verifyArchive(plugin, archive, archiveName);
        return { plugin, archive, archiveName };
    });
    mkdirSync(options.output, { recursive: true });
    for (const { plugin, archive, archiveName } of packages) {
        const archivePath = join(options.output, archiveName);
        writeFileSync(archivePath, archive);
        const shownPath = forwardSlashes(relative(options.root, archivePath)) || archiveName;
        console.log(`package: ${shownPath}, ${plugin.files.length} files, ${describeSize(archive.byteLength)}`);
    }
} catch (error) {
    if (!(error instanceof PackageError)) throw error;
    console.error(`package: ${error.message}`);
    process.exitCode = 1;
}
