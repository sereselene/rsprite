selftest.UsePlugin("rsprite-finder")

local Report = require("tests/support/report")
local TextFit = require("src/utils/text_fit")

local check = Report.New("text fit")

local CHARACTER_WIDTH = 8
local PANEL_WIDTH = 232

local function measure(text)
    return #text * CHARACTER_WIDTH
end

local function allFit(lines)
    for _, line in ipairs(lines) do
        if measure(line) > PANEL_WIDTH then
            return false
        end
    end
    return true
end

local shortName = "LEFTARROW"
check.Same(
    "a short name stays on one line",
    TextFit.Wrap(shortName, PANEL_WIDTH, measure, 3),
    { shortName }
)

local necromancyIcon = "BP3_MISSION_ICON_SKILL_NECROMANCY"
local wrapped = TextFit.Wrap(necromancyIcon, PANEL_WIDTH, measure, 3)
check.Same(
    "a long name breaks after underscores",
    wrapped,
    { "BP3_MISSION_ICON_SKILL_", "NECROMANCY" }
)
check.Equal("the wrapped lines rebuild the full name", table.concat(wrapped), necromancyIcon)

local cutscene = "NECROMANCY_INTRO_CUTSCENE_SCENE_08_LAYOUT_0011_BG"
wrapped = TextFit.Wrap(cutscene, PANEL_WIDTH, measure, 3)
check.Check("a very long name fits the panel", allFit(wrapped), table.concat(wrapped, " | "))
check.Equal("a very long name keeps every character", table.concat(wrapped), cutscene)
check.Check("a very long name needs no more than three lines", #wrapped <= 3, #wrapped)

local unbroken = string.rep("X", 60)
wrapped = TextFit.Wrap(unbroken, PANEL_WIDTH, measure, 3)
check.Check(
    "a name with no underscores is split to fit",
    allFit(wrapped),
    table.concat(wrapped, " | ")
)
check.Equal("a split name keeps every character", table.concat(wrapped), unbroken)

local enormous = string.rep("WORD_", 30)
wrapped = TextFit.Wrap(enormous, PANEL_WIDTH, measure, 3)
check.Equal("an enormous name stops at three lines", #wrapped, 3)
check.Equal("the third line ends with an ellipsis", string.sub(wrapped[3], -3), "...")
check.Check("an enormous name still fits", allFit(wrapped), table.concat(wrapped, " | "))

check.Equal("Fit leaves short text alone", TextFit.Fit("Unknown", PANEL_WIDTH, measure), "Unknown")
check.Equal(
    "Fit trims long text with an ellipsis",
    TextFit.Fit(string.rep("A", 40), 80, measure),
    "AAAAAAA..."
)

check.Finish()
