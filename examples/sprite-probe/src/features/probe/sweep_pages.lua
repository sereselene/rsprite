local Client = require("src/services/client")
local Pages = require("src/features/probe/pages")
local ProbeStore = require("src/services/probe_store")

local SweepPages = {}

local EVERY_SPRITE = 1000000

local everySprite = nil
local entries = nil
local preparing = false

local function rebuild()
    local found = {}
    for _, finding in ipairs(ProbeStore.LoadFindings()) do
        found[finding.name] = true
    end
    entries = {}
    for _, entry in ipairs(everySprite) do
        if not found[entry.name] then
            entries[#entries + 1] = { id = entry.id, name = entry.name }
        end
    end
end

local function onIndexReady()
    everySprite = Client.Call("listing every sprite", rsprite.Find, "", { limit = EVERY_SPRITE })
        or {}
    preparing = false
    rebuild()
end

function SweepPages.Prepare()
    if everySprite ~= nil then
        rebuild()
        return
    end
    if preparing then
        return
    end
    preparing = true
    local started = Client.Call("reading sprite names", function()
        rsprite.BuildIndex(onIndexReady)
        return true
    end)
    if started ~= true then
        everySprite = {}
        preparing = false
        rebuild()
    end
end

function SweepPages.IsReady()
    return entries ~= nil and not preparing
end

function SweepPages.PageCount()
    if entries == nil then
        return 0
    end
    return math.ceil(#entries / Pages.PAGE_SIZE)
end

function SweepPages.Entries(page)
    local slice = {}
    if entries == nil then
        return slice
    end
    local offset = (page - 1) * Pages.PAGE_SIZE
    for position = 1, Pages.PAGE_SIZE do
        slice[position] = entries[offset + position]
    end
    return slice
end

return SweepPages
