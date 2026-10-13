local Client = require("src/services/client")
local Pages = require("src/features/probe/pages")
local ProbeRunner = require("src/features/probe/probe_runner")

local SettingsPanel = {}

SettingsPanel.DEFAULT_PAGE = 19
SettingsPanel.SPRITES_LABEL = "Mode 1: one sprite per step"
SettingsPanel.BUILD_UP_LABEL = "Mode 2: pages 1 to 25"
SettingsPanel.COUNTER_LABEL = "Mode 3: save survival"
SettingsPanel.SWEEP_LABEL = "Mode 4: sweep"
SettingsPanel.RESUME_LABEL = "Resume sweep"
SettingsPanel.FINDINGS_LABEL = "Show findings"
SettingsPanel.STOP_LABEL = "Stop"

local INSET = 10
local ROW_HEIGHT = 28
local TEXT_COLOUR = 0xFFFFFFFF
local BUTTON_COLOUR = 0x3A3A3AFF
local STOP_COLOUR = 0x803030FF
local INTRO_WIDTH = 536
local PAGE_LABEL_WIDTH = 40
local FIELD_WIDTH = 60
local FIELD_MAXIMUM_LENGTH = 3
local OPTIONS_WIDTH = 300
local MODE_BUTTON_WIDTH = 172
local STOP_BUTTON_WIDTH = 120
local BUTTON_GAP = 10
local INTRO_Y = 10
local PAGE_ROW_Y = 50
local MODE_ROW_Y = 90
local SWEEP_ROW_Y = 130
local STOP_ROW_Y = 170
local STATUS_Y = 210
local CLICK_KEY_PREFIX = "rsprite-sprite-probe:"

local chosenPage = SettingsPanel.DEFAULT_PAGE
local settingPosition = 1
local parts = nil

local function optionsLabel()
    return "Options: " .. tostring(Pages.SettingName(settingPosition))
end

local function addButton(parent, layout, label, key, onClick)
    local button = Client.NewRectangle(parent, {
        x = layout.x,
        y = layout.y,
        width = layout.width,
        height = ROW_HEIGHT,
        colour = layout.colour or BUTTON_COLOUR,
        clickable = true,
    })
    local text = Client.NewText(parent, {
        x = layout.x,
        y = layout.y,
        width = layout.width,
        height = ROW_HEIGHT,
        text = label,
        colour = TEXT_COLOUR,
        centred = true,
    })
    Client.OnClick(button, CLICK_KEY_PREFIX .. key, onClick)
    return { button = button, text = text }
end

local function setStatus(message)
    if parts ~= nil then
        Client.Set(parts.status, "content", message)
    end
end

local function chosenPageFromField()
    local text = Client.FieldText(parts and parts.pageField)
    local page = math.tointeger(tonumber(text or ""))
    if page == nil or page < 1 or page > Pages.PAGE_COUNT then
        local message =
            string.format("the page must be a whole number from 1 to %d", Pages.PAGE_COUNT)
        Client.Say(message)
        setStatus(message)
        return nil
    end
    chosenPage = page
    return page
end

local function startSprites()
    local page = chosenPageFromField()
    if page ~= nil and ProbeRunner.StartSprites(settingPosition, page) then
        setStatus(
            string.format(
                "Running mode 1 on page %d. Close this window to watch the probe panel.",
                page
            )
        )
    end
end

local function startBuildUp()
    if ProbeRunner.StartBuildUp(settingPosition) then
        setStatus("Running mode 2. Close this window to watch the probe panel.")
    end
end

local function startCounter()
    if ProbeRunner.StartCounter() then
        setStatus("Running mode 3. Kill the client from Task Manager when you are ready.")
    end
end

local function startSweep()
    if ProbeRunner.StartSweep() then
        setStatus("Running mode 4. Close this window to watch the probe panel.")
    end
end

local function resumeSweep()
    if ProbeRunner.ResumeSweep() then
        setStatus("Resuming the sweep. Close this window to watch the probe panel.")
    end
end

local function showFindings()
    local findings = ProbeRunner.ShowFindings()
    setStatus(#findings .. " crashing sprites found so far. They are listed in the console.")
end

local function stop()
    ProbeRunner.Stop()
    setStatus("Stopped.")
end

local function cycleOptions()
    settingPosition = settingPosition % Pages.SettingCount() + 1
    if parts ~= nil then
        Client.Set(parts.optionsButton.text, "content", optionsLabel())
    end
end

function SettingsPanel.Destroy()
    if parts == nil then
        return
    end
    local mounted = parts
    parts = nil
    for _, component in ipairs(mounted.components) do
        Client.Destroy(component)
    end
end

function SettingsPanel.Mount(component)
    SettingsPanel.Destroy()
    if component == nil then
        return nil
    end
    local mounted = { components = {} }
    local function keep(created)
        mounted.components[#mounted.components + 1] = created
        return created
    end
    keep(Client.NewText(component, {
        x = INSET,
        y = INTRO_Y,
        width = INTRO_WIDTH,
        height = 32,
        maxLines = 2,
        colour = TEXT_COLOUR,
        text = string.format(
            "Sprite probe for client %s, pages 1 to %d. Start a mode, then close this window to watch the probe panel and the console.",
            Pages.CLIENT,
            Pages.PAGE_COUNT
        ),
    }))
    keep(Client.NewText(component, {
        x = INSET,
        y = PAGE_ROW_Y + 6,
        width = PAGE_LABEL_WIDTH,
        height = 16,
        text = "Page",
        colour = TEXT_COLOUR,
    }))
    mounted.pageField = keep(Client.NewNumberField(component, {
        x = INSET + PAGE_LABEL_WIDTH,
        y = PAGE_ROW_Y,
        width = FIELD_WIDTH,
        height = ROW_HEIGHT,
        maxLength = FIELD_MAXIMUM_LENGTH,
        text = tostring(chosenPage),
    }))
    local function keepButton(button)
        keep(button.button)
        keep(button.text)
        return button
    end
    mounted.optionsButton = keepButton(addButton(component, {
        x = INSET + PAGE_LABEL_WIDTH + FIELD_WIDTH + BUTTON_GAP,
        y = PAGE_ROW_Y,
        width = OPTIONS_WIDTH,
    }, optionsLabel(), "options", cycleOptions))
    mounted.spritesButton = keepButton(addButton(component, {
        x = INSET,
        y = MODE_ROW_Y,
        width = MODE_BUTTON_WIDTH,
    }, SettingsPanel.SPRITES_LABEL, "sprites", startSprites))
    mounted.buildUpButton = keepButton(addButton(component, {
        x = INSET + MODE_BUTTON_WIDTH + BUTTON_GAP,
        y = MODE_ROW_Y,
        width = MODE_BUTTON_WIDTH,
    }, SettingsPanel.BUILD_UP_LABEL, "build-up", startBuildUp))
    mounted.counterButton = keepButton(addButton(component, {
        x = INSET + 2 * (MODE_BUTTON_WIDTH + BUTTON_GAP),
        y = MODE_ROW_Y,
        width = MODE_BUTTON_WIDTH,
    }, SettingsPanel.COUNTER_LABEL, "counter", startCounter))
    mounted.sweepButton = keepButton(addButton(component, {
        x = INSET,
        y = SWEEP_ROW_Y,
        width = MODE_BUTTON_WIDTH,
    }, SettingsPanel.SWEEP_LABEL, "sweep", startSweep))
    mounted.resumeButton = keepButton(addButton(component, {
        x = INSET + MODE_BUTTON_WIDTH + BUTTON_GAP,
        y = SWEEP_ROW_Y,
        width = MODE_BUTTON_WIDTH,
    }, SettingsPanel.RESUME_LABEL, "resume-sweep", resumeSweep))
    mounted.findingsButton = keepButton(addButton(component, {
        x = INSET + 2 * (MODE_BUTTON_WIDTH + BUTTON_GAP),
        y = SWEEP_ROW_Y,
        width = MODE_BUTTON_WIDTH,
    }, SettingsPanel.FINDINGS_LABEL, "findings", showFindings))
    mounted.stopButton = keepButton(addButton(component, {
        x = INSET,
        y = STOP_ROW_Y,
        width = STOP_BUTTON_WIDTH,
        colour = STOP_COLOUR,
    }, SettingsPanel.STOP_LABEL, "stop", stop))
    mounted.status = keep(Client.NewText(component, {
        x = INSET,
        y = STATUS_Y,
        width = INTRO_WIDTH,
        height = 16,
        colour = TEXT_COLOUR,
        text = ProbeRunner.RunningMode()
                and ("Mode " .. ProbeRunner.RunningMode() .. " is running.")
            or "Nothing is running.",
    }))
    parts = mounted
    return mounted
end

function SettingsPanel.Parts()
    return parts
end

return SettingsPanel
