selftest.UsePlugin("rsprite-finder")

local ClientFakes = require("tests/support/client_fakes")
local FinderFakes = require("tests/support/finder_fakes")
local Report = require("tests/support/report")

local check = Report.New("crash guard")

local MARKER_KEY = "rsprite_finder_drawing"
local HIDDEN_KEY = "rsprite_finder_hidden"
local STATE_KEY = "rsprite_finder_state"
local RECOVERY_WARNING =
    "rsprite-finder: the last session closed while drawing these sprites, so they are now hidden: "

local sprites = ClientFakes.DefaultSprites()
sprites[#sprites + 1] = { 1243, "FLOORSHADOWS" }
local client, prettyuiFake = FinderFakes.Install({ sprites = sprites })

local function loadFinder()
    FinderFakes.ForgetModules()
    return require("src/features/finder/finder_window"), require("src/features/finder/crash_guard")
end

local function openAndWait(FinderWindow)
    FinderWindow.Open()
    FinderFakes.TicksUntil(client, function()
        return rsprite.IsIndexReady() and (FinderWindow.Parts()).indexReady
    end, 40)
    return FinderWindow.Parts()
end

local function search(finder, state, query)
    FinderFakes.Type(client, finder.searchField, query)
    FinderFakes.TicksUntil(client, function()
        return state.query == query
    end, 10)
end

local function markerNames()
    local marker = client.stored[MARKER_KEY]
    if marker == nil or marker.names == nil then
        return nil
    end
    local names = {}
    for name in string.gmatch(marker.names, "[^,]+") do
        names[#names + 1] = name
    end
    return names
end

local function listed(state, name)
    for _, entry in ipairs(state.entries or {}) do
        if entry.name == name then
            return true
        end
    end
    return false
end

client.stored.rsprite_finder_favourites = { names = "FLOORSHADOWS,SKILL_ATTACK", only = false }
local FinderWindow, CrashGuard = loadFinder()
local finder, state = openAndWait(FinderWindow)
check.Equal("the finder never lists a crashing sprite", listed(state, "FLOORSHADOWS"), false)
check.Equal("browsing counts every other sprite", finder.resultsText.content, "153 sprites")
search(finder, state, "floorshadows")
check.Equal(
    "searching for a crashing sprite finds nothing",
    finder.resultsText.content,
    "0 matches"
)
search(finder, state, "")
finder.favouritesButton:Click()
check.Equal(
    "favourites only drops a starred crashing sprite",
    finder.resultsText.content,
    "1 favourite"
)
check.Equal(
    "the starred crashing sprite stays in the saved favourites",
    client.stored.rsprite_finder_favourites.names,
    "FLOORSHADOWS,SKILL_ATTACK"
)
finder.favouritesButton:Click()

check.Equal("the guard waits 50 ticks", CrashGuard.CLEAR_AFTER_TICKS, 50)
FinderFakes.TicksUntil(client, function()
    return not CrashGuard.IsWaiting()
end, 60)
finder.nextButton:Click()
local drawn = markerNames()
check.Check("a page change saves a marker before drawing", drawn ~= nil, "marker")
check.Equal("the marker names the page's tiles and the preview", #drawn, #state.tiles + 1)
check.Equal("the marker starts with the first tile", drawn[1], state.tiles[1].name)
check.Equal("the marker ends with the preview", drawn[#drawn], state.selectedEntry.name)
check.Equal("the marker records the page", client.stored[MARKER_KEY].page, 2)
for _ = 1, CrashGuard.CLEAR_AFTER_TICKS - 1 do
    client.FireLogic()
end
check.Check(
    "the marker stays until the draw has had time to survive",
    markerNames() ~= nil,
    "still there"
)
client.FireLogic()
check.Equal("the marker clears 50 ticks after the draw", markerNames(), nil)

client.Click(finder.grid.tiles[3].square)
check.Same(
    "a tile click saves a marker naming only the preview",
    markerNames(),
    { state.selectedEntry.name }
)
finder.window:Close()
check.Equal("closing the window clears the marker straight away", markerNames(), nil)

FinderWindow.Destroy()
client.stored[MARKER_KEY] = { version = 1, page = 3, names = "SKILL_ATTACK,SKILL_MAGIC" }
client.stored[STATE_KEY] = {
    version = 2,
    query = "",
    tag = "",
    page = 3,
    previewSize = 48,
    previewBackground = "dark",
    selectedName = "SKILL_MAGIC",
}
FinderWindow, CrashGuard = loadFinder()
local warningsBefore = client.WarningsMentioning(RECOVERY_WARNING)
finder, state = openAndWait(FinderWindow)
check.Equal(
    "a marker left by a crash warns once",
    client.WarningsMentioning(RECOVERY_WARNING .. "SKILL_ATTACK, SKILL_MAGIC") - warningsBefore,
    1
)
check.Equal(
    "the crashed sprites are saved as hidden",
    client.stored[HIDDEN_KEY].names,
    "SKILL_ATTACK,SKILL_MAGIC"
)
check.Equal("the finder starts on page 1 after a crash", state.page, 1)
check.Check(
    "the saved selection is not restored after a crash",
    state.selectedName ~= "SKILL_MAGIC",
    tostring(state.selectedName)
)
check.Equal(
    "the finder no longer lists the hidden sprites",
    listed(state, "SKILL_ATTACK") or listed(state, "SKILL_MAGIC"),
    false
)
search(finder, state, "attack")
check.Equal("searching skips the hidden sprites", finder.resultsText.content, "0 matches")
FinderWindow.Open()
check.Equal(
    "opening again does not warn again",
    client.WarningsMentioning(RECOVERY_WARNING) - warningsBefore,
    1
)

FinderWindow.Destroy()
client.stored[MARKER_KEY] = { version = 1, page = 1, names = "BP3_MISSION_ICON_SKILL_NECROMANCY" }
FinderFakes.ForgetModules()
local App = require("src/app/init")
CrashGuard = require("src/features/finder/crash_guard")
App.Start()
local warningsBeforeCog = client.WarningsMentioning(RECOVERY_WARNING)
client.FireEvent("SettingsLayerReady", { component = FinderFakes.SettingsDialog(client) })
check.Equal(
    "opening the settings cog recovers from a crash too",
    client.WarningsMentioning(RECOVERY_WARNING) - warningsBeforeCog,
    1
)
check.Equal(
    "the cog warning names the sprite it was drawing",
    client.WarningsMentioning(RECOVERY_WARNING .. "BP3_MISSION_ICON_SKILL_NECROMANCY"),
    1
)
check.Equal("the cog adds to the hidden sprites", CrashGuard.HiddenCount(), 3)
check.Equal("the cog clears the marker", markerNames(), nil)
check.Equal("the recovered state starts on page 1", client.stored[STATE_KEY].page, 1)

local showButton = FinderFakes.LiveFancyButton(prettyuiFake, "Show hidden sprites again")
check.Check("the cog offers to show hidden sprites again", showButton ~= nil, "button")
showButton:Click()
check.Equal(
    "showing hidden sprites again says how many",
    client.WarningsMentioning("rsprite-finder: 3 hidden sprites are shown again"),
    1
)
check.Equal(
    "showing hidden sprites again clears the saved list",
    client.stored[HIDDEN_KEY].names,
    ""
)
check.Equal("nothing is hidden afterwards", CrashGuard.HiddenCount(), 0)
FinderWindow = require("src/features/finder/finder_window")
state = select(2, openAndWait(FinderWindow))
check.Equal("the shown sprites are listed again", listed(state, "SKILL_ATTACK"), true)
check.Equal(
    "a crashing sprite stays hidden after showing hidden sprites",
    listed(state, "FLOORSHADOWS"),
    false
)
App.Shutdown()

check.Finish()
