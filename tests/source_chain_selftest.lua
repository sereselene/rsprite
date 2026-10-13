selftest.UsePlugin("rsprite")

local ClientFakes = require("tests/support/client_fakes")
local Report = require("tests/support/report")

local SOURCE = "tests/source_chain_selftest.lua:"

local check = Report.New("source chain")
ClientFakes.Install()
local rsprite = ClientFakes.LoadRsprite().Public
local handle = ClientFakes.Handle("icon")

local source, index = rsprite.Resolve({ "MISSING", "SKILL_ATTACK" })
check.Equal("a missing name falls through to the next name", source, 9318)
check.Equal("the index is the winning position", index, 2)

source, index = rsprite.Resolve({ handle, "SKILL_ATTACK" })
check.Check("a handle before a name wins as is", source == handle and index == 1, tostring(index))

source, index = rsprite.Resolve({ "SKILL_ATTACK", handle })
check.Check("a name before a handle wins", source == 9318 and index == 1, tostring(source))

source, index = rsprite.Resolve({ "MISSING", handle })
check.Check("a handle after a missing name wins", source == handle and index == 2, tostring(index))

source, index = rsprite.Resolve(9318)
check.Check("a valid number id resolves", source == 9318 and index == 1, tostring(source))

source, index = rsprite.Resolve({ -1, 1.5, 3, "SKILL_MAGIC" })
check.Check(
    "invalid numbers and ids with no sprite are skipped",
    source == 33454 and index == 4,
    tostring(source) .. " at " .. tostring(index)
)

source, index = rsprite.Resolve("skill_herblore")
check.Check("a single name is a one entry chain", source == 9329 and index == 1, tostring(source))

source, index = rsprite.Resolve(handle)
check.Check(
    "a single handle is a one entry chain",
    source == handle and index == 1,
    tostring(index)
)

source, index = rsprite.Resolve({ "MISSING", "ALSO_MISSING", 3 })
check.Check("all missing gives nil", source == nil and index == nil, tostring(source))

check.Raises(
    "a chain entry of the wrong type raises",
    function()
        rsprite.Resolve({ "SKILL_ATTACK", true })
    end,
    "rsprite.Resolve: chain entry 2 must be a sprite name, sprite id or resource handle, got boolean",
    SOURCE
)

check.Raises(
    "a nil source raises",
    function()
        rsprite.Resolve(nil)
    end,
    "rsprite.Resolve: source must be a sprite name, sprite id, resource handle or an array of them, got nil",
    SOURCE
)

check.Raises(
    "a nested table raises",
    function()
        rsprite.Resolve({ {} })
    end,
    "rsprite.Resolve: chain entry 1 must be a sprite name, sprite id or resource handle, got table",
    SOURCE
)

local resolvedSource, resolvedPosition = rsprite.Resolve({ "FLOORSHADOWS", "SKILL_ATTACK" })
check.Same(
    "a crashing name is skipped in a chain",
    { resolvedSource, resolvedPosition },
    { 9318, 2 }
)
resolvedSource, resolvedPosition = rsprite.Resolve({ 1243, "SKILL_MAGIC" })
check.Same(
    "a crashing id is skipped in a chain",
    { resolvedSource, resolvedPosition },
    { 33454, 2 }
)
check.Equal(
    "a chain of only a crashing sprite resolves to nothing",
    rsprite.Resolve("FLOORSHADOWS"),
    nil
)

check.Finish()
