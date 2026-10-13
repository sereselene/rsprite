selftest.UsePlugin("rsprite")

local ClientFakes = require("tests/support/client_fakes")
local Report = require("tests/support/report")

local check = Report.New("version")
ClientFakes.Install()
local rsprite = ClientFakes.LoadRsprite().Public

local function manifestVersion(path)
    local file = assert(io.open(path, "r"))
    local manifest = file:read("a")
    file:close()
    return string.match(manifest, '"version"%s*:%s*"([^"]+)"')
end

local coreVersion = manifestVersion("plugins/rsprite/plugin.json")
local finderVersion = manifestVersion("plugins/rsprite-finder/plugin.json")

check.Check("plugin.json has a version", coreVersion ~= nil, tostring(coreVersion))
check.Equal("rsprite.version equals plugin.json's version", rsprite.version, coreVersion)
check.Equal("rsprite-finder ships on the same version", finderVersion, coreVersion)
check.Check(
    "the version is semver",
    string.match(rsprite.version or "", "^%d+%.%d+%.%d+$") ~= nil,
    tostring(rsprite.version)
)

check.Finish()
