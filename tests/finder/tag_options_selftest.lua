local Report = require("tests/support/report")
local TagOptions = require("src/features/finder/tag_options")

local check = Report.New("tag options")

local tags = { "skill", "ability", "achievement", "map icon", "arrow", "icon", "skill" }
local options = TagOptions.Build(tags)

local sortedLabels =
    { TagOptions.ALL_TAGS, "ability", "achievement", "arrow", "icon", "map icon", "skill" }
local byteOrdered =
    { TagOptions.ALL_TAGS, "ability", "achievement", "arrow", "icon", "map icon", "skill" }
table.sort(byteOrdered)
check.Same("labels are in the same order a plain sort gives", options.labels, byteOrdered)
check.Same("All tags is the first entry", options.labels, sortedLabels)

local positionsMatch = true
for position, entry in ipairs(options.entries) do
    if entry.id ~= position or entry.label ~= options.labels[position] then
        positionsMatch = false
    end
end
check.Check("every entry's id is its position", positionsMatch, #options.entries)
check.Equal("repeated tags appear once", #options.entries, 7)

check.Equal("All tags maps to no tag", TagOptions.TagFor(options, TagOptions.ALL_TAGS), nil)
check.Equal("a label maps back to its real tag", TagOptions.TagFor(options, "map icon"), "map icon")
check.Equal("no tag selects All tags", TagOptions.PositionFor(options, nil), 1)
check.Equal("a tag selects its own position", TagOptions.PositionFor(options, "skill"), 7)
check.Equal("an unknown tag falls back to All tags", TagOptions.PositionFor(options, "gone"), 1)
check.Equal("no tags at all still offers All tags", #TagOptions.Build(nil).entries, 1)

check.Finish()
