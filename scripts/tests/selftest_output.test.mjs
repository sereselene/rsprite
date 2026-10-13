import assert from "node:assert/strict";
import { describe, test } from "node:test";

import { failedCheckLines } from "../lua-runner.mjs";

describe("selftest output", () => {
    test("counts a failed check line from the report", () => {
        const failed = "[selftest] sprite lookup, a known name gives its id: expected 9318, got nil FAIL";
        assert.deepEqual(failedCheckLines([failed]), [failed]);
    });

    test("counts a failed check with no detail", () => {
        const failed = "[selftest] isolation, the core never mentions it:  FAIL";
        assert.deepEqual(failedCheckLines([failed]), [failed]);
    });

    test("ignores a passing check, a warning ending in FAIL and an empty line", () => {
        const lines = [
            "[selftest] sprite lookup, a known name gives its id: expected 9318, got 9318 PASS",
            "rsprite: looking up sprite DRAW_FAIL failed: lookup FAIL",
            "rsprite-finder: the tag is FAIL",
            "",
        ];
        assert.deepEqual(failedCheckLines(lines), []);
    });
});
