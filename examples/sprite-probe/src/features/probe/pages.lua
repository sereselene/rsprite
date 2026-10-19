local PageData = require("src/data/pages")

local Pages = {}

Pages.CLIENT = PageData.client
Pages.PAGE_SIZE = PageData.pageSize
Pages.PAGE_COUNT = PageData.pageCount

function Pages.SettingCount()
    return #PageData.settings
end

function Pages.SettingName(settingPosition)
    local setting = PageData.settings[settingPosition]
    return setting and setting.name or nil
end

function Pages.Entries(settingPosition, page)
    local setting = PageData.settings[settingPosition]
    if setting == nil then
        return {}
    end
    return setting.pages[page] or {}
end

function Pages.TileNumber(page, position)
    return (page - 1) * Pages.PAGE_SIZE + position
end

return Pages
