local LuaPlatform = require("lua_platform")

local Utilities = {}

Utilities.prefixAllLines = function(linesString, prefix)
    return prefix .. linesString:gsub("\n", "\n" .. prefix)
end

TRACK_ISSUE(
    "Lua",
    "There are no directory-related functions in Lua.",
    "Use os.rename to check if something exists (can be a directory)"
)
Utilities.fileOrDirectoryExists = function(path)
    local result, error, errorCode = os.rename(path, path)
    if (not result) then
        local permissionDeniedErrorCode = 13
        if (code == permissionDeniedErrorCode) then
            return true
        end

        return false
    end
    return true
end

Utilities.fileExists = function(filePath)
    local file = LuaPlatform.IO.open(filePath, LuaPlatform.IO.Constants.Modes.Read)
    if file == nil then
        return false
    end

    file:close()
    return true
end

Utilities.readAllContentFromFile = function(filePath)
    local file = LuaPlatform.IO.open(filePath, LuaPlatform.IO.Constants.Modes.Read)
    assert(file)
    local content = file:read("*a")
    file:close()
    return content
end

Utilities.overwriteContentInFile = function(filePath, newContent)
    local file = LuaPlatform.IO.open(filePath, LuaPlatform.IO.Constants.Modes.Overwrite)
    assert(file)
    file:write(newContent)
    file:close()
end

Utilities.copyFile = function(fromPath, toPath)
    local fromContent = Utilities.readAllContentFromFile(fromPath)
    Utilities.overwriteContentInFile(toPath, fromContent)
end

Utilities.splitStringBySeparator = function(str, separatorCharacter)
    if str:sub(-1) ~= separatorCharacter then
        str = str .. separatorCharacter
    end
    return str:gmatch("(.-)" .. separatorCharacter)
end

Utilities.newlineBreakStringAtWidth = function(str, width)
    local brokenString = ""
    local index = 1
    while true do
        local nextPart = str:sub(index, index + width - 1)
        if (nextPart:len() == 0) then
            break
        end
        brokenString = brokenString .. nextPart .. "\n"
        index = index + width
    end

    brokenString = brokenString:sub(1, -2)
    return brokenString
end

Utilities.urlEncode = function(str)
    str = str:gsub(" ", "%%20")
    str = str:gsub("\n", "%%0a")
    return str
end

Utilities.osExecuteEncode = function(str)
    str = str:gsub("&", "^&")
    str = str:gsub("<", "^<")
    str = str:gsub(">", "^>")
    return str
end

Utilities.trim = function(str)
    return str:gsub("^%s*(.-)%s*$", "%1")
end

Utilities.openUrlInLocalDefaultBrowser = function(url)
    return Utilities.runLocally(Utilities.urlEncode(url))
end

Utilities.runLocally = function(callString)
    local call = 'start "" ' .. Utilities.osExecuteEncode(callString)
    local successErrorlevel = 0
    if (os.execute(call) ~= successErrorlevel) then
        return false
    end

    return true
end

Utilities.encodeHexToByte = function(str)
    return (str:gsub(
        "..",
        function(twoHexCharacters)
            return string.char(tonumber(twoHexCharacters, 16))
        end
    ))
end

Utilities.encodeByteToHex = function(str)
    return (str:gsub(
        ".",
        function(character)
            return string.format("%02X", string.byte(character))
        end
    ))
end

TRACK_ISSUE("Lua", "Lua does not offer a round function.", "Waste a minute and implement one.")
Utilities.roundFloatingPointToNearestInteger = function(v)
    return v + 0.5 - (v + 0.5) % 1
end

Utilities.DegToRad = 0.017453293
Utilities.FeetToM = 0.3048
Utilities.KnotsToKmh = 1.852
Utilities.EarthRadius = 6371

Utilities.Math = {}
Utilities.Math.lerp = function(v1, v2, t)
    return v1 + (v2 - v1) * t
end

Utilities.getBlinkingColor = function(color, baseBrightness, blinkRate)
    return Utilities.getBlinkingColorBetweenTwo(0xFF000000, color, baseBrightness, blinkRate)
end

Utilities.getBlinkingColorBetweenTwo = function(color1, color2, baseBrightness, blinkRate)
    local brightness = (math.sin(LuaPlatform.Time.now() * blinkRate) + 1.0) * 0.5
    brightness = Utilities.Math.lerp(baseBrightness, 1.0, brightness)
    return Utilities.lerpColors(color1, color2, brightness)
end

TRACK_ISSUE(
    "Lua",
    "FlyWithLua is supposed to run Lua 5.1, which, in a clean development environment, does not support bit operations via bit.* functions.",
    "Disable in tests for now."
)
Utilities.lerpColors = function(color1, color2, t)
    if (IS_TEST ~= nil) then
        return 0xFF000000
    end

    local shiftByte = function(fourBytes, mask, shift)
        local byteOnly = bit.band(fourBytes, mask)
        byteOnly = bit.rshift(byteOnly, shift)
        return byteOnly
    end
    local getRed = function(color)
        return shiftByte(color, 0x000000FF, 0)
    end
    local getGreen = function(color)
        return shiftByte(color, 0x0000FF00, 8)
    end
    local getBlue = function(color)
        return shiftByte(color, 0x00FF0000, 16)
    end

    local red = Utilities.Math.lerp(getRed(color1), getRed(color2), t)
    local green = Utilities.Math.lerp(getGreen(color1), getGreen(color2), t)
    local blue = Utilities.Math.lerp(getBlue(color1), getBlue(color2), t)

    local setByte = function(fourBytes, newByte, shift)
        local shifted = bit.lshift(newByte, shift)
        shifted = bit.bor(fourBytes, shifted)
        return shifted
    end

    local setRed = function(color, newRed)
        return setByte(color, newRed, 0)
    end
    local setGreen = function(color, newGreen)
        return setByte(color, newGreen, 8)
    end
    local setBlue = function(color, newBlue)
        return setByte(color, newBlue, 16)
    end
    local getColorFromComponents = function(baseColor, r, g, b)
        local color = baseColor
        color = setRed(color, r)
        color = setGreen(color, g)
        color = setBlue(color, b)
        return color
    end

    return getColorFromComponents(0xFF000000, red, green, blue)
end

Utilities.getOccurrenceLocation = function(level)
    local stackLevelAboveTrackIssue = level
    local debugInfo = debug.getinfo(stackLevelAboveTrackIssue)
    local newOccurrenceLocation = debugInfo.source:sub(2, -1) .. ":" .. debugInfo.currentline
    return newOccurrenceLocation
end

return Utilities
