local ClientFakes = require("tests/support/client_fakes")
local PrettyuiFake = require("tests/support/prettyui_fake")

local FinderFakes = {}

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
