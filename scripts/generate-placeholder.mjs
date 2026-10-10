import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { writePng } from "./png.mjs";

const repositoryRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const outputPath = join(repositoryRoot, "plugins", "rsprite", "resources", "placeholder.png");

const SIZE = 24;
const BORDER = 2;
const FILL = [140, 140, 140, 255];
const EDGE = [72, 72, 72, 255];

const isEdge = (row, column) => row < BORDER || column < BORDER || row >= SIZE - BORDER || column >= SIZE - BORDER;

writePng(outputPath, SIZE, SIZE, (row, column) => (isEdge(row, column) ? EDGE : FILL));
console.log(`placeholder: wrote a ${SIZE} by ${SIZE} grey square with a ${BORDER} pixel darker border to plugins/rsprite/resources/placeholder.png`);
