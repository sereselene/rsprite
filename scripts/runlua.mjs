import { runLuaFile } from "./lua-runner.mjs";

const [entryRelativePath] = process.argv.slice(2);
if (entryRelativePath === undefined) {
    console.error("No file given. Pass one path relative to the repository root, such as node scripts/runlua.mjs tests/sprite_lookup_selftest.lua");
    process.exitCode = 1;
} else {
    process.exitCode = runLuaFile(entryRelativePath);
}
