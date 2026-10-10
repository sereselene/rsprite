local Report = {}

local function joinAll(items)
    local texts = {}
    for position, item in ipairs(items) do
        texts[position] = tostring(item)
    end
    return table.concat(texts, " | ")
end

function Report.New(area)
    local suite = { failures = 0 }

    function suite.Check(label, passed, detail)
        if not passed then
            suite.failures = suite.failures + 1
        end
        print(
            string.format(
                "[selftest] %s, %s: %s %s",
                area,
                label,
                tostring(detail or ""),
                passed and "PASS" or "FAIL"
            )
        )
    end

    function suite.Equal(label, actual, expected)
        suite.Check(
            label,
            actual == expected,
            string.format("expected %s, got %s", tostring(expected), tostring(actual))
        )
    end

    function suite.Same(label, actualList, expectedList)
        local actualText = joinAll(actualList)
        local expectedText = joinAll(expectedList)
        suite.Check(
            label,
            actualText == expectedText,
            string.format("expected [%s], got [%s]", expectedText, actualText)
        )
    end

    function suite.Raises(label, action, expectedText, expectedSource)
        local succeeded, failure = pcall(action)
        local message = tostring(failure)
        local passed = not succeeded
            and string.find(message, expectedText, 1, true) ~= nil
            and (expectedSource == nil or string.find(message, expectedSource, 1, true) == 1)
        suite.Check(label, passed, succeeded and "did not raise" or message)
    end

    function suite.Finish()
        if suite.failures > 0 then
            error(string.format("%d %s checks failed", suite.failures, area))
        end
    end

    return suite
end

return Report
