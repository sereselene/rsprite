selftest.UsePlugin("rsprite-finder")

local FinderFakes = require("tests/support/finder_fakes")
local Report = require("tests/support/report")

local check = Report.New("drop down")
local client = FinderFakes.Install()
local DropDown = require("src/components/drop_down")
local Theme = require("src/utils/theme")

local parent = client.NewComponent("layer")
local chosen = {}
local entries = {
    { label = "All tags", id = 1 },
    { label = "icon", id = 2 },
    { label = "skill", id = 3 },
}
local dropDown = DropDown.New(
    parent,
    { x = 266, y = 8, width = 140, height = 28 },
    entries,
    3,
    function(entryId)
        chosen[#chosen + 1] = entryId
    end
)
local combo = dropDown.component

check.Equal("it is built on the native combo field", combo.kind, "combo field")
check.Equal("it keeps the combo look", combo.stylesheetID, id.StyleSheet.COMBO_DEFAULT)
check.Equal("it sits where asked", combo.x, 266)
check.Equal("it is as tall as asked", combo.height, 28)
check.Equal("entries use the small font", combo.entryText.font, id.Font.MUSEO_SANS_11PT_REGULAR)
check.Equal("entries use the field text colour", combo.entryText.rgba, Theme.FIELD_TEXT)
check.Equal("entries are shadowed", combo.entryText.isShadowed, true)
check.Equal("entries are short to suit the small font", combo.entryHeight, DropDown.ENTRY_HEIGHT)
check.Equal("the list shows ten entries at a time", combo.dropdownMaxVisibleEntries, 10)
check.Equal(
    "hovered entries use the hover colour",
    combo.mouseoverBackgroundRGBA,
    Theme.FIELD_HOVER
)
check.Equal("hovered text keeps its colour", combo.mouseoverForegroundRGBA, Theme.FIELD_TEXT)
check.Equal(
    "the chosen entry uses the selected colour",
    combo.selectedBackgroundRGBA,
    Theme.FIELD_SELECTED
)
check.Equal("disabled entries are dimmed", combo.disabledForegroundRGBA, Theme.FIELD_DISABLED)
check.Equal("the caret is white", combo.caretRGBA, Theme.FIELD_CARET)
check.Equal("the content is inset", combo.contentMargin.left, Theme.FIELD_MARGIN)
check.Equal("the header is inset", combo.headerMargin.left, Theme.FIELD_MARGIN)

check.Same(
    "labels map to their ids",
    combo.entryIdsByLabel,
    { ["All tags"] = 1, icon = 2, skill = 3 }
)
check.Equal("the starting entry is selected", dropDown.SelectedId(), 3)

dropDown.Select(1)
check.Equal("selecting moves the selection", dropDown.SelectedId(), 1)
check.Same("selecting from code does not report a choice", chosen, {})

FinderFakes.Choose(client, dropDown, "icon")
check.Same("choosing an entry reports its id", chosen, { 2 })
check.Equal("the choice stays selected", dropDown.SelectedId(), 2)

client.raiseOnSetEntries = true
DropDown.New(parent, { x = 0, y = 0, width = 140, height = 28 }, entries, 1, function() end)
DropDown.New(parent, { x = 0, y = 0, width = 140, height = 28 }, entries, 1, function() end)
check.Equal(
    "a failure filling the entries warns once in plain words",
    client.WarningsMentioning("rsprite-finder: filling a dropdown failed"),
    1
)
client.raiseOnSetEntries = false

local brokenDropDown = DropDown.New(
    parent,
    { x = 0, y = 0, width = 140, height = 28 },
    entries,
    1,
    function()
        error("the choice handler broke")
    end
)
FinderFakes.Choose(client, brokenDropDown, "icon")
FinderFakes.Choose(client, brokenDropDown, "skill")
check.Equal(
    "a raising choice handler warns once in plain words",
    client.WarningsMentioning("rsprite-finder: handling a dropdown choice failed"),
    1
)

check.Finish()
