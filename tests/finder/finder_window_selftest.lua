local FinderFakes = require("tests/support/finder_fakes")
local Report = require("tests/support/report")

local check = Report.New("finder window")
local client, prettyuiFake = FinderFakes.Install()
local DetailPanel = require("src/features/finder/detail_panel")
local FinderOptions = require("src/features/finder/finder_options")
local FinderWindow = require("src/features/finder/finder_window")

local function sizeButton(finder, size)
    for _, button in ipairs(finder.detail.sizeButtons.buttons) do
        if button.size == size then
            return button
        end
    end
    return nil
end

local function clickSize(finder, size)
    client.Click(sizeButton(finder, size).root)
end

local function clearButton()
    return prettyuiFake.Find("fancyButtons", function(button)
        return button.text == FinderWindow.CLEAR_LABEL and not button.destroyed
    end)
end

check.Equal("opening reports success", FinderWindow.Open(), true)
local finder, state = FinderWindow.Parts()
check.Equal("the window is titled", prettyuiFake.Logged("Window.new rsprite finder"), 1)
check.Equal("the window is opened", FinderWindow.IsOpen(), true)
check.Equal("the spinner shows while names are read", prettyuiFake.Logged("Spinner.new"), 1)
check.Equal("the loading line shows", finder.loadingText.hidden, false)
check.Equal("the grid is hidden while loading", finder.grid.tiles[1].square.hidden, true)

FinderFakes.TicksUntil(client, function()
    return rsprite.IsIndexReady()
end, 40)
check.Equal("the spinner goes when the names are ready", prettyuiFake.Logged("Spinner.Destroy"), 1)
check.Equal("the loading line goes", finder.loadingText.hidden, true)
check.Equal("browsing shows the total", finder.resultsText.content, "153 sprites")
check.Equal("the window keeps its width", FinderWindow.WIDTH, 724)
check.Equal("the window height fits its content", FinderWindow.HEIGHT, 514)
check.Equal(
    "the left column ends level with the detail panel",
    FinderWindow.COLUMN_BOTTOM,
    8 + DetailPanel.HEIGHT
)
check.Equal(
    "the paging row is pinned to the bottom of the left column",
    finder.previousButton.options.y + 24,
    FinderWindow.COLUMN_BOTTOM
)
check.Equal(
    "both paging arrows share the pinned row",
    finder.nextButton.options.y,
    finder.previousButton.options.y
)
check.Equal("the grid holds 30 tiles", #finder.grid.tiles, 30)
check.Equal("the search box asks plainly", finder.searchField.component.emptyText, "Search sprites")
check.Equal(
    "the search box uses the small font",
    finder.searchField.component.text.font,
    id.Font.MUSEO_SANS_11PT_REGULAR
)
check.Equal(
    "the search box keeps the input look",
    finder.searchField.component.stylesheetID,
    id.StyleSheet.INPUT_DEFAULT
)
check.Equal(
    "the search box draws its own background",
    finder.searchField.component.containerSprite.sprite,
    client.textField
)
local pagingCentre = FinderWindow.PAGING_X + FinderWindow.PAGING_WIDTH / 2
local columnCentre = FinderWindow.LEFT_COLUMN_X + FinderWindow.LEFT_COLUMN_WIDTH / 2
check.Check(
    "the paging row is centred in the left column",
    math.abs(pagingCentre - columnCentre) <= 0.5,
    pagingCentre
)
check.Equal(
    "the left arrow starts the centred row",
    finder.previousButton.options.x,
    FinderWindow.PAGING_X
)
local gapBeforeLabel = finder.pageText.x - (finder.previousButton.options.x + 24)
local gapAfterLabel = finder.nextButton.options.x - (finder.pageText.x + finder.pageText.width)
check.Equal("the arrows sit evenly either side of the page label", gapBeforeLabel, gapAfterLabel)
check.Equal(
    "the right arrow ends the centred row",
    finder.nextButton.options.x + 24,
    FinderWindow.PAGING_X + FinderWindow.PAGING_WIDTH
)
check.Equal(
    "All tags is the first tag entry",
    finder.tagOptions.entries[1].label,
    FinderWindow.ALL_TAGS
)
local tagBox = finder.tagBox.component
check.Equal("no PrettyUI combo box is used for tags", #prettyuiFake.comboBoxes, 0)
check.Equal("no PrettyUI text fields are used", #prettyuiFake.textFields, 0)
check.Equal(
    "the tag box uses the small font",
    tagBox.entryText.font,
    id.Font.MUSEO_SANS_11PT_REGULAR
)
check.Equal("the tag box keeps the combo look", tagBox.stylesheetID, id.StyleSheet.COMBO_DEFAULT)
check.Equal(
    "the tag box lines up with the search box",
    tagBox.height,
    finder.searchField.component.height
)
check.Equal("All tags has the first id", tagBox.entryIdsByLabel[FinderWindow.ALL_TAGS], 1)
local idsFollowPositions = true
for position, label in ipairs(finder.tagOptions.labels) do
    if tagBox.entryIdsByLabel[label] ~= position then
        idsFollowPositions = false
    end
end
check.Check("every tag id is its sorted position", idsFollowPositions, "ids")
check.Equal("the tag box starts on All tags", tagBox.selectedID, 1)
check.Equal("browsing pages through everything", finder.pageText.content, "Page 1 of 6")
check.Equal("the previous arrow starts disabled", finder.previousButton.disabled, true)
check.Equal("the next arrow starts enabled", finder.nextButton.disabled, false)
check.Equal(
    "curated sprites come first",
    finder.grid.tiles[1].sprite.sprite,
    rsprite.Get("BP3_MISSION_ICON_SKILL_NECROMANCY")
)
check.Equal("the first result is selected", state.selectedName, "BP3_MISSION_ICON_SKILL_NECROMANCY")
check.Equal(
    "the detail panel names the selection",
    finder.detail.nameLines[1].content .. finder.detail.nameLines[2].content,
    "BP3_MISSION_ICON_SKILL_NECROMANCY"
)
check.Equal("a sprite with no known size says so", finder.detail.factValues.Size.content, "Unknown")

FinderFakes.Type(client, finder.searchField, "skill")
for _ = 1, FinderWindow.DEBOUNCE_TICKS - 1 do
    client.FireLogic()
end
check.Equal("typing waits for a pause", finder.resultsText.content, "153 sprites")
client.FireLogic()
check.Equal("the search runs after 5 quiet ticks", finder.resultsText.content, "4 matches")
check.Equal("a short search fits one page", finder.pageText.content, "Page 1 of 1")
check.Equal("the next arrow is disabled on the last page", finder.nextButton.disabled, true)

client.Click(finder.grid.tiles[2].square)
local picked = state.tiles[2].name
check.Equal("clicking a tile selects it", state.selectedName, picked)
check.Equal("the detail panel shows the pick", finder.detail.nameLines[1].content, picked)
local function copyText(label)
    return finder.detail.copyFields[label].component.content
end
check.Equal("the name box holds the name", copyText("Name"), picked)
check.Equal("the Get box holds the Get line", copyText("Get"), 'rsprite.Get("' .. picked .. '")')
check.Equal(
    "the Draw box holds the Draw line at the lit size",
    copyText("Draw"),
    'rsprite.Draw(parent, "' .. picked .. '", { size = 48 })'
)
check.Equal(
    "the PrettyUI box holds the AddSprite line at the lit size",
    copyText("PrettyUI"),
    'window:AddSprite(rsprite.Get("' .. picked .. '"), { size = 48 })'
)
for _, label in ipairs({ "Name", "Get", "Draw", "PrettyUI" }) do
    local field = finder.detail.copyFields[label].component
    check.Equal(
        "the " .. label .. " box uses the small font",
        field.text.font,
        id.Font.MUSEO_SANS_11PT_REGULAR
    )
    check.Equal(
        "the " .. label .. " box keeps the input look",
        field.stylesheetID,
        id.StyleSheet.INPUT_DEFAULT
    )
    check.Equal(
        "the " .. label .. " box shares the text box background",
        field.containerSprite.sprite,
        client.textField
    )
    check.Equal("the " .. label .. " box has no placeholder", field.emptyText, "")
    check.Equal("the " .. label .. " box spans the panel", field.width, 232)
    local expected = copyText(label)
    FinderFakes.Type(client, finder.detail.copyFields[label], "something else")
    check.Equal("typing into the " .. label .. " box is put back", copyText(label), expected)
end

local sizeLabels = {}
for position, button in ipairs(finder.detail.sizeButtons.buttons) do
    sizeLabels[position] = button.label.content
end
check.Same("the size buttons show just the number", sizeLabels, { "16", "24", "32", "48", "64" })
check.Equal(
    "the size labels use the small font",
    sizeButton(finder, 16).label.font,
    id.Font.MUSEO_SANS_11PT_REGULAR
)
check.Equal("no PrettyUI simple buttons are used for sizes", #prettyuiFake.simpleButtons, 0)
check.Same("one preview size is lit", finder.detail.sizeButtons.LitSizes(), { 48 })
clickSize(finder, 64)
check.Same("choosing 64 lights only 64", finder.detail.sizeButtons.LitSizes(), { 64 })
check.Equal(
    "the Draw box follows the size buttons",
    copyText("Draw"),
    'rsprite.Draw(parent, "' .. picked .. '", { size = 64 })'
)
check.Equal(
    "the PrettyUI box follows the size buttons",
    copyText("PrettyUI"),
    'window:AddSprite(rsprite.Get("' .. picked .. '"), { size = 64 })'
)
clickSize(finder, 16)
check.Same("choosing 16 lights only 16", finder.detail.sizeButtons.LitSizes(), { 16 })
check.Equal(
    "the Draw box follows straight away",
    copyText("Draw"),
    'rsprite.Draw(parent, "' .. picked .. '", { size = 16 })'
)
clickSize(finder, 16)
check.Same("choosing the lit size keeps it lit", finder.detail.sizeButtons.LitSizes(), { 16 })
check.Equal("the preview size is remembered in state", state.previewSize, 16)

local detail = finder.detail
local backgrounds = detail.backgrounds
local function visibleBackground()
    local visible = {}
    for _, name in ipairs({ "dark", "light", "checker" }) do
        if not backgrounds[name].hidden then
            visible[#visible + 1] = name
        end
    end
    return visible
end
check.Equal(
    "the background control explains itself",
    detail.backgroundButton.tooltip,
    "Preview background"
)
check.Same("the preview starts on the dark background", visibleBackground(), { "dark" })
check.Equal("the dark background is the tile colour", backgrounds.dark.rgba, 0x14110EFF)
check.Equal("the light background is a warm light colour", backgrounds.light.rgba, 0xD9CFBFFF)
check.Equal(
    "the checkerboard uses the finder's own image",
    backgrounds.checker.sprite,
    client.checker
)
check.Equal("the checkerboard is tiled", backgrounds.checker.isTiling, true)
local tileColours = {}
for position, tile in ipairs(finder.grid.tiles) do
    tileColours[position] = tile.square.rgba
end
detail.backgroundButton:Click()
check.Same("one click shows the light background", visibleBackground(), { "light" })
detail.backgroundButton:Click()
check.Same("a second click shows the checkerboard", visibleBackground(), { "checker" })
check.Equal(
    "the background is saved",
    client.stored.rsprite_finder_state.previewBackground,
    "checker"
)
local tilesUnchanged = true
for position, tile in ipairs(finder.grid.tiles) do
    if tile.square.rgba ~= tileColours[position] then
        tilesUnchanged = false
    end
end
check.Check("the grid tiles keep their own background", tilesUnchanged, "tiles")
detail.backgroundButton:Click()
check.Same("a third click goes back to dark", visibleBackground(), { "dark" })
detail.backgroundButton:Click()

local boxX = backgrounds.dark.x
check.Equal("the preview square is centred in the panel", boxX, FinderWindow.DETAIL_X + 68)
check.Equal("the star sits in the preview row", detail.star.options.y, backgrounds.dark.y)
check.Equal("the star starts the preview row", detail.star.options.x, FinderWindow.DETAIL_X)
check.Equal(
    "the background control sits in the preview row",
    detail.backgroundButton.options.y,
    backgrounds.dark.y
)
check.Equal(
    "the background control is three quarters of the star's size",
    detail.backgroundButton.options.size,
    18
)
check.Equal("the star keeps its full size", detail.star.options.size, 24)
check.Equal(
    "the background control ends the preview row",
    detail.backgroundButton.options.x + 18,
    FinderWindow.DETAIL_X + 232
)
check.Equal(
    "the hint ends on the shared bottom line",
    detail.hintText.y + 16,
    FinderWindow.COLUMN_BOTTOM
)
local tileYs = {}
for row = 0, 4 do
    tileYs[#tileYs + 1] = finder.grid.tiles[row * 6 + 1].square.y
end
local rowGaps = {}
for row = 2, 5 do
    rowGaps[#rowGaps + 1] = tileYs[row] - tileYs[row - 1] - 64
end
check.Same(
    "the grid rows are evenly spaced",
    rowGaps,
    { rowGaps[1], rowGaps[1], rowGaps[1], rowGaps[1] }
)
check.Check("the spare height goes into the row gaps", rowGaps[1] > 6, rowGaps[1])
local gapAbovePaging = FinderWindow.PAGING_Y - (tileYs[5] + 64)
check.Check(
    "no large gap is left above the paging row",
    gapAbovePaging >= FinderWindow.PAGING_GAP and gapAbovePaging < FinderWindow.PAGING_GAP + 4,
    gapAbovePaging
)
check.Check(
    "the results label stays in the left column",
    finder.resultsText.x + finder.resultsText.width
        <= FinderWindow.LEFT_COLUMN_X + FinderWindow.LEFT_COLUMN_WIDTH,
    finder.resultsText.x + finder.resultsText.width
)
check.Check(
    "the favourites star sits between the tag box and the results",
    finder.favouritesButton.options.x > finder.tagBox.component.x + finder.tagBox.component.width
        and finder.favouritesButton.options.x + 24 < finder.resultsText.x,
    finder.favouritesButton.options.x
)
check.Equal(
    "the favourites star explains itself",
    finder.favouritesButton.tooltip,
    "Show favourites only"
)

FinderFakes.Choose(client, finder.tagBox, "icon")
check.Equal("a tag with no matches empties the results", finder.resultsText.content, "0 matches")
check.Equal("the empty message shows", finder.emptyTitle.hidden, false)
check.Equal("the empty hint shows", finder.emptyHint.hidden, false)
check.Check("the clear filters button appears", clearButton() ~= nil, "shown")
check.Equal("the empty state hides the tiles", finder.grid.tiles[1].square.hidden, true)

clearButton():Click()
check.Equal("clearing filters empties the query", state.query, "")
check.Equal("clearing filters resets the tag", state.tag, nil)
check.Equal("clearing filters empties the search field", finder.searchField.component.content, "")
check.Equal(
    "clearing filters selects All tags",
    tagBox.selectedID,
    finder.tagOptions.positionByLabel[FinderWindow.ALL_TAGS]
)
check.Equal("clearing filters shows everything", finder.resultsText.content, "153 sprites")
check.Equal("clearing filters hides the clear cross", finder.searchField.clearButton.visible, false)
check.Equal("the clear button goes away", clearButton(), nil)
check.Equal("the empty message hides", finder.emptyTitle.hidden, true)

local cross = finder.searchField.clearButton
local searchBox = finder.searchField.component
check.Equal("the clear cross is hidden while the box is empty", cross.visible, false)
check.Equal("a hidden cross hides its image too", cross.image.hidden, true)
check.Equal("the clear cross explains itself", cross.tooltip.text, "Clear search")
check.Equal(
    "the clear cross sits inside the right end of the box",
    cross.root.x + 16,
    searchBox.x + searchBox.width - 8
)
check.Equal(
    "the clear cross is centred down the box",
    cross.root.y,
    searchBox.y + math.floor((searchBox.height - 16) / 2)
)
check.Check(
    "typed text stops short of the clear cross",
    searchBox.x + searchBox.width - searchBox.contentMargin.right < cross.root.x,
    searchBox.contentMargin.right
)
check.Equal("the left inset is unchanged", searchBox.contentMargin.left, 8)

FinderFakes.Choose(client, finder.tagBox, "skill")
FinderFakes.Type(client, finder.searchField, "attack")
check.Equal("the clear cross shows as soon as there is text", cross.visible, true)
FinderFakes.TicksUntil(client, function()
    return state.query == "attack"
end, 10)
check.Equal("a search within a tag narrows the results", finder.resultsText.content, "1 match")
local findsBefore = client.stored.rsprite_finder_state.query
check.Equal("the typed query is saved", findsBefore, "attack")
local optionsBefore = { FinderOptions.Current().groupVariants, FinderOptions.Current().hideClutter }
client.Fire(cross.root, "ONMOUSEOVER", 0, 0)
check.Equal(
    "hovering the cross lights it",
    cross.image.spriteID,
    rsprite.Get("RS3_ICON_CLEAR_16PX_1") or -1
)
client.Click(cross.root)
check.Equal("clearing empties the box", searchBox.content, "")
check.Equal("clearing hides the cross", cross.visible, false)
check.Equal("clearing searches straight away", finder.resultsText.content, "4 matches")
check.Equal("clearing empties the query", state.query, "")
check.Equal("clearing keeps the tag", state.tag, "skill")
check.Equal("clearing updates the saved query", client.stored.rsprite_finder_state.query, "")
check.Same(
    "clearing keeps the options",
    { FinderOptions.Current().groupVariants, FinderOptions.Current().hideClutter },
    optionsBefore
)
check.Equal(
    "the cross rests again once hidden",
    cross.image.spriteID,
    rsprite.Get("RS3_ICON_CLEAR_16PX_0") or -1
)
FinderFakes.Type(client, finder.searchField, "pending")
client.Click(cross.root)
for _ = 1, FinderWindow.DEBOUNCE_TICKS + 1 do
    client.FireLogic()
end
check.Equal("clearing cancels a search still waiting to run", state.query, "")
FinderWindow.ClearFilters()

FinderFakes.Type(client, finder.searchField, "zzqqxxnothing")
FinderFakes.TicksUntil(client, function()
    return finder.resultsText.content ~= "153 sprites"
end, 10)
check.Equal("a nonsense word finds nothing", finder.resultsText.content, "0 matches")
FinderWindow.ClearFilters()

FinderFakes.Choose(client, finder.tagBox, "skill")
check.Equal("a tag filters the results", finder.resultsText.content, "4 matches")
FinderFakes.Choose(client, finder.tagBox, FinderWindow.ALL_TAGS)
check.Equal("All tags lifts the filter", finder.resultsText.content, "153 sprites")

for _ = 1, 5 do
    finder.nextButton:Click()
end
check.Equal("the next arrow reaches the last page", finder.pageText.content, "Page 6 of 6")
check.Equal("the next arrow is disabled on the last page", finder.nextButton.disabled, true)
check.Equal("the previous arrow is enabled", finder.previousButton.disabled, false)
check.Equal("the last page shows its few sprites", finder.grid.tiles[3].square.hidden, false)
check.Equal("empty slots on the last page are hidden", finder.grid.tiles[30].square.hidden, true)
local selectedBeforeClose = state.selectedName

finder.window:Close()
check.Equal("closing hides the finder", FinderWindow.IsOpen(), false)
check.Equal("closing stops the search listener", client.subscriptions["rsprite-finder:search"], nil)
local stored = client.stored.rsprite_finder_state
check.Check("closing saves the state", stored ~= nil and stored.page == 6, stored and stored.page)

for _, field in pairs(finder.detail.copyFields) do
    field.component.content = ""
end
check.Equal("opening again reports success", FinderWindow.Open(), true)
check.Equal("opening again reuses the window", prettyuiFake.Logged("Window.new"), 1)
check.Equal("opening again shows the window", prettyuiFake.Logged("Window.Show"), 2)
check.Equal("opening again keeps the page", finder.pageText.content, "Page 6 of 6")
check.Equal("opening again rewrites the Name box", copyText("Name"), selectedBeforeClose)
check.Equal(
    "opening again rewrites the Get box",
    copyText("Get"),
    'rsprite.Get("' .. selectedBeforeClose .. '")'
)
check.Equal(
    "opening again rewrites the Draw box",
    copyText("Draw"),
    'rsprite.Draw(parent, "' .. selectedBeforeClose .. '", { size = 16 })'
)

FinderFakes.Type(client, finder.searchField, "skill")
FinderFakes.TicksUntil(client, function()
    return state.query == "skill"
end, 10)
clickSize(finder, 32)
FinderFakes.Choose(client, finder.tagBox, "skill")
FinderWindow.Destroy()
FinderFakes.ForgetModules()
local ReloadedWindow = require("src/features/finder/finder_window")
check.Equal("a reloaded finder opens", ReloadedWindow.Open(), true)
local reloaded, reloadedState = ReloadedWindow.Parts()
check.Equal("the query is restored", reloadedState.query, "skill")
check.Equal("the search field shows the query", reloaded.searchField.component.content, "skill")
check.Same("the restored size is lit", reloaded.detail.sizeButtons.LitSizes(), { 32 })
check.Equal("the preview size is restored", reloadedState.previewSize, 32)
check.Equal("the preview background is restored", reloadedState.previewBackground, "light")
check.Equal("the restored background is shown", reloaded.detail.backgrounds.light.hidden, false)
check.Equal("the tag is restored", reloadedState.tag, "skill")
check.Equal(
    "the tag box shows the restored tag",
    reloaded.tagBox.component.selectedID,
    reloaded.tagOptions.positionByLabel.skill
)
check.Equal("the selection is restored", reloadedState.selectedName, state.selectedName)
check.Equal("the results come straight back", reloaded.resultsText.content, "4 matches")
check.Equal("no second spinner is needed", prettyuiFake.Logged("Spinner.new"), 1)

ReloadedWindow.Destroy()
check.Finish()
