selftest.UsePlugin("rsprite-finder")

local ClientFakes = require("tests/support/client_fakes")
local FinderFakes = require("tests/support/finder_fakes")
local Report = require("tests/support/report")

local check = Report.New("favourites")
local sprites = ClientFakes.DefaultSprites()
for position, name in ipairs({
    "ATTACKING_RETICULE_FRAME_2",
    "ATTACKING_RETICULE_FRAME_1",
    "ATTACKING_RETICULE_FRAME_3",
    "LOBBY_BANNER_FR",
    "LOBBY_BANNER_EN",
}) do
    sprites[#sprites + 1] = { 36699 + position, name }
end
local client, prettyuiFake = FinderFakes.Install({ sprites = sprites })
local Favourites = require("src/features/finder/favourites")
local FinderOptions = require("src/features/finder/finder_options")
local FinderWindow = require("src/features/finder/finder_window")
local ResultList = require("src/features/finder/result_list")

check.Same("names decode from one string", Favourites.Decode("A_1,B,C_2"), { "A_1", "B", "C_2" })
check.Same("an empty string has no names", Favourites.Decode(""), {})
check.Same("a missing value has no names", Favourites.Decode(nil), {})
check.Equal("names encode to one string", Favourites.Encode({ "A_1", "B" }), "A_1,B")
local list = Favourites.New()
check.Equal("starring adds a name", Favourites.Set(list, "FIRST", true), true)
Favourites.Set(list, "SECOND", true)
check.Same("the newest star comes first", list.names, { "SECOND", "FIRST" })
check.Equal("starring twice changes nothing", Favourites.Set(list, "FIRST", true), false)
check.Equal("a starred name is a favourite", Favourites.Contains(list, "FIRST"), true)
check.Equal("unstarring removes a name", Favourites.Set(list, "FIRST", false), true)
check.Equal("an unstarred name is not a favourite", Favourites.Contains(list, "FIRST"), false)
check.Equal("nothing selected cannot be starred", Favourites.Set(list, nil, true), false)

client.stored.rsprite_finder_favourites = { names = "GONE_SPRITE", only = false }
FinderWindow.Open()
FinderFakes.TicksUntil(client, function()
    return rsprite.IsIndexReady()
end, 40)
local finder, state = FinderWindow.Parts()
local detail = finder.detail

local function clearButton()
    return prettyuiFake.Find("fancyButtons", function(button)
        return button.text == FinderWindow.CLEAR_LABEL and not button.destroyed
    end)
end

local function select(name)
    local tilePosition = ResultList.Locate(state.results, name)
    local page = math.floor((tilePosition - 1) / 30) + 1
    while state.page < page do
        finder.nextButton:Click()
    end
    while state.page > page do
        finder.previousButton:Click()
    end
    client.Click(finder.grid.tiles[tilePosition - (page - 1) * 30].square)
end

local function shownNames()
    local names = {}
    for position, tile in ipairs(state.tiles) do
        names[position] = tile.name
    end
    return names
end

check.Equal("the favourites star starts off", finder.favouritesButton.disabled, true)
finder.favouritesButton:Click()
check.Equal("favourites only shows no favourites", finder.resultsText.content, "0 favourites")
check.Equal("an empty favourites list says so", finder.emptyTitle.content, "No favourites yet")
check.Equal(
    "an empty favourites list says how to fill it",
    finder.emptyHint.content,
    "Star a sprite to keep it here."
)
check.Equal("the empty message is shown", finder.emptyTitle.hidden, false)
check.Equal("there is nothing to clear", clearButton(), nil)
check.Same(
    "a favourite missing on this client is kept",
    Favourites.Decode(client.stored.rsprite_finder_favourites.names),
    { "GONE_SPRITE" }
)
finder.favouritesButton:Click()
check.Equal(
    "turning favourites only off shows everything again",
    finder.resultsText.content,
    "155 sprites"
)
check.Equal(
    "the no results message is back to normal",
    finder.emptyTitle.content,
    FinderWindow.EMPTY_TITLE
)

select("ATTACKING_RETICULE_FRAME_1")
detail.nextVariant:Click()
check.Equal("the star starts off for a new sprite", detail.star.disabled, true)
check.Equal("the star offers to add", detail.star.tooltip, "Add to favourites")
detail.star:Click()
check.Equal("the star lights for a favourite", detail.star.disabled, false)
check.Equal("the star offers to remove", detail.star.tooltip, "Remove from favourites")
check.Same(
    "starring stores the exact variant",
    Favourites.Decode(client.stored.rsprite_finder_favourites.names),
    { "ATTACKING_RETICULE_FRAME_2", "GONE_SPRITE" }
)
check.Equal(
    "favourites are stored as one string",
    type(client.stored.rsprite_finder_favourites.names),
    "string"
)
detail.previousVariant:Click()
check.Equal("another variant of a starred one is not starred", detail.star.disabled, true)

select("SKILL_ATTACK")
detail.star:Click()
FinderOptions.Set(FinderOptions.HIDE_CLUTTER, false)
FinderWindow.OptionsChanged()
select("LOBBY_BANNER_FR")
detail.star:Click()
FinderOptions.Set(FinderOptions.HIDE_CLUTTER, true)
FinderWindow.OptionsChanged()

finder.favouritesButton:Click()
check.Equal("the favourites star lights up", finder.favouritesButton.disabled, false)
check.Equal("favourites only counts favourites", finder.resultsText.content, "3 favourites")
check.Same(
    "favourites show newest first, ignoring grouping and hidden copies",
    shownNames(),
    { "LOBBY_BANNER_FR", "SKILL_ATTACK", "ATTACKING_RETICULE_FRAME_2" }
)
client.Click(finder.grid.tiles[3].square)
check.Equal("a favourite variant has no stepper", detail.variantText.hidden, true)
check.Equal("a favourite shows a lit star", detail.star.disabled, false)

FinderFakes.Type(client, finder.searchField, "lobby")
FinderFakes.TicksUntil(client, function()
    return state.query == "lobby"
end, 10)
check.Equal("the search filters within favourites", finder.resultsText.content, "1 favourite")
FinderWindow.ClearFilters()
FinderFakes.Choose(client, finder.tagBox, "skill")
check.Equal("the tag filters within favourites", finder.resultsText.content, "1 favourite")
check.Same("only the tagged favourite shows", shownNames(), { "SKILL_ATTACK" })
FinderFakes.Type(client, finder.searchField, "zzqqxx")
FinderFakes.TicksUntil(client, function()
    return state.query == "zzqqxx"
end, 10)
check.Equal(
    "a search that misses every favourite reads as no match",
    finder.emptyTitle.content,
    FinderWindow.EMPTY_TITLE
)
check.Check("a search that misses every favourite can be cleared", clearButton() ~= nil, "clear")
FinderWindow.ClearFilters()
FinderFakes.Type(client, finder.searchField, "lobby")
FinderFakes.TicksUntil(client, function()
    return state.query == "lobby"
end, 10)
client.Click(finder.searchField.clearButton.root)
check.Equal("clearing the search keeps favourites only", finder.favouritesButton.disabled, false)
check.Equal(
    "clearing the search shows every favourite again",
    finder.resultsText.content,
    "3 favourites"
)

local findCalls = 0
local find = rsprite.Find
rsprite.Find = function(...)
    findCalls = findCalls + 1
    return find(...)
end
client.Click(finder.grid.tiles[1].square)
detail.star:Click()
rsprite.Find = find
check.Equal("unstarring in favourites only reuses the search", findCalls, 0)
check.Equal(
    "unstarring in favourites only removes the tile",
    finder.resultsText.content,
    "2 favourites"
)
check.Same(
    "the remaining favourites keep their order",
    shownNames(),
    { "SKILL_ATTACK", "ATTACKING_RETICULE_FRAME_2" }
)
check.Same(
    "the missing favourite is still stored",
    Favourites.Decode(client.stored.rsprite_finder_favourites.names),
    { "SKILL_ATTACK", "ATTACKING_RETICULE_FRAME_2", "GONE_SPRITE" }
)
check.Equal("favourites only is saved", client.stored.rsprite_finder_favourites.only, true)

FinderWindow.Destroy()
FinderFakes.ForgetModules()
local ReloadedWindow = require("src/features/finder/finder_window")
ReloadedWindow.Open()
finder, state = ReloadedWindow.Parts()
detail = finder.detail
check.Equal("favourites only is restored", finder.favouritesButton.disabled, false)
check.Equal("favourites are restored", finder.resultsText.content, "2 favourites")
check.Same(
    "the restored favourites keep their order",
    shownNames(),
    { "SKILL_ATTACK", "ATTACKING_RETICULE_FRAME_2" }
)

for _ = 1, 2 do
    client.Click(finder.grid.tiles[1].square)
    detail.star:Click()
end
check.Equal(
    "only missing favourites left reads as none",
    finder.emptyTitle.content,
    "No favourites yet"
)
check.Equal("the count leaves out missing favourites", finder.resultsText.content, "0 favourites")
check.Equal("the finder warned about nothing", client.WarningsMentioning("rsprite-finder"), 0)

ReloadedWindow.Destroy()
check.Finish()
