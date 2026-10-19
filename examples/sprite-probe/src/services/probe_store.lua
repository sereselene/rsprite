local Client = require("src/services/client")

local ProbeStore = {}

ProbeStore.STEP_KEY = "rsprite_sprite_probe_step"
ProbeStore.COUNTER_KEY = "rsprite_sprite_probe_counter"
ProbeStore.SWEEP_KEY = "rsprite_sprite_probe_sweep"
ProbeStore.FINDINGS_KEY = "rsprite_sprite_probe_findings"
ProbeStore.FINDING_SEPARATOR = ","

local EMPTY = {}

local function load(key)
    local value = Client.LoadStructuredData(key)
    if type(value) == "table" then
        return value
    end
    return EMPTY
end

function ProbeStore.SaveStep(step)
    return Client.SaveStructuredData(ProbeStore.STEP_KEY, step)
end

function ProbeStore.LoadStep()
    local step = load(ProbeStore.STEP_KEY)
    if type(step.mode) ~= "number" then
        return nil
    end
    return step
end

function ProbeStore.ClearStep()
    return Client.SaveStructuredData(ProbeStore.STEP_KEY, EMPTY)
end

function ProbeStore.SaveCounter(value)
    return Client.SaveStructuredData(ProbeStore.COUNTER_KEY, { value = value })
end

function ProbeStore.LoadCounter()
    local counter = load(ProbeStore.COUNTER_KEY)
    if type(counter.value) ~= "number" then
        return nil
    end
    return counter.value
end

function ProbeStore.ClearCounter()
    return Client.SaveStructuredData(ProbeStore.COUNTER_KEY, EMPTY)
end

function ProbeStore.SaveSweep(record)
    return Client.SaveStructuredData(ProbeStore.SWEEP_KEY, record)
end

function ProbeStore.LoadSweep()
    local record = load(ProbeStore.SWEEP_KEY)
    if type(record.nextPage) ~= "number" and type(record.namePage) ~= "number" then
        return nil
    end
    return record
end

function ProbeStore.ClearSweep()
    return Client.SaveStructuredData(ProbeStore.SWEEP_KEY, EMPTY)
end

function ProbeStore.LoadFindings()
    local saved = load(ProbeStore.FINDINGS_KEY)
    local findings = {}
    if type(saved.entries) ~= "string" then
        return findings
    end
    for spriteId, name in
        string.gmatch(saved.entries, "(%d+) ([^" .. ProbeStore.FINDING_SEPARATOR .. "]+)")
    do
        findings[#findings + 1] = { id = tonumber(spriteId), name = name }
    end
    return findings
end

function ProbeStore.AddFinding(spriteId, name)
    local findings = ProbeStore.LoadFindings()
    for _, finding in ipairs(findings) do
        if finding.name == name then
            return false
        end
    end
    findings[#findings + 1] = { id = spriteId, name = name }
    local parts = {}
    for position, finding in ipairs(findings) do
        parts[position] = finding.id .. " " .. finding.name
    end
    return Client.SaveStructuredData(
        ProbeStore.FINDINGS_KEY,
        { entries = table.concat(parts, ProbeStore.FINDING_SEPARATOR) }
    )
end

return ProbeStore
