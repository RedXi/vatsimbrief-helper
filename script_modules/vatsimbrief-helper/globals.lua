Globals = {}

TRACK_ISSUE = TRACK_ISSUE or function(component, description, workaround)
    end

MULTILINE_TEXT = MULTILINE_TEXT or function(...)
    end

TRIGGER_ISSUE_AFTER_TIME = TRIGGER_ISSUE_AFTER_TIME or function(trackingSince, triggerAfterHowLong)
    end

TRIGGER_ISSUE_IF = TRIGGER_ISSUE_IF or function(condition)
    end

Globals.daysToSeconds = function(days)
    return days * 24 * 60 * 60
end

Globals.readAllContentFromFile = function(filePath)
    local file = io.open(filePath, "r")
    assert(file)
    local content = file:read("*a")
    file:close()
    return content
end

Globals.emptyString = ""

Globals.splitStringBySeparator = function(str, separator)
    -- I wonder why lua does not offer a simple function like this. Pretty annoying.
    local result = {}
    local c0 = 1 -- Offset of next chunk
    while true do
        i = str:find(separator, c0) -- Find "next" occurrence
        if i == nil then
            break
        end
        c1 = i - 1 -- Index of last char of next chunk
        local chunk
        if c1 > c0 then
            chunk = str:sub(c0, c1)
        else
            chunk = ""
        end
        table.insert(result, chunk)
        c0 = c0 + #chunk + #separator
    end

    -- Append string after last separator
    if c0 <= #str then
        chunk = str:sub(c0)
    else
        chunk = ""
    end
    table.insert(result, chunk)
    return result
end
TRACK_ISSUE(
    "Bug",
    "If there's only one character between two separators, this function returns an empty string.",
    TRIGGER_ISSUE_IF(Globals.splitStringBySeparator(":c:", ":")[1] == Globals.emptyString)
)

Globals.stringIsEmpty = function(s)
    return s == nil or s == Globals.emptyString
end

Globals.stringIsNotEmpty = function(s)
    return not Globals.stringIsEmpty(s)
end

Globals.computeDistanceOnEarth = function(latLon1, latLon2)
    local degToRad = 0.017453293
    latLon1[1] = latLon1[1] * degToRad
    latLon1[2] = latLon1[2] * degToRad
    latLon2[1] = latLon2[1] * degToRad
    latLon2[2] = latLon2[2] * degToRad
    local sinMeanLat = math.sin((latLon2[1] - latLon1[1]) * 0.5)
    local sinMeanLon = math.sin((latLon2[2] - latLon1[2]) * 0.5)
    local underSquareRoot =
        (sinMeanLat * sinMeanLat) + (math.cos(latLon1[1]) * math.cos(latLon2[1]) * (sinMeanLon * sinMeanLon))
    local centralAngle = 2.0 * math.asin(math.min(1.0, math.sqrt(underSquareRoot)))
    local earthRadius = 6371.0
    local d = centralAngle * earthRadius
    return d
end

return Globals
