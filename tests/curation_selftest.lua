selftest.UsePlugin("rsprite")

local Report = require("tests/support/report")

local check = Report.New("curation")
local loaded, Curation = pcall(require, "src/data/curation")
check.Check(
    "the generated curation module loads",
    loaded and type(Curation) == "table",
    tostring(Curation)
)

local function isAscii(text)
    return type(text) == "string" and string.find(text, "[^\32-\126]") == nil
end

local function allAscii(texts)
    for _, text in ipairs(texts or {}) do
        if not isAscii(text) then
            return false, text
        end
    end
    return true, nil
end

local ruleCount = 0
local rulesWithoutTags = {}
local rulesWithoutMatchers = {}
for position, rule in ipairs(Curation.rules) do
    ruleCount = ruleCount + 1
    if type(rule.tags) ~= "table" or #rule.tags == 0 or not allAscii(rule.tags) then
        rulesWithoutTags[#rulesWithoutTags + 1] = position
    end
    if rule.prefix == nil and rule.contains == nil and rule.suffix == nil then
        rulesWithoutMatchers[#rulesWithoutMatchers + 1] = position
    end
end
check.Check("there are tag rules", ruleCount > 0, ruleCount)
check.Same("every rule has ASCII tags", rulesWithoutTags, {})
check.Same("every rule has a prefix, contains or suffix", rulesWithoutMatchers, {})

local badNames = {}
local badAliases = {}
local curatedCount = 0
for name, entry in pairs(Curation.curated) do
    curatedCount = curatedCount + 1
    if not isAscii(name) or string.find(name, "[^A-Z0-9_]") then
        badNames[#badNames + 1] = name
    end
    local aliasesAscii, badAlias = allAscii(entry.aliases)
    if not aliasesAscii then
        badAliases[#badAliases + 1] = name .. " " .. tostring(badAlias)
    end
end
table.sort(badNames)
table.sort(badAliases)
check.Check("there are curated names", curatedCount > 0, curatedCount)
check.Same("every curated name is an ASCII sprite name", badNames, {})
check.Same("every curated alias is ASCII", badAliases, {})

local necromancy = Curation.curated.BP3_MISSION_ICON_SKILL_NECROMANCY
check.Check("Necromancy is curated under its mission icon", necromancy ~= nil, tostring(necromancy))
check.Same(
    "Necromancy has its aliases",
    necromancy and necromancy.aliases or {},
    { "necromancy", "skill necromancy" }
)
check.Same("Attack has its plain alias", Curation.curated.SKILL_ATTACK.aliases, { "attack" })

check.Finish()
