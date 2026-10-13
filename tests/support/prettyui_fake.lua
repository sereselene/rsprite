local PrettyuiFake = {}

local function describeAll(...)
    local parts = {}
    for position = 1, select("#", ...) do
        parts[position] = tostring((select(position, ...)))
    end
    return table.concat(parts, " ")
end

function PrettyuiFake.Install()
    local fake = {
        log = {},
        windows = {},
        views = {},
        textFields = {},
        comboBoxes = {},
        simpleButtons = {},
        spriteButtons = {},
        fancyButtons = {},
        spinners = {},
        tooltips = {},
        checkboxGroups = {},
        raiseOnContent = false,
        raiseOnWindow = false,
    }

    local function record(...)
        fake.log[#fake.log + 1] = describeAll(...)
    end

    local function newFancyButton(parent, text, action, options)
        record("FancyButton.new", text, options and options.variant or "neutral")
        local button = { parent = parent, text = text, options = options or {}, destroyed = false }
        function button:Click()
            action(self)
        end
        function button:Destroy()
            record("FancyButton.Destroy", self.text)
            self.destroyed = true
        end
        fake.fancyButtons[#fake.fancyButtons + 1] = button
        return button
    end

    prettyui = {}

    prettyui.SimpleView = {
        new = function(parent, options)
            record("SimpleView.new", options.width, options.height)
            local view = {
                parent = parent,
                options = options,
                content = ui.Layer.new(parent),
                destroyed = false,
            }
            function view:AddText(value)
                record("SimpleView.AddText", type(value) == "table" and value.text or value)
                local text = ui.Text.new(self.content)
                text.content = type(value) == "table" and value.text or value
                return text
            end
            function view:AddFancyButton(text, action, buttonOptions)
                return newFancyButton(self.content, text, action, buttonOptions)
            end
            function view:AddCheckboxButton(choices, groupOptions)
                record("SimpleView.AddCheckboxButton", #choices)
                local group = {
                    parent = self.content,
                    choices = choices,
                    options = groupOptions or {},
                    selected = {},
                }
                for _, choice in ipairs(choices) do
                    group.selected[choice.value] = choice.selected == true
                end
                function group.GetSelectedValues()
                    local values = {}
                    for _, choice in ipairs(group.choices) do
                        if group.selected[choice.value] then
                            values[#values + 1] = choice.value
                        end
                    end
                    return values
                end
                function group.Toggle(_, value)
                    group.selected[value] = not group.selected[value]
                    if group.options.onChange ~= nil then
                        group.options.onChange(
                            group,
                            group.GetSelectedValues(),
                            value,
                            group.selected[value]
                        )
                    end
                end
                fake.checkboxGroups[#fake.checkboxGroups + 1] = group
                return group
            end
            function view:Destroy()
                record("SimpleView.Destroy")
                self.destroyed = true
            end
            fake.views[#fake.views + 1] = view
            return view
        end,
    }

    prettyui.Window = {
        new = function(parent, options)
            record("Window.new", options.title)
            if fake.raiseOnWindow then
                error("the window could not be created")
            end
            local content = ui.Layer.new(parent)
            local window = setmetatable({
                parent = parent,
                options = options,
                visible = true,
            }, {
                __index = function(_, key)
                    if key ~= "content" then
                        return nil
                    end
                    if fake.raiseOnContent then
                        error("the window content is not ready")
                    end
                    return content
                end,
            })
            function window:Show()
                record("Window.Show")
                self.visible = true
            end
            function window:Close()
                record("Window.Close")
                self.visible = false
                if options.onClose ~= nil then
                    options.onClose(self)
                end
            end
            function window:Destroy()
                record("Window.Destroy")
                self.destroyed = true
            end
            fake.windows[#fake.windows + 1] = window
            return window
        end,
    }

    prettyui.TextField = {
        new = function(parent, options)
            record("TextField.new", options.placeholder or "")
            local field = { parent = parent, options = options }
            fake.textFields[#fake.textFields + 1] = field
            return field
        end,
    }

    prettyui.ComboBox = {
        new = function(parent, options)
            record("ComboBox.new", #options.entries)
            local combo = { parent = parent, options = options }
            fake.comboBoxes[#fake.comboBoxes + 1] = combo
            return combo
        end,
    }

    prettyui.SimpleButton = {
        new = function(parent, content, action, options)
            record("SimpleButton.new", content)
            local button =
                { parent = parent, content = content, action = action, options = options or {} }
            fake.simpleButtons[#fake.simpleButtons + 1] = button
            return button
        end,
    }

    prettyui.SpriteButton = {
        new = function(parent, spriteName, action, options)
            record("SpriteButton.new", spriteName)
            local button = {
                parent = parent,
                spriteName = spriteName,
                options = options or {},
                disabled = options and options.disabled or false,
                tooltip = options and options.tooltip,
            }
            function button:SetDisabled(disabled)
                self.disabled = disabled
            end
            function button:SetTooltip(value)
                self.tooltip = value
            end
            function button:Click()
                if self.options.toggleable then
                    self.disabled = not self.disabled
                    action(self, not self.disabled)
                elseif not self.disabled then
                    action(self)
                end
            end
            function button:Destroy()
                record("SpriteButton.Destroy", self.spriteName)
                self.destroyed = true
            end
            fake.spriteButtons[#fake.spriteButtons + 1] = button
            return button
        end,
    }

    prettyui.FancyButton = { new = newFancyButton }

    prettyui.Tooltip = {
        attach = function(target, parent, options)
            record("Tooltip.attach", options and options.text)
            local attachment = {
                target = target,
                parent = parent,
                text = options and options.text,
                destroyed = false,
            }
            function attachment:SetText(text)
                self.text = text
                return not self.destroyed
            end
            function attachment:Show() end
            function attachment:Hide() end
            function attachment:Destroy()
                self.destroyed = true
            end
            fake.tooltips[#fake.tooltips + 1] = attachment
            return attachment
        end,
    }

    prettyui.Spinner = {
        new = function(parent, options)
            record("Spinner.new", options and options.size)
            local spinner = { parent = parent, destroyed = false }
            function spinner:Destroy()
                record("Spinner.Destroy")
                self.destroyed = true
            end
            fake.spinners[#fake.spinners + 1] = spinner
            return spinner
        end,
    }

    function fake.Find(collection, predicate)
        for _, item in ipairs(fake[collection]) do
            if predicate(item) then
                return item
            end
        end
        return nil
    end

    function fake.Logged(prefix)
        local count = 0
        for _, line in ipairs(fake.log) do
            if string.sub(line, 1, #prefix) == prefix then
                count = count + 1
            end
        end
        return count
    end

    return fake
end

return PrettyuiFake
