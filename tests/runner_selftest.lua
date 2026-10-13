local Report = require("tests/support/report")

local check = Report.New("runner")

check.Raises("a plugin module needs a named plugin first", function()
    require("src/utils/whole_number")
end, 'Name the plugin this test covers first, with selftest.UsePlugin("rsprite")')
check.Raises("a plugin that does not exist is refused", function()
    selftest.UsePlugin("not-a-plugin")
end, "there is no plugin called not-a-plugin under plugins")

selftest.UsePlugin("rsprite")
local WholeNumber = require("src/utils/whole_number")
check.Equal("a plugin module loads once the plugin is named", WholeNumber.From(3), 3)
selftest.UsePlugin("rsprite")
check.Equal("naming the same plugin again is allowed", type(require("src/app/init")), "table")
check.Raises("a test cannot switch to another plugin", function()
    selftest.UsePlugin("rsprite-finder")
end, "this test already uses plugins/rsprite, so it cannot also use plugins/rsprite-finder")
check.Raises(
    "a module missing from the plugin names both places looked",
    function()
        require("src/not_a_module")
    end,
    "no module src/not_a_module, looked in src/not_a_module.lua and plugins/rsprite/src/not_a_module.lua"
)

check.Finish()
