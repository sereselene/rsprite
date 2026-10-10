local Arguments = require("src/utils/arguments")
local Client = require("src/services/client")
local Placeholder = require("src/components/placeholder")
local SpriteDrawing = require("src/features/drawing/sprite_drawing")
local Warnings = require("src/services/warnings")
local WholeNumber = require("src/utils/whole_number")

local ItemDrawing = {}

local CLEARED_ITEM = -1

local SET_ITEM_OPTION_TYPES = {
    quantity = "number",
    placeholder = "boolean",
}

local DRAW_ITEM_OPTION_TYPES =
    Arguments.CombineTypes(SpriteDrawing.LAYOUT_OPTION_TYPES, SET_ITEM_OPTION_TYPES)

local function optionsProblem(functionName, options, expectedTypes)
    return Arguments.OptionsProblem(functionName, options, expectedTypes)
        or Arguments.WholeNumberOptionProblem(functionName, options, "quantity")
end

local function setItemProperty(sprite, propertyName, value)
    return Warnings.IfFailed(
        "item " .. propertyName,
        "setting " .. propertyName .. " on an item sprite",
        Client.SetProperty(sprite, propertyName, value)
    )
end

local function showPlaceholder(sprite, options, clearFirst)
    if clearFirst then
        Client.SetAssociatedObject(sprite, CLEARED_ITEM)
    end
    Placeholder.Show(sprite, options.placeholder ~= false)
    return false
end

local function showItem(sprite, itemId, options, clearBeforePlaceholder)
    setItemProperty(sprite, "hidden", true)
    local wholeId = WholeNumber.From(itemId)
    if wholeId == nil then
        Warnings.Once(
            "item " .. tostring(itemId),
            "item id "
                .. tostring(itemId)
                .. " is not a whole number 0 or above, so the placeholder is shown instead"
        )
        return showPlaceholder(sprite, options, clearBeforePlaceholder)
    end
    local description = "drawing item " .. wholeId
    if
        not Warnings.IfFailed(description, description, Client.SetAssociatedObject(sprite, wholeId))
    then
        return showPlaceholder(sprite, options, true)
    end
    if options.quantity ~= nil then
        setItemProperty(
            sprite,
            "associatedObjectQuantityMode",
            Client.QuantityDisplayMode("ALWAYS")
        )
        setItemProperty(sprite, "associatedObjectQuantity", options.quantity)
    else
        setItemProperty(sprite, "associatedObjectQuantityMode", Client.QuantityDisplayMode("NEVER"))
    end
    setItemProperty(sprite, "hidden", false)
    return true
end

function ItemDrawing.DrawItem(parent, itemId, options)
    local problem = Arguments.ComponentProblem("rsprite.DrawItem", "parent", parent)
        or optionsProblem("rsprite.DrawItem", options, DRAW_ITEM_OPTION_TYPES)
    if problem ~= nil then
        error(problem, 2)
    end
    local resolvedOptions = options or {}
    local sprite = SpriteDrawing.CreateLaidOut(parent, resolvedOptions)
    if sprite == nil then
        return nil
    end
    showItem(sprite, itemId, resolvedOptions, false)
    return sprite
end

function ItemDrawing.SetItem(sprite, itemId, options)
    local problem = Arguments.ComponentProblem("rsprite.SetItem", "sprite", sprite)
        or optionsProblem("rsprite.SetItem", options, SET_ITEM_OPTION_TYPES)
    if problem ~= nil then
        error(problem, 2)
    end
    return showItem(sprite, itemId, options or {}, true)
end

return ItemDrawing
