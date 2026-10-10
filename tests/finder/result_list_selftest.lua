local Report = require("tests/support/report")
local ResultList = require("src/features/finder/result_list")

local check = Report.New("result list")

local function entriesFrom(names)
    local entries = {}
    for position, name in ipairs(names) do
        entries[position] = { name = name, id = position }
    end
    return entries
end

local function namesOf(tiles)
    local names = {}
    for position, tile in ipairs(tiles) do
        names[position] = tile.label
    end
    return names
end

local GROUPED = { groupVariants = true }
local HIDDEN = { hideClutter = true }

check.Same(
    "a trailing number marks a family",
    { ResultList.FamilyOf("EMOTES_102") },
    { "EMOTES", 102 }
)
check.Same(
    "only the last number counts",
    { ResultList.FamilyOf("AIF_FLAG_PACK_2_7") },
    { "AIF_FLAG_PACK_2", 7 }
)
check.Same(
    "a name without a trailing number is not in a family",
    { ResultList.FamilyOf("SKILL_ATTACK") },
    {}
)
check.Same("digits must follow an underscore", { ResultList.FamilyOf("ICON32") }, {})
check.Same("pixel sizes are not numbers", { ResultList.FamilyOf("ICON_32PX") }, {})

local clutter = {}
for _, name in ipairs({
    "BANNER_FR",
    "BANNER_DE",
    "BANNER_PT",
    "BANNER_ES",
    "BANNER_EN",
    "BANNER",
    "RS3_BTN_ACCORDION_MOBILE_0",
    "ESCAPE_MENU_MOBILE_BANNER",
    "AUTOMOBILE",
    "FRIENDS_FRAME",
    "AIF_MEMBER_MAY_OFFER_LRG_PT_0",
    "OFFER_ES_12",
    "OFFER_EN_3",
    "OFFER_FR_X",
}) do
    clutter[#clutter + 1] = tostring(ResultList.IsClutter(name))
end
check.Same(
    "language copies and mobile sprites are clutter, English and plain names are not",
    clutter,
    {
        "true",
        "true",
        "true",
        "true",
        "false",
        "false",
        "true",
        "true",
        "false",
        "false",
        "true",
        "true",
        "false",
        "false",
    }
)

local names = {
    "SKILL_ATTACK",
    "FRAME_10",
    "FRAME_2",
    "LONELY_4",
    "FRAME_1",
    "PANEL_07",
    "PANEL_01",
    "BANNER_MOBILE_1",
    "BANNER_MOBILE_2",
    "BANNER_1",
}
local plain = ResultList.Build(entriesFrom(names), {})
check.Equal("with both options off every sprite has a tile", #plain.tiles, 10)
check.Equal("with both options off nothing has variants", plain.tiles[2].family, nil)

local grouped = ResultList.Build(entriesFrom(names), GROUPED)
check.Same("families take the place of their best ranked member", namesOf(grouped.tiles), {
    "SKILL_ATTACK",
    "FRAME (3 variants)",
    "LONELY_4",
    "PANEL (2 variants)",
    "BANNER_MOBILE (2 variants)",
    "BANNER_1",
})
local frame = grouped.tiles[2]
check.Equal("a family tile shows its lowest numbered member", frame.name, "FRAME_1")
check.Same(
    "variants run in numeric order",
    { frame.members[1].name, frame.members[2].name, frame.members[3].name },
    { "FRAME_1", "FRAME_2", "FRAME_10" }
)
check.Equal("leading zeros sort by number", grouped.tiles[4].name, "PANEL_01")
check.Same("every variant can be found", { ResultList.Locate(grouped, "FRAME_10") }, { 2, 3 })
check.Same(
    "a single sprite is found as its own tile",
    { ResultList.Locate(grouped, "LONELY_4") },
    { 3, 1 }
)
check.Same("a missing name is not found", { ResultList.Locate(grouped, "NOPE") }, {})
check.Same("no name is not found", { ResultList.Locate(grouped, nil) }, {})

local hidden = ResultList.Build(entriesFrom(names), HIDDEN)
check.Equal("hiding leaves out the mobile copies", #hidden.tiles, 8)
check.Equal("hidden sprites cannot be found", ResultList.Locate(hidden, "BANNER_MOBILE_1"), nil)

local both = ResultList.Build(
    entriesFrom({ "MAP_1", "MAP_MOBILE_1", "MAP_2", "MAP_MOBILE_2", "TITLE_FR", "TITLE_EN" }),
    { groupVariants = true, hideClutter = true }
)
check.Same(
    "with both options on, hidden copies never form a family",
    namesOf(both.tiles),
    { "MAP (2 variants)", "TITLE_EN" }
)

local favourites =
    ResultList.Build(entriesFrom({ "FRAME_1", "FRAME_2", "BANNER_FR", "SKILL_ATTACK" }), {
        groupVariants = true,
        hideClutter = true,
        favourites = { "BANNER_FR", "GONE_SPRITE", "FRAME_2", "SKILL_ATTACK" },
    })
check.Same(
    "favourites come in starred order, ungrouped and unhidden, skipping missing names",
    namesOf(favourites.tiles),
    { "BANNER_FR", "FRAME_2", "SKILL_ATTACK" }
)
check.Equal("favourites are single tiles", favourites.tiles[2].family, nil)
check.Same("a favourite can be found", { ResultList.Locate(favourites, "FRAME_2") }, { 2, 1 })
check.Equal(
    "a favourite missing from the results is not found",
    ResultList.Locate(favourites, "GONE_SPRITE"),
    nil
)
check.Equal(
    "a sprite outside the favourites is left out",
    ResultList.Locate(favourites, "FRAME_1"),
    nil
)

check.Equal("no entries make no tiles", #ResultList.Build(nil, GROUPED).tiles, 0)

check.Finish()
