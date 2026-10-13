selftest.UsePlugin("rsprite-finder")

local FinderFakes = require("tests/support/finder_fakes")

local PAGE_COUNT = 40
local EVERY_RESULT = 1000000
local SETTINGS = {
    { name = "both options on", options = { groupVariants = true, hideClutter = true } },
    { name = "grouping off", options = { groupVariants = false, hideClutter = true } },
    { name = "hiding copies off", options = { groupVariants = true, hideClutter = false } },
    { name = "both options off", options = { groupVariants = false, hideClutter = false } },
}

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

FinderFakes.Install({ sprites = catalogueSprites() })
local FinderState = require("src/features/finder/finder_state")
local ResultList = require("src/features/finder/result_list")

local entries = rsprite.Find("", { limit = EVERY_RESULT })
print(table.concat({ "pages", PAGE_COUNT, FinderState.PAGE_SIZE }, "\t"))
for settingPosition, setting in ipairs(SETTINGS) do
    print(table.concat({ "setting", settingPosition, setting.name }, "\t"))
    local list = ResultList.Build(entries, setting.options)
    for page = 1, PAGE_COUNT do
        for position = 1, FinderState.PAGE_SIZE do
            local tile = list.tiles[(page - 1) * FinderState.PAGE_SIZE + position]
            if tile ~= nil then
                print(
                    table.concat(
                        { "tile", settingPosition, page, position, tile.members[1].id, tile.name },
                        "\t"
                    )
                )
            end
        end
    end
end
