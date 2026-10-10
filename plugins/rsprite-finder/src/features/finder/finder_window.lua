local Client = require("src/services/client")
local DropDown = require("src/components/drop_down")
local DetailPanel = require("src/features/finder/detail_panel")
local Favourites = require("src/features/finder/favourites")
local FinderOptions = require("src/features/finder/finder_options")
local FinderState = require("src/features/finder/finder_state")
local Preferences = require("src/services/preferences")
local SpriteGrid = require("src/features/finder/sprite_grid")
local TagOptions = require("src/features/finder/tag_options")
local TextBox = require("src/components/text_box")
local Theme = require("src/utils/theme")

local FinderWindow = {}

FinderWindow.TITLE = "rsprite finder"
FinderWindow.ALL_TAGS = TagOptions.ALL_TAGS
FinderWindow.DEBOUNCE_TICKS = 5
FinderWindow.PREFERENCES_NAME = "state"
FinderWindow.EMPTY_TITLE = "No sprites match"
FinderWindow.EMPTY_HINT = "Try fewer words, or set the tag back to All tags."
FinderWindow.CLEAR_LABEL = "CLEAR FILTERS"
FinderWindow.LOADING_TEXT = "Reading sprite names"
FinderWindow.NO_FAVOURITES_TITLE = "No favourites yet"
FinderWindow.NO_FAVOURITES_HINT = "Star a sprite to keep it here."
FinderWindow.FAVOURITES_ONLY_TOOLTIP = "Show favourites only"
FinderWindow.CLEAR_SEARCH_TOOLTIP = "Clear search"

local WIDTH = 724
local FRAME_HEIGHT = 40
local SEARCH_PLACEHOLDER = "Search sprites"
local LOGIC_KEY = "rsprite-finder:search"
local EVERY_RESULT = 1000000
local MARGIN = 8
local FIELD_HEIGHT = 28
local TOP_GAP = 8
local SEARCH_WIDTH = 180
local TAG_X = MARGIN + SEARCH_WIDTH + TOP_GAP
local TAG_WIDTH = 132
local FAVOURITES_X = TAG_X + TAG_WIDTH + TOP_GAP
local RESULTS_X = FAVOURITES_X + DetailPanel.CONTROL_SIZE + TOP_GAP
local RESULTS_WIDTH = MARGIN + SpriteGrid.WIDTH - RESULTS_X
local LINE_HEIGHT = 16
local GRID_Y = MARGIN + FIELD_HEIGHT + 10
local PAGING_GAP = 10
local ARROW_SIZE = 24
local PAGE_TEXT_WIDTH = 110
local PAGING_SPACING = 8
local PAGING_WIDTH = ARROW_SIZE + PAGING_SPACING + PAGE_TEXT_WIDTH + PAGING_SPACING + ARROW_SIZE
local PAGING_X = MARGIN + math.floor((SpriteGrid.WIDTH - PAGING_WIDTH) / 2)
local PAGE_TEXT_X = PAGING_X + ARROW_SIZE + PAGING_SPACING
local NEXT_ARROW_X = PAGE_TEXT_X + PAGE_TEXT_WIDTH + PAGING_SPACING
local DETAIL_X = MARGIN + SpriteGrid.WIDTH + 10
local DETAIL_WIDTH = 232
local COLUMN_BOTTOM = math.max(
    MARGIN + DetailPanel.HEIGHT,
    GRID_Y + SpriteGrid.MINIMUM_HEIGHT + PAGING_GAP + ARROW_SIZE
)
local PAGING_Y = COLUMN_BOTTOM - ARROW_SIZE
local GRID_HEIGHT = PAGING_Y - PAGING_GAP - GRID_Y
local CONTENT_HEIGHT = COLUMN_BOTTOM + MARGIN
local HEIGHT = CONTENT_HEIGHT + FRAME_HEIGHT

FinderWindow.COLUMN_BOTTOM = COLUMN_BOTTOM
FinderWindow.PAGING_Y = PAGING_Y
FinderWindow.PAGING_X = PAGING_X
FinderWindow.PAGING_WIDTH = PAGING_WIDTH
FinderWindow.LEFT_COLUMN_X = MARGIN
FinderWindow.DETAIL_X = DETAIL_X
FinderWindow.LEFT_COLUMN_WIDTH = SpriteGrid.WIDTH
FinderWindow.GRID_Y = GRID_Y
FinderWindow.GRID_HEIGHT = GRID_HEIGHT
FinderWindow.PAGING_GAP = PAGING_GAP

FinderWindow.WIDTH = WIDTH
FinderWindow.HEIGHT = HEIGHT
local SPINNER_SIZE = 48
local MESSAGE_WIDTH = SpriteGrid.WIDTH

local finder = nil
local state = nil
local favourites = nil
local pendingQuery = nil
local quietTicks = 0
local ticking = false

local function bodyFont()
    return Client.Font(Theme.BODY_FONT)
end

local function search(query, tag)
    local options = { limit = EVERY_RESULT }
    if tag ~= nil then
        options.tags = { tag }
    end
    return Client.Call("searching sprites", rsprite.Find, query, options) or {}
end

local function save()
    if state ~= nil then
        Preferences.Save(FinderWindow.PREFERENCES_NAME, FinderState.Snapshot(state))
    end
end

local function viewOptions()
    if favourites.only then
        return { favourites = favourites.names }
    end
    return FinderOptions.Current()
end

local function hasNoFavourites()
    return favourites.only
        and state.total == 0
        and (#favourites.names == 0 or (state.query == "" and state.tag == nil))
end

local function setVisible(component, visible)
    Client.Set(component, "hidden", not visible)
end

local function showEmpty(visible)
    local noFavourites = visible and hasNoFavourites()
    Client.Set(
        finder.emptyTitle,
        "content",
        noFavourites and FinderWindow.NO_FAVOURITES_TITLE or FinderWindow.EMPTY_TITLE
    )
    Client.Set(
        finder.emptyHint,
        "content",
        noFavourites and FinderWindow.NO_FAVOURITES_HINT or FinderWindow.EMPTY_HINT
    )
    setVisible(finder.emptyTitle, visible)
    setVisible(finder.emptyHint, visible)
    local wantsClearButton = visible and not noFavourites
    if wantsClearButton and finder.clearButton == nil then
        finder.clearButton = Client.Call(
            "creating the clear filters button",
            prettyui.FancyButton.new,
            finder.content,
            FinderWindow.CLEAR_LABEL,
            function()
                FinderWindow.ClearFilters()
            end,
            { x = MARGIN, y = GRID_Y + 52, variant = "neutral" }
        )
    elseif not wantsClearButton and finder.clearButton ~= nil then
        local button = finder.clearButton
        finder.clearButton = nil
        Client.Call("removing the clear filters button", function()
            button:Destroy()
        end)
    end
end

local function showDetail()
    finder.detail.Show(state.selectedEntry, {
        previewSize = state.previewSize,
        variantStep = FinderState.VariantStep(state),
        starred = Favourites.Contains(favourites, state.selectedName),
        background = state.previewBackground,
    })
end

local function render()
    Client.Set(finder.resultsText, "content", FinderState.ResultsLabel(state, favourites.only))
    Client.Set(finder.pageText, "content", FinderState.PageLabel(state))
    Client.Call("updating the page buttons", function()
        finder.previousButton:SetDisabled(state.page <= 1)
        finder.nextButton:SetDisabled(state.page >= FinderState.PageCount(state))
    end)
    finder.grid.Show(state.tiles, FinderState.SelectedPosition(state))
    showEmpty(state.total == 0)
    showDetail()
end

local function refresh(change)
    if finder == nil or not finder.indexReady then
        return
    end
    FinderState.Refresh(state, search, viewOptions(), change)
    render()
    save()
end

local function applyQuery(query)
    if FinderState.SetQuery(state, query) then
        refresh(FinderState.SEARCH_CHANGED)
    end
end

local function flushPendingQuery()
    if pendingQuery ~= nil then
        local query = pendingQuery
        pendingQuery = nil
        applyQuery(query)
    end
end

local function onLogic()
    if pendingQuery == nil then
        return
    end
    quietTicks = quietTicks + 1
    if quietTicks >= FinderWindow.DEBOUNCE_TICKS then
        flushPendingQuery()
    end
end

local function startTicking()
    if not ticking then
        ticking = Client.Subscribe("Logic", LOGIC_KEY, onLogic)
    end
end

local function stopTicking()
    if ticking then
        Client.Unsubscribe("Logic", LOGIC_KEY)
        ticking = false
    end
end

local function onSearchTyped(text)
    pendingQuery = text or ""
    quietTicks = 0
end

local function onSearchCleared()
    pendingQuery = nil
    quietTicks = 0
    applyQuery("")
end

local function onTagChosen(entryId)
    local tag = TagOptions.TagFor(finder.tagOptions, finder.tagOptions.labels[entryId])
    if FinderState.SetTag(state, tag) then
        refresh(FinderState.SEARCH_CHANGED)
    end
end

local function selectTagInBox()
    local position = TagOptions.PositionFor(finder.tagOptions, state.tag)
    finder.tagBox.Select(position)
end

local function changePage(step)
    if FinderState.SetPage(state, state.page + step) then
        refresh()
    end
end

local function selectPosition(position)
    local tile = state.tiles[position]
    if tile == nil then
        return
    end
    if tile ~= state.selectedTile then
        FinderState.Select(state, tile, 1)
    end
    render()
    save()
end

local function stepVariant(step)
    if FinderState.StepVariant(state, step) then
        showDetail()
        save()
    end
end

local function setPreviewSize(size)
    FinderState.SetPreviewSize(state, size)
    showDetail()
    save()
end

local function cycleBackground()
    finder.detail.ShowBackground(FinderState.CycleBackground(state))
    save()
end

local function setStarred(starred)
    if Favourites.Set(favourites, state.selectedName, starred) then
        Favourites.Save(favourites)
        if favourites.only then
            FinderState.Invalidate(state)
            refresh()
            return
        end
    end
    showDetail()
end

local function setFavouritesOnly(enabled)
    if favourites.only == enabled then
        return
    end
    favourites.only = enabled
    Favourites.Save(favourites)
    FinderState.Invalidate(state)
    refresh(FinderState.OPTIONS_CHANGED)
end

local function showLoading(visible)
    setVisible(finder.loadingText, visible)
    if visible and finder.spinner == nil then
        finder.spinner = Client.Call("creating the spinner", prettyui.Spinner.new, finder.content, {
            x = MARGIN + math.floor((SpriteGrid.WIDTH - SPINNER_SIZE) / 2),
            y = GRID_Y + 40,
            size = SPINNER_SIZE,
        })
    elseif not visible and finder.spinner ~= nil then
        local spinner = finder.spinner
        finder.spinner = nil
        Client.Call("removing the spinner", function()
            spinner:Destroy()
        end)
    end
end

local function onIndexReady()
    if finder == nil then
        return
    end
    finder.indexReady = true
    showLoading(false)
    refresh()
end

local function onClosed()
    flushPendingQuery()
    stopTicking()
    if finder ~= nil then
        finder.visible = false
    end
    save()
end

local function addText(layout)
    layout.font = layout.font or bodyFont()
    layout.colour = layout.colour or Theme.TEXT
    layout.height = layout.height or LINE_HEIGHT
    return Client.NewText(finder.content, layout)
end

local function build()
    local gameArea = Client.GameArea()
    if gameArea == nil then
        return false
    end
    local window = Client.Call("creating the finder window", prettyui.Window.new, gameArea, {
        title = FinderWindow.TITLE,
        x = -math.floor(WIDTH / 2),
        y = -math.floor(HEIGHT / 2),
        xAnchor = 0.5,
        yAnchor = 0.5,
        width = WIDTH,
        height = HEIGHT,
        scrollable = false,
        onClose = onClosed,
    })
    if window == nil then
        return false
    end
    finder = { window = window, content = window.content, indexReady = false }
    local content = finder.content

    finder.searchField = TextBox.New(content, {
        x = MARGIN,
        y = MARGIN,
        width = SEARCH_WIDTH,
        height = FIELD_HEIGHT,
        placeholder = SEARCH_PLACEHOLDER,
        clearTooltip = FinderWindow.CLEAR_SEARCH_TOOLTIP,
    }, onSearchTyped, onSearchCleared)

    finder.tagOptions = TagOptions.Build(Client.Call("reading tags", rsprite.Tags))
    finder.tagBox = DropDown.New(
        content,
        { x = TAG_X, y = MARGIN, width = TAG_WIDTH, height = FIELD_HEIGHT },
        finder.tagOptions.entries,
        TagOptions.PositionFor(finder.tagOptions, state.tag),
        onTagChosen
    )
    finder.favouritesButton = Client.Call(
        "creating the favourites only button",
        prettyui.SpriteButton.new,
        content,
        "STAR",
        function(_, enabled)
            setFavouritesOnly(enabled)
        end,
        {
            x = FAVOURITES_X,
            y = MARGIN + math.floor((FIELD_HEIGHT - DetailPanel.CONTROL_SIZE) / 2),
            size = DetailPanel.CONTROL_SIZE,
            toggleable = true,
            disabled = not favourites.only,
            tooltip = FinderWindow.FAVOURITES_ONLY_TOOLTIP,
        }
    )

    finder.resultsText =
        addText({ x = RESULTS_X, y = MARGIN + 6, width = RESULTS_WIDTH, colour = Theme.MUTED })

    finder.grid =
        SpriteGrid.New(content, { x = MARGIN, y = GRID_Y, height = GRID_HEIGHT }, selectPosition)

    finder.previousButton = Client.Call(
        "creating the previous page button",
        prettyui.SpriteButton.new,
        content,
        "ARROW_LEFT",
        function()
            changePage(-1)
        end,
        { x = PAGING_X, y = PAGING_Y, size = ARROW_SIZE }
    )
    finder.pageText = addText({
        x = PAGE_TEXT_X,
        y = PAGING_Y + 4,
        width = PAGE_TEXT_WIDTH,
        centred = true,
    })
    finder.nextButton = Client.Call(
        "creating the next page button",
        prettyui.SpriteButton.new,
        content,
        "ARROW_RIGHT",
        function()
            changePage(1)
        end,
        { x = NEXT_ARROW_X, y = PAGING_Y, size = ARROW_SIZE }
    )

    finder.detail = DetailPanel.New(content, { x = DETAIL_X, y = MARGIN, width = DETAIL_WIDTH }, {
        onPreviewSize = setPreviewSize,
        onStepVariant = stepVariant,
        onStar = setStarred,
        onCycleBackground = cycleBackground,
    })

    finder.loadingText = addText({
        x = MARGIN,
        y = GRID_Y + 40 + SPINNER_SIZE + 8,
        width = MESSAGE_WIDTH,
        text = FinderWindow.LOADING_TEXT,
        centred = true,
        hidden = true,
    })
    finder.emptyTitle = addText({
        x = MARGIN,
        y = GRID_Y + 8,
        width = MESSAGE_WIDTH,
        text = FinderWindow.EMPTY_TITLE,
        colour = Theme.GOLD,
        hidden = true,
    })
    finder.emptyHint = addText({
        x = MARGIN,
        y = GRID_Y + 28,
        width = MESSAGE_WIDTH,
        text = FinderWindow.EMPTY_HINT,
        colour = Theme.MUTED,
        hidden = true,
    })
    return true
end

local function restoreFields()
    finder.searchField.SetText(state.query)
    selectTagInBox()
    finder.detail.WriteCopyFields()
end

function FinderWindow.Open()
    if rsprite == nil or prettyui == nil then
        Client.Warn("dependencies", "the finder needs both rsprite and PrettyUI enabled")
        return false
    end
    if state == nil then
        state = FinderState.New(Preferences.Load(FinderWindow.PREFERENCES_NAME))
    end
    if favourites == nil then
        favourites = Favourites.Load()
    end
    if finder == nil and not build() then
        return false
    end
    Client.Call("showing the finder", function()
        finder.window:Show()
    end)
    finder.visible = true
    restoreFields()
    startTicking()
    if finder.indexReady then
        refresh()
    elseif Client.Call("checking the sprite index", rsprite.IsIndexReady) then
        onIndexReady()
    elseif not finder.loading then
        finder.loading = true
        finder.grid.Hide()
        showLoading(true)
        Client.Call("reading sprite names", rsprite.BuildIndex, onIndexReady)
    end
    return true
end

function FinderWindow.ClearFilters()
    pendingQuery = nil
    finder.searchField.SetText("")
    FinderState.ClearFilters(state)
    selectTagInBox()
    refresh(FinderState.SEARCH_CHANGED)
end

function FinderWindow.OptionsChanged()
    if state == nil then
        return
    end
    FinderState.Invalidate(state)
    refresh(FinderState.OPTIONS_CHANGED)
end

function FinderWindow.IsOpen()
    return finder ~= nil and finder.visible == true
end

function FinderWindow.Parts()
    return finder, state
end

function FinderWindow.Destroy()
    stopTicking()
    save()
    if finder ~= nil then
        local window = finder.window
        finder = nil
        Client.Call("destroying the finder window", function()
            window:Destroy()
        end)
    end
    state = nil
    favourites = nil
    pendingQuery = nil
end

return FinderWindow
