local Client = require("src/services/client")
local ProbeRunner = require("src/features/probe/probe_runner")
local ProbeStore = require("src/services/probe_store")
local SettingsPanel = require("src/features/settings/settings_panel")
local Stage = require("src/features/probe/stage")

local App = {}

local SETTINGS_KEY = "rsprite-sprite-probe:settings"
local SETTINGS_LABEL = "the settings cog"

local subscribed = false

local function reportLastSession()
    local step = ProbeStore.LoadStep()
    if step ~= nil then
        if step.mode == ProbeRunner.SWEEP then
            Client.Say(
                string.format(
                    "last session stopped at sweep page %s. Press Resume sweep to name the sprite.",
                    tostring(step.page)
                )
            )
            ProbeStore.SaveSweep({
                crashPage = step.page,
                namePage = step.page,
                namePosition = 1,
                fallbackDone = false,
                foundAny = false,
            })
        elseif step.mode == ProbeRunner.NAMING then
            Client.Say(
                string.format(
                    "last session stopped at sweep page %s tile %s id %s %s, now saved as a finding. Press Resume sweep to carry on.",
                    tostring(step.page),
                    tostring(step.tile),
                    tostring(step.id),
                    tostring(step.name)
                )
            )
            ProbeStore.AddFinding(step.id, step.name)
            local record = ProbeStore.LoadSweep() or { crashPage = step.page, fallbackDone = false }
            record.namePage = step.page
            record.namePosition = step.position or 1
            record.foundAny = true
            ProbeStore.SaveSweep(record)
        elseif step.mode == ProbeRunner.SPRITES then
            Client.Say(
                string.format(
                    "last session stopped at page %s tile %s id %s %s, with %s",
                    tostring(step.page),
                    tostring(step.tile),
                    tostring(step.id),
                    tostring(step.name),
                    tostring(step.options)
                )
            )
        else
            Client.Say(
                string.format(
                    "last session stopped at build up page %s, with %s",
                    tostring(step.page),
                    tostring(step.options)
                )
            )
        end
        ProbeStore.ClearStep()
    end
    local counter = ProbeStore.LoadCounter()
    if counter ~= nil then
        Client.Say("the saved counter from the last session reached " .. tostring(counter))
        ProbeStore.ClearCounter()
    end
end

local function onSettingsLayerReady(event)
    Client.Call("opening the probe settings", SettingsPanel.Mount, event and event.component)
end

function App.Start()
    if rsprite == nil then
        Client.Say("the probe needs rsprite enabled")
    end
    reportLastSession()
    subscribed =
        Client.Subscribe("SettingsLayerReady", SETTINGS_KEY, SETTINGS_LABEL, onSettingsLayerReady)
end

function App.Shutdown()
    ProbeRunner.Shutdown()
    if subscribed then
        Client.Unsubscribe("SettingsLayerReady", SETTINGS_KEY, SETTINGS_LABEL)
        subscribed = false
    end
    SettingsPanel.Destroy()
    Stage.Destroy()
end

return App
