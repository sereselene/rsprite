local Client = require("src/services/client")
local Warnings = require("src/services/warnings")
local WholeNumber = require("src/utils/whole_number")

local SpriteLookup = {}

local MISSING = false

local idByName = {}
local nameById = {}

function SpriteLookup.Get(name)
    if type(name) ~= "string" or name == "" then
        return nil
    end
    local key = string.upper(name)
    local cached = idByName[key]
    if cached ~= nil then
        return cached or nil
    end
    local found, value = Client.SpriteIdByName(key)
    local spriteId = found and WholeNumber.From(value) or nil
    if not found then
        Warnings.Once("get " .. key, "looking up sprite " .. key .. " failed: " .. tostring(value))
    elseif spriteId == nil then
        Warnings.Once("get " .. key, "there is no sprite called " .. key)
    end
    idByName[key] = spriteId or MISSING
    return spriteId
end

function SpriteLookup.Name(spriteId)
    local wholeId = WholeNumber.From(spriteId)
    if wholeId == nil then
        return nil
    end
    local cached = nameById[wholeId]
    if cached ~= nil then
        return cached or nil
    end
    local found, value = Client.SpriteNameById(wholeId)
    local name = found and type(value) == "string" and value ~= "" and value or nil
    if not found then
        Warnings.Once(
            "name " .. wholeId,
            "looking up sprite id " .. wholeId .. " failed: " .. tostring(value)
        )
    elseif name == nil then
        Warnings.Once("name " .. wholeId, "there is no sprite with id " .. wholeId)
    end
    nameById[wholeId] = name or MISSING
    return name
end

return SpriteLookup
