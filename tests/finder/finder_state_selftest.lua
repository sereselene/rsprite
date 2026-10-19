selftest.UsePlugin("rsprite-finder")

local Report = require("tests/support/report")
local FinderState = require("src/features/finder/finder_state")

local check = Report.New("finder state")

local function namesFrom(count)
    local names = {}
    for position = 1, count do
        names[position] = "NAME_" .. position
    end
    return names
end

local function fakeSearch(names)
    local calls = { count = 0 }
    local search = function(query, tag)
        calls.count = calls.count + 1
        local matches = {}
        for position, name in ipairs(names) do
            local queryMatches = query == ""
                or string.find(name, string.upper(query), 1, true) ~= nil
            local tagMatches = tag == nil or (tag == "even" and position % 2 == 0)
            if queryMatches and tagMatches then
                matches[#matches + 1] = { name = name, id = position }
            end
        end
        return matches
    end
    return search, calls
end

local NO_OPTIONS = {}
local SEARCH_CHANGED = FinderState.SEARCH_CHANGED

check.Equal("a page holds 30 sprites", FinderState.PAGE_SIZE, 30)

local search = fakeSearch(namesFrom(70))
local state = FinderState.New()
FinderState.Refresh(state, search, NO_OPTIONS)
check.Equal("70 results make 3 pages", FinderState.PageCount(state), 3)
check.Equal("the first page is full", #state.tiles, 30)
check.Equal("the page label reads naturally", FinderState.PageLabel(state), "Page 1 of 3")

FinderState.SetPage(state, 2)
FinderState.Refresh(state, search, NO_OPTIONS)
check.Equal("the second page starts at the 31st result", state.tiles[1].name, "NAME_31")

FinderState.SetPage(state, 3)
FinderState.Refresh(state, search, NO_OPTIONS)
check.Equal("the last page holds the remainder", #state.tiles, 10)
check.Equal("the last page starts at the 61st result", state.tiles[1].name, "NAME_61")

local exactPages = FinderState.New()
FinderState.Refresh(exactPages, fakeSearch(namesFrom(60)), NO_OPTIONS)
check.Equal("60 results make exactly 2 pages", FinderState.PageCount(exactPages), 2)

FinderState.SetPage(state, 99)
check.Equal("paging past the end clamps to the last page", state.page, 3)
FinderState.SetPage(state, 0)
check.Equal("paging before the start clamps to the first page", state.page, 1)

state = FinderState.New()
check.Equal("no results still count as one page", FinderState.PageCount(state), 1)

local shrinking = FinderState.New({ version = FinderState.SAVED_VERSION, page = 9 })
FinderState.Refresh(shrinking, fakeSearch(namesFrom(70)), NO_OPTIONS)
check.Equal("a saved page beyond the results clamps to the last page", shrinking.page, 3)
check.Equal("the clamped page shows the last results", shrinking.tiles[1].name, "NAME_61")

local oldSave = FinderState.New({ version = FinderState.SAVED_VERSION, page = 5 })
FinderState.Refresh(oldSave, fakeSearch(namesFrom(100)), NO_OPTIONS)
check.Equal("a page saved under the old 18 per page clamps to the new last page", oldSave.page, 4)
check.Equal("the clamped old page shows the last partial page", #oldSave.tiles, 10)

state = FinderState.New()
state.page = 3
check.Equal("a new query reports a change", FinderState.SetQuery(state, "name_1"), true)
check.Equal("a new query resets to page 1", state.page, 1)
state.page = 2
check.Equal("the same query reports no change", FinderState.SetQuery(state, "name_1"), false)
check.Equal("the same query keeps the page", state.page, 2)
check.Equal("a new tag reports a change", FinderState.SetTag(state, "even"), true)
check.Equal("a new tag resets to page 1", state.page, 1)
check.Equal("an empty tag means all tags", FinderState.SetTag(state, "") and state.tag, nil)

state = FinderState.New()
FinderState.Refresh(state, search, NO_OPTIONS)
check.Equal("the first result is selected to begin with", state.selectedName, "NAME_1")
FinderState.Select(state, state.tiles[2])
FinderState.SetPage(state, 2)
FinderState.Refresh(state, search, NO_OPTIONS)
check.Equal("selection survives paging", state.selectedName, "NAME_2")
check.Equal(
    "the selected entry survives paging",
    state.selectedEntry and state.selectedEntry.name,
    "NAME_2"
)
check.Equal("the selected sprite is not on this page", FinderState.SelectedPosition(state), nil)

FinderState.SetPage(state, 1)
FinderState.Refresh(state, search, NO_OPTIONS)
check.Equal(
    "the selected sprite is found again on its page",
    FinderState.SelectedPosition(state),
    2
)

FinderState.SetQuery(state, "name_2")
FinderState.Refresh(state, search, NO_OPTIONS, SEARCH_CHANGED)
check.Equal("a selection still in the results is kept", state.selectedName, "NAME_2")

FinderState.SetQuery(state, "name_3")
FinderState.Refresh(state, search, NO_OPTIONS, SEARCH_CHANGED)
check.Equal(
    "a selection that leaves the results falls back to the first result",
    state.selectedName,
    "NAME_3"
)

FinderState.SetQuery(state, "nothing at all")
FinderState.Refresh(state, search, NO_OPTIONS, SEARCH_CHANGED)
check.Equal("no results clear the selection", state.selectedEntry, nil)

local restored =
    FinderState.New({ version = FinderState.SAVED_VERSION, selectedName = "NAME_30", page = 1 })
FinderState.Refresh(restored, search, NO_OPTIONS)
check.Equal(
    "a saved selection is looked up again",
    restored.selectedEntry and restored.selectedEntry.name,
    "NAME_30"
)
local vanished = FinderState.New({ version = FinderState.SAVED_VERSION, selectedName = "NAME_99" })
FinderState.Refresh(vanished, search, NO_OPTIONS)
check.Equal(
    "a saved selection that no longer exists falls back to the first result",
    vanished.selectedName,
    "NAME_1"
)

state = FinderState.New()
check.Equal("the default preview size is 48", state.previewSize, 48)
for _, size in ipairs({ 16, 24, 32, 48, 64 }) do
    check.Equal(
        "preview size " .. size .. " is accepted",
        FinderState.SetPreviewSize(state, size) and state.previewSize,
        size
    )
end
local accepted = {}
for _, size in ipairs({ 20, 96, 0 }) do
    accepted[#accepted + 1] = tostring(FinderState.SetPreviewSize(state, size))
end
accepted[#accepted + 1] = tostring(FinderState.SetPreviewSize(state, "16"))
accepted[#accepted + 1] = tostring(FinderState.SetPreviewSize(state, nil))
check.Same(
    "other preview sizes are refused",
    accepted,
    { "false", "false", "false", "false", "false" }
)
check.Equal("a refused size leaves the last good one", state.previewSize, 64)
check.Equal(
    "a saved preview size that is not allowed falls back",
    FinderState.New({ previewSize = 99 }).previewSize,
    48
)
check.Equal(
    "a saved size of 20 falls back to 48",
    FinderState.New({ previewSize = 20 }).previewSize,
    48
)
check.Equal("a saved size of 64 is restored", FinderState.New({ previewSize = 64 }).previewSize, 64)

check.Equal(
    "the copy text is exactly the Get line",
    FinderState.GetText("SKILL_ATTACK"),
    'rsprite.Get("SKILL_ATTACK")'
)
check.Equal(
    "the draw text is exactly the Draw line at the given size",
    FinderState.DrawText("SKILL_ATTACK", 24),
    'rsprite.Draw(parent, "SKILL_ATTACK", { size = 24 })'
)

state = FinderState.New()
state.total = 36493
check.Equal(
    "an empty query with all tags shows the total",
    FinderState.ResultsLabel(state),
    "36,493 sprites"
)
state.total = 1
check.Equal("a single sprite reads naturally", FinderState.ResultsLabel(state), "1 sprite")
state.total = 36493
check.Equal("page counts use a thousands comma", FinderState.PageLabel(state), "Page 1 of 1,217")
check.Equal("small counts have no comma", FinderState.FormatCount(999), "999")
check.Equal("millions get two commas", FinderState.FormatCount(1234567), "1,234,567")
state.query = "x"
state.total = 1
check.Equal("one result reads as one match", FinderState.ResultsLabel(state), "1 match")
state.total = 293
check.Equal("many results read as a count", FinderState.ResultsLabel(state), "293 matches")
state.total = 2201
check.Equal("large match counts use a comma", FinderState.ResultsLabel(state), "2,201 matches")
state.total = 293
state.query = ""
state.tag = "icon"
check.Equal("a tag on its own still shows a count", FinderState.ResultsLabel(state), "293 matches")

local saved = FinderState.Snapshot({
    query = "arrow",
    tag = "icon",
    page = 4,
    previewSize = 24,
    selectedName = "LEFTARROW",
})
local reloaded = FinderState.New(saved)
check.Same(
    "a snapshot loads back the same way",
    { reloaded.query, reloaded.tag, reloaded.page, reloaded.previewSize, reloaded.selectedName },
    { "arrow", "icon", 4, 24, "LEFTARROW" }
)

local backgrounds = FinderState.New()
check.Equal("the preview starts on the dark background", backgrounds.previewBackground, "dark")
local cycled = {}
for _ = 1, 4 do
    cycled[#cycled + 1] = FinderState.CycleBackground(backgrounds)
end
check.Same(
    "the background cycles light, checker, dark and round again",
    cycled,
    { "light", "checker", "dark", "light" }
)
check.Equal(
    "the background is part of the snapshot",
    FinderState.New(FinderState.Snapshot(backgrounds)).previewBackground,
    "light"
)
check.Equal(
    "an unknown saved background falls back to dark",
    FinderState.New({ previewBackground = "purple" }).previewBackground,
    "dark"
)
check.Equal(
    "the PrettyUI text is exactly the AddSprite line at the given size",
    FinderState.PrettyText("SKILL_ATTACK", 32),
    'window:AddSprite(rsprite.Get("SKILL_ATTACK"), { size = 32 })'
)
local favouriteLabels = FinderState.New()
favouriteLabels.total = 4
check.Equal(
    "favourites are counted as favourites",
    FinderState.ResultsLabel(favouriteLabels, true),
    "4 favourites"
)
favouriteLabels.total = 1
check.Equal(
    "one favourite reads naturally",
    FinderState.ResultsLabel(favouriteLabels, true),
    "1 favourite"
)
favouriteLabels.query = "x"
favouriteLabels.total = 1200
check.Equal(
    "a search within favourites still counts favourites",
    FinderState.ResultsLabel(favouriteLabels, true),
    "1,200 favourites"
)

local counted, searchCalls = fakeSearch(namesFrom(70))
local cached = FinderState.New()
FinderState.Refresh(cached, counted, NO_OPTIONS)
FinderState.SetPage(cached, 2)
FinderState.Refresh(cached, counted, NO_OPTIONS)
FinderState.SetPage(cached, 3)
FinderState.Refresh(cached, counted, NO_OPTIONS)
FinderState.Select(cached, cached.tiles[4])
FinderState.Refresh(cached, counted, NO_OPTIONS)
check.Equal("paging and selecting search only once", searchCalls.count, 1)
check.Equal("paging still shows the right results", cached.tiles[1].name, "NAME_61")
FinderState.SetQuery(cached, "name_6")
FinderState.Refresh(cached, counted, NO_OPTIONS, SEARCH_CHANGED)
check.Equal("a new query searches again", searchCalls.count, 2)
FinderState.SetTag(cached, "even")
FinderState.Refresh(cached, counted, NO_OPTIONS, SEARCH_CHANGED)
check.Equal("a new tag searches again", searchCalls.count, 3)
local totalBeforeOption = cached.total
FinderState.Invalidate(cached)
FinderState.Refresh(cached, counted, { groupVariants = true }, FinderState.OPTIONS_CHANGED)
check.Equal("a changed option reuses the search", searchCalls.count, 3)
check.Equal("a changed option still rebuilds the tiles", cached.total, 1)
check.Check(
    "a changed option changes the count",
    cached.total ~= totalBeforeOption,
    totalBeforeOption
)
FinderState.Invalidate(cached)
FinderState.Refresh(cached, counted, { favourites = { "NAME_6" } }, FinderState.OPTIONS_CHANGED)
check.Equal("favourites only reuses the search", searchCalls.count, 3)
check.Equal("favourites only shows the starred tile", cached.tiles[1].name, "NAME_6")
FinderState.SetQuery(cached, "name_1")
FinderState.Refresh(cached, counted, NO_OPTIONS, SEARCH_CHANGED)
check.Equal("a new query after an option change searches again", searchCalls.count, 4)

local GROUPED = { groupVariants = true, hideClutter = true }
local familyNames = {
    "SKILL_ATTACK",
    "EMOTES_10",
    "EMOTES_2",
    "BANNER_FR",
    "EMOTES_1",
    "BANNER_EN",
    "MENU_MOBILE_0",
}
for position = 1, 40 do
    familyNames[#familyNames + 1] = "SINGLE_" .. position .. "_SPRITE"
end
local familySearch = fakeSearch(familyNames)
local grouped = FinderState.New()
FinderState.Refresh(grouped, familySearch, GROUPED)
check.Equal(
    "a family takes one tile where its best member ranked",
    grouped.tiles[2].label,
    "EMOTES (3 variants)"
)
check.Equal("a family tile shows its lowest numbered member", grouped.tiles[2].name, "EMOTES_1")
check.Equal("hidden copies leave the count", grouped.total, 43)
check.Equal(
    "there is no variant stepper for a single sprite",
    FinderState.VariantStep(grouped),
    nil
)

FinderState.Select(grouped, grouped.tiles[2])
check.Same(
    "a family starts on its first variant",
    FinderState.VariantStep(grouped),
    { index = 1, count = 3 }
)
check.Equal("the first variant is the lowest number", grouped.selectedName, "EMOTES_1")
check.Equal(
    "stepping back from the first variant does nothing",
    FinderState.StepVariant(grouped, -1),
    false
)
FinderState.StepVariant(grouped, 1)
check.Equal("variants step in numeric order", grouped.selectedName, "EMOTES_2")
FinderState.StepVariant(grouped, 1)
check.Equal("10 comes after 2", grouped.selectedEntry.name, "EMOTES_10")
check.Equal(
    "stepping past the last variant does nothing",
    FinderState.StepVariant(grouped, 1),
    false
)
check.Equal(
    "the variant label reads naturally",
    FinderState.VariantLabel(FinderState.VariantStep(grouped)),
    "Variant 3 of 3"
)
check.Equal(
    "large variant counts use a comma",
    FinderState.VariantLabel({ index = 2, count = 1200 }),
    "Variant 2 of 1,200"
)

local restoredVariant = FinderState.New(FinderState.Snapshot(grouped))
FinderState.Refresh(restoredVariant, familySearch, GROUPED)
check.Equal("the exact variant is restored", restoredVariant.selectedName, "EMOTES_10")
check.Same(
    "the restored variant is stepped to",
    FinderState.VariantStep(restoredVariant),
    { index = 3, count = 3 }
)
check.Equal(
    "the restored family tile is highlighted",
    FinderState.SelectedPosition(restoredVariant),
    2
)

FinderState.Invalidate(grouped)
FinderState.Refresh(grouped, familySearch, NO_OPTIONS, FinderState.OPTIONS_CHANGED)
check.Equal("turning the options off shows every sprite", grouped.total, 47)
check.Equal("turning grouping off keeps the variant selected", grouped.selectedName, "EMOTES_10")
check.Equal("a variant on its own has no stepper", FinderState.VariantStep(grouped), nil)

local paged =
    FinderState.New({ version = FinderState.SAVED_VERSION, selectedName = "SINGLE_40_SPRITE" })
FinderState.Refresh(paged, familySearch, NO_OPTIONS)
check.Equal("a restored selection keeps the saved page", paged.page, 1)
FinderState.Invalidate(paged)
FinderState.Refresh(paged, familySearch, GROUPED, FinderState.OPTIONS_CHANGED)
check.Equal("an option change moves to the page holding the selection", paged.page, 2)
check.Equal(
    "the selection is kept through an option change",
    paged.selectedName,
    "SINGLE_40_SPRITE"
)

local lost = FinderState.New({ version = FinderState.SAVED_VERSION, selectedName = "BANNER_FR" })
FinderState.Refresh(lost, familySearch, NO_OPTIONS)
lost.page = 2
FinderState.Invalidate(lost)
FinderState.Refresh(lost, familySearch, GROUPED, FinderState.OPTIONS_CHANGED)
check.Equal("a hidden selection falls back to the first result", lost.selectedName, "SKILL_ATTACK")
check.Equal("the fallback goes back to the first page", lost.page, 1)

local stuckBefore = {
    query = "lantern",
    tag = "icon",
    page = 19,
    previewSize = 64,
    previewBackground = "checker",
    selectedName = "FLOORSHADOWS",
}
local recovered = FinderState.New(stuckBefore)
check.Equal("a state saved before versions starts on page 1", recovered.page, 1)
check.Equal("a state saved before versions restores no selection", recovered.selectedName, nil)
check.Same(
    "a state saved before versions keeps its search, tag and preview settings",
    { recovered.query, recovered.tag, recovered.previewSize, recovered.previewBackground },
    { "lantern", "icon", 64, "checker" }
)
local older =
    FinderState.New({ version = FinderState.SAVED_VERSION - 1, page = 19, selectedName = "NAME_1" })
check.Same(
    "an older version starts on page 1 with no selection",
    { older.page, older.selectedName },
    { 1, nil }
)
local current =
    FinderState.New({ version = FinderState.SAVED_VERSION, page = 19, selectedName = "NAME_1" })
check.Same(
    "the current version keeps its page and selection",
    { current.page, current.selectedName },
    { 19, "NAME_1" }
)
check.Equal(
    "a snapshot carries the version",
    FinderState.Snapshot(current).version,
    FinderState.SAVED_VERSION
)
local startingOver = FinderState.New({
    version = FinderState.SAVED_VERSION,
    query = "name",
    page = 3,
    selectedName = "NAME_1",
})
FinderState.StartOver(startingOver)
check.Same(
    "starting over goes to page 1 with no selection and keeps the search",
    { startingOver.page, startingOver.selectedName, startingOver.query },
    { 1, nil, "name" }
)

check.Finish()
