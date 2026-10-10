local FinderFakes = require("tests/support/finder_fakes")
local Report = require("tests/support/report")

local check = Report.New("size buttons")
local client = FinderFakes.Install({
    sprites = {
        { 9, "RS3_BTN_ICON_RESIZABLE_9" },
        { 13, "RS3_BTN_ICON_RESIZABLE_13" },
        { 18, "RS3_BTN_ICON_RESIZABLE_18" },
        { 22, "RS3_BTN_ICON_RESIZABLE_22" },
        { 27, "RS3_BTN_ICON_RESIZABLE_27" },
        { 31, "RS3_BTN_ICON_RESIZABLE_31" },
    },
})
local SizeButtons = require("src/components/size_buttons")

local parent = client.NewComponent("layer")
local chosen = {}
local group
group = SizeButtons.New(
    parent,
    { x = 0, y = 0, buttonWidth = 44, gap = 3, height = 24 },
    { 16, 24, 32, 48, 64 },
    function(size)
        chosen[#chosen + 1] = size
        group.Light(size)
    end
)

check.Equal("five buttons are built", #group.buttons, 5)
local labels = {}
local fonts = {}
for position, button in ipairs(group.buttons) do
    labels[position] = button.label.content
    fonts[position] = tostring(button.label.font == id.Font.MUSEO_SANS_11PT_REGULAR)
end
check.Same("labels are just the numbers", labels, { "16", "24", "32", "48", "64" })
check.Same("labels use the small font", fonts, { "true", "true", "true", "true", "true" })
local first = group.buttons[1]
check.Equal("labels are centred across", first.label.alignHorizontal, ui.AlignMode.CENTRE)
check.Equal("labels are centred down", first.label.alignVertical, ui.AlignMode.CENTRE)
check.Equal(
    "labels are white like the rest of PrettyUI's buttons",
    first.label.rgba,
    SizeButtons.TEXT_COLOUR
)
check.Equal("buttons sit 47 pixels apart", group.buttons[2].root.x - first.root.x, 47)
check.Equal(
    "the last button ends at the panel edge",
    group.buttons[5].root.x + group.buttons[5].root.width,
    232
)

check.Equal("buttons take clicks", first.root.clickthrough, false)
check.Equal("hovering shows the blank cursor", first.root.cursorConfig.mouseOverCursor, 99)
check.Equal("the click op uses the same cursor", first.root.opCursors[0], 99)

check.Equal("every piece is drawn", #SizeButtons.PIECES, 9)
check.Equal("corners do not tile", first.parts.topLeft.isTiling, false)
check.Equal("the centre tiles", first.parts.centre.isTiling, true)
check.Equal("an unlit button uses the resting frame", first.parts.topLeft.spriteID, 18)
check.Equal("the resting centre is drawn", first.parts.centre.spriteID, 22)
check.Equal("a missing frame sprite is left blank", first.parts.top.spriteID, -1)

client.Fire(first.root, "ONMOUSEOVER", 0, 0)
check.Equal("hovering uses the hover frame", first.parts.topLeft.spriteID, 9)
client.Fire(first.root, "ONMOUSELEAVE", 0, 0)
check.Equal("leaving returns to the resting frame", first.parts.topLeft.spriteID, 18)

group.Light(48)
check.Same("lighting a size lights only that one", group.LitSizes(), { 48 })
check.Equal("the lit button uses the active frame", group.buttons[4].parts.topLeft.spriteID, 27)
check.Equal("the lit centre is drawn", group.buttons[4].parts.centre.spriteID, 31)
client.Fire(group.buttons[4].root, "ONMOUSEOVER", 0, 0)
check.Equal("hovering a lit button keeps it lit", group.buttons[4].parts.topLeft.spriteID, 27)

client.Click(group.buttons[5].root)
check.Same("clicking a size reports it", chosen, { 64 })
check.Same("clicking a size moves the light", group.LitSizes(), { 64 })
client.Click(group.buttons[5].root)
check.Same("clicking the lit size keeps exactly one lit", group.LitSizes(), { 64 })
check.Equal(
    "the old size still under the mouse shows the hover frame",
    group.buttons[4].parts.topLeft.spriteID,
    9
)
client.Fire(group.buttons[4].root, "ONMOUSELEAVE", 0, 0)
check.Equal(
    "the old size goes back to its resting frame once the mouse leaves",
    group.buttons[4].parts.topLeft.spriteID,
    18
)

check.Equal(
    "SpriteName follows the frame numbering",
    SizeButtons.SpriteName("neutral", "bottomRight"),
    "RS3_BTN_ICON_RESIZABLE_26"
)
check.Equal(
    "hover frames start at 9",
    SizeButtons.SpriteName("hovered", "topLeft"),
    "RS3_BTN_ICON_RESIZABLE_9"
)
check.Equal(
    "active frames start at 27",
    SizeButtons.SpriteName("active", "topLeft"),
    "RS3_BTN_ICON_RESIZABLE_27"
)

check.Finish()
