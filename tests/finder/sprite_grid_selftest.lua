local FinderFakes = require("tests/support/finder_fakes")
local Report = require("tests/support/report")

local check = Report.New("sprite grid")
local client, prettyuiFake = FinderFakes.Install()
local ResultList = require("src/features/finder/result_list")
local SpriteGrid = require("src/features/finder/sprite_grid")

local function pageOf(offset)
    local entries, total = rsprite.Find("", { offset = offset, limit = 30 })
    return ResultList.Build(entries, {}).tiles, total
end

local function countLog(prefix)
    local count = 0
    for _, line in ipairs(client.log) do
        if string.sub(line, 1, #prefix) == prefix then
            count = count + 1
        end
    end
    return count
end

local parent = client.NewComponent("layer")
local spritesBefore = #client.sprites
local textsBefore = #client.ComponentsOfKind("text")
local selected = nil
client.ClearLog()
local grid = SpriteGrid.New(parent, { x = 0, y = 0 }, function(position)
    selected = position
end)
check.Equal("the grid has 6 columns and 5 rows", SpriteGrid.COLUMNS * SpriteGrid.ROWS, 30)
check.Equal("30 tiles are built", #grid.tiles, 30)
check.Equal("30 tile sprites are created once", #client.sprites - spritesBefore, 30)
check.Equal("tiles have no name captions", #client.ComponentsOfKind("text") - textsBefore, 0)
local expectedX = math.floor((SpriteGrid.TILE_WIDTH - SpriteGrid.SPRITE_SIZE) / 2)
local expectedY = math.floor((SpriteGrid.TILE_HEIGHT - SpriteGrid.SPRITE_SIZE) / 2)
check.Equal(
    "the first sprite is centred in its tile",
    client.log[1],
    string.format("SetPos %d %d 0 0", expectedX, expectedY)
)

local firstPage, total = pageOf(0)
grid.Show(firstPage, 2)
check.Equal("every shown tile gets a tooltip", #prettyuiFake.tooltips, 30)
local tooltip = grid.tiles[1].tooltip
check.Equal("a tooltip holds the full sprite name", tooltip.text, firstPage[1].name)
check.Equal("a tooltip targets its tile square", tooltip.target, grid.tiles[1].square)
check.Equal("a tooltip is drawn on the tile's own layer", tooltip.parent, parent)

local spritesAfterFirstPage = #client.sprites
local componentsAfterFirstPage = #client.components
client.ClearLog()
local destroyedBefore = client.destroyedComponents

local secondPage = pageOf(30)
grid.Show(secondPage, nil)
check.Equal("a page change creates no sprites", #client.sprites, spritesAfterFirstPage)
check.Equal(
    "a page change creates no other components",
    #client.components,
    componentsAfterFirstPage
)
check.Equal("a page change creates no tooltips", #prettyuiFake.tooltips, 30)
check.Equal("a page change destroys no sprites", countLog("Destroy"), 0)
check.Equal(
    "a page change destroys no other components",
    client.destroyedComponents,
    destroyedBefore
)
check.Equal(
    "tile sprites are re-pointed at the new page",
    grid.tiles[1].sprite.sprite,
    rsprite.Get(secondPage[1].name)
)
check.Equal("tooltips follow the new page", grid.tiles[1].tooltip.text, secondPage[1].name)

local lastPageNumber = math.ceil(total / 30)
local lastPage = pageOf((lastPageNumber - 1) * 30)
grid.Show(lastPage, nil)
local filled = #lastPage
local emptyHidden = true
for position = filled + 1, 30 do
    local tile = grid.tiles[position]
    if not (tile.square.hidden and tile.border.hidden and tile.sprite.hidden) then
        emptyHidden = false
    end
end
check.Check("the last page is partial", filled > 0 and filled < 30, filled)
check.Check("empty slots on the last page are hidden", emptyHidden, 30 - filled)
check.Check(
    "filled slots on the last page are shown",
    grid.tiles[filled].square.hidden == false and grid.tiles[filled].sprite.hidden == false,
    filled
)

grid.Show(firstPage, 3)
local highlighted = {}
for position, tile in ipairs(grid.tiles) do
    if tile.border.hidden == false then
        highlighted[#highlighted + 1] = position
    end
end
check.Same("only the selected tile has its border", highlighted, { 3 })

client.Click(grid.tiles[5].square)
check.Equal("clicking a tile selects it", selected, 5)

local family = ResultList.Build({
    { name = "SKILL_ATTACK" },
    { name = "ATTACKING_RETICULE_FRAME_2" },
    { name = "ATTACKING_RETICULE_FRAME_1" },
    { name = "ATTACKING_RETICULE_FRAME_3" },
}, { groupVariants = true }).tiles
grid.Show(family, 2)
check.Equal(
    "a family tile's tooltip names the family with its count",
    grid.tiles[2].tooltip.text,
    "ATTACKING_RETICULE_FRAME (3 variants)"
)
check.Equal(
    "a single sprite keeps its own name as the tooltip",
    grid.tiles[1].tooltip.text,
    "SKILL_ATTACK"
)
check.Equal("a family takes one tile", grid.tiles[3].square.hidden, true)

check.Finish()
