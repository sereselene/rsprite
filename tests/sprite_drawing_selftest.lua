local ClientFakes = require("tests/support/client_fakes")
local Report = require("tests/support/report")

local SOURCE = "tests/sprite_drawing_selftest.lua:"

local check = Report.New("sprite drawing")
local client = ClientFakes.Install()
local rsprite = ClientFakes.LoadRsprite().Public
local parent = client.NewComponent("layer")

client.ClearLog()
local sprite, index = rsprite.Draw(parent, { "MISSING", "SKILL_ATTACK" })
check.Check("Draw returns a sprite", sprite ~= nil, tostring(sprite))
check.Equal("Draw returns the resolved index", index, 2)
check.Same("the first resolving source is written with the default size 24", client.log, {
    "SetPos 0 0 0 0",
    "SetSize 24 24",
    "clickthrough true",
    "sprite 9318",
    "hidden false",
})

client.ClearLog()
sprite, index = rsprite.Draw(parent, "MISSING_NAME")
check.Check("nothing resolving still returns a sprite", sprite ~= nil, tostring(sprite))
check.Equal("nothing resolving gives a nil index", index, nil)
check.Same("nothing resolving shows the placeholder", client.log, {
    "SetPos 0 0 0 0",
    "SetSize 24 24",
    "clickthrough true",
    "sprite handle:placeholder",
    "hidden false",
})

client.ClearLog()
rsprite.Draw(parent, "MISSING_NAME", { placeholder = false })
check.Same("placeholder false leaves it hidden", client.log, {
    "SetPos 0 0 0 0",
    "SetSize 24 24",
    "clickthrough true",
    "hidden true",
})

for _, emptyCase in ipairs({
    { chain = {}, name = "an empty chain" },
    { chain = { nil, "SKILL_ATTACK" }, name = "a chain starting with nil" },
}) do
    local emptyChain = emptyCase.chain
    local drawn = rsprite.Draw(parent, emptyChain)
    check.Check(emptyCase.name .. " still returns a sprite", drawn ~= nil, tostring(drawn))

    client.ClearLog()
    local _, emptyIndex = rsprite.Draw(parent, emptyChain)
    check.Equal(emptyCase.name .. " gives a nil index", emptyIndex, nil)
    check.Same(emptyCase.name .. " shows the placeholder through Draw", client.log, {
        "SetPos 0 0 0 0",
        "SetSize 24 24",
        "clickthrough true",
        "sprite handle:placeholder",
        "hidden false",
    })

    client.ClearLog()
    rsprite.Draw(parent, emptyChain, { placeholder = false })
    check.Same(emptyCase.name .. " draws nothing through Draw with placeholder false", client.log, {
        "SetPos 0 0 0 0",
        "SetSize 24 24",
        "clickthrough true",
        "hidden true",
    })

    client.ClearLog()
    rsprite.SetSource(drawn, emptyChain)
    check.Same(emptyCase.name .. " shows the placeholder through SetSource", client.log, {
        "sprite handle:placeholder",
        "hidden false",
    })

    client.ClearLog()
    rsprite.SetSource(drawn, emptyChain, { placeholder = false })
    check.Same(
        emptyCase.name .. " draws nothing through SetSource with placeholder false",
        client.log,
        { "hidden true" }
    )
end

local layoutProblems = {
    { options = { size = 0 }, message = "rsprite.Draw: option size must be above 0, got 0" },
    { options = { width = -5 }, message = "rsprite.Draw: option width must be above 0, got -5" },
    { options = { height = 0 }, message = "rsprite.Draw: option height must be above 0, got 0" },
    {
        options = { size = 0 / 0 },
        message = "rsprite.Draw: option size must be a finite number, got nan",
    },
    {
        options = { size = math.huge },
        message = "rsprite.Draw: option size must be a finite number, got inf",
    },
    {
        options = { width = -math.huge },
        message = "rsprite.Draw: option width must be a finite number, got -inf",
    },
    {
        options = { x = 0 / 0 },
        message = "rsprite.Draw: option x must be a finite number, got nan",
    },
    {
        options = { yAnchor = math.huge },
        message = "rsprite.Draw: option yAnchor must be a finite number, got inf",
    },
}
for _, layoutProblem in ipairs(layoutProblems) do
    check.Raises(layoutProblem.message, function()
        rsprite.Draw(parent, "SKILL_ATTACK", layoutProblem.options)
    end, layoutProblem.message, SOURCE)
end

client.ClearLog()
rsprite.Draw(
    parent,
    "SKILL_ATTACK",
    { size = 0.5, x = -20, y = -4, xAnchor = 1.5, yAnchor = -0.25 }
)
check.Same("fractions, negative positions and anchors outside 0 to 1 are allowed", client.log, {
    "SetPos -20 -4 1.5 -0.25",
    "SetSize 0.5 0.5",
    "clickthrough true",
    "sprite 9318",
    "hidden false",
})

local colour = 0x11223344
client.ClearLog()
rsprite.Draw(parent, "SKILL_MAGIC", {
    x = 5,
    y = 6,
    xAnchor = 0.5,
    yAnchor = 1,
    size = 30,
    colour = colour,
    alpha = 0.5,
})
check.Same("position, anchors, size, colour and alpha reach the client", client.log, {
    "SetPos 5 6 0.5 1",
    "SetSize 30 30",
    "clickthrough true",
    "rgba " .. tostring(colour),
    "alpha 0.5",
    "sprite 33454",
    "hidden false",
})

client.ClearLog()
rsprite.Draw(parent, "SKILL_MAGIC", { size = 30, width = 40, height = 12 })
check.Equal("width and height override size", client.log[2], "SetSize 40 12")

client.ClearLog()
rsprite.Draw(parent, "SKILL_MAGIC", { width = 40 })
check.Equal("a missing height falls back to the default size", client.log[2], "SetSize 40 24")

local handle = ClientFakes.Handle("logo")
client.ClearLog()
sprite, index = rsprite.Draw(parent, { "MISSING", handle })
check.Equal("a resource handle in the chain is drawn", client.log[4], "sprite handle:logo")
check.Equal("the handle's index is returned", index, 2)

client.ClearLog()
local resolved = rsprite.SetSource(sprite, { "MISSING", "SKILL_HERBLORE" }, { alpha = 1 })
check.Equal("SetSource returns the resolved index", resolved, 2)
check.Same("SetSource only touches appearance and source", client.log, {
    "alpha 1",
    "sprite 9329",
    "hidden false",
})

client.ClearLog()
resolved = rsprite.SetSource(sprite, "MISSING", { placeholder = false })
check.Equal("SetSource with nothing resolving gives nil", resolved, nil)
check.Same("SetSource with placeholder false hides the sprite", client.log, { "hidden true" })

check.Check(
    "a fake component counts as a component",
    rsprite.Draw(parent, "SKILL_ATTACK") ~= nil,
    type(parent)
)

local spritesBefore = #client.sprites
check.Raises("a nil parent raises", function()
    rsprite.Draw(nil, "SKILL_ATTACK")
end, "rsprite.Draw: parent must be a component, got nil", SOURCE)
check.Raises("a string parent raises", function()
    rsprite.Draw("panel", "SKILL_ATTACK")
end, "rsprite.Draw: parent must be a component, got string", SOURCE)
check.Raises(
    "a table parent raises with a hint",
    function()
        rsprite.Draw({}, "SKILL_ATTACK")
    end,
    "rsprite.Draw: parent must be a component, not a table. Pass the component itself, such as a window's content",
    SOURCE
)
check.Raises("a number parent keeps the plain message", function()
    rsprite.Draw(5, "SKILL_ATTACK")
end, "rsprite.Draw: parent must be a component, got number", SOURCE)
check.Raises(
    "SetSource on a table raises with a hint",
    function()
        rsprite.SetSource({}, "SKILL_ATTACK")
    end,
    "rsprite.SetSource: sprite must be a component, not a table. Pass the sprite itself, such as the one rsprite.Draw returned",
    SOURCE
)
check.Raises("an unknown option raises", function()
    rsprite.Draw(parent, "SKILL_ATTACK", { colur = 1 })
end, "rsprite.Draw: unknown option colur", SOURCE)
check.Raises("a non-number colour raises", function()
    rsprite.Draw(parent, "SKILL_ATTACK", { colour = "red" })
end, "rsprite.Draw: option colour must be a number, got string", SOURCE)
check.Raises("a non-number size raises", function()
    rsprite.Draw(parent, "SKILL_ATTACK", { size = "big" })
end, "rsprite.Draw: option size must be a number, got string", SOURCE)
check.Raises("options that are not a table raise", function()
    rsprite.Draw(parent, "SKILL_ATTACK", 24)
end, "rsprite.Draw: options must be a table, got number", SOURCE)
check.Raises(
    "a chain entry of the wrong type raises",
    function()
        rsprite.Draw(parent, { "SKILL_ATTACK", false })
    end,
    "rsprite.Draw: chain entry 2 must be a sprite name, sprite id or resource handle, got boolean",
    SOURCE
)
check.Raises("SetSource on a nil sprite raises", function()
    rsprite.SetSource(nil, "SKILL_ATTACK")
end, "rsprite.SetSource: sprite must be a component, got nil", SOURCE)
check.Raises("SetSource rejects layout options", function()
    rsprite.SetSource(sprite, "SKILL_ATTACK", { size = 24 })
end, "rsprite.SetSource: unknown option size", SOURCE)
check.Equal("raising calls create no sprites", #client.sprites, spritesBefore)

client.raiseOnCreate = true
local warningsBefore = #client.warnings
sprite, index = rsprite.Draw(parent, "SKILL_ATTACK")
check.Check("a failed create gives nil", sprite == nil and index == nil, tostring(sprite))
check.Equal("a failed create warns once", #client.warnings - warningsBefore, 1)
client.raiseOnCreate = false

check.Finish()
