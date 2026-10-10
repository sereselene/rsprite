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

client.ClearLog()
rsprite.DrawItem(parent, nil)
check.Equal(
    "a nil id makes no SetAssociatedObject call",
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
