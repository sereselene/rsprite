local ClientFakes = require("tests/support/client_fakes")
local Report = require("tests/support/report")

local check = Report.New("preferences")
local client = ClientFakes.Install()
local Preferences = require("src/services/preferences")

check.Equal(
    "keys carry the rsprite_finder_ prefix",
    Preferences.Key("state"),
    "rsprite_finder_state"
)
check.Equal(
    "saving reports success",
    Preferences.Save("state", { query = "arrow", page = 3, previewSize = 24 }),
    true
)
check.Check(
    "the value is stored under the prefixed key",
    client.stored.rsprite_finder_state ~= nil,
    "stored"
)
check.Equal("nothing is stored under the bare key", client.stored.state, nil)

local loaded = Preferences.Load("state")
check.Same(
    "values round trip",
    { loaded.query, loaded.page, loaded.previewSize },
    { "arrow", 3, 24 }
)

local unprefixed = {}
for key in pairs(client.stored) do
    if string.sub(key, 1, #Preferences.PREFIX) ~= Preferences.PREFIX then
        unprefixed[#unprefixed + 1] = key
    end
end
check.Same("every stored key is prefixed", unprefixed, {})

check.Equal("a missing value loads as nil", Preferences.Load("missing"), nil)

PersistentDB = {
    GetStructuredData = function()
        error("storage is unavailable")
    end,
    SetStructuredData = function()
        error("storage is unavailable")
    end,
}
check.Equal("a failing save reports failure", Preferences.Save("state", { query = "x" }), false)
check.Equal("a failing load gives nil", Preferences.Load("state"), nil)

check.Finish()
