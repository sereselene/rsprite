selftest.UsePlugin("rsprite")

local ClientFakes = require("tests/support/client_fakes")
local Report = require("tests/support/report")

local SOURCE = "tests/sprite_search_selftest.lua:"

local FIXTURE_SPRITES = {
    { 10, "ATTACK" },
    { 11, "ATTACK_LONGER_NAME" },
    { 12, "ATTACK_ICOM" },
    { 13, "ATTACK_ICON" },
    { 14, "ATTACK_CURATED_LONG" },
    { 15, "SKILL_ATTACK" },
    { 16, "COMBAT_STYLE" },
    { 17, "SWORD_THING" },
    { 18, "BIG_ATTACK_ICON" },
    { 19, "COUNTERATTACKER" },
    { 20, "ICON_QUEST_15PX" },
    { 21, "BUTTON_30PX_ON" },
    { 22, "SIZED_BY_HAND" },
    { 23, "UNRELATED_NAME" },
    { 24, "ARROW_UP" },
    { 25, "LEFT_POINTER" },
}

local FIXTURE_CURATION = {
    rules = {
        { prefix = "SWORD_", tags = { "attack" } },
        { contains = "ICON", tags = { "icon" } },
        { prefix = "BUTTON_", tags = { "button", "big button" } },
    },
    curated = {
        SKILL_ATTACK = { tags = { "skill" }, aliases = { "attack" } },
        COMBAT_STYLE = { tags = {}, aliases = { "attack style" } },
        ATTACK_CURATED_LONG = { tags = { "curated" }, aliases = {} },
        SIZED_BY_HAND = { tags = {}, aliases = { "hand sized" }, width = 40, height = 20 },
        LEFT_POINTER = { tags = {}, aliases = { "arrow left" } },
    },
}

local check = Report.New("sprite search")
ClientFakes.Install({ sprites = FIXTURE_SPRITES })
local rsprite = ClientFakes.LoadRsprite(FIXTURE_CURATION).Public

local function namesOf(entries)
    local names = {}
    for position, entry in ipairs(entries) do
        names[position] = entry.name
    end
    return names
end

local function firstNamed(entries, name)
    for _, entry in ipairs(entries) do
        if entry.name == name then
            return entry
        end
    end
    return nil
end

local attackOrder = {
    "ATTACK",
    "SKILL_ATTACK",
    "COMBAT_STYLE",
    "ATTACK_CURATED_LONG",
    "ATTACK_ICOM",
    "ATTACK_ICON",
    "ATTACK_LONGER_NAME",
    "SWORD_THING",
    "BIG_ATTACK_ICON",
    "COUNTERATTACKER",
}

local entries, total = rsprite.Find("attack")
check.Same(
    "ranking runs exact name, exact alias, name or alias prefix, tag, whole word, substring",
    namesOf(entries),
    attackOrder
)
check.Equal("the total counts every match", total, #attackOrder)

local skillAttack = firstNamed(entries, "SKILL_ATTACK")
check.Equal("an entry carries its live id", skillAttack.id, 15)
check.Same("an entry carries curated tags", skillAttack.tags, { "skill" })
check.Same("an entry carries curated aliases", skillAttack.aliases, { "attack" })
check.Same("an entry carries rule tags", firstNamed(entries, "SWORD_THING").tags, { "attack" })
check.Equal("an entry without a known size has no width", skillAttack.width, nil)

local spaced = namesOf((rsprite.Find("skill attack")))
local underscored = namesOf((rsprite.Find("Skill_Attack")))
local hyphenated = namesOf((rsprite.Find("SKILL-ATTACK")))
check.Equal("a spaced query puts the exact name first", spaced[1], "SKILL_ATTACK")
check.Same("spaces and underscores search the same", underscored, spaced)
check.Same("hyphens and underscores search the same", hyphenated, spaced)

entries = rsprite.Find("arrow")
check.Same(
    "a curated alias prefix outranks a shorter uncurated name prefix",
    namesOf(entries),
    { "LEFT_POINTER", "ARROW_UP" }
)

entries, total = rsprite.Find("attack icon")
check.Same("every word has to match", namesOf(entries), { "ATTACK_ICON", "BIG_ATTACK_ICON" })
check.Equal("the multi word total is the AND count", total, 2)

entries = rsprite.Find("hand")
check.Same("aliases are searched", namesOf(entries), { "SIZED_BY_HAND" })

entries = rsprite.Find("big")
check.Same(
    "multi word tags match on any word",
    namesOf(entries),
    { "BIG_ATTACK_ICON", "BUTTON_30PX_ON" }
)

entries, total = rsprite.Find("", { tags = { "attack" } })
check.Same("a tag filter keeps only tagged names", namesOf(entries), { "SWORD_THING" })
check.Equal("a tag filter total", total, 1)

entries = rsprite.Find("", { tags = { "icon" } })
check.Same(
    "an empty query lists the tag ordered by length then id",
    namesOf(entries),
    { "ATTACK_ICON", "BIG_ATTACK_ICON", "ICON_QUEST_15PX" }
)

entries = rsprite.Find("attack", { tags = { "skill" } })
check.Same("a tag filter narrows a query", namesOf(entries), { "SKILL_ATTACK" })

entries, total = rsprite.Find("attack", { limit = 3, offset = 2 })
check.Same(
    "limit and offset page through the ranking",
    namesOf(entries),
    { attackOrder[3], attackOrder[4], attackOrder[5] }
)
check.Equal("the total ignores paging", total, #attackOrder)

entries = rsprite.Find("attack", { limit = 0 })
check.Equal("a limit of 0 returns nothing", #entries, 0)

entries = rsprite.Find("ICON_QUEST_15PX")
check.Equal("a _15PX name gets width 15", entries[1].width, 15)
check.Equal("a _15PX name gets height 15", entries[1].height, 15)
entries = rsprite.Find("button 30px")
check.Equal("a _30PX_ name in the middle gets its size", entries[1].width, 30)
entries = rsprite.Find("sized by hand")
check.Equal("a curated width wins", entries[1].width, 40)
check.Equal("a curated height wins", entries[1].height, 20)

entries, total = rsprite.Find("")
check.Equal("an empty query browses every sprite", total, #FIXTURE_SPRITES)
check.Same("browsing lists curated sprites first, then everything by id", namesOf(entries), {
    "ATTACK_CURATED_LONG",
    "SKILL_ATTACK",
    "COMBAT_STYLE",
    "SIZED_BY_HAND",
    "LEFT_POINTER",
    "ATTACK",
    "ATTACK_LONGER_NAME",
    "ATTACK_ICOM",
    "ATTACK_ICON",
    "SWORD_THING",
    "BIG_ATTACK_ICON",
    "COUNTERATTACKER",
    "ICON_QUEST_15PX",
    "BUTTON_30PX_ON",
    "UNRELATED_NAME",
    "ARROW_UP",
})
entries = rsprite.Find("", { offset = 4, limit = 3 })
check.Same(
    "browsing pages like any search",
    namesOf(entries),
    { "LEFT_POINTER", "ATTACK", "ATTACK_LONGER_NAME" }
)
entries, total = rsprite.Find("", { tags = { "icon" } })
check.Same(
    "browsing respects the tag filter in id order",
    namesOf(entries),
    { "ATTACK_ICON", "BIG_ATTACK_ICON", "ICON_QUEST_15PX" }
)
check.Equal("browsing a tag counts only that tag", total, 3)

local tags = rsprite.Tags()
check.Same("Tags lists every rule and curated tag once, sorted", tags, {
    "attack",
    "big button",
    "button",
    "curated",
    "icon",
    "skill",
})
tags[1] = "changed"
check.Equal("Tags hands back a fresh list each time", rsprite.Tags()[1], "attack")

entries, total = rsprite.Find("nothing matches this")
check.Check("no match gives an empty list and a total of 0", #entries == 0 and total == 0, total)

check.Raises("a nil query raises", function()
    rsprite.Find(nil)
end, "rsprite.Find: text must be a string, got nil", SOURCE)
check.Raises("a negative limit raises", function()
    rsprite.Find("attack", { limit = -1 })
end, "rsprite.Find: option limit must be a whole number 0 or above, got -1", SOURCE)
check.Raises("a fractional offset raises", function()
    rsprite.Find("attack", { offset = 1.5 })
end, "rsprite.Find: option offset must be a whole number 0 or above, got 1.5", SOURCE)
check.Raises("a non-string tag raises", function()
    rsprite.Find("attack", { tags = { 1 } })
end, "rsprite.Find: option tags must be an array of strings, got number at position 1", SOURCE)
check.Raises("an unknown option raises", function()
    rsprite.Find("attack", { colour = 1 })
end, "rsprite.Find: unknown option colour", SOURCE)

check.Finish()
