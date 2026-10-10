import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { writePng } from "./png.mjs";

const repositoryRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const resourcesFolder = join(repositoryRoot, "plugins", "rsprite-finder", "resources");

const STATE_SIZE = 36;
const WIDTH = STATE_SIZE;
const HEIGHT = STATE_SIZE * 2;
const CLEAR = [0, 0, 0, 0];
const CORNER = [11, 13, 13, 73];
const TOP_EDGE = [124, 126, 126, 255];
const SIDE_EDGE = [91, 90, 90, 255];
const BOTTOM_EDGE = [87, 89, 89, 255];
const INNER_SHADOW = [26, 28, 28, 255];
const FILL = [18, 20, 20, 255];
const FOCUSED_FILL = [26, 28, 28, 255];

const restingState = (row, column) => {
    const last = STATE_SIZE - 1;
    const onCorner = (row === 0 || row === last) && (column === 0 || column === last);
    if (onCorner) return CORNER;
    if (row === 0) return TOP_EDGE;
    if (row === last) return BOTTOM_EDGE;
    if (column === 0 || column === last) return SIDE_EDGE;
    if (row === 1 || row === last - 1 || column === 1 || column === last - 1) return INNER_SHADOW;
    return FILL;
};

const focusedState = (row, column) => {
    const last = STATE_SIZE - 1;
    if (row === 0 || row === last || column === 0 || column === last) return CLEAR;
    return FOCUSED_FILL;
};

writePng(join(resourcesFolder, "text_field.png"), WIDTH, HEIGHT, (row, column) =>
    row < STATE_SIZE ? restingState(row, column) : focusedState(row - STATE_SIZE, column),
);
console.log(
    `finder-images: wrote a ${WIDTH} by ${HEIGHT} two state text field background to plugins/rsprite-finder/resources/text_field.png`,
);

const CHECKER_SQUARE = 8;
const CHECKER_SIZE = CHECKER_SQUARE * 2;
const CHECKER_LIGHT = [204, 204, 204, 255];
const CHECKER_DARK = [153, 153, 153, 255];

writePng(join(resourcesFolder, "checker.png"), CHECKER_SIZE, CHECKER_SIZE, (row, column) =>
    (Math.floor(row / CHECKER_SQUARE) + Math.floor(column / CHECKER_SQUARE)) % 2 === 0 ? CHECKER_LIGHT : CHECKER_DARK,
);
console.log(
    `finder-images: wrote a ${CHECKER_SIZE} by ${CHECKER_SIZE} checkerboard to plugins/rsprite-finder/resources/checker.png`,
);
