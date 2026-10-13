selftest.UsePlugin("rsprite-finder")

local FinderFakes = require("tests/support/finder_fakes")
local Report = require("tests/support/report")

local check = Report.New("finder options")
local client, prettyuiFake = FinderFakes.Install({
    sprites = FinderFakes.SpritesWith({
        "ATTACKING_RETICULE_FRAME_2",
        "ATTACKING_RETICULE_FRAME_1",
        "ATTACKING_RETICULE_FRAME_3",
        "EMOTES_10",
        "EMOTES_2",
        "MENU_MOBILE_PANEL",
        "LOBBY_BANNER_FR",
        "LOBBY_BANNER_DE",
        "LOBBY_BANNER_EN",
    }),
})
local App = require("src/app/init")
local FinderOptions = require("src/features/finder/finder_options")
local FinderWindow = require("src/features/finder/finder_window")
local ResultList = require("src/features/finder/result_list")

local findCalls = 0
local find = rsprite.Find
rsprite.Find = function(...)
    findCalls = findCalls + 1
    return find(...)
end

local function latestGroup()
    return prettyuiFake.checkboxGroups[#prettyuiFake.checkboxGroups]
end

App.Start()
client.FireEvent("SettingsLayerReady", { component = FinderFakes.SettingsDialog(client) })
local group = latestGroup()
check.Equal("the cog shows one group of options", #prettyuiFake.checkboxGroups, 1)
check.Equal("the options sit in the settings view", group.parent, prettyuiFake.views[1].content)
check.Same(
    "the options are worded plainly",
    { group.choices[1].text, group.choices[2].text },
    { "Group numbered variants", "Hide mobile and language copies" }
)
check.Same(
    "both options start on",
    group:GetSelectedValues(),
    { FinderOptions.GROUP_VARIANTS, FinderOptions.HIDE_CLUTTER }
)

FinderWindow.Open()
FinderFakes.TicksUntil(client, function()
    return rsprite.IsIndexReady()
end, 40)
local finder, state = FinderWindow.Parts()
check.Equal(
    "hidden copies and grouped variants shrink the count",
    finder.resultsText.content,
    "156 sprites"
)
check.Equal("the page count follows the tiles", finder.pageText.content, "Page 1 of 6")
check.Equal("opening searches once", findCalls, 1)

for _ = 1, 5 do
    finder.nextButton:Click()
end
check.Equal("paging reaches the last page", finder.pageText.content, "Page 6 of 6")
check.Equal("paging runs no new search", findCalls, 1)
finder.previousButton:Click()
check.Equal("paging back runs no new search", findCalls, 1)
finder.nextButton:Click()

local function pagePositionOf(name)
    local tilePosition = ResultList.Locate(state.results, name)
    return tilePosition - (state.page - 1) * 30
end

local familyPosition = pagePositionOf("ATTACKING_RETICULE_FRAME_2")
local familyTile = finder.grid.tiles[familyPosition]
check.Equal(
    "a family tile's tooltip counts its variants",
    familyTile.tooltip.text,
    "ATTACKING_RETICULE_FRAME (3 variants)"
)
check.Equal(
    "a family is drawn with its lowest numbered member",
    state.tiles[familyPosition].name,
    "ATTACKING_RETICULE_FRAME_1"
)
check.Equal(
    "the emote family steps from 2 to 10",
    state.tiles[pagePositionOf("EMOTES_10")].label,
    "EMOTES (2 variants)"
)
check.Equal("the mobile copy is hidden", ResultList.Locate(state.results, "MENU_MOBILE_PANEL"), nil)
check.Equal("the French copy is hidden", ResultList.Locate(state.results, "LOBBY_BANNER_FR"), nil)
check.Check(
    "the English copy stays",
    ResultList.Locate(state.results, "LOBBY_BANNER_EN") ~= nil,
    "kept"
)

client.Click(familyTile.square)
local detail = finder.detail
local function copyText(label)
    return detail.copyFields[label].component.content
end
check.Equal(
    "a family starts on its first variant",
    detail.nameLines[1].content,
    "ATTACKING_RETICULE_FRAME_1"
)
check.Equal("the stepper shows where it is", detail.variantText.content, "Variant 1 of 3")
check.Equal("the stepper is visible", detail.variantText.hidden, false)
check.Equal("the stepper uses the left arrow", detail.previousVariant.spriteName, "ARROW_LEFT")
check.Equal("the stepper uses the right arrow", detail.nextVariant.spriteName, "ARROW_RIGHT")
check.Equal("the left arrow is disabled at the start", detail.previousVariant.disabled, true)
local previewSquare = detail.backgrounds.dark
check.Equal(
    "the left arrow sits just left of the preview",
    detail.previousVariant.options.x + 24 + 6,
    previewSquare.x
)
check.Equal(
    "the right arrow sits just right of the preview",
    detail.nextVariant.options.x,
    previewSquare.x + previewSquare.width + 6
)
check.Equal(
    "the arrows are centred on the preview",
    detail.previousVariant.options.y,
    previewSquare.y + math.floor((previewSquare.height - 24) / 2)
)
check.Equal(
    "the variant label sits just under the preview",
    detail.variantText.y,
    previewSquare.y + previewSquare.height + 2
)
check.Equal("the right arrow is enabled", detail.nextVariant.disabled, false)

detail.nextVariant:Click()
check.Equal(
    "stepping shows the next variant",
    detail.nameLines[1].content,
    "ATTACKING_RETICULE_FRAME_2"
)
check.Equal("the label follows the step", detail.variantText.content, "Variant 2 of 3")
check.Equal("the Name box follows the step", copyText("Name"), "ATTACKING_RETICULE_FRAME_2")
check.Equal(
    "the Get box follows the step",
    copyText("Get"),
    'rsprite.Get("ATTACKING_RETICULE_FRAME_2")'
)
check.Equal(
    "the Draw box follows the step",
    copyText("Draw"),
    'rsprite.Draw(parent, "ATTACKING_RETICULE_FRAME_2", { size = 48 })'
)
check.Equal("the Id follows the step", detail.factValues.Id.content, "36700")
check.Equal("both arrows are enabled in the middle", detail.previousVariant.disabled, false)
detail.nextVariant:Click()
check.Equal("the last variant is reached", state.selectedName, "ATTACKING_RETICULE_FRAME_3")
check.Equal("the right arrow is disabled at the end", detail.nextVariant.disabled, true)
check.Equal("stepping runs no new search", findCalls, 1)
check.Equal(
    "the exact variant is saved",
    client.stored.rsprite_finder_state.selectedName,
    "ATTACKING_RETICULE_FRAME_3"
)

local stepperButtons = #prettyuiFake.spriteButtons
client.Click(finder.grid.tiles[pagePositionOf("LOBBY_BANNER_EN")].square)
check.Equal("a single sprite hides the stepper text", detail.variantText.hidden, true)
check.Equal("a single sprite removes the stepper arrows", detail.previousVariant, nil)
check.Check(
    "the removed arrows are destroyed",
    prettyuiFake.spriteButtons[stepperButtons - 1].destroyed == true
        and prettyuiFake.spriteButtons[stepperButtons].destroyed == true,
    stepperButtons
)

client.Click(familyTile.square)
detail.nextVariant:Click()
detail.nextVariant:Click()
FinderWindow.Destroy()
FinderFakes.ForgetModules()
local ReloadedApp = require("src/app/init")
local ReloadedWindow = require("src/features/finder/finder_window")
ReloadedApp.Start()
ReloadedWindow.Open()
finder, state = ReloadedWindow.Parts()
detail = finder.detail
check.Equal("the exact variant is restored", state.selectedName, "ATTACKING_RETICULE_FRAME_3")
check.Equal(
    "the restored variant is shown",
    detail.nameLines[1].content,
    "ATTACKING_RETICULE_FRAME_3"
)
check.Equal("the restored stepper shows the variant", detail.variantText.content, "Variant 3 of 3")
check.Equal(
    "the restored family tile is highlighted",
    finder.grid.tiles[familyPosition].border.hidden,
    false
)

client.FireEvent("SettingsLayerReady", { component = FinderFakes.SettingsDialog(client) })
group = latestGroup()
local searchesBefore = findCalls
group:Toggle(FinderOptions.GROUP_VARIANTS)
check.Equal("turning grouping off applies straight away", finder.resultsText.content, "159 sprites")
check.Equal("an option change reuses the results", findCalls, searchesBefore)
check.Equal("the selection survives the change", state.selectedName, "ATTACKING_RETICULE_FRAME_3")
check.Equal("the page follows the selection", finder.pageText.content, "Page 6 of 6")
check.Equal("ungrouped sprites have no stepper", detail.variantText.hidden, true)
check.Same(
    "turning grouping off is saved",
    client.stored.rsprite_finder_options,
    { groupVariants = false, hideClutter = true }
)

group:Toggle(FinderOptions.HIDE_CLUTTER)
check.Equal("showing copies applies straight away", finder.resultsText.content, "162 sprites")
check.Same(
    "showing copies is saved",
    client.stored.rsprite_finder_options,
    { groupVariants = false, hideClutter = false }
)

client.Click(finder.grid.tiles[pagePositionOf("LOBBY_BANNER_FR")].square)
group:Toggle(FinderOptions.HIDE_CLUTTER)
check.Equal("hiding copies again applies straight away", finder.resultsText.content, "159 sprites")
check.Equal(
    "a hidden selection falls back to the first result",
    state.selectedName,
    state.results.tiles[1].name
)
check.Equal("the fallback returns to the first page", finder.pageText.content, "Page 1 of 6")

client.FireEvent("SettingsLayerReady", { component = FinderFakes.SettingsDialog(client) })
check.Equal("the cog rebuilds its options", #prettyuiFake.checkboxGroups, 3)
check.Same(
    "the rebuilt options show the saved choices",
    latestGroup():GetSelectedValues(),
    { FinderOptions.HIDE_CLUTTER }
)
latestGroup():Toggle(FinderOptions.GROUP_VARIANTS)
check.Equal(
    "both options on again restore the grouped count",
    finder.resultsText.content,
    "156 sprites"
)

FinderFakes.ForgetModules()
local Reloaded = require("src/features/finder/finder_options")
check.Same(
    "saved options load back",
    Reloaded.Current(),
    { groupVariants = true, hideClutter = true }
)
client.stored.rsprite_finder_options = nil
FinderFakes.ForgetModules()
check.Same(
    "options default to on",
    require("src/features/finder/finder_options").Current(),
    { groupVariants = true, hideClutter = true }
)

check.Equal("the finder warned about nothing", client.WarningsMentioning("rsprite-finder"), 0)

ReloadedApp.Shutdown()
check.Finish()
