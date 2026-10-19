selftest.UsePlugin("rsprite-finder")

local FinderFakes = require("tests/support/finder_fakes")
local Report = require("tests/support/report")

local check = Report.New("settings view")
local client, prettyuiFake = FinderFakes.Install()
local App = require("src/app/init")
local SettingsView = require("src/features/settings/settings_view")

App.Start()
check.Check(
    "the cog is listened for",
    client.handlers.SettingsLayerReady["rsprite-finder:settings"] ~= nil,
    "subscribed"
)

client.FireEvent("SettingsLayerReady", { component = FinderFakes.SettingsDialog(client) })
local firstView = prettyuiFake.views[1]
check.Check(
    "the first opening builds a view",
    firstView ~= nil and not firstView.destroyed,
    #prettyuiFake.views
)
check.Equal("the view fills the dialog width", firstView.options.width, 556)
check.Equal("the view fills the dialog height", firstView.options.height, 300)
check.Equal(
    "the line of text is shown",
    prettyuiFake.Logged("SimpleView.AddText " .. SettingsView.MESSAGE),
    1
)
check.Equal(
    "the open button is positive",
    prettyuiFake.Logged("FancyButton.new OPEN FINDER positive"),
    1
)
check.Equal(
    "the cog offers to show hidden sprites again",
    prettyuiFake.Logged("FancyButton.new " .. SettingsView.SHOW_HIDDEN_LABEL .. " neutral"),
    1
)

prettyuiFake.log = {}
client.FireEvent("SettingsLayerReady", { component = FinderFakes.SettingsDialog(client) })
check.Same(
    "a second opening destroys the previous view before building a new one",
    { prettyuiFake.log[1], prettyuiFake.log[2] },
    {
        "SimpleView.Destroy",
        "SimpleView.new 556 300",
    }
)
check.Equal("the first view is destroyed", firstView.destroyed, true)
local secondView = prettyuiFake.views[2]
check.Equal("the second view is live", secondView.destroyed, false)

local openButton = prettyuiFake.Find("fancyButtons", function(button)
    return button.text == SettingsView.BUTTON_LABEL and button.parent == secondView.content
end)
openButton:Click()
check.Equal(
    "the open button opens the finder window",
    prettyuiFake.Logged("Window.new rsprite finder"),
    1
)
check.Equal("opening the finder closes nothing else", secondView.destroyed, false)

App.Shutdown()
check.Equal(
    "shutdown stops listening for the cog",
    client.handlers.SettingsLayerReady["rsprite-finder:settings"],
    nil
)
check.Equal("shutdown destroys the view", secondView.destroyed, true)
check.Equal("shutdown destroys the finder window", prettyuiFake.windows[1].destroyed, true)
check.Equal(
    "shutdown leaves no finder listener on Logic",
    client.subscriptions["rsprite-finder:search"],
    nil
)

check.Finish()
