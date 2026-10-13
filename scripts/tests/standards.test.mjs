import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { basename, extname, join, resolve } from "node:path";
import { describe, test } from "node:test";
import { fileURLToPath } from "node:url";

const repositoryRoot = resolve(fileURLToPath(new URL("../..", import.meta.url)));
const MAXIMUM_LINE_LENGTH = 200;
const SCRIPT_EXTENSIONS = new Set([".mjs", ".js", ".cjs"]);
const YAML_EXTENSIONS = new Set([".yml", ".yaml"]);
const HASH_COMMENT_FILES = new Set([".gitignore", ".styluaignore", ".gitattributes", "CODEOWNERS", ".nvmrc"]);
const INI_FILES = new Set([".editorconfig", ".gitlint"]);
const TOML_EXTENSIONS = new Set([".toml"]);
const REGEX_PRECEDING_CHARACTERS = new Set([..."(,=:[!&|?{};+-*%<>~^"]);
const REGEX_PRECEDING_WORDS = new Set(["return", "typeof", "case", "do", "else", "in", "of", "new", "delete", "void", "throw", "yield", "await"]);
const QUOTE_OPENERS = new Set([..." \t:[{,(="]);
const BLOCK_SCALAR_KEY = /^(\s*)(?:-\s+)?([A-Za-z0-9_-]+):\s*[|>][-+0-9]*\s*$/;
const WORD_START = /[A-Za-z_$]/;
const WORD_CHARACTER = /[A-Za-z0-9_$]/;
const NUMBER_CHARACTER = /[0-9.]/;

const isWhitespace = (character) => character === " " || character === "\t" || character === "\r" || character === "\n";

const atTokenStart = (source, index) => index === 0 || isWhitespace(source[index - 1]);

const skipQuoted = (source, start, quote) => {
    for (let index = start + 1; index < source.length; index += 1) {
        if (source[index] === "\\") index += 1;
        else if (source[index] === quote) return index + 1;
        else if (source[index] === "\n") return -1;
    }
    return -1;
};

const scanTemplateText = (source, start) => {
    let newlines = 0;
    for (let index = start; index < source.length; index += 1) {
        const character = source[index];
        if (character === "\\") index += 1;
        else if (character === "`") return { end: index + 1, newlines, opensExpression: false };
        else if (character === "$" && source[index + 1] === "{") return { end: index + 2, newlines, opensExpression: true };
        else if (character === "\n") newlines += 1;
    }
    return null;
};

const skipRegularExpression = (source, start) => {
    let inClass = false;
    for (let index = start + 1; index < source.length; index += 1) {
        const character = source[index];
        if (character === "\\") index += 1;
        else if (character === "\n") return -1;
        else if (character === "[") inClass = true;
        else if (character === "]") inClass = false;
        else if (character === "/" && !inClass) {
            let end = index + 1;
            while (end < source.length && /[a-z]/.test(source[end])) end += 1;
            return end;
        }
    }
    return -1;
};

export const scriptCommentLines = (source) => {
    const found = [];
    let index = 0;
    let line = 1;
    let previousSignificant = "";
    let previousWord = "";
    let braceDepth = 0;
    const templateDepths = [];
    if (source.startsWith("#!")) {
        index = source.indexOf("\n");
        if (index === -1) return [];
    }
    const resumeTemplate = (start) => {
        const text = scanTemplateText(source, start);
        if (text === null) return false;
        line += text.newlines;
        index = text.end;
        if (text.opensExpression) templateDepths.push(braceDepth);
        previousSignificant = text.opensExpression ? "{" : "a";
        previousWord = "";
        return true;
    };
    while (index < source.length) {
        const character = source[index];
        const next = source[index + 1];
        if (character === "\n") {
            line += 1;
            index += 1;
        } else if (isWhitespace(character)) {
            index += 1;
        } else if (character === "/" && next === "/") {
            if (atTokenStart(source, index)) found.push(line);
            const end = source.indexOf("\n", index);
            if (end === -1) break;
            index = end;
        } else if (character === "/" && next === "*") {
            if (atTokenStart(source, index)) found.push(line);
            const end = source.indexOf("*/", index + 2);
            if (end === -1) return [];
            line += source.slice(index, end).split("\n").length - 1;
            index = end + 2;
        } else if (character === "'" || character === '"') {
            const end = skipQuoted(source, index, character);
            if (end === -1) return [];
            index = end;
            previousSignificant = "a";
            previousWord = "";
        } else if (character === "`") {
            if (!resumeTemplate(index + 1)) return [];
        } else if (character === "/") {
            const looksLikeRegularExpression =
                previousSignificant === "" || REGEX_PRECEDING_CHARACTERS.has(previousSignificant) || REGEX_PRECEDING_WORDS.has(previousWord);
            const end = looksLikeRegularExpression ? skipRegularExpression(source, index) : -1;
            index = end === -1 ? index + 1 : end;
            previousSignificant = end === -1 ? "/" : "a";
            previousWord = "";
        } else if (WORD_START.test(character)) {
            let end = index + 1;
            while (end < source.length && WORD_CHARACTER.test(source[end])) end += 1;
            previousWord = source.slice(index, end);
            previousSignificant = "a";
            index = end;
        } else if (/[0-9]/.test(character)) {
            while (index < source.length && NUMBER_CHARACTER.test(source[index])) index += 1;
            previousSignificant = "a";
            previousWord = "";
        } else if (character === "}" && templateDepths.length > 0 && templateDepths[templateDepths.length - 1] === braceDepth) {
            templateDepths.pop();
            if (!resumeTemplate(index + 1)) return [];
        } else {
            if (character === "{") braceDepth += 1;
            if (character === "}") braceDepth -= 1;
            previousSignificant = character;
            previousWord = "";
            index += 1;
        }
    }
    return templateDepths.length > 0 ? [] : found;
};

export const hashCommentColumn = (line) => {
    let quote = null;
    for (let index = 0; index < line.length; index += 1) {
        const character = line[index];
        if (quote !== null) {
            if (quote === '"' && character === "\\") index += 1;
            else if (character === quote) quote = null;
        } else if ((character === '"' || character === "'") && (index === 0 || QUOTE_OPENERS.has(line[index - 1]))) {
            quote = character;
        } else if (character === "#" && atTokenStart(line, index)) {
            return index;
        }
    }
    return -1;
};

export const yamlCommentLines = (source) => {
    const lines = source.split(/\r?\n/);
    const found = [];
    let block = null;
    const finishBlock = () => {
        if (block !== null && block.key === "script") {
            for (const offset of scriptCommentLines(block.lines.join("\n"))) found.push(block.firstLine + offset - 1);
        }
        block = null;
    };
    lines.forEach((line, position) => {
        const lineNumber = position + 1;
        const indent = line.length - line.trimStart().length;
        if (block !== null) {
            if (line.trim() === "" || indent > block.indent) {
                block.lines.push(line);
                if (block.key === "run" && hashCommentColumn(line) !== -1) found.push(lineNumber);
                return;
            }
            finishBlock();
        }
        if (lineNumber === 1 && line.startsWith("#!")) return;
        const blockStart = BLOCK_SCALAR_KEY.exec(line);
        if (blockStart !== null) {
            block = { key: blockStart[2], indent, firstLine: lineNumber + 1, lines: [] };
            return;
        }
        if (hashCommentColumn(line) !== -1) found.push(lineNumber);
    });
    finishBlock();
    return found;
};

export const pythonCommentLines = (source) => {
    const found = [];
    let line = 1;
    let index = source.startsWith("#!") ? source.indexOf("\n") : 0;
    if (index === -1) return [];
    while (index < source.length) {
        const character = source[index];
        if (character === "\n") {
            line += 1;
            index += 1;
        } else if (character === "#") {
            found.push(line);
            const end = source.indexOf("\n", index);
            if (end === -1) break;
            index = end;
        } else if (character === "'" || character === '"') {
            const triple = character.repeat(3);
            if (source.startsWith(triple, index)) {
                const end = source.indexOf(triple, index + 3);
                if (end === -1) return [];
                line += source.slice(index, end).split("\n").length - 1;
                index = end + 3;
            } else {
                const end = skipQuoted(source, index, character);
                if (end === -1) return [];
                index = end;
            }
        } else {
            index += 1;
        }
    }
    return found;
};

const leadingMarkerLines = (source, markers) =>
    source
        .split(/\r?\n/)
        .map((line, position) => ({ line: position + 1, text: line.trimStart() }))
        .filter(({ text }) => markers.some((marker) => text.startsWith(marker)))
        .map(({ line }) => line);

const tomlCommentLines = (source) =>
    source
        .split(/\r?\n/)
        .map((line, position) => ({ line: position + 1, column: hashCommentColumn(line) }))
        .filter(({ column }) => column !== -1)
        .map(({ line }) => line);

const trackedFiles = () => {
    const run = spawnSync("git", ["ls-files", "-z"], { cwd: repositoryRoot, encoding: "utf8" });
    assert.equal(run.status, 0, run.stderr);
    return run.stdout.split("\0").filter((path) => path !== "");
};

const textFiles = () =>
    trackedFiles()
        .map((path) => ({ path, contents: readFileSync(join(repositoryRoot, path)) }))
        .filter(({ contents }) => !contents.includes(0))
        .map(({ path, contents }) => ({ path, text: contents.toString("latin1") }));

const isMarkdown = (path) => extname(path).toLowerCase() === ".md";

const commentRuleFor = (path) => {
    const name = basename(path);
    const extension = extname(path).toLowerCase();
    if (isMarkdown(path)) return null;
    if (SCRIPT_EXTENSIONS.has(extension)) return { rule: "no // or /* comments in scripts", lines: scriptCommentLines };
    if (YAML_EXTENSIONS.has(extension)) return { rule: "no # comments in YAML, run blocks or // comments in script blocks", lines: yamlCommentLines };
    if (extension === ".py") return { rule: "no # comments in Python", lines: pythonCommentLines };
    if (TOML_EXTENSIONS.has(extension)) return { rule: "no # comments in TOML", lines: tomlCommentLines };
    if (INI_FILES.has(name)) return { rule: "no # or ; comment lines in INI files", lines: (source) => leadingMarkerLines(source, ["#", ";"]) };
    if (HASH_COMMENT_FILES.has(name)) return { rule: "no # comment lines in ignore and config files", lines: (source) => leadingMarkerLines(source, ["#"]) };
    return null;
};

const describeJsonProblem = (path, text, error) => {
    const position = Number(/position (\d+)/.exec(error.message)?.[1]);
    const line = Number.isNaN(position) ? 1 : text.slice(0, position).split("\n").length;
    return `${path}:${line} JSON must parse, so it has no comments (${error.message})`;
};

describe("standards across every tracked file", () => {
    const files = textFiles();

    test("finds the tracked text files and leaves out the images", () => {
        const paths = files.map((file) => file.path);
        assert.ok(paths.includes("scripts/package.mjs"), "scripts are scanned");
        assert.ok(paths.includes(".github/workflows/release.yml"), "workflows are scanned");
        assert.ok(paths.includes(".gitlint-rules/type_scope_format.py"), "the gitlint rule is scanned");
        assert.ok(!paths.some((path) => path.endsWith(".png")), "images are left out");
    });

    test("every tracked text file is plain ASCII", () => {
        const problems = files.flatMap(({ path, text }) =>
            text
                .split("\n")
                .map((line, position) => ({ line: position + 1, column: line.search(/[^\x00-\x7f]/) }))
                .filter(({ column }) => column !== -1)
                .map(({ line, column }) => `${path}:${line} only plain ASCII is allowed (column ${column + 1})`),
        );
        assert.deepEqual(problems, []);
    });

    test("no line outside Markdown is over 200 characters", () => {
        const problems = files
            .filter(({ path }) => !isMarkdown(path))
            .flatMap(({ path, text }) =>
                text
                    .split(/\r?\n/)
                    .map((line, position) => ({ line: position + 1, length: line.length }))
                    .filter(({ length }) => length > MAXIMUM_LINE_LENGTH)
                    .map(({ line, length }) => `${path}:${line} lines must be 200 characters or fewer, this one is ${length}`),
            );
        assert.deepEqual(problems, []);
    });

    test("no script, workflow, action, Python or config file has a comment", () => {
        const scanned = [];
        const problems = files.flatMap(({ path, text }) => {
            const scanner = commentRuleFor(path);
            if (scanner === null) return [];
            scanned.push(path);
            return scanner.lines(text).map((line) => `${path}:${line} ${scanner.rule}`);
        });
        for (const expected of [
            "scripts/package.mjs",
            ".github/workflows/ci.yml",
            ".github/actions/comment-checks-summary/action.yml",
            ".gitlint-rules/type_scope_format.py",
            ".gitignore",
            ".editorconfig",
            "stylua.toml",
        ]) {
            assert.ok(scanned.includes(expected), `${expected} is scanned for comments`);
        }
        assert.ok(!scanned.some(isMarkdown), "Markdown is never scanned for comments");
        assert.deepEqual(problems, []);
    });

    test("every tracked JSON file parses, so none has a comment", () => {
        const problems = files
            .filter(({ path }) => extname(path).toLowerCase() === ".json")
            .flatMap(({ path, text }) => {
                try {
                    JSON.parse(text);
                    return [];
                } catch (error) {
                    return [describeJsonProblem(path, text, error)];
                }
            });
        assert.deepEqual(problems, []);
    });
});

describe("comment scanners", () => {
    test("the script scanner finds real comments", () => {
        assert.deepEqual(scriptCommentLines("const value = 1;\n// a note\nconst other = 2; /* another */\n"), [2, 3]);
    });

    test("the script scanner ignores URLs, slashes in strings and templates, regular expressions and division", () => {
        const source = [
            '#!/usr/bin/env node',
            'const address = "https://example.com/path";',
            "const quoted = 'a // b';",
            "const template = `see https://example.com and ${value / 2} // still text`;",
            "const pattern = /^\\/\\/ (.+)$/;",
            "const split = path.split(/\\r?\\n/);",
            "const half = total / 2;",
            "const nested = `${items.map((item) => `${item}//`).join(\"/\")}`;",
        ].join("\n");
        assert.deepEqual(scriptCommentLines(source), []);
    });

    test("the script scanner does not flag anything it cannot be sure of", () => {
        assert.deepEqual(scriptCommentLines('const broken = "never closed\n// after\n'), []);
        assert.deepEqual(scriptCommentLines("const open = `a template that never closes\n// after\n"), []);
    });

    test("the YAML scanner finds real comments", () => {
        assert.deepEqual(yamlCommentLines("name: CI\n# a note\nkey: value # trailing\n"), [2, 3]);
    });

    test("the YAML scanner checks run blocks for shell comments and script blocks for script comments", () => {
        const source = [
            "steps:",
            "  - run: |",
            "      echo \"a # b\"",
            "      # a shell note",
            "      echo \"${#items[@]}\"",
            "  - with:",
            "      script: |",
            "        const address = \"https://example.com\";",
            "        // a script note",
            "  - name: done",
        ].join("\n");
        assert.deepEqual(yamlCommentLines(source), [4, 9]);
    });

    test("the YAML scanner ignores quoted hashes, apostrophes, URLs and Markdown in text blocks", () => {
        const source = [
            'placeholder: "#1"',
            "description: It doesn't fail #here",
            "label: 'issue #4'",
            "url: https://example.com/#anchor",
            "value: |",
            "  ### A Markdown heading",
            "  # Another",
        ].join("\n");
        assert.deepEqual(yamlCommentLines(source), [2]);
    });

    test("the Python scanner finds comments and ignores hashes in strings and the shebang", () => {
        const source = ['#!/usr/bin/env python3', 'pattern = r"^(?: #(?P<issue>\\d+))?$"', "text = '''a # b'''", "value = 1  # a note"].join("\n");
        assert.deepEqual(pythonCommentLines(source), [4]);
    });

    test("the Python scanner does not flag anything it cannot be sure of", () => {
        assert.deepEqual(pythonCommentLines('text = "never closed\n# after\n'), []);
    });
});
