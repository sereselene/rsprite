local Client = require("src/services/client")
local Pages = require("src/features/probe/pages")
local ProbeStore = require("src/services/probe_store")
local Stage = require("src/features/probe/stage")
local SweepPages = require("src/features/probe/sweep_pages")

local ProbeRunner = {}

ProbeRunner.SPRITES = 1
ProbeRunner.BUILD_UP = 2
ProbeRunner.COUNTER = 3
ProbeRunner.WAIT_TICKS = 3
ProbeRunner.BUILD_UP_LAST_PAGE = 25
ProbeRunner.COUNTER_REPORT_TICKS = 20
ProbeRunner.SWEEP = 4
ProbeRunner.NAMING = 5
ProbeRunner.SWEEP_WAIT_TICKS = 25
ProbeRunner.SWEEP_REPORT_PAGES = 50
ProbeRunner.SWEEP_SETTING_NAME = "both options off"

local TICK_KEY = "rsprite-sprite-probe:tick"
local TICK_LABEL = "ticks"

local current = nil
local ticking = false
local anyRunStarted = false

local function stopTicking()
    if ticking then
        Client.Unsubscribe("Logic", TICK_KEY, TICK_LABEL)
        ticking = false
    end
end

local function finish(message)
    stopTicking()
    local finished = current
    current = nil
    if finished ~= nil and finished.mode ~= ProbeRunner.COUNTER then
        ProbeStore.ClearStep()
    end
    Stage.Clear()
    Stage.SetStatus(message)
    Client.Say(message)
end

local function stepSprites(run)
    local entry = run.entries[run.position]
    if entry == nil then
        finish(string.format("finished page %d with %s", run.page, run.settingName))
        return
    end
    local tile = Pages.TileNumber(run.page, run.position)
    if run.showingPreview then
        Stage.ShowPreview(entry.name)
        run.showingPreview = false
        run.position = run.position + 1
        run.wait = ProbeRunner.WAIT_TICKS
        return
    end
    ProbeStore.SaveStep({
        mode = ProbeRunner.SPRITES,
        page = run.page,
        tile = tile,
        id = entry.id,
        name = entry.name,
        options = run.settingName,
    })
    local line = string.format("page %d tile %d id %d %s", run.page, tile, entry.id, entry.name)
    Client.Say(line)
    Stage.SetStatus(line)
    Stage.ShowTile(entry.name)
    run.showingPreview = true
end

local function stepBuildUp(run)
    if run.page > ProbeRunner.BUILD_UP_LAST_PAGE then
        finish(
            string.format(
                "finished build up pages 1 to %d with %s",
                ProbeRunner.BUILD_UP_LAST_PAGE,
                run.settingName
            )
        )
        return
    end
    ProbeStore.SaveStep({ mode = ProbeRunner.BUILD_UP, page = run.page, options = run.settingName })
    local kilobytes = Client.MemoryKilobytes()
    local memory = kilobytes and string.format("%.1f KB of Lua memory", kilobytes)
        or "Lua memory unknown"
    local line = string.format(
        "build up page %d, %d components created by the probe, %s",
        run.page,
        Client.CreatedComponents(),
        memory
    )
    Client.Say(line)
    Stage.SetStatus(line)
    Stage.ShowGrid(Pages.Entries(run.settingPosition, run.page))
    run.page = run.page + 1
    run.wait = ProbeRunner.WAIT_TICKS
end

local function stepCounter(run)
    run.value = run.value + 1
    ProbeStore.SaveCounter(run.value)
    if run.value % ProbeRunner.COUNTER_REPORT_TICKS == 0 then
        local line = "saved counter " .. run.value
        Client.Say(line)
        Stage.SetStatus(line)
    end
end

local function stepSweep(run)
    if not SweepPages.IsReady() then
        return
    end
    if run.pageCount == nil then
        run.pageCount = SweepPages.PageCount()
        Client.Say(
            string.format(
                "sweeping pages %d to %d with %s",
                run.page,
                run.pageCount,
                ProbeRunner.SWEEP_SETTING_NAME
            )
        )
    end
    if run.page > run.pageCount then
        ProbeStore.ClearSweep()
        finish(
            string.format(
                "sweep finished after page %d, with %d crashing sprites found so far. Press Show findings to list them.",
                run.pageCount,
                #ProbeStore.LoadFindings()
            )
        )
        return
    end
    ProbeStore.SaveStep({ mode = ProbeRunner.SWEEP, page = run.page })
    local line = string.format("sweep page %d of %d", run.page, run.pageCount)
    if run.page % ProbeRunner.SWEEP_REPORT_PAGES == 0 or run.page == run.pageCount then
        Client.Say(line)
    end
    Stage.SetStatus(line)
    Stage.ShowGrid(SweepPages.Entries(run.page))
    run.page = run.page + 1
    run.wait = ProbeRunner.SWEEP_WAIT_TICKS
end

local function finishNaming(run)
    local record = run.record
    if
        record.namePage == record.crashPage
        and not record.foundAny
        and not record.fallbackDone
        and record.crashPage > 1
    then
        record.namePage = record.crashPage - 1
        record.namePosition = 1
        record.fallbackDone = true
        ProbeStore.SaveSweep(record)
        Client.Say(
            string.format(
                "page %d drew safely one sprite at a time, so page %d is named too",
                record.crashPage,
                record.namePage
            )
        )
        run.page = record.namePage
        run.position = 1
        run.showingPreview = false
        run.wait = ProbeRunner.WAIT_TICKS
        return
    end
    local nextPage = record.crashPage + 1
    ProbeStore.SaveSweep({ nextPage = nextPage })
    Client.Say(string.format("naming finished, so the sweep carries on from page %d", nextPage))
    run.mode = ProbeRunner.SWEEP
    run.page = nextPage
    run.pageCount = nil
    run.wait = 0
end

local function stepNaming(run)
    if not SweepPages.IsReady() then
        return
    end
    local entry = SweepPages.Entries(run.page)[run.position]
    if entry == nil then
        finishNaming(run)
        return
    end
    if run.showingPreview then
        Stage.ShowPreview(entry.name)
        run.showingPreview = false
        run.position = run.position + 1
        run.wait = ProbeRunner.WAIT_TICKS
        return
    end
    local tile = Pages.TileNumber(run.page, run.position)
    ProbeStore.SaveStep({
        mode = ProbeRunner.NAMING,
        page = run.page,
        position = run.position,
        tile = tile,
        id = entry.id,
        name = entry.name,
    })
    local line =
        string.format("sweep page %d tile %d id %d %s", run.page, tile, entry.id, entry.name)
    Client.Say(line)
    Stage.SetStatus(line)
    Stage.ShowTile(entry.name)
    run.showingPreview = true
end

local STEPS = {
    [ProbeRunner.SPRITES] = stepSprites,
    [ProbeRunner.BUILD_UP] = stepBuildUp,
    [ProbeRunner.COUNTER] = stepCounter,
    [ProbeRunner.SWEEP] = stepSweep,
    [ProbeRunner.NAMING] = stepNaming,
}

local function onTick()
    local run = current
    if run == nil then
        stopTicking()
        return
    end
    if run.wait > 0 then
        run.wait = run.wait - 1
        return
    end
    STEPS[run.mode](run)
end

local function begin(run, message)
    if current ~= nil then
        finish("stopped mode " .. current.mode .. " to start mode " .. run.mode)
    end
    if not Stage.Ensure() then
        Client.Say("the probe panel could not be built, so nothing was started")
        return false
    end
    Stage.Clear()
    run.wait = 0
    current = run
    anyRunStarted = true
    if not ticking then
        ticking = Client.Subscribe("Logic", TICK_KEY, TICK_LABEL, function()
            Client.Call("running a probe step", onTick)
        end)
    end
    if not ticking then
        current = nil
        Client.Say("the probe could not start ticking, so nothing was started")
        return false
    end
    Stage.SetStatus(message)
    Client.Say(message)
    return true
end

function ProbeRunner.StartSprites(settingPosition, page)
    local settingName = Pages.SettingName(settingPosition)
    return begin({
        mode = ProbeRunner.SPRITES,
        settingPosition = settingPosition,
        settingName = settingName,
        page = page,
        entries = Pages.Entries(settingPosition, page),
        position = 1,
        showingPreview = false,
    }, string.format("mode 1: drawing page %d one sprite at a time, with %s", page, settingName))
end

function ProbeRunner.StartBuildUp(settingPosition)
    local freshStart = not anyRunStarted
    local settingName = Pages.SettingName(settingPosition)
    local started = begin(
        {
            mode = ProbeRunner.BUILD_UP,
            settingPosition = settingPosition,
            settingName = settingName,
            page = 1,
        },
        string.format(
            "mode 2: paging from 1 to %d with %s",
            ProbeRunner.BUILD_UP_LAST_PAGE,
            settingName
        )
    )
    if started and not freshStart then
        Client.Say(
            "another mode already ran in this session, so restart the client for a clean build up test"
        )
    end
    return started
end

function ProbeRunner.StartCounter()
    return begin({ mode = ProbeRunner.COUNTER, value = 0 }, "mode 3: saving a counter every tick")
end

function ProbeRunner.StartSweep()
    ProbeStore.ClearSweep()
    SweepPages.Prepare()
    return begin(
        { mode = ProbeRunner.SWEEP, page = 1 },
        string.format("mode 4: sweeping every page with %s", ProbeRunner.SWEEP_SETTING_NAME)
    )
end

function ProbeRunner.ResumeSweep()
    local record = ProbeStore.LoadSweep()
    if record == nil then
        Client.Say("there is no sweep to resume. Press Mode 4 to start one.")
        return false
    end
    SweepPages.Prepare()
    if type(record.namePage) == "number" then
        return begin(
            {
                mode = ProbeRunner.NAMING,
                record = record,
                page = record.namePage,
                position = record.namePosition or 1,
                showingPreview = false,
            },
            string.format(
                "resuming the sweep by naming page %d one sprite at a time",
                record.namePage
            )
        )
    end
    return begin(
        { mode = ProbeRunner.SWEEP, page = record.nextPage },
        string.format("resuming the sweep from page %d", record.nextPage)
    )
end

function ProbeRunner.ShowFindings()
    local findings = ProbeStore.LoadFindings()
    if #findings == 0 then
        Client.Say("no crashing sprites have been found yet")
        return findings
    end
    Client.Say(
        #findings
            .. " crashing sprites found, ready to paste into unsafe.json in the catalogue folder:"
    )
    for _, finding in ipairs(findings) do
        Client.Say(string.format('{ "id": %d, "name": "%s" },', finding.id, finding.name))
    end
    return findings
end

local function rememberSweepPosition(run)
    if run.mode == ProbeRunner.SWEEP then
        ProbeStore.SaveSweep({ nextPage = run.page })
    elseif run.mode == ProbeRunner.NAMING then
        run.record.namePage = run.page
        run.record.namePosition = run.position
        ProbeStore.SaveSweep(run.record)
    end
end

function ProbeRunner.Stop()
    if current == nil then
        Client.Say("nothing is running")
        return false
    end
    rememberSweepPosition(current)
    finish("stopped mode " .. current.mode)
    return true
end

function ProbeRunner.RunningMode()
    return current and current.mode or nil
end

function ProbeRunner.Shutdown()
    if current ~= nil then
        rememberSweepPosition(current)
    end
    if current ~= nil and current.mode ~= ProbeRunner.COUNTER then
        ProbeStore.ClearStep()
    end
    current = nil
    stopTicking()
end

return ProbeRunner
