import { mkdirSync, writeFileSync } from "node:fs";
import { dirname } from "node:path";
import { crc32, deflateSync } from "node:zlib";

const SIGNATURE = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
const RGBA_COLOUR_TYPE = 6;
const BIT_DEPTH = 8;

const chunk = (type, data) => {
    const length = Buffer.alloc(4);
    length.writeUInt32BE(data.length);
    const body = Buffer.concat([Buffer.from(type, "ascii"), data]);
    const checksum = Buffer.alloc(4);
    checksum.writeUInt32BE(crc32(body));
    return Buffer.concat([length, body, checksum]);
};

export const writePng = (outputPath, width, height, colourAt) => {
    const rowLength = 1 + width * 4;
    const pixels = Buffer.alloc(rowLength * height);
    for (let row = 0; row < height; row += 1) {
        for (let column = 0; column < width; column += 1) {
            pixels.set(colourAt(row, column), row * rowLength + 1 + column * 4);
        }
    }
    const header = Buffer.alloc(13);
    header.writeUInt32BE(width, 0);
    header.writeUInt32BE(height, 4);
    header.writeUInt8(BIT_DEPTH, 8);
    header.writeUInt8(RGBA_COLOUR_TYPE, 9);
    const png = Buffer.concat([
        SIGNATURE,
        chunk("IHDR", header),
        chunk("IDAT", deflateSync(pixels, { level: 9 })),
        chunk("IEND", Buffer.alloc(0)),
    ]);
    mkdirSync(dirname(outputPath), { recursive: true });
    writeFileSync(outputPath, png);
};
