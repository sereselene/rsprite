local ClientFakes = require("tests/support/client_fakes")
local Report = require("tests/support/report")

local check = Report.New("isolation")

_G.prettyui = nil
local client = ClientFakes.Install()
ClientFakes.LoadRsprite()
package.loaded.main = nil
local loaded, rsprite = pcall(require, "main")
check.Check(
    "main.lua loads with prettyui absent",
    loaded and type(rsprite) == "table",
    tostring(rsprite)
)
check.Equal("main.lua defines PluginShutdown", type(PluginShutdown), "function")
check.Equal("loading makes no sprite lookups", client.lookups, 0)
check.Equal("loading makes no FromID calls", client.fromIdCalls, 0)
check.Equal("loading creates no sprites", #client.sprites, 0)
check.Equal("loading subscribes to nothing", client.SubscriptionCount(), 0)

check.Equal("Get works", rsprite.Get("SKILL_ATTACK"), 9318)
check.Equal("Name works", rsprite.Name(9318), "SKILL_ATTACK")
check.Equal("Resolve works", rsprite.Resolve({ "MISSING", "SKILL_MAGIC" }), 33454)
local entries, total = rsprite.Find("attack")
check.Check("Find works", total >= 1 and entries[1].name == "SKILL_ATTACK", total)
local sprite, index = rsprite.Draw(client.NewComponent("layer"), "SKILL_ATTACK")
check.Check("Draw works", sprite ~= nil and index == 1, tostring(index))
check.Check(
    "DrawItem works",
    rsprite.DrawItem(client.NewComponent("layer"), ClientFakes.ITEM_ID) ~= nil,
    "drawn"
)

PluginShutdown()
check.Equal("PluginShutdown leaves nothing subscribed", client.SubscriptionCount(), 0)

local mentions = {}
for _, path in ipairs(selftest.ListFiles("plugins/rsprite")) do
    if not string.find(path, "%.png$") then
        local file = assert(io.open(path, "r"))
        local contents = file:read("a")
        file:close()
        if string.find(string.lower(contents), "prettyui", 1, true) then
            mentions[#mentions + 1] = path
        end
    end
end
check.Same("no file under plugins/rsprite mentions prettyui", mentions, {})

check.Finish()
