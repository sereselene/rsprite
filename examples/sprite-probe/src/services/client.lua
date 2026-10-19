local Client = {}

local PREFIX = "rsprite-sprite-probe: "
local HIDDEN_SOURCE = {}
local HIDDEN_OPTIONS = { placeholder = false }

local warnedKeys = {}
local createdComponents = 0

function Client.Say(message)
    print(PREFIX .. message)
end

function Client.Warn(key, message)
    if warnedKeys[key] then
        return
    end
    warnedKeys[key] = true
    Client.Say(message)
end

function Client.Call(label, action, ...)
    local results = table.pack(pcall(action, ...))
    if not results[1] then
        Client.Warn(label, label .. " failed: " .. tostring(results[2]))
        return nil
    end
    return table.unpack(results, 2, results.n)
end

function Client.CreatedComponents()
    return createdComponents
end

function Client.MemoryKilobytes()
    local measured, kilobytes = pcall(collectgarbage, "count")
    if measured and type(kilobytes) == "number" then
        return kilobytes
    end
    return nil
end

local function counted(component)
    if component ~= nil then
        createdComponents = createdComponents + 1
    end
    return component
end

local function place(component, layout)
    component:SetPos(layout.x or 0, layout.y or 0)
    component:SetSize(layout.width or 0, layout.height or 0)
end

function Client.GameArea()
    return Client.Call("finding the game area", function()
        return ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2__GAME_AREA)
    end)
end

function Client.NewLayer(parent, layout)
    return counted(Client.Call("creating a layer", function()
        local layer = ui.Layer.new(parent)
        place(layer, layout)
        layer.clickthrough = layout.clickable ~= true
        return layer
    end))
end

function Client.NewRectangle(parent, layout)
    return counted(Client.Call("creating a rectangle", function()
        local rectangle = ui.Rectangle.new(parent)
        place(rectangle, layout)
        rectangle.fill = true
        rectangle.rgba = layout.colour
        rectangle.clickthrough = layout.clickable ~= true
        return rectangle
    end))
end

function Client.NewText(parent, layout)
    return counted(Client.Call("creating text", function()
        local text = ui.Text.new(parent)
        place(text, layout)
        text.content = layout.text or ""
        text.font = id.Font.MUSEO_SANS_11PT_REGULAR
        text.rgba = layout.colour
        text.maxLines = layout.maxLines or 1
        text.clickthrough = true
        if layout.centred then
            text.alignHorizontal = ui.AlignMode.CENTRE
            text.alignVertical = ui.AlignMode.CENTRE
        end
        return text
    end))
end

function Client.NewNumberField(parent, layout)
    return counted(Client.Call("creating the page field", function()
        local field = ui.InputField.new(parent)
        field.stylesheetID = id.StyleSheet.INPUT_DEFAULT
        place(field, layout)
        field:Setup(
            ui.TextContentVisibilityMode.VISIBLE,
            ui.InputFieldFilterMode.NUMERIC,
            layout.maxLength
        )
        field.content = layout.text or ""
        return field
    end))
end

function Client.FieldText(field)
    if field == nil then
        return nil
    end
    return Client.Call("reading the page field", function()
        return field.content
    end)
end

function Client.Set(component, propertyName, value)
    if component == nil then
        return false
    end
    return Client.Call("setting " .. propertyName, function()
        component[propertyName] = value
        return true
    end) == true
end

function Client.OnClick(component, key, callback)
    if component == nil then
        return false
    end
    return Client.Call("listening for clicks", function()
        component:Subscribe(ui.Hook.ONCLICK, key, function()
            Client.Call("handling a click", callback)
            return false
        end)
        return true
    end) == true
end

function Client.Destroy(component)
    if component == nil then
        return
    end
    Client.Call("removing a component", function()
        component:Destroy()
    end)
end

function Client.NewSprite(parent, layout)
    return counted(Client.Call("creating a probe sprite", rsprite.Draw, parent, HIDDEN_SOURCE, {
        x = layout.x,
        y = layout.y,
        size = layout.size,
        placeholder = false,
    }))
end

function Client.ShowSprite(sprite, name)
    if sprite == nil then
        return
    end
    Client.Call("drawing " .. name, rsprite.SetSource, sprite, name)
end

function Client.HideSprite(sprite)
    if sprite == nil then
        return
    end
    Client.Call("hiding a probe sprite", rsprite.SetSource, sprite, HIDDEN_SOURCE, HIDDEN_OPTIONS)
end

function Client.LoadStructuredData(key)
    return Client.Call("loading the probe's saved data", function()
        return PersistentDB:GetStructuredData(key)
    end)
end

function Client.SaveStructuredData(key, value)
    return Client.Call("saving the probe's saved data", function()
        PersistentDB:SetStructuredData(key, value)
        return true
    end) == true
end

function Client.Subscribe(eventName, key, label, callback)
    return Client.Call("listening for " .. label, function()
        Event[eventName].Subscribe(key, callback)
        return true
    end) == true
end

function Client.Unsubscribe(eventName, key, label)
    Client.Call("no longer listening for " .. label, function()
        Event[eventName].Unsubscribe(key)
    end)
end

return Client
