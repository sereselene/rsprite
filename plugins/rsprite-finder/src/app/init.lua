local Client = require("src/services/client")
local FinderOptions = require("src/features/finder/finder_options")
local FinderWindow = require("src/features/finder/finder_window")
local SettingsView = require("src/features/settings/settings_view")

local App = {}

local SETTINGS_KEY = "rsprite-finder:settings"

local subscribed = false

local function onOptionChanged(optionName, selected)
    if FinderOptions.Set(optionName, selected) then
        FinderWindow.OptionsChanged()
    end
end

local function onSettingsLayerReady(event)
    Client.Call("checking how the last session closed", FinderWindow.RecoverFromCrash)
    Client.Call("opening the settings dialog", function()
        SettingsView.Mount(event.component, {
            openFinder = FinderWindow.Open,
            showHiddenAgain = FinderWindow.ShowHiddenAgain,
            choices = FinderOptions.CHOICES,
            options = FinderOptions.Current(),
            onOptionChanged = onOptionChanged,
        })
    end)
end

function App.Start()
    if rsprite == nil or prettyui == nil then
        Client.Warn("dependencies", "the finder needs both rsprite and PrettyUI enabled")
    end
    subscribed = Client.Subscribe("SettingsLayerReady", SETTINGS_KEY, onSettingsLayerReady)
end

function App.Shutdown()
    if subscribed then
        Client.Unsubscribe("SettingsLayerReady", SETTINGS_KEY)
        subscribed = false
    end
    SettingsView.Destroy()
    FinderWindow.Destroy()
end

return App
