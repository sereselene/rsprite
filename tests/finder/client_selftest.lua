local ClientFakes = require("tests/support/client_fakes")
local Report = require("tests/support/report")

local check = Report.New("finder client")
local client = ClientFakes.Install()
local Client = require("src/services/client")

local smallFont = id.Font.MUSEO_SANS_11PT_REGULAR
local boldFont = id.Font.MUSEO_SANS_13PT_BOLD
check.Equal("text is measured", Client.TextWidth(smallFont, "ABCD"), 24)
Client.TextWidth(smallFont, "ABCDEFGH")
Client.TextWidth(smallFont, "A")
check.Equal("repeated measurements look the font up once", client.fontLookups, 1)
Client.TextWidth(boldFont, "ABCD")
Client.TextWidth(boldFont, "AB")
check.Equal("each font is looked up once", client.fontLookups, 2)

local parent = client.NewComponent("layer")
local text = Client.NewText(parent, { text = "Centred", centred = true, centredVertically = true })
check.Equal("text can be centred across", text.alignHorizontal, ui.AlignMode.CENTRE)
check.Equal("text can be centred down", text.alignVertical, ui.AlignMode.CENTRE)
local plain = Client.NewText(parent, { text = "Plain" })
check.Equal("text is not centred down unless asked", plain.alignVertical, nil)

local clicks = 0
local button = client.NewComponent("rectangle")
check.Equal(
    "listening for clicks reports success",
    Client.OnClick(button, "rsprite-finder:test", function()
        clicks = clicks + 1
    end),
    true
)
client.Click(button)
check.Equal("a click runs the callback", clicks, 1)
Client.OnClick(button, "rsprite-finder:raises", function()
    error("the click handler broke")
end)
client.Click(button)
check.Equal(
    "a raising click handler warns once",
    client.WarningsMentioning("rsprite-finder: handling a click failed"),
    1
)
check.Equal(
    "a nil component cannot be listened to",
    Client.OnClick(nil, "key", function() end),
    false
)

client.raiseOnSubscribe = true
local unheard = client.NewComponent("rectangle")
check.Equal(
    "a click listener that cannot subscribe reports failure",
    Client.OnClick(unheard, "rsprite-finder:unheard", function() end),
    false
)
Client.OnClick(unheard, "rsprite-finder:unheard again", function() end)
check.Equal(
    "failing to listen for clicks warns once in plain words",
    client.WarningsMentioning("rsprite-finder: listening for clicks failed"),
    1
)
Client.OnHook(
    unheard,
    "ONMOUSELEAVE",
    "rsprite-finder:leave",
    Client.MOUSE_LEAVE_LABELS,
    function() end
)
check.Equal(
    "failing to listen for the mouse leaving warns in plain words",
    client.WarningsMentioning("rsprite-finder: listening for the mouse leaving failed"),
    1
)
client.raiseOnSubscribe = false

local hovered = client.NewComponent("rectangle")
Client.OnHook(hovered, "ONMOUSEOVER", "rsprite-finder:enter", Client.MOUSE_ENTER_LABELS, function()
    error("the hover handler broke")
end)
client.Fire(hovered, "ONMOUSEOVER")
client.Fire(hovered, "ONMOUSEOVER")
check.Equal(
    "a raising hover handler warns once in plain words",
    client.WarningsMentioning("rsprite-finder: handling the mouse entering failed"),
    1
)

local hookNames = {}
for hookName in pairs(ui.Hook) do
    hookNames[#hookNames + 1] = hookName
end
local namingHooks = 0
for _, warning in ipairs(client.warnings) do
    for _, hookName in ipairs(hookNames) do
        if string.find(warning, hookName, 1, true) then
            namingHooks = namingHooks + 1
        end
    end
end
check.Equal("no warning names a client hook", namingHooks, 0)

check.Finish()
