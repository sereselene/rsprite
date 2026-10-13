selftest.UsePlugin("rsprite")

local Report = require("tests/support/report")

local check = Report.New("standards")

local SCANNED_FOLDERS = { "plugins", "examples", "tests" }
local SCANNED_FILES = { ".luacheckrc" }
local LUA_FILES = { [".luacheckrc"] = true }
local MAXIMUM_LINE_LENGTH = 200
local BINARY_EXTENSIONS = { png = true }

local function extensionOf(path)
    return string.match(path, "%.([%w]+)$") or ""
end

local function readWhole(path)
    local file = assert(io.open(path, "r"))
    local contents = file:read("a")
    file:close()
    return contents
end

local function skipQuoted(source, start, quote)
    local position = start + 1
    while position <= #source do
        local character = string.sub(source, position, position)
        if character == "\\" then
            position = position + 2
        elseif character == quote or character == "\n" then
            return position + 1
        else
            position = position + 1
        end
    end
    return position
end

local function commentOffset(source)
    local position = 1
    while position <= #source do
        local character = string.sub(source, position, position)
        if character == "-" and string.sub(source, position + 1, position + 1) == "-" then
            return position
        end
        if character == '"' or character == "'" then
            position = skipQuoted(source, position, character)
        elseif character == "[" and string.match(source, "^%[=*%[", position) then
            local equals = string.match(source, "^%[(=*)%[", position)
            local closing = "]" .. equals .. "]"
            local finish = string.find(source, closing, position + #equals + 2, true)
            position = finish and (finish + #closing) or (#source + 1)
        else
            position = position + 1
        end
    end
    return nil
end

local function lineNumberAt(source, offset)
    local _, newlines = string.gsub(string.sub(source, 1, offset), "\n", "")
    return newlines + 1
end

local comments = {}
local nonAscii = {}
local longLines = {}
local scanned = 0
local scannedLua = {}

local function scanFile(path)
    scanned = scanned + 1
    local source = readWhole(path)
    local badByte = string.find(source, "[\128-\255]")
    if badByte then
        nonAscii[#nonAscii + 1] = path .. ":" .. lineNumberAt(source, badByte)
    end
    local lineNumber = 0
    for line in string.gmatch(source .. "\n", "([^\n]*)\n") do
        lineNumber = lineNumber + 1
        if #line > MAXIMUM_LINE_LENGTH then
            longLines[#longLines + 1] = path .. ":" .. lineNumber
        end
    end
    if extensionOf(path) == "lua" or LUA_FILES[path] then
        scannedLua[path] = true
        local offset = commentOffset(source)
        if offset then
            comments[#comments + 1] = path .. ":" .. lineNumberAt(source, offset)
        end
    end
end

for _, folder in ipairs(SCANNED_FOLDERS) do
    for _, path in ipairs(selftest.ListFiles(folder)) do
        if not BINARY_EXTENSIONS[extensionOf(path)] then
            scanFile(path)
        end
    end
end
for _, path in ipairs(SCANNED_FILES) do
    scanFile(path)
end

check.Check("files were scanned", scanned > 0, scanned)
check.Equal("the Luacheck config is scanned as Lua", scannedLua[".luacheckrc"], true)
check.Same("no Lua file has a comment outside strings", comments, {})
check.Same("no file has a non-ASCII byte", nonAscii, {})
check.Same("no line is over 200 characters", longLines, {})

check.Check(
    "the comment scanner finds a real comment",
    commentOffset("local value = 1 -" .. "- note") ~= nil,
    "found"
)
check.Check(
    "the comment scanner ignores dashes in strings",
    commentOffset('local value = "a -' .. '- b" .. [[c -' .. "- d]]") == nil,
    "ignored"
)

check.Finish()
