local Client = require("src/services/client")

local Stage = {}

Stage.COLUMNS = 6
Stage.ROWS = 5
Stage.TILE_SIZE = 32
Stage.PREVIEW_SIZE = 64

local STAGE_X = 80
local STAGE_Y = 80
local CELL = 40
local INSET = 8
local HEADER_HEIGHT = 24
local GRID_WIDTH = Stage.COLUMNS * CELL
local GRID_HEIGHT = Stage.ROWS * CELL
local SINGLE_X = INSET + GRID_WIDTH + INSET
local STATUS_HEIGHT = 16
local WIDTH = SINGLE_X + Stage.PREVIEW_SIZE + INSET
local HEIGHT = HEADER_HEIGHT + GRID_HEIGHT + STATUS_HEIGHT + INSET
local BACKGROUND_COLOUR = 0x1A1A1AF0
local TEXT_COLOUR = 0xFFFFFFFF
local TITLE = "rsprite sprite probe"

local parts = nil

local function build()
    local gameArea = Client.GameArea()
    if gameArea == nil then
        return nil
    end
    local root =
        Client.NewLayer(gameArea, { x = STAGE_X, y = STAGE_Y, width = WIDTH, height = HEIGHT })
    if root == nil then
        return nil
    end
    local built = { root = root, grid = {} }
    Client.NewRectangle(root, { width = WIDTH, height = HEIGHT, colour = BACKGROUND_COLOUR })
    Client.NewText(
        root,
        { x = INSET, y = 4, width = GRID_WIDTH, height = 16, text = TITLE, colour = TEXT_COLOUR }
    )
    built.status = Client.NewText(root, {
        x = INSET,
        y = HEADER_HEIGHT + GRID_HEIGHT,
        width = WIDTH - 2 * INSET,
        height = STATUS_HEIGHT,
        colour = TEXT_COLOUR,
    })
    for position = 1, Stage.COLUMNS * Stage.ROWS do
        local column = (position - 1) % Stage.COLUMNS
        local row = math.floor((position - 1) / Stage.COLUMNS)
        built.grid[position] = Client.NewSprite(root, {
            x = INSET + column * CELL,
            y = HEADER_HEIGHT + row * CELL,
            size = Stage.TILE_SIZE,
        })
    end
    built.tile = Client.NewSprite(root, { x = SINGLE_X, y = HEADER_HEIGHT, size = Stage.TILE_SIZE })
    built.preview = Client.NewSprite(root, {
        x = SINGLE_X,
        y = HEADER_HEIGHT + CELL,
        size = Stage.PREVIEW_SIZE,
    })
    return built
end

function Stage.Ensure()
    if parts == nil then
        parts = build()
    end
    return parts ~= nil
end

function Stage.SetStatus(text)
    if parts ~= nil then
        Client.Set(parts.status, "content", text)
    end
end

function Stage.ShowTile(name)
    if parts ~= nil then
        Client.ShowSprite(parts.tile, name)
    end
end

function Stage.ShowPreview(name)
    if parts ~= nil then
        Client.ShowSprite(parts.preview, name)
    end
end

function Stage.ShowGrid(entries)
    if parts == nil then
        return
    end
    for position, sprite in ipairs(parts.grid) do
        local entry = entries[position]
        if entry == nil then
            Client.HideSprite(sprite)
        else
            Client.ShowSprite(sprite, entry.name)
        end
    end
end

function Stage.Clear()
    if parts == nil then
        return
    end
    for _, sprite in ipairs(parts.grid) do
        Client.HideSprite(sprite)
    end
    Client.HideSprite(parts.tile)
    Client.HideSprite(parts.preview)
end

function Stage.Destroy()
    if parts == nil then
        return
    end
    local root = parts.root
    parts = nil
    Client.Destroy(root)
end

function Stage.Parts()
    return parts
end

return Stage
