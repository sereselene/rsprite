local ClientFakes = {}

ClientFakes.ITEM_ID = 13562

local REAL_SPRITES = {
    { 2, "HITSPLAT" },
    { 6910, "BP3_MISSION_ICON_SKILL_NECROMANCY" },
    { 9318, "SKILL_ATTACK" },
    { 9329, "SKILL_HERBLORE" },
    { 33454, "SKILL_MAGIC" },
    { 36636, "MAPFUNCTION_SEP_90" },
}
local FILLER_STEP = 250
local HIGHEST_REAL_ID = 36636
local WARNING_PREFIXES = { "rsprite: ", "rsprite-finder: " }
local TEXT_WIDTH_PER_CHARACTER = 6

local MUTABLE_SPRITE_PROPERTIES = {
    sprite = true,
    spriteID = true,
    rgba = true,
    colour = true,
    alpha = true,
    hidden = true,
    clickthrough = true,
    associatedObjectQuantity = true,
    associatedObjectQuantityMode = true,
    rotationDegrees = true,
    isFlippedHorizontally = true,
    isFlippedVertical = true,
    isTiling = true,
}

local originalPrint = print
local handleTags = setmetatable({}, { __mode = "k" })

local function newUserdataWith(metatable)
    local userdata = selftest.NewUserdata()
    debug.setmetatable(userdata, metatable)
    return userdata
end

function ClientFakes.Handle(tag)
    local handle = selftest.NewUserdata()
    handleTags[handle] = tag
    return handle
end

local function deepCopy(value)
    if type(value) ~= "table" then
        return value
    end
    local copy = {}
    for key, inner in pairs(value) do
        copy[key] = deepCopy(inner)
    end
    return copy
end

local function isWarning(line)
    for _, prefix in ipairs(WARNING_PREFIXES) do
        if string.sub(line, 1, #prefix) == prefix then
            return true
        end
    end
    return false
end

local function describe(value)
    if handleTags[value] ~= nil then
        return "handle:" .. handleTags[value]
    end
    return tostring(value)
end

function ClientFakes.DefaultSprites()
    local realNames = {}
    for _, entry in ipairs(REAL_SPRITES) do
        realNames[entry[1]] = entry[2]
    end
    local sprites = {}
    for spriteId = 0, HIGHEST_REAL_ID do
        if realNames[spriteId] ~= nil then
            sprites[#sprites + 1] = { spriteId, realNames[spriteId] }
        elseif spriteId % FILLER_STEP == 0 then
            sprites[#sprites + 1] = { spriteId, "FILLER_" .. spriteId .. "_SPRITE" }
        end
    end
    return sprites
end

function ClientFakes.Install(options)
    local settings = options or {}
    local client = {
        log = {},
        warnings = {},
        sprites = {},
        lookups = 0,
        fromIdCalls = 0,
        raiseOnLookup = false,
        raiseOnFromId = false,
        raiseOnFromIdFor = {},
        raiseOnEventSubscribe = false,
        raiseOnAssociate = false,
        raiseOnClear = false,
        raiseOnSetEntries = false,
        raiseOnSubscribe = false,
        fontLookups = 0,
        raiseOnCreate = false,
        components = {},
        destroyedComponents = 0,
        handlers = {},
        stored = {},
    }

    local idByName = {}
    local nameById = {}
    for _, entry in ipairs(settings.sprites or ClientFakes.DefaultSprites()) do
        idByName[entry[2]] = entry[1]
        nameById[entry[1]] = entry[2]
    end

    local function record(...)
        local parts = {}
        for position = 1, select("#", ...) do
            parts[position] = describe((select(position, ...)))
        end
        client.log[#client.log + 1] = table.concat(parts, " ")
    end

    local fromId = setmetatable({}, {
        __call = function(_, value)
            client.fromIdCalls = client.fromIdCalls + 1
            if type(value) ~= "number" then
                error("FromID expects a number")
            end
            local whole = value >= 0 and math.floor(value) or math.ceil(value)
            if client.raiseOnFromId or client.raiseOnFromIdFor[whole] then
                error("FromID failed")
            end
            return nameById[whole]
        end,
    })

    id = {
        Sprite = setmetatable({ FromID = fromId }, {
            __index = function(_, key)
                if type(key) ~= "string" then
                    error("sprite names are strings")
                end
                client.lookups = client.lookups + 1
                if client.raiseOnLookup then
                    error("lookup failed")
                end
                return idByName[key] or -1
            end,
        }),
        Font = { MUSEO_SANS_11PT_REGULAR = 11, MUSEO_SANS_13PT_BOLD = 13 },
        Component = { TOPLEVEL_V2__GAME_AREA = 1 },
        StyleSheet = { INPUT_DEFAULT = 7, COMBO_DEFAULT = 8 },
    }

    local clickHandlers = setmetatable({}, { __mode = "k" })

    local function newComponent(kind, parent)
        local fields = {
            hidden = false,
            width = 0,
            height = 0,
            kind = kind,
            cursorConfig = { mouseOverCursor = -1 },
            opCursors = {},
        }
        fields.opConfig = {
            ClearOpCursors = function()
                fields.opCursors = {}
            end,
            SetOpCursor = function(_, opIndex, cursorId)
                fields.opCursors[opIndex] = cursorId
            end,
        }
        if kind == "input field" then
            fields.text = {}
            fields.containerSprite = {}
            fields.content = ""
        end
        if kind == "combo field" then
            fields.entryText = {}
            fields.entryIdsByLabel = {}
            fields.hasSelection = false
            fields.selectedID = -1
        end
        local methods = {}
        function methods.SetPos(_, x, y)
            fields.x = x
            fields.y = y
        end
        function methods.SetSize(_, width, height)
            fields.width = width
            fields.height = height
        end
        function methods.MoveToFront() end
        function methods.Setup(_, visibility, filterMode, maximumLength)
            fields.visibility = visibility
            fields.filterMode = filterMode
            fields.maxLength = maximumLength
        end
        function methods.Destroy()
            fields.destroyed = true
            client.destroyedComponents = client.destroyedComponents + 1
        end
        function methods.HasEntry(_, entryId)
            for _, knownId in pairs(fields.entryIdsByLabel) do
                if knownId == entryId then
                    return true
                end
            end
            return false
        end
        function methods.Select(self, entryId)
            if not methods.HasEntry(self, entryId) then
                return false
            end
            fields.hasSelection = true
            fields.selectedID = entryId
            return true
        end
        function methods.SetEntries(self, entryIdsByLabel, selectedId)
            if client.raiseOnSetEntries then
                error("cannot fill these entries")
            end
            fields.entryIdsByLabel = entryIdsByLabel
            fields.hasSelection = false
            fields.selectedID = -1
            if not methods.Select(self, selectedId) then
                methods.Select(self, 1)
            end
            return true
        end
        local component = newUserdataWith({
            __index = function(_, key)
                return methods[key] or fields[key]
            end,
            __newindex = function(_, key, value)
                fields[key] = value
            end,
        })
        function methods.Subscribe(_, hook, key, callback)
            if client.raiseOnSubscribe then
                error("cannot subscribe here")
            end
            clickHandlers[component] = clickHandlers[component] or {}
            clickHandlers[component][hook .. ":" .. key] = callback
        end
        client.components[#client.components + 1] =
            { kind = kind, component = component, parent = parent }
        return component
    end

    function client.Fire(component, hookName, ...)
        local fired = 0
        local prefix = hookName .. ":"
        for key, callback in pairs(clickHandlers[component] or {}) do
            if string.sub(key, 1, #prefix) == prefix then
                callback(component, ...)
                fired = fired + 1
            end
        end
        return fired
    end

    function client.Click(component)
        return client.Fire(component, "ONCLICK")
    end

    function client.ComponentsOfKind(kind)
        local found = {}
        for _, entry in ipairs(client.components) do
            if entry.kind == kind and not entry.component.destroyed then
                found[#found + 1] = entry.component
            end
        end
        return found
    end

    client.gameArea = newComponent("game area", nil)

    local function newSprite(parent)
        if client.raiseOnCreate then
            error("cannot create a sprite here")
        end
        local fields = { hidden = false, associatedObjectID = -1 }
        local methods = {}
        function methods.SetPos(_, ...)
            record("SetPos", ...)
        end
        function methods.SetSize(_, ...)
            record("SetSize", ...)
        end
        function methods.SetAssociatedObject(_, itemId)
            record("SetAssociatedObject", itemId)
            if client.raiseOnAssociate and itemId >= 0 then
                error("cannot associate that item")
            end
            if client.raiseOnClear and itemId < 0 then
                error("cannot clear that item")
            end
            fields.associatedObjectID = itemId
        end
        function methods.Destroy()
            record("Destroy")
        end
        local sprite = newUserdataWith({
            __index = function(_, key)
                return methods[key] or fields[key]
            end,
            __newindex = function(_, key, value)
                if not MUTABLE_SPRITE_PROPERTIES[key] then
                    error("sol: cannot set property " .. tostring(key) .. " on ui.Sprite")
                end
                record(key, value)
                fields[key] = value
            end,
        })
        client.sprites[#client.sprites + 1] = { sprite = sprite, fields = fields, parent = parent }
        return sprite
    end

    local function constructor(kind)
        return {
            new = function(parent)
                return newComponent(kind, parent)
            end,
        }
    end

    ui = {
        Sprite = { new = newSprite },
        Text = constructor("text"),
        Rectangle = constructor("rectangle"),
        Layer = constructor("layer"),
        InputField = constructor("input field"),
        ComboField = constructor("combo field"),
        Margin = {
            new = function(left, top, right, bottom)
                return {
                    left = left,
                    top = top or left,
                    right = right or left,
                    bottom = bottom or left,
                }
            end,
        },
        TextContentVisibilityMode = {
            VISIBLE = "VISIBLE",
            SHOW_LAST = "SHOW_LAST",
            HIDDEN = "HIDDEN",
        },
        InputFieldFilterMode = { NONE = "NONE", NUMERIC = "NUMERIC" },
        InputFieldKeyHandlingMode = { DEFAULT = "DEFAULT", CHAT = "CHAT" },
        Interfaces = {
            GetComponent = function()
                return client.gameArea
            end,
        },
        Hook = {
            ONCLICK = "ONCLICK",
            ONRELEASE = "ONRELEASE",
            ONMOUSEOVER = "ONMOUSEOVER",
            ONMOUSELEAVE = "ONMOUSELEAVE",
            ONCONTENTCHANGED = "ONCONTENTCHANGED",
            ONSELECTIONCHANGED = "ONSELECTIONCHANGED",
        },
        AlignMode = { TOPLEFT = "TOPLEFT", CENTRE = "CENTRE", BOTTOMRIGHT = "BOTTOMRIGHT" },
        ObjectQuantityDisplayMode = { NEVER = "NEVER", ALWAYS = "ALWAYS", MULTIPLE = "MULTIPLE" },
    }

    config = {
        Cursor = { CURSOR_BLANK = { id = 99 } },
        Font = {
            FromID = function()
                client.fontLookups = client.fontLookups + 1
                return {
                    GetStringWidth = function(_, text)
                        return #text * TEXT_WIDTH_PER_CHARACTER
                    end,
                }
            end,
        },
    }

    PersistentDB = {
        GetStructuredData = function(_, key)
            return deepCopy(client.stored[key])
        end,
        SetStructuredData = function(_, key, value)
            client.stored[key] = deepCopy(value)
        end,
    }

    client.placeholder = ClientFakes.Handle("placeholder")
    client.textField = ClientFakes.Handle("text_field")
    client.checker = ClientFakes.Handle("checker")
    Plugin = {
        resources = settings.resources or {
            placeholder = client.placeholder,
            text_field = client.textField,
            checker = client.checker,
        },
    }

    local function eventKind(eventName)
        client.handlers[eventName] = {}
        return {
            Subscribe = function(key, callback)
                if client.raiseOnEventSubscribe then
                    error("cannot subscribe to " .. eventName)
                end
                client.handlers[eventName][key] = callback
            end,
            Unsubscribe = function(key)
                client.handlers[eventName][key] = nil
            end,
        }
    end

    Event = {
        Logic = eventKind("Logic"),
        Draw = eventKind("Draw"),
        SettingsLayerReady = eventKind("SettingsLayerReady"),
    }
    client.subscriptions = client.handlers.Logic

    function client.FireEvent(eventName, payload)
        local callbacks = {}
        for _, callback in pairs(client.handlers[eventName]) do
            callbacks[#callbacks + 1] = callback
        end
        for _, callback in ipairs(callbacks) do
            callback(payload)
        end
        return #callbacks
    end

    function client.NewComponent(kind)
        return newComponent(kind, nil)
    end

    function client.Logged(prefix)
        local count = 0
        for _, line in ipairs(client.log) do
            if string.sub(line, 1, #prefix) == prefix then
                count = count + 1
            end
        end
        return count
    end

    function client.ClearLog()
        client.log = {}
    end

    function client.SubscriptionCount()
        local count = 0
        for _ in pairs(client.subscriptions) do
            count = count + 1
        end
        return count
    end

    function client.FireLogic()
        local callbacks = {}
        for _, callback in pairs(client.subscriptions) do
            callbacks[#callbacks + 1] = callback
        end
        for _, callback in ipairs(callbacks) do
            callback({ logicTick = 0 })
        end
        return #callbacks
    end

    function client.WarningsMentioning(text)
        local count = 0
        for _, warning in ipairs(client.warnings) do
            if string.find(warning, text, 1, true) then
                count = count + 1
            end
        end
        return count
    end

    _G.print = function(...)
        local parts = {}
        for position = 1, select("#", ...) do
            parts[position] = tostring((select(position, ...)))
        end
        local line = table.concat(parts, "\t")
        if isWarning(line) then
            client.warnings[#client.warnings + 1] = line
            return
        end
        originalPrint(...)
    end

    return client
end

function ClientFakes.LoadRsprite(curation)
    local loadedModules = package.loaded
    for name in pairs(loadedModules) do
        if type(name) == "string" and string.sub(name, 1, 4) == "src/" then
            loadedModules[name] = nil
        end
    end
    if curation ~= nil then
        loadedModules["src/data/curation"] = curation
    end
    return require("src/app/init")
end

return ClientFakes
