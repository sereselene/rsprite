local App = require("src/app/init")

App.Start()

function PluginShutdown()
    App.Shutdown()
end

return App
