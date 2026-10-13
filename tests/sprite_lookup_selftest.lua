local ClientFakes = require("tests/support/client_fakes")
local Report = require("tests/support/report")

local SOURCE = "tests/sprite_lookup_selftest.lua:"

local check = Report.New("sprite lookup")
local client = ClientFakes.Install()
local rsprite = ClientFakes.LoadRsprite().Public

check.Equal("a known name gives its id", rsprite.Get("SKILL_ATTACK"), 9318)
check.Equal("an unknown name gives nil", rsprite.Get("NOT_A_SPRITE"), nil)
check.Equal("lower case input resolves", rsprite.Get("skill_herblore"), 9329)
check.Equal("mixed case input resolves", rsprite.Get("Skill_Magic"), 33454)

local neverMinusOne = true
for _, name in ipairs({ "NOT_A_SPRITE", "ALSO_MISSING", "", "SKILL_ATTACK" }) do
    local result = rsprite.Get(name)
    if result == -1 then
        neverMinusOne = false
    end
end
check.Check("Get never returns -1", neverMinusOne, "checked hits, misses and empty names")

local lookupsBefore = client.lookups
local warningsBeforeTypes = #client.warnings
check.Equal("nil gives nil", rsprite.Get(nil), nil)
check.Equal("an empty string gives nil", rsprite.Get(""), nil)
check.Equal("nil and empty names make no client calls", client.lookups, lookupsBefore)
check.Equal("nil and empty names warn about nothing", #client.warnings, warningsBeforeTypes)
check.Raises("a number name raises", function()
    rsprite.Get(9318)
end, "rsprite.Get: name must be a string, got number", SOURCE)
check.Raises("a table name raises", function()
    rsprite.Get({})
end, "rsprite.Get: name must be a string, got table", SOURCE)
check.Raises("a boolean name raises", function()
    rsprite.Get(false)
end, "rsprite.Get: name must be a string, got boolean", SOURCE)
check.Equal("names of the wrong type make no client calls", client.lookups, lookupsBefore)

lookupsBefore = client.lookups
rsprite.Get("SKILL_ATTACK")
rsprite.Get("skill_attack")
rsprite.Get("NOT_A_SPRITE")
rsprite.Get("not_a_sprite")
check.Equal(
    "repeat lookups of a hit and a miss make no further client calls",
    client.lookups,
    lookupsBefore
)
check.Equal(
    "an unknown name warns once however often it is asked for",
    client.WarningsMentioning("NOT_A_SPRITE"),
    1
)

client.raiseOnLookup = true
local warningsBefore = #client.warnings
lookupsBefore = client.lookups
local raisingName = "BP3_MISSION_ICON_SKILL_NECROMANCY"
check.Equal("a raising client gives nil", rsprite.Get(raisingName), nil)
check.Equal("a raising client gives nil again", rsprite.Get(raisingName), nil)
check.Equal("a failed lookup is tried again", client.lookups - lookupsBefore, 2)
check.Equal("a raising client prints one warning", #client.warnings - warningsBefore, 1)
client.raiseOnLookup = false
check.Equal("the name resolves once the client stops raising", rsprite.Get(raisingName), 6910)

check.Equal("Name gives the name of a known id", rsprite.Name(9318), "SKILL_ATTACK")
check.Equal("Name of a gap gives nil", rsprite.Name(3), nil)
check.Equal("Name of an id past the end gives nil", rsprite.Name(36637), nil)

local fromIdBefore = client.fromIdCalls
check.Equal("Name rejects 1.5", rsprite.Name(1.5), nil)
check.Equal("Name rejects -1", rsprite.Name(-1), nil)
check.Equal("Name rejects nan", rsprite.Name(0 / 0), nil)
check.Equal("Name of nil gives nil", rsprite.Name(nil), nil)
check.Raises('Name of "9318" raises', function()
    rsprite.Name("9318")
end, "rsprite.Name: id must be a number, got string", SOURCE)
check.Raises("Name of a table raises", function()
    rsprite.Name({})
end, "rsprite.Name: id must be a number, got table", SOURCE)
check.Equal("rejected ids make no FromID calls", client.fromIdCalls, fromIdBefore)

fromIdBefore = client.fromIdCalls
rsprite.Name(9318)
rsprite.Name(3)
check.Equal("repeat Name lookups of a hit and a miss are cached", client.fromIdCalls, fromIdBefore)

client.raiseOnFromId = true
warningsBefore = #client.warnings
fromIdBefore = client.fromIdCalls
check.Equal("a raising FromID gives nil", rsprite.Name(9329), nil)
check.Equal("a raising FromID gives nil again", rsprite.Name(9329), nil)
check.Equal("a failed Name lookup is tried again", client.fromIdCalls - fromIdBefore, 2)
check.Equal("a raising FromID prints one warning", #client.warnings - warningsBefore, 1)
client.raiseOnFromId = false
check.Equal("the id resolves once FromID stops raising", rsprite.Name(9329), "SKILL_HERBLORE")

check.Equal("a whole float id is accepted", rsprite.Name(9329.0), "SKILL_HERBLORE")

check.Finish()
