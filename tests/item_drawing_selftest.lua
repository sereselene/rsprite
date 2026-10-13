local ClientFakes = require("tests/support/client_fakes")
local Report = require("tests/support/report")

local SOURCE = "tests/item_drawing_selftest.lua:"

local check = Report.New("item drawing")
local client = ClientFakes.Install()
local rsprite = ClientFakes.LoadRsprite().Public
local parent = {}

local function countEntries(log, prefix)
    local count = 0
    for _, line in ipairs(log) do
        if string.sub(line, 1, #prefix) == prefix then
            count = count + 1
        end
    end
    return count
end

client.ClearLog()
local sprite = rsprite.DrawItem(parent, ClientFakes.ITEM_ID)
check.Check("DrawItem returns a sprite", sprite ~= nil, tostring(sprite))
check.Same("the call order is exactly the confirmed one", client.log, {
    "SetPos 0 0 0 0",
    "SetSize 24 24",
    "clickthrough true",
    "hidden true",
    "SetAssociatedObject 13562",
    "associatedObjectQuantityMode NEVER",
    "hidden false",
})

client.ClearLog()
rsprite.DrawItem(parent, ClientFakes.ITEM_ID, { x = 4, y = 8, size = 36, quantity = 5 })
check.Same("a quantity switches to ALWAYS and sets the quantity", client.log, {
    "SetPos 4 8 0 0",
    "SetSize 36 36",
    "clickthrough true",
    "hidden true",
    "SetAssociatedObject 13562",
    "associatedObjectQuantityMode ALWAYS",
    "associatedObjectQuantity 5",
    "hidden false",
})

local invalidIds = { -1, 1.5, "13562", false }
for _, invalidId in ipairs(invalidIds) do
    client.ClearLog()
    local drawn = rsprite.DrawItem(parent, invalidId)
    check.Check(
        "invalid id " .. tostring(invalidId) .. " still returns a sprite",
        drawn ~= nil,
        tostring(drawn)
    )
    check.Equal(
        "invalid id " .. tostring(invalidId) .. " makes no SetAssociatedObject call",
        countEntries(client.log, "SetAssociatedObject"),
        0
    )
    check.Equal(
        "invalid id " .. tostring(invalidId) .. " shows the placeholder",
        client.log[#client.log - 1],
        "sprite handle:placeholder"
    )
end

for _, placeholderSetting in ipairs({ true, false }) do
    local label = "with placeholder " .. tostring(placeholderSetting)
    local warningsBeforeNil = #client.warnings
    client.ClearLog()
    local empty = rsprite.DrawItem(parent, nil, { placeholder = placeholderSetting })
    check.Check("DrawItem with nil still returns a sprite " .. label, empty ~= nil, tostring(empty))
    check.Same("DrawItem with nil makes an empty hidden sprite " .. label, client.log, {
        "SetPos 0 0 0 0",
        "SetSize 24 24",
        "clickthrough true",
        "hidden true",
    })
    check.Equal(
        "DrawItem with nil warns about nothing " .. label,
        #client.warnings,
        warningsBeforeNil
    )

    client.ClearLog()
    local cleared = rsprite.SetItem(empty, nil, { placeholder = placeholderSetting })
    check.Equal("SetItem with nil returns false " .. label, cleared, false)
    check.Same("SetItem with nil clears the art and hides the sprite " .. label, client.log, {
        "hidden true",
        "SetAssociatedObject -1",
    })
    check.Equal(
        "SetItem with nil warns about nothing " .. label,
        #client.warnings,
        warningsBeforeNil
    )
end

local function lastWarning()
    return client.warnings[#client.warnings]
end

local warningsBeforeWording = #client.warnings
rsprite.DrawItem(parent, -7)
check.Equal("an invalid id warns once", #client.warnings, warningsBeforeWording + 1)
check.Equal(
    "the warning says the placeholder is shown when it is",
    lastWarning(),
    "rsprite: item id -7 is not a whole number 0 or above, so the placeholder is shown instead"
)
client.ClearLog()
rsprite.DrawItem(parent, -8, { placeholder = false })
check.Equal(
    "the warning says nothing is shown when the placeholder is off",
    lastWarning(),
    "rsprite: item id -8 is not a whole number 0 or above, so nothing is shown"
)
check.Equal(
    "an invalid id with the placeholder off stays hidden",
    client.log[#client.log],
    "hidden true"
)
check.Equal(
    "an invalid id with the placeholder off makes no SetAssociatedObject call",
    countEntries(client.log, "SetAssociatedObject"),
    0
)

client.raiseOnAssociate = true
local warningsBefore = #client.warnings
client.ClearLog()
rsprite.DrawItem(parent, ClientFakes.ITEM_ID)
check.Same("a raising SetAssociatedObject clears with -1 and shows the placeholder", client.log, {
    "SetPos 0 0 0 0",
    "SetSize 24 24",
    "clickthrough true",
    "hidden true",
    "SetAssociatedObject 13562",
    "SetAssociatedObject -1",
    "sprite handle:placeholder",
    "hidden false",
})
check.Equal("a raising SetAssociatedObject warns once", #client.warnings - warningsBefore, 1)
client.raiseOnAssociate = false

client.ClearLog()
local shown = rsprite.SetItem(sprite, 4151)
check.Equal("SetItem returns true when the item is shown", shown, true)
check.Same("SetItem hides first", client.log, {
    "hidden true",
    "SetAssociatedObject 4151",
    "associatedObjectQuantityMode NEVER",
    "hidden false",
})

client.ClearLog()
shown = rsprite.SetItem(sprite, -5)
check.Equal("SetItem returns false for an invalid id", shown, false)
check.Same("SetItem with an invalid id clears the old item and shows the placeholder", client.log, {
    "hidden true",
    "SetAssociatedObject -1",
    "sprite handle:placeholder",
    "hidden false",
})

client.ClearLog()
rsprite.SetItem(sprite, -5, { placeholder = false })
check.Equal(
    "SetItem with placeholder false leaves it hidden",
    client.log[#client.log],
    "hidden true"
)

local itemSprite = rsprite.DrawItem(parent, ClientFakes.ITEM_ID)
client.ClearLog()
rsprite.SetSource(itemSprite, "SKILL_ATTACK")
check.Same(
    "SetSource on an item sprite hides it, clears the item art, then draws the source",
    client.log,
    {
        "hidden true",
        "SetAssociatedObject -1",
        "associatedObjectQuantityMode NEVER",
        "sprite 9318",
        "hidden false",
    }
)
client.ClearLog()
rsprite.SetSource(itemSprite, "SKILL_MAGIC")
check.Same("a second SetSource has no item art left to clear", client.log, {
    "sprite 33454",
    "hidden false",
})

local countedSprite = rsprite.DrawItem(parent, ClientFakes.ITEM_ID, { quantity = 5 })
client.ClearLog()
rsprite.SetSource(countedSprite, "SKILL_ATTACK")
check.Same("SetSource on an item sprite with a quantity clears the quantity mode too", client.log, {
    "hidden true",
    "SetAssociatedObject -1",
    "associatedObjectQuantityMode NEVER",
    "sprite 9318",
    "hidden false",
})

local emptiedSprite = rsprite.DrawItem(parent, ClientFakes.ITEM_ID)
rsprite.SetItem(emptiedSprite, nil)
client.ClearLog()
rsprite.SetSource(emptiedSprite, "SKILL_ATTACK")
check.Same("SetSource after SetItem with nil makes no clearing calls", client.log, {
    "sprite 9318",
    "hidden false",
})

local placeholderSprite = rsprite.DrawItem(parent, ClientFakes.ITEM_ID)
rsprite.SetItem(placeholderSprite, -9)
client.ClearLog()
rsprite.SetSource(placeholderSprite, "SKILL_ATTACK")
check.Same("SetSource after an invalid SetItem makes no clearing calls", client.log, {
    "sprite 9318",
    "hidden false",
})

local plainSprite = rsprite.Draw(parent, "SKILL_ATTACK")
client.ClearLog()
rsprite.SetSource(plainSprite, "SKILL_MAGIC")
check.Same("SetSource on a plain sprite makes no extra calls", client.log, {
    "sprite 33454",
    "hidden false",
})

local drawnSprite = rsprite.Draw(parent, "SKILL_ATTACK")
client.ClearLog()
rsprite.SetItem(drawnSprite, ClientFakes.ITEM_ID)
check.Same("SetItem on a drawn sprite makes no clearing calls", client.log, {
    "hidden true",
    "SetAssociatedObject 13562",
    "associatedObjectQuantityMode NEVER",
    "hidden false",
})

for _, layoutProblem in ipairs({
    { options = { size = 0 }, message = "rsprite.DrawItem: option size must be above 0, got 0" },
    {
        options = { height = 0 / 0 },
        message = "rsprite.DrawItem: option height must be a finite number, got nan",
    },
    {
        options = { x = 0 / 0 },
        message = "rsprite.DrawItem: option x must be a finite number, got nan",
    },
    {
        options = { yAnchor = math.huge },
        message = "rsprite.DrawItem: option yAnchor must be a finite number, got inf",
    },
}) do
    check.Raises(layoutProblem.message, function()
        rsprite.DrawItem(parent, ClientFakes.ITEM_ID, layoutProblem.options)
    end, layoutProblem.message, SOURCE)
end

client.ClearLog()
rsprite.DrawItem(parent, ClientFakes.ITEM_ID, { size = 12.5 })
check.Equal("a fractional item size is allowed", client.log[2], "SetSize 12.5 12.5")

check.Raises("a nil parent raises", function()
    rsprite.DrawItem(nil, ClientFakes.ITEM_ID)
end, "rsprite.DrawItem: parent must be a component, got nil", SOURCE)
check.Raises("a negative quantity raises", function()
    rsprite.DrawItem(parent, ClientFakes.ITEM_ID, { quantity = -2 })
end, "rsprite.DrawItem: option quantity must be a whole number 0 or above, got -2", SOURCE)
check.Raises("a non-number size raises", function()
    rsprite.DrawItem(parent, ClientFakes.ITEM_ID, { size = "large" })
end, "rsprite.DrawItem: option size must be a number, got string", SOURCE)
check.Raises("SetItem rejects layout options", function()
    rsprite.SetItem(sprite, ClientFakes.ITEM_ID, { size = 24 })
end, "rsprite.SetItem: unknown option size", SOURCE)
check.Raises("SetItem on a nil sprite raises", function()
    rsprite.SetItem(nil, ClientFakes.ITEM_ID)
end, "rsprite.SetItem: sprite must be a component, got nil", SOURCE)

check.Finish()
