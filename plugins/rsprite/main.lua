local App = require("src/app/init")

function PluginShutdown()
    App.Shutdown()
end

return App.Public
