local PREFIX = "rsprite-example: "
local SETTINGS_KEY = "rsprite-example:settings"
local CLOSE_KEY = "rsprite-example:close"

local PANEL_X = 80
local PANEL_Y = 80
local PANEL_WIDTH = 444
local PANEL_HEIGHT = 152
local COLUMN_WIDTH = 54
local ICON_Y = 30
local CAPTION_Y = 62
local SWAP_HEADING_Y = 82
local SWAP_ICON_Y = 100
local SWAP_CAPTION_Y = 132
local SWAP_COLUMN_WIDTH = 72
local ICON_SIZE = 24
local CLOSE_WIDTH = 56
local CLOSE_HEIGHT = 18
local BACKGROUND_COLOUR = 0x1A1A1AF0
local CLOSE_COLOUR = 0x803030FF
local LABEL_COLOUR = 0xFFFFFFFF
local EXPLORERS_RING = 13562
local SWAP_SOURCE = "SKILL_ATTACK"
local INVALID_ITEM = -5
local FIND_QUERIES = { "attack", "necromancy", "arrow" }
local FIND_SHOWN = 5
local DIALOG_MESSAGE =
    "Close this window to see the rsprite example panel in the top left of the game screen."
local DIALOG_TEXT_X = 10
local DIALOG_TEXT_Y = 10
local DIALOG_TEXT_WIDTH = 536

local panelRoot = nil
local dialogText = nil

local function say(message)
    print(PREFIX .. message)
end

local function safely(label, action)
    local results = table.pack(pcall(action))
    if not results[1] then
        say(label .. " raised " .. tostring(results[2]))
        return nil
    end
    return table.unpack(results, 2, results.n)
end

local function addLabel(parent, text, x, y, width)
    return safely("label " .. text, function()
        local label = ui.Text.new(parent)
        label:SetPos(x, y)
        label:SetSize(width, 14)
        label.content = text
        label.font = id.Font.MUSEO_SANS_11PT_REGULAR
        label.rgba = LABEL_COLOUR
        label.clickthrough = true
        return label
    end)
end

local function destroyDialogText()
    if dialogText == nil then
        return
    end
    local text = dialogText
    dialogText = nil
    safely("removing the dialog text", function()
        text:Destroy()
    end)
end

local function showDialogText(component)
    destroyDialogText()
    if component == nil then
        return
    end
    dialogText =
        addLabel(component, DIALOG_MESSAGE, DIALOG_TEXT_X, DIALOG_TEXT_Y, DIALOG_TEXT_WIDTH)
end

local function destroyPanel()
    if panelRoot == nil then
        return
    end
    local root = panelRoot
    panelRoot = nil
    safely("closing the panel", function()
        root:Destroy()
    end)
end

local function createPanel()
    destroyPanel()
    return safely("building the panel", function()
        local gameArea = ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2__GAME_AREA)
        local root = ui.Layer.new(gameArea)
        root:SetPos(PANEL_X, PANEL_Y)
        root:SetSize(PANEL_WIDTH, PANEL_HEIGHT)
        root.clickthrough = false
        panelRoot = root

        local background = ui.Rectangle.new(root)
        background:SetPos(0, 0)
        background:SetSize(PANEL_WIDTH, PANEL_HEIGHT)
        background.fill = true
        background.rgba = BACKGROUND_COLOUR
        background.clickthrough = false

        addLabel(root, "rsprite example", 8, 6, 200)

        local closeButton = ui.Rectangle.new(root)
        closeButton:SetPos(PANEL_WIDTH - CLOSE_WIDTH - 6, 4)
        closeButton:SetSize(CLOSE_WIDTH, CLOSE_HEIGHT)
        closeButton.fill = true
        closeButton.rgba = CLOSE_COLOUR
        closeButton.clickthrough = false
        closeButton:Subscribe(ui.Hook.ONCLICK, CLOSE_KEY, function()
            destroyPanel()
            return false
        end)
        addLabel(root, "Close", PANEL_WIDTH - CLOSE_WIDTH + 6, 6, CLOSE_WIDTH - 10)
        root:MoveToFront()
        return root
    end)
end

local DRAWINGS = {
    {
        caption = "attack",
        description = 'Draw("SKILL_ATTACK")',
        draw = function(parent, x)
            return rsprite.Draw(parent, "SKILL_ATTACK", { x = x, y = ICON_Y, size = ICON_SIZE })
        end,
    },
    {
        caption = "herblore",
        description = 'Draw("skill_herblore")',
        draw = function(parent, x)
            return rsprite.Draw(parent, "skill_herblore", { x = x, y = ICON_Y, size = ICON_SIZE })
        end,
    },
    {
        caption = "magic",
        description = 'Draw({ "MISSING_NAME", "SKILL_MAGIC" })',
        draw = function(parent, x)
            return rsprite.Draw(
                parent,
                { "MISSING_NAME", "SKILL_MAGIC" },
                { x = x, y = ICON_Y, size = ICON_SIZE }
            )
        end,
    },
    {
        caption = "missing",
        description = 'Draw("MISSING_NAME")',
        draw = function(parent, x)
            return rsprite.Draw(parent, "MISSING_NAME", { x = x, y = ICON_Y, size = ICON_SIZE })
        end,
    },
    {
        caption = "ring",
        description = "DrawItem(13562)",
        isItem = true,
        draw = function(parent, x)
            return rsprite.DrawItem(parent, EXPLORERS_RING, { x = x, y = ICON_Y, size = ICON_SIZE })
        end,
    },
    {
        caption = "ring x5",
        description = "DrawItem(13562, quantity 5)",
        isItem = true,
        draw = function(parent, x)
            return rsprite.DrawItem(
                parent,
                EXPLORERS_RING,
                { x = x, y = ICON_Y, size = ICON_SIZE, quantity = 5 }
            )
        end,
    },
}

local SWAPS = {
    {
        caption = "to sprite",
        draw = function(parent, layout)
            local sprite = rsprite.DrawItem(parent, EXPLORERS_RING, layout)
            rsprite.SetSource(sprite, SWAP_SOURCE)
            return sprite
        end,
    },
    {
        caption = "to item",
        draw = function(parent, layout)
            local sprite = rsprite.Draw(parent, SWAP_SOURCE, layout)
            rsprite.SetItem(sprite, EXPLORERS_RING)
            return sprite
        end,
    },
    {
        caption = "item back",
        draw = function(parent, layout)
            local sprite = rsprite.DrawItem(parent, EXPLORERS_RING, layout)
            rsprite.SetSource(sprite, SWAP_SOURCE)
            rsprite.SetItem(sprite, EXPLORERS_RING)
            return sprite
        end,
    },
    {
        caption = "sprite back",
        draw = function(parent, layout)
            local sprite = rsprite.Draw(parent, SWAP_SOURCE, layout)
            rsprite.SetItem(sprite, EXPLORERS_RING)
            rsprite.SetSource(sprite, SWAP_SOURCE)
            return sprite
        end,
    },
    {
        caption = "no count",
        draw = function(parent, layout)
            layout.quantity = 5
            local sprite = rsprite.DrawItem(parent, EXPLORERS_RING, layout)
            rsprite.SetSource(sprite, SWAP_SOURCE)
            return sprite
        end,
    },
    {
        caption = "no grey",
        draw = function(parent, layout)
            local sprite = rsprite.DrawItem(parent, INVALID_ITEM, layout)
            rsprite.SetItem(sprite, EXPLORERS_RING)
            return sprite
        end,
    },
}

local function drawSwaps(root)
    addLabel(root, "swaps", 8, SWAP_HEADING_Y, 200)
    for position, swap in ipairs(SWAPS) do
        local x = 8 + (position - 1) * SWAP_COLUMN_WIDTH
        safely("swap " .. swap.caption, function()
            return swap.draw(root, { x = x, y = SWAP_ICON_Y, size = ICON_SIZE })
        end)
        addLabel(root, swap.caption, x - 4, SWAP_CAPTION_Y, SWAP_COLUMN_WIDTH)
    end
end

local function drawEverything(root)
    for position, drawing in ipairs(DRAWINGS) do
        local x = 8 + (position - 1) * COLUMN_WIDTH
        local sprite, resolvedIndex = safely(drawing.description, function()
            return drawing.draw(root, x)
        end)
        addLabel(root, drawing.caption, x - 4, CAPTION_Y, COLUMN_WIDTH)
        local indexText = drawing.isItem and "" or (", resolved index " .. tostring(resolvedIndex))
        say(drawing.description .. " gave a sprite " .. tostring(sprite ~= nil) .. indexText)
    end
end

local function printLookups()
    say('Get("SKILL_ATTACK") = ' .. tostring(rsprite.Get("SKILL_ATTACK")))
    say('Get("skill_herblore") = ' .. tostring(rsprite.Get("skill_herblore")))
    say('Get("MISSING_NAME") = ' .. tostring(rsprite.Get("MISSING_NAME")))
    say("Name(9318) = " .. tostring(rsprite.Name(9318)))
    local source, index = rsprite.Resolve({ "MISSING_NAME", "SKILL_MAGIC" })
    say(
        string.format(
            'Resolve({ "MISSING_NAME", "SKILL_MAGIC" }) = %s at index %s',
            tostring(source),
            tostring(index)
        )
    )
end

local function printFinds()
    for _, query in ipairs(FIND_QUERIES) do
        local entries, total = rsprite.Find(query, { limit = FIND_SHOWN })
        local shown = {}
        for _, entry in ipairs(entries) do
            shown[#shown + 1] = string.format("%s (%d)", entry.name, entry.id)
        end
        say(
            string.format(
                'Find("%s") total %d, top %d: %s',
                query,
                total,
                #shown,
                table.concat(shown, ", ")
            )
        )
    end
end

local function onSettingsOpened(event)
    say("cog opened, rsprite " .. tostring(rsprite.version))
    showDialogText(event and event.component)
    local root = createPanel()
    if root ~= nil then
        drawEverything(root)
        drawSwaps(root)
    end
    printLookups()
    say("IsIndexReady before BuildIndex = " .. tostring(rsprite.IsIndexReady()))
    safely("BuildIndex", function()
        rsprite.BuildIndex(function(count)
            say("BuildIndex ready with " .. tostring(count) .. " names")
            safely("Find", printFinds)
        end)
    end)
end

local subscribed = safely("subscribing to the settings cog", function()
    Event.SettingsLayerReady.Subscribe(SETTINGS_KEY, function(event)
        safely("the settings cog handler", function()
            onSettingsOpened(event)
        end)
    end)
    return true
end)
local settingsSubscribed = subscribed == true

function PluginShutdown()
    if settingsSubscribed then
        safely("unsubscribing from the settings cog", function()
            Event.SettingsLayerReady.Unsubscribe(SETTINGS_KEY)
        end)
        settingsSubscribed = false
    end
    destroyDialogText()
    destroyPanel()
end

say("loaded, rsprite is " .. type(rsprite))
