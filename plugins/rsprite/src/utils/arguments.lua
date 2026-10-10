local WholeNumber = require("src/utils/whole_number")

local Arguments = {}

function Arguments.CombineTypes(...)
    local combined = {}
    for _, expectedTypes in ipairs({ ... }) do
        for optionName, optionType in pairs(expectedTypes) do
            combined[optionName] = optionType
        end
    end
    return combined
end

function Arguments.ComponentProblem(functionName, argumentName, value)
    local valueType = type(value)
    if valueType == "userdata" or valueType == "table" then
        return nil
    end
    return string.format(
        "%s: %s must be a component, got %s",
        functionName,
        argumentName,
        valueType
    )
end

function Arguments.OptionsProblem(functionName, options, expectedTypes)
    if options == nil then
        return nil
    end
    if type(options) ~= "table" then
        return string.format("%s: options must be a table, got %s", functionName, type(options))
    end
    for optionName, value in pairs(options) do
        local expectedType = expectedTypes[optionName]
        if expectedType == nil then
            return string.format("%s: unknown option %s", functionName, tostring(optionName))
        end
        if type(value) ~= expectedType then
            return string.format(
                "%s: option %s must be a %s, got %s",
                functionName,
                optionName,
                expectedType,
                type(value)
            )
        end
    end
    return nil
end

function Arguments.WholeNumberOptionProblem(functionName, options, optionName)
    local value = options ~= nil and options[optionName] or nil
    if value == nil or WholeNumber.From(value) ~= nil then
        return nil
    end
    return string.format(
        "%s: option %s must be a whole number 0 or above, got %s",
        functionName,
        optionName,
        tostring(value)
    )
end

return Arguments
