selftest.UsePlugin("rsprite")

local FinderFakes = require("tests/support/finder_fakes")
local Report = require("tests/support/report")

local check = Report.New("sprite probe")

local PROBE_FOLDER = "examples/sprite-probe"
local STEP_KEY = "rsprite_sprite_probe_step"
local COUNTER_KEY = "rsprite_sprite_probe_counter"

local function catalogueSprites()
    local file = assert(io.open("catalogue/sprites.tsv", "r"))
    local contents = file:read("a")
    file:close()
    local sprites = {}
    for spriteId, name in string.gmatch(contents, "(%d+)\t([^\n]+)\n") do
        sprites[#sprites + 1] = { tonumber(spriteId), name }
    end
    return sprites
end

local sprites = catalogueSprites()

local function startProbe(stored, spriteList)
    local client = FinderFakes.Install({ sprites = spriteList or sprites })
    for key, value in pairs(stored or {}) do
        client.stored[key] = value
    end
    local _, environment = selftest.LoadPlugin(PROBE_FOLDER)
    return client, environment
end

local function linesMentioning(client, text)
    local found = {}
    for _, line in ipairs(client.warnings) do
        if string.find(line, text, 1, true) then
            found[#found + 1] = line
        end
    end
    return found
end

local function openCog(client, environment)
    local dialog = FinderFakes.SettingsDialog(client)
    client.FireEvent("SettingsLayerReady", { component = dialog })
    return environment.require("src/features/settings/settings_panel").Parts()
end

local function ticks(client, count)
    for _ = 1, count do
        client.FireLogic()
    end
end

local client, environment = startProbe()
check.Equal("loading prints nothing", #client.warnings, 0)
check.Equal("loading ticks nothing", client.SubscriptionCount(), 0)
check.Equal("loading draws no sprites", #client.sprites, 0)
check.Check(
    "loading listens for the settings cog",
    client.handlers.SettingsLayerReady["rsprite-sprite-probe:settings"] ~= nil,
    "listening"
)
local panel = openCog(client, environment)
check.Equal("opening the cog draws no sprites", #client.sprites, 0)
check.Equal("opening the cog starts nothing", client.SubscriptionCount(), 0)
check.Equal("the page field starts on page 19", panel.pageField.content, "19")
check.Equal(
    "the options start with both on",
    panel.optionsButton.text.content,
    "Options: both options on"
)

local Pages = environment.require("src/features/probe/pages")
local pageNineteen = Pages.Entries(1, 19)
check.Equal("page 19 holds 30 sprites", #pageNineteen, 30)
check.Equal(
    "page 19 starts where the finder's does",
    pageNineteen[1].name,
    "RS3_LOBBY_SECONDARY_TH_CELESTIALLANTERNS_EN"
)
local listsFloorShadows = false
for _, entry in ipairs(pageNineteen) do
    if entry.id == 1243 or entry.name == "FLOORSHADOWS" then
        listsFloorShadows = true
    end
end
check.Equal("page 19 no longer holds FLOORSHADOWS", listsFloorShadows, false)
check.Equal(
    "tile 566 is now the sprite that followed it",
    pageNineteen[26].name,
    "LUT_CAVE_DUNGEON_ZAROSIAN_SENNTISTEN_FUL"
)
check.Equal(
    "page 19 now ends with tile 571",
    pageNineteen[30].name,
    "HITMARK_HITSPLAT_BLIGHT_RIGHT_OTHER"
)
check.Equal("there are four option settings", Pages.SettingCount(), 4)

client.Click(panel.spritesButton.button)
check.Equal("mode 1 starts ticking", client.SubscriptionCount(), 1)
check.Equal("mode 1 builds the probe panel", #client.sprites, 32)
ticks(client, 1)
check.Same("the first step is saved before drawing", {
    client.stored[STEP_KEY].mode,
    client.stored[STEP_KEY].page,
    client.stored[STEP_KEY].tile,
    client.stored[STEP_KEY].id,
    client.stored[STEP_KEY].name,
}, { 1, 19, 541, 1192, "RS3_LOBBY_SECONDARY_TH_CELESTIALLANTERNS_EN" })
check.Equal(
    "the first step is printed in the agreed form",
    #linesMentioning(
        client,
        "rsprite-sprite-probe: page 19 tile 541 id 1192 RS3_LOBBY_SECONDARY_TH_CELESTIALLANTERNS_EN"
    ),
    1
)
local stage = environment.require("src/features/probe/stage").Parts()
check.Equal("the sprite is drawn at 32 px first", stage.tile.sprite, 1192)
check.Equal("the 64 px preview waits for the next tick", stage.preview.sprite, nil)
ticks(client, 1)
check.Equal("the sprite is then drawn at 64 px", stage.preview.sprite, 1192)
ticks(client, 3)
check.Equal("the next sprite waits three ticks", client.stored[STEP_KEY].tile, 541)
ticks(client, 1)
check.Equal("the next sprite follows after three ticks", client.stored[STEP_KEY].tile, 542)
ticks(client, 24 * 5 + 1)
check.Equal(
    "tile 566 is saved before it is drawn",
    client.stored[STEP_KEY].name,
    "LUT_CAVE_DUNGEON_ZAROSIAN_SENNTISTEN_FUL"
)
check.Equal(
    "tile 566 is printed before it is drawn",
    #linesMentioning(
        client,
        "rsprite-sprite-probe: page 19 tile 566 id 1247 LUT_CAVE_DUNGEON_ZAROSIAN_SENNTISTEN_FUL"
    ),
    1
)
check.Equal("tile 566 is drawn at 32 px", stage.tile.sprite, 1247)
ticks(client, 5 * 5)
check.Equal(
    "mode 1 finishes after the page",
    #linesMentioning(client, "finished page 19 with both options on"),
    1
)
check.Equal("a finished page clears the saved step", client.stored[STEP_KEY].mode, nil)
check.Equal("a finished page stops ticking", client.SubscriptionCount(), 0)

panel.pageField.content = "0"
client.Click(panel.spritesButton.button)
check.Equal(
    "page 0 is refused",
    #linesMentioning(client, "the page must be a whole number from 1 to 40"),
    1
)
panel.pageField.content = "41"
client.Click(panel.spritesButton.button)
check.Equal(
    "page 41 is refused",
    #linesMentioning(client, "the page must be a whole number from 1 to 40"),
    2
)
check.Equal("a refused page starts nothing", client.SubscriptionCount(), 0)

panel.pageField.content = "2"
client.Click(panel.optionsButton.button)
check.Equal(
    "the options button moves to the next setting",
    panel.optionsButton.text.content,
    "Options: grouping off"
)
client.Click(panel.spritesButton.button)
ticks(client, 1)
check.Equal(
    "mode 1 uses the chosen setting",
    client.stored[STEP_KEY].name,
    Pages.Entries(2, 2)[1].name
)
check.Equal("mode 1 saves the chosen setting", client.stored[STEP_KEY].options, "grouping off")
client.Click(panel.stopButton.button)
check.Equal("Stop stops ticking", client.SubscriptionCount(), 0)
check.Equal("Stop clears the saved step", client.stored[STEP_KEY].mode, nil)
check.Equal("Stop hides the sprites", stage.tile.hidden, true)
for _ = 1, 3 do
    client.Click(panel.optionsButton.button)
end
check.Equal(
    "the options button wraps back round",
    panel.optionsButton.text.content,
    "Options: both options on"
)

client = startProbe({
    [STEP_KEY] = {
        mode = 1,
        page = 19,
        tile = 566,
        id = 1243,
        name = "FLOORSHADOWS",
        options = "both options on",
    },
})
check.Same("a saved step from the last session is reported on start", client.warnings, {
    "rsprite-sprite-probe: last session stopped at page 19 tile 566 id 1243 FLOORSHADOWS, with both options on",
})
check.Equal("the reported step is cleared", client.stored[STEP_KEY].mode, nil)
check.Equal("reporting starts nothing", client.SubscriptionCount(), 0)

client, environment = startProbe()
panel = openCog(client, environment)
local Client = environment.require("src/services/client")
client.Click(panel.buildUpButton.button)
local componentsBefore = Client.CreatedComponents()
ticks(client, 4 * 25 + 1)
local buildUpLines = linesMentioning(client, "rsprite-sprite-probe: build up page ")
check.Equal("mode 2 prints all 25 pages", #buildUpLines, 25)
check.Check(
    "mode 2 prints the page, the components and the Lua memory",
    string.match(
        buildUpLines[1],
        "^rsprite%-sprite%-probe: build up page 1, %d+ components created by the probe, [%w%.%s]+$"
    ) ~= nil,
    buildUpLines[1]
)
check.Check(
    "mode 2 creates no components while paging",
    string.find(
        buildUpLines[25],
        string.format("page 25, %d components", componentsBefore),
        1,
        true
    ) ~= nil,
    buildUpLines[25]
)
check.Equal(
    "mode 2 draws page 25 last",
    environment.require("src/features/probe/stage").Parts().grid[1].sprite,
    Pages.Entries(1, 25)[1].id
)
check.Equal(
    "mode 2 reports a fresh start quietly",
    #linesMentioning(client, "restart the client"),
    0
)
check.Equal("mode 2 finishes", #linesMentioning(client, "finished build up pages 1 to 25"), 1)
check.Equal("mode 2 clears its saved step", client.stored[STEP_KEY].mode, nil)
client.Click(panel.buildUpButton.button)
check.Equal(
    "mode 2 warns when it is not a fresh start",
    #linesMentioning(client, "restart the client for a clean build up test"),
    1
)
client.Click(panel.stopButton.button)

client.Click(panel.counterButton.button)
ticks(client, 40)
check.Equal("mode 3 saves the counter every tick", client.stored[COUNTER_KEY].value, 40)
check.Equal(
    "mode 3 prints every 20 ticks",
    #linesMentioning(client, "rsprite-sprite-probe: saved counter "),
    2
)
client.Click(panel.stopButton.button)
check.Equal("Stop stops mode 3", client.SubscriptionCount(), 0)
check.Equal("Stop keeps the counter", client.stored[COUNTER_KEY].value, 40)

client = startProbe({ [COUNTER_KEY] = { value = 1234 } })
check.Same("the saved counter is reported on start", client.warnings, {
    "rsprite-sprite-probe: the saved counter from the last session reached 1234",
})
check.Equal("the reported counter is cleared", client.stored[COUNTER_KEY].value, nil)

local SWEEP_KEY = "rsprite_sprite_probe_sweep"
local FINDINGS_KEY = "rsprite_sprite_probe_findings"
local sweepSprites = FinderFakes.SpritesWith({})
sweepSprites[#sweepSprites + 1] = { 1243, "FLOORSHADOWS" }

local function probeStored(fromClient)
    local kept = {}
    for _, key in ipairs({ STEP_KEY, COUNTER_KEY, SWEEP_KEY, FINDINGS_KEY }) do
        local value = fromClient.stored[key]
        if value ~= nil then
            local copy = {}
            for field, inner in pairs(value) do
                copy[field] = inner
            end
            kept[key] = copy
        end
    end
    return kept
end

local function sweepReady(sweepClient, sweepEnvironment)
    local SweepPages = sweepEnvironment.require("src/features/probe/sweep_pages")
    FinderFakes.TicksUntil(sweepClient, function()
        return SweepPages.IsReady()
    end, 60)
    return SweepPages
end

client, environment = startProbe(nil, sweepSprites)
panel = openCog(client, environment)
local ProbeRunner = environment.require("src/features/probe/probe_runner")
check.Equal("the sweep waits 25 ticks per page", ProbeRunner.SWEEP_WAIT_TICKS, 25)
client.Click(panel.sweepButton.button)
local SweepPages = sweepReady(client, environment)
check.Equal("the sweep covers every sprite but the crashing one", SweepPages.PageCount(), 6)
FinderFakes.TicksUntil(client, function()
    return client.stored[STEP_KEY] ~= nil and client.stored[STEP_KEY].page == 1
end, 5)
check.Same(
    "the sweep saves the page before drawing it",
    { client.stored[STEP_KEY].mode, client.stored[STEP_KEY].page },
    { 4, 1 }
)
ticks(client, ProbeRunner.SWEEP_WAIT_TICKS)
check.Equal("the next page waits 25 ticks", client.stored[STEP_KEY].page, 1)
ticks(client, 1)
check.Equal("the next page follows after 25 ticks", client.stored[STEP_KEY].page, 2)
client.Click(panel.stopButton.button)
check.Equal("stopping a sweep remembers the next page", client.stored[SWEEP_KEY].nextPage, 3)
client.Click(panel.resumeButton.button)
ticks(client, 1)
check.Equal(
    "resuming a stopped sweep carries on from the next page",
    client.stored[STEP_KEY].page,
    3
)
ticks(client, 4 * (ProbeRunner.SWEEP_WAIT_TICKS + 1))
check.Equal(
    "the sweep finishes after the last page",
    #linesMentioning(client, "sweep finished after page 6"),
    1
)
check.Equal("a finished sweep clears its saved position", client.stored[SWEEP_KEY].nextPage, nil)
check.Equal("a finished sweep clears its saved step", client.stored[STEP_KEY].mode, nil)
check.Equal("the sweep never draws a sprite known to crash", client.Logged("sprite 1243"), 0)

client, environment = startProbe({ [STEP_KEY] = { mode = 4, page = 3 } }, sweepSprites)
check.Same("a crash during the sweep is reported with its page", client.warnings, {
    "rsprite-sprite-probe: last session stopped at sweep page 3. Press Resume sweep to name the sprite.",
})
check.Same(
    "the crashed page is saved for naming",
    { client.stored[SWEEP_KEY].crashPage, client.stored[SWEEP_KEY].namePage },
    { 3, 3 }
)
panel = openCog(client, environment)
client.Click(panel.resumeButton.button)
SweepPages = sweepReady(client, environment)
local pageThree = SweepPages.Entries(3)
local culprit = pageThree[4]
ticks(client, 1)
check.Same(
    "resuming names the crashed page one sprite at a time",
    { client.stored[STEP_KEY].mode, client.stored[STEP_KEY].position },
    { 5, 1 }
)
FinderFakes.TicksUntil(client, function()
    return client.stored[STEP_KEY].position == 4
end, 40)
check.Equal(
    "naming saves each sprite before drawing it",
    client.stored[STEP_KEY].name,
    culprit.name
)

client, environment = startProbe(probeStored(client), sweepSprites)
check.Equal(
    "a crash while naming reports the sprite and saves it as a finding",
    #linesMentioning(
        client,
        string.format(
            "last session stopped at sweep page 3 tile 64 id %d %s, now saved as a finding",
            culprit.id,
            culprit.name
        )
    ),
    1
)
check.Equal(
    "the finding is saved",
    client.stored[FINDINGS_KEY].entries,
    culprit.id .. " " .. culprit.name
)
panel = openCog(client, environment)
local loggedBefore = client.Logged("sprite " .. culprit.id)
client.Click(panel.resumeButton.button)
sweepReady(client, environment)
ticks(client, 1)
check.Equal(
    "naming carries on with the sprite after the finding",
    client.stored[STEP_KEY].name,
    pageThree[5].name
)
FinderFakes.TicksUntil(client, function()
    return #linesMentioning(client, "naming finished, so the sweep carries on from page 4") == 1
end, 200)
check.Equal(
    "after a finding the sweep carries on from the next page",
    #linesMentioning(client, "naming finished, so the sweep carries on from page 4"),
    1
)
check.Equal(
    "a page with a finding does not name the page before it",
    #linesMentioning(client, "is named too"),
    0
)
FinderFakes.TicksUntil(client, function()
    return #linesMentioning(client, "sweep finished") == 1
end, 200)
check.Equal(
    "the found sprite is never drawn again",
    client.Logged("sprite " .. culprit.id),
    loggedBefore
)
client.Click(panel.findingsButton.button)
check.Equal(
    "Show findings prints each finding ready to paste",
    #linesMentioning(
        client,
        string.format('rsprite-sprite-probe: { "id": %d, "name": "%s" },', culprit.id, culprit.name)
    ),
    1
)

client, environment = startProbe({ [STEP_KEY] = { mode = 4, page = 3 } }, sweepSprites)
panel = openCog(client, environment)
client.Click(panel.resumeButton.button)
FinderFakes.TicksUntil(client, function()
    return #linesMentioning(client, "naming finished") == 1
end, 400)
check.Equal(
    "a crashed page that draws safely names the page before it too",
    #linesMentioning(client, "page 3 drew safely one sprite at a time, so page 2 is named too"),
    1
)
check.Equal(
    "after the page before, the sweep carries on after the crashed page",
    #linesMentioning(client, "naming finished, so the sweep carries on from page 4"),
    1
)
client.Click(panel.stopButton.button)

client, environment = startProbe(nil, sweepSprites)
panel = openCog(client, environment)
client.Click(panel.findingsButton.button)
check.Equal(
    "Show findings says when there are none",
    #linesMentioning(client, "no crashing sprites have been found yet"),
    1
)
client.Click(panel.resumeButton.button)
check.Equal(
    "Resume sweep says when there is nothing to resume",
    #linesMentioning(client, "there is no sweep to resume"),
    1
)

check.Finish()
