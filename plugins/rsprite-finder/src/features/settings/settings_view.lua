local Client = require("src/services/client")

local SettingsView = {}

SettingsView.MESSAGE = "Open the sprite finder to search every sprite in the game."
SettingsView.BUTTON_LABEL = "OPEN FINDER"
SettingsView.SHOW_HIDDEN_LABEL = "Show hidden sprites again"

local currentView = nil

function SettingsView.Destroy()
    if currentView == nil then
        return
    end
    local view = currentView
    currentView = nil
    Client.Call("closing the settings view", function()
        view:Destroy()
    end)
end

local function optionChoices(choices, options)
    local listed = {}
    for position, choice in ipairs(choices) do
        listed[position] = {
            text = choice.text,
            value = choice.value,
            selected = options[choice.value] == true,
        }
    end
    return listed
end

function SettingsView.Mount(component, handlers)
    SettingsView.Destroy()
    local width, height = Client.ComponentSize(component)
    currentView = Client.Call("building the settings view", prettyui.SimpleView.new, component, {
        width = width,
        height = height,
    })
    if currentView == nil then
        return nil
    end
    Client.Call("writing the settings text", function()
        currentView:AddText(SettingsView.MESSAGE)
    end)
    Client.Call("adding the open finder button", function()
        currentView:AddFancyButton(SettingsView.BUTTON_LABEL, function()
            Client.Call("opening the finder", handlers.openFinder)
        end, { variant = "positive" })
    end)
    Client.Call("adding the show hidden sprites button", function()
        currentView:AddFancyButton(SettingsView.SHOW_HIDDEN_LABEL, function()
            Client.Call("showing hidden sprites again", handlers.showHiddenAgain)
        end, { variant = "neutral" })
    end)
    Client.Call("adding the finder options", function()
        currentView:AddCheckboxButton(optionChoices(handlers.choices, handlers.options), {
            onChange = function(_, _, changedValue, selected)
                Client.Call(
                    "changing a finder option",
                    handlers.onOptionChanged,
                    changedValue,
                    selected
                )
            end,
        })
    end)
    return currentView
end

return SettingsView
