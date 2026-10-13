local ClientFakes = require("tests/support/client_fakes")
local PrettyuiFake = require("tests/support/prettyui_fake")

local FinderFakes = {}

local FIRST_EXTRA_SPRITE_ID = 36700
local SETTINGS_DIALOG_WIDTH = 556
local SETTINGS_DIALOG_HEIGHT = 300

function FinderFakes.SpritesWith(names)
    local sprites = ClientFakes.DefaultSprites()
    for position, name in ipairs(names) do
        sprites[#sprites + 1] = { FIRST_EXTRA_SPRITE_ID + position - 1, name }
    end
    return sprites
end

function FinderFakes.SettingsDialog(client)
    local component = client.NewComponent("settings dialog")
    component.width = SETTINGS_DIALOG_WIDTH
    component.height = SETTINGS_DIALOG_HEIGHT
    return component
end

function FinderFakes.LiveFancyButton(prettyuiFake, text)
    return prettyuiFake.Find("fancyButtons", function(button)
        return button.text == text and not button.destroyed
    end)
end

function FinderFakes.Install(options)
    local client = ClientFakes.Install(options)
    local prettyuiFake = PrettyuiFake.Install()
    rsprite = selftest.LoadPlugin("plugins/rsprite")
    return client, prettyuiFake
end

function FinderFakes.ForgetModules()
    local loadedModules = package.loaded
    for name in pairs(loadedModules) do
        if type(name) == "string" and string.sub(name, 1, 4) == "src/" then
            loadedModules[name] = nil
        end
    end
end

function FinderFakes.Type(client, textBox, text)
    textBox.component.content = text
    client.Fire(textBox.component, "ONCONTENTCHANGED", "CONTENT_CHANGE", text)
end

function FinderFakes.Choose(client, dropDown, label)
    local entryId = dropDown.component.entryIdsByLabel[label]
    if entryId == nil then
        return false
    end
    dropDown.component:Select(entryId)
    client.Fire(dropDown.component, "ONSELECTIONCHANGED", entryId, 1)
    return true
end

function FinderFakes.TicksUntil(client, condition, limit)
    local ticks = 0
    while not condition() and ticks < limit do
        client.FireLogic()
        ticks = ticks + 1
    end
    return ticks
end

return FinderFakes
