import { spawnSync } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const validator = join(dirname(fileURLToPath(import.meta.url)), "..", "..", "validate-release-tag.mjs");
const run = spawnSync(process.execPath, [validator, "--pushed"], { stdio: "inherit" });
process.exitCode = run.status ?? 1;
