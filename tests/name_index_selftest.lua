selftest.UsePlugin("rsprite")

local ClientFakes = require("tests/support/client_fakes")
local Report = require("tests/support/report")

local SOURCE = "tests/name_index_selftest.lua:"
local LAST_BEFORE_GAP = 1000
local FIRST_AFTER_GAP = 1500
local HIGHEST_ID = 4500

local check = Report.New("name index")

local function gappedSprites()
    local sprites = {}
    for spriteId = 0, HIGHEST_ID do
        if spriteId <= LAST_BEFORE_GAP or spriteId >= FIRST_AFTER_GAP then
            sprites[#sprites + 1] = { spriteId, "NAME_" .. spriteId }
        end
    end
    return sprites
end

local function freshIndex()
    local client = ClientFakes.Install({ sprites = gappedSprites() })
    local app = ClientFakes.LoadRsprite()
    return client, app, require("src/features/search/name_index")
end

local function sameEntries(first, second)
    if #first.names ~= #second.names then
        return false
    end
    for position = 1, #first.names do
        if
            first.names[position] ~= second.names[position]
            or first.ids[position] ~= second.ids[position]
        then
            return false
        end
    end
    return true
end

local client, app, NameIndex = freshIndex()
check.Equal("the index is not ready before anything asks for it", app.Public.IsIndexReady(), false)
local synchronous = NameIndex.Entries()
local expectedNames = (LAST_BEFORE_GAP + 1) + (HIGHEST_ID - FIRST_AFTER_GAP + 1)
check.Equal("the synchronous walk finds every name", #synchronous.names, expectedNames)
check.Equal(
    "a gap of 499 inside the range does not stop the walk",
    synchronous.ids[LAST_BEFORE_GAP + 2],
    FIRST_AFTER_GAP
)
check.Equal("the last id found is the highest one", synchronous.ids[#synchronous.ids], HIGHEST_ID)
check.Equal(
    "the walk stops after 500 consecutive nils past the highest hit",
    client.fromIdCalls,
    HIGHEST_ID + NameIndex.CONSECUTIVE_NIL_LIMIT + 1
)
check.Equal("the synchronous walk subscribes to nothing", client.SubscriptionCount(), 0)
check.Equal("the index is ready afterwards", app.Public.IsIndexReady(), true)

client, app, NameIndex = freshIndex()
local readyCount = 0
local readyNames = nil
app.Public.BuildIndex(function(count)
    readyCount = readyCount + 1
    readyNames = count
end)
check.Equal("BuildIndex subscribes to Logic", client.SubscriptionCount(), 1)
check.Equal("BuildIndex makes no FromID calls until the first tick", client.fromIdCalls, 0)

local callsPerTick = {}
local ticks = 0
while client.SubscriptionCount() > 0 and ticks < 20 do
    local before = client.fromIdCalls
    client.FireLogic()
    ticks = ticks + 1
    callsPerTick[#callsPerTick + 1] = client.fromIdCalls - before
end
check.Same("the chunked walk reads 2,000 ids per tick", callsPerTick, { 2000, 2000, 1001 })
check.Equal("onReady fires once", readyCount, 1)
check.Equal("onReady is given the name count", readyNames, expectedNames)
check.Equal("the Logic subscription is removed when done", client.SubscriptionCount(), 0)
client.FireLogic()
check.Equal("onReady does not fire again on later ticks", readyCount, 1)

local chunked = NameIndex.Entries()
check.Check(
    "synchronous and chunked walks build identical indexes",
    sameEntries(synchronous, chunked),
    #chunked.names
)

local lateReadyCount = 0
app.Public.BuildIndex(function()
    lateReadyCount = lateReadyCount + 1
end)
check.Equal("BuildIndex on a ready index calls onReady straight away", lateReadyCount, 1)
check.Equal("BuildIndex on a ready index subscribes to nothing", client.SubscriptionCount(), 0)

client, app, NameIndex = freshIndex()
local interruptedReady = 0
app.Public.BuildIndex(function()
    interruptedReady = interruptedReady + 1
end)
client.FireLogic()
local finishedEarly = NameIndex.Entries()
check.Equal(
    "a synchronous request mid build finishes the walk",
    #finishedEarly.names,
    expectedNames
)
check.Equal("a synchronous request mid build fires onReady once", interruptedReady, 1)
check.Equal(
    "a synchronous request mid build removes the subscription",
    client.SubscriptionCount(),
    0
)

client, app = freshIndex()
local shutdownReady = 0
app.Public.BuildIndex(function()
    shutdownReady = shutdownReady + 1
end)
client.FireLogic()
app.Shutdown()
check.Equal("shutdown removes the Logic subscription", client.SubscriptionCount(), 0)
check.Equal("shutdown leaves the index unbuilt", app.Public.IsIndexReady(), false)
check.Equal("shutdown drops pending onReady callbacks", shutdownReady, 0)

client, app = freshIndex()
check.Equal("Find builds the index when nothing has yet", app.Public.IsIndexReady(), false)
local _, total = app.Public.Find("NAME_45")
check.Check("Find searched the whole index", total > 0, total)
check.Equal("Find left the index ready", app.Public.IsIndexReady(), true)
check.Equal("Find built it without subscribing", client.SubscriptionCount(), 0)

client, app = freshIndex()
local goodCalls = 0
local failingCalls = 0
local function failingCallback()
    failingCalls = failingCalls + 1
    error("the consumer broke")
end
app.Public.BuildIndex(failingCallback)
app.Public.BuildIndex(function()
    goodCalls = goodCalls + 1
end)
for _ = 1, 10 do
    client.FireLogic()
end
check.Equal("a failing callback is called once", failingCalls, 1)
check.Equal("a failing callback does not stop the next one", goodCalls, 1)
check.Equal("a failing callback does not stop the index finishing", app.Public.IsIndexReady(), true)
check.Equal(
    "a failing callback is reported once",
    client.WarningsMentioning("rsprite.BuildIndex"),
    1
)
check.Check(
    "the warning says the BuildIndex callback raised and was skipped",
    client.WarningsMentioning(
        "the function passed to rsprite.BuildIndex raised an error and was skipped"
    ) == 1,
    client.warnings[#client.warnings]
)
check.Equal(
    "the warning includes the error text",
    client.WarningsMentioning("the consumer broke"),
    1
)

app.Public.BuildIndex(failingCallback)
check.Equal("a callback that failed is never called again", failingCalls, 1)
check.Equal(
    "skipping it again prints nothing new",
    client.WarningsMentioning("rsprite.BuildIndex"),
    1
)

app.Public.BuildIndex(function()
    error("a different problem")
end)
check.Equal(
    "a different failure is reported too",
    client.WarningsMentioning("rsprite.BuildIndex"),
    2
)
check.Equal(
    "the second warning carries its own error text",
    client.WarningsMentioning("a different problem"),
    1
)

check.Raises("a non-function onReady raises", function()
    app.Public.BuildIndex("soon")
end, "rsprite.BuildIndex: onReady must be a function, got string", SOURCE)

check.Finish()
