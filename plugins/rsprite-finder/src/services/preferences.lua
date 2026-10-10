local Preferences = {}

Preferences.PREFIX = "rsprite_finder_"

function Preferences.Key(name)
    return Preferences.PREFIX .. name
end

function Preferences.Load(name)
    local loaded, value = pcall(function()
        return PersistentDB:GetStructuredData(Preferences.Key(name))
    end)
    if loaded and type(value) == "table" then
        return value
    end
    return nil
end

function Preferences.Save(name, value)
    local saved = pcall(function()
        PersistentDB:SetStructuredData(Preferences.Key(name), value)
    end)
    return saved
end

return Preferences
