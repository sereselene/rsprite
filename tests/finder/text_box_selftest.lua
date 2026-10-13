local ClientFakes = require("tests/support/client_fakes")
local FinderFakes = require("tests/support/finder_fakes")
local Report = require("tests/support/report")

local check = Report.New("text box")
local sprites = ClientFakes.DefaultSprites()
sprites[#sprites + 1] = { 36700, "RS3_ICON_CLEAR_16PX_0" }
sprites[#sprites + 1] = { 36701, "RS3_ICON_CLEAR_16PX_1" }
local client = FinderFakes.Install({ sprites = sprites })
local TextBox = require("src/components/text_box")
local Theme = require("src/utils/theme")

local parent = client.NewComponent("layer")
local changes = {}
local box = TextBox.New(
    parent,
    { x = 8, y = 8, width = 250, height = 28, placeholder = "Search sprites" },
    function(text)
        changes[#changes + 1] = text
    end
)
local field = box.component

check.Equal("it is built on the native input field", field.kind, "input field")
check.Equal("it keeps the input look", field.stylesheetID, id.StyleSheet.INPUT_DEFAULT)
check.Equal("text uses the small font", field.text.font, id.Font.MUSEO_SANS_11PT_REGULAR)
check.Equal("text uses the field text colour", field.text.rgba, Theme.FIELD_TEXT)
check.Equal("the placeholder is shown", field.emptyText, "Search sprites")
check.Equal("the placeholder is dimmed", field.emptyTextRGBA, Theme.FIELD_PLACEHOLDER)
check.Equal("the caret is white", field.caretRGBA, Theme.FIELD_CARET)
check.Equal(
    "selected text uses the selected colour",
    field.selectionHighlightRGBA,
    Theme.FIELD_SELECTED
)
check.Equal("the background is the finder's own", field.containerSprite.sprite, client.textField)
check.Equal("the text is inset", field.contentMargin.left, Theme.FIELD_MARGIN)

box.SetText("skill")
check.Equal("set text is shown", box.GetText(), "skill")
FinderFakes.Type(client, box, "magic")
check.Same("typing reports the new text", changes, { "magic" })

local plain = TextBox.New(parent, { x = 0, y = 0, width = 232, height = 26 }, function() end)
check.Equal("a box without a placeholder shows none", plain.component.emptyText, "")
check.Equal("a box without a clear button has none", plain.clearButton, nil)
check.Equal(
    "a box without a clear button keeps the usual right inset",
    plain.component.contentMargin.right,
    8
)

local cleared = 0
local clearable = TextBox.New(
    parent,
    { x = 10, y = 20, width = 180, height = 28, clearTooltip = "Clear search" },
    function() end,
    function()
        cleared = cleared + 1
    end
)
local cross = clearable.clearButton
check.Equal(
    "a clearable box leaves room for its cross",
    clearable.component.contentMargin.right,
    8 + 16 + 4
)
check.Equal("the cross starts hidden", cross.visible, false)
clearable.SetText("abc")
check.Equal("setting text shows the cross", cross.visible, true)
check.Equal("the shown cross can be seen", cross.root.hidden, false)
clearable.SetText("")
check.Equal("emptying the text hides the cross", cross.visible, false)
FinderFakes.Type(client, clearable, "typed")
check.Equal("typing shows the cross", cross.visible, true)
check.Equal("the cross takes clicks", cross.root.clickthrough, false)
check.Equal("the cross shows the button cursor", cross.root.cursorConfig.mouseOverCursor, 99)
check.Equal("the cross rests on its plain frame", cross.image.spriteID, 36700)
client.Fire(cross.root, "ONMOUSEOVER", 0, 0)
check.Equal("hovering the cross lights it", cross.image.spriteID, 36701)
client.Fire(cross.root, "ONMOUSELEAVE", 0, 0)
check.Equal("leaving the cross dims it again", cross.image.spriteID, 36700)
client.Fire(cross.root, "ONMOUSEOVER", 0, 0)
client.Click(cross.root)
check.Equal("clicking the cross empties the box", clearable.component.content, "")
check.Equal("clicking the cross reports it once", cleared, 1)
check.Equal("clicking the cross hides it", cross.visible, false)
check.Equal("a hidden cross does not stay lit", cross.image.spriteID, 36700)
client.Click(cross.root)
check.Equal("a hidden cross ignores clicks", cleared, 1)

local brokenBox = TextBox.New(parent, { x = 8, y = 8, width = 250, height = 28 }, function()
    error("the typing handler broke")
end)
FinderFakes.Type(client, brokenBox, "a")
FinderFakes.Type(client, brokenBox, "ab")
check.Equal(
    "a raising typing handler warns once in plain words",
    client.WarningsMentioning("rsprite-finder: handling typing failed"),
    1
)

check.Finish()
