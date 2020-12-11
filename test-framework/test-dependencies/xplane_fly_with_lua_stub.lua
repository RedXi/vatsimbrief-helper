--[[

MIT License

Copyright (c) 2020 VerticalLongboard

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

--]]
local luaUnit = require("luaunit")
local imguiStub = require("imgui_stub")
local Utilities = require("test_utilities")

SCRIPT_DIRECTORY = os.getenv("TEMP_TEST_SCRIPT_FOLDER") .. "\\"

local function resetPlatformGlobals()
    local invalidSystem = "TEST"
    local invalidPlaneTailnumber = "???"
    local invalidPlaneIcao = "...."
    local invalidXplaneVersion = "0"
    local defaultAircraftPath = SCRIPT_DIRECTORY
    local invalidAircraftFilename = "does_not_exist.acf"

    PLANE_TAILNUMBER = invalidPlaneTailnumber
    SYSTEM = invalidSystem
    PLANE_ICAO = invalidPlaneIcao
    XPLANE_VERSION = invalidXplaneVersion
    AIRCRAFT_PATH = defaultAircraftPath
    AIRCRAFT_FILENAME = invalidAircraftFilename
end

resetPlatformGlobals()

flyWithLuaStub = {
    Constants = {
        AccessTypeReadable = "readable",
        AccessTypeWritable = "writable",
        DatarefTypeInteger = "Int",
        DatarefTypeFloat = "Float",
        InitialStateActivate = "activate",
        InitialStateDeactivate = "deactivate"
    },
    datarefs = {},
    windows = {},
    suppressLogMessageString = nil,
    doSometimesFunctions = {},
    doOftenFunctions = {},
    doEveryFrameFunctions = {},
    macros = {},
    commands = {},
    nonResettableNumLogMessagesSuppressed = 0
}

function logMsg(stringToLog)
    if (type(stringToLog) ~= "string") then
        stringToLog = tostring(stringToLog)
    end

    if (stringToLog ~= nil) then
        if (flyWithLuaStub.suppressLogMessageString ~= nil) then
            if (stringToLog:sub(1, #flyWithLuaStub.suppressLogMessageString) == flyWithLuaStub.suppressLogMessageString) then
                flyWithLuaStub.nonResettableNumLogMessagesSuppressed =
                    flyWithLuaStub.nonResettableNumLogMessagesSuppressed + 1
                return
            end
        end

        if (flyWithLuaStub.suppressLogMessageStrings ~= nil) then
            for str, _ in pairs(flyWithLuaStub.suppressLogMessageStrings) do
                if (stringToLog:find(str, 1, true) ~= nil) then
                    flyWithLuaStub.nonResettableNumLogMessagesSuppressed =
                        flyWithLuaStub.nonResettableNumLogMessagesSuppressed + 1
                    return
                end
            end
        end
    end

    if (stringToLog == "" or stringToLog == "\n") then
        print(tostring(Utilities.getOccurrenceLocation(3)) .. " is logging an empty string or just a newline.")
    end
    print("[7m" .. stringToLog .. "[0m")
end

function flyWithLuaStub:printSummary()
    print(("FlyWithLuaStub: [7m%d log messages suppressed[0m"):format(self.nonResettableNumLogMessagesSuppressed))
end

function flyWithLuaStub:suppressLogMessagesContaining(listOfStrings)
    if (flyWithLuaStub.suppressLogMessageStrings == nil) then
        flyWithLuaStub.suppressLogMessageStrings = {}
    end
    for _, str in pairs(listOfStrings) do
        flyWithLuaStub.suppressLogMessageStrings[str] = {}
    end
end

function flyWithLuaStub:suppressLogMessagesBeginningWith(stringBeginning)
    flyWithLuaStub.suppressLogMessageString = stringBeginning
end

function flyWithLuaStub:setPlaneIcao(value)
    self.planeIcao = value
    PLANE_ICAO = value
end

function flyWithLuaStub:reset()
    resetPlatformGlobals()
    self.datarefs = {}
    self.windows = {}
    self.doSometimesFunctions = {}
    self.doOftenFunctions = {}
    self.doEveryFrameFunctions = {}
    self.macros = {}
    self.command = {}
end

function flyWithLuaStub:createSharedDatarefHandle(datarefId, datarefType, initialData)
    luaUnit.assertNotNil(datarefId)
    if (self.datarefs[datarefId]) then
        logMsg(("Warning: Creating new dataref handle for existing dataref=%s"):format(datarefId))
    end

    luaUnit.assertNotNil(datarefType)
    luaUnit.assertNotNil(initialData)

    self.datarefs[datarefId] = {
        type = datarefType,
        localVariables = {},
        isInternallyDefinedDataref = true,
        data = initialData
    }
end

function flyWithLuaStub:bootstrapAllMacros()
    for _, macro in pairs(self.macros) do
        luaUnit.assertIsFalse(macro.isActiveNow)
        if (macro.activateInitially) then
            macro.activateFunction()
            macro.isActiveNow = true
        end
    end

    flyWithLuaStub:readbackAllWritableDatarefs()
end

function flyWithLuaStub:activateAllMacros(activate)
    for _, macro in pairs(self.macros) do
        if (activate) then
            luaUnit.assertIsFalse(macro.isActiveNow)
            macro.activateFunction()
        else
            luaUnit.assertIsTrue(macro.isActiveNow)
            macro.deactivateFunction()
        end
        macro.isActiveNow = activate
    end
end

function flyWithLuaStub:_activateMacroByReference(macro, activate)
    if (activate) then
        luaUnit.assertIsFalse(macro.isActiveNow)
        macro.activateFunction()
    else
        luaUnit.assertIsTrue(macro.isActiveNow)
        macro.deactivateFunction()
    end
    macro.isActiveNow = activate
end

function flyWithLuaStub:activateMacro(macroName, activate)
    local anyMacroActivated = false
    for _, macro in pairs(self.macros) do
        if (macro.name == macroName) then
            self:_activateMacroByReference(macro, activate)
            anyMacroActivated = true
        end
    end

    luaUnit.assertTrue(anyMacroActivated)
end

function flyWithLuaStub:isMacroActive(macroName)
    for _, macro in pairs(self.macros) do
        if (macro.name == macroName) then
            return macro.isActiveNow
        end
    end

    return false
end

function flyWithLuaStub:closeWindowByReference(window)
    luaUnit.assertTrue(window.isVisible)
    luaUnit.assertFalse(window.wasDestroyed)
    window.closeFunction()
    window.isVisible = false
end

function flyWithLuaStub:getWindowByTitle(windowTitle)
    luaUnit.assertNotNil(windowTitle)
    for _, window in pairs(self.windows) do
        if (window.title == nil) then
            logMsg(
                ("Warning: Titleless window imgui builder=%s onclose=%s found."):format(
                    window.imguiBuilderFunctionName or "NIL",
                    window.closeFunctionName or "NIL"
                )
            )
        elseif (window.title == windowTitle) then
            return window
        end
    end

    return nil
end

function flyWithLuaStub:_callAllFunctionsInTable(functionTable)
    for _, f in pairs(functionTable) do
        f()
    end
end

function flyWithLuaStub:debugPrintAllDatarefs()
    logMsg("All datarefs:")
    local numDatarefs = 0
    for datarefId, d in pairs(self.datarefs) do
        logMsg(("Dataref id=%s type=%s value=%s"):format(datarefId, d.type, tostring(d)))
        numDatarefs = numDatarefs + 1
    end

    logMsg(("Datarefs count=%d"):format(numDatarefs))
end

function flyWithLuaStub:debugPrintAllWindows()
    logMsg("All windows:")
    local numWindows = 0
    for windowTitle, w in pairs(self.windows) do
        logMsg(
            ("Window title=%s visible=%s destroyed=%s render=%s"):format(
                tostring(w.title),
                tostring(w.isVisible),
                tostring(w.wasDestroyed),
                tostring(w.imguiBuilderFunctionName)
            )
        )
        numWindows = numWindows + 1
    end

    logMsg(("Windows count=%d"):format(numWindows))
end

function flyWithLuaStub:runAllDoSometimesFunctions()
    self:_callAllFunctionsInTable(self.doSometimesFunctions)
end

function flyWithLuaStub:runAllDoOftenFunctions()
    self:_callAllFunctionsInTable(self.doOftenFunctions)
end

function flyWithLuaStub:runAllDoEveryFrameFunctions()
    self:_callAllFunctionsInTable(self.doEveryFrameFunctions)
end

function flyWithLuaStub:runImguiFrame()
    imguiStub:startFrame()

    for _, w in pairs(flyWithLuaStub.windows) do
        if (not w.wasDestroyed and w.isVisible) then
            w.imguiBuilderFunction()
        end
    end

    imguiStub:endFrame()
end

function flyWithLuaStub:cleanupBeforeRunningNextFrame()
    for key, window in pairs(self.windows) do
        if (window.wasDestroyed) then
            table.remove(self.windows, key)
        end
    end
end

function flyWithLuaStub:runNextCompleteFrameAfterExternalWritesToDatarefs()
    self:cleanupBeforeRunningNextFrame()

    self:writeAllDatarefValuesToLocalVariables()

    self:runAllDoSometimesFunctions()
    self:runAllDoOftenFunctions()
    self:runAllDoEveryFrameFunctions()
    self:runImguiFrame()

    self:readbackAllWritableDatarefs()
end

function flyWithLuaStub:readbackAllWritableDatarefs()
    for n, d in pairs(self.datarefs) do
        for localVariableName, localVariable in pairs(d.localVariables) do
            if (localVariable.accessType == self.Constants.AccessTypeWritable) then
                d.data = localVariable.readFunction()
            end
        end
    end
end

function flyWithLuaStub:writeAllDatarefValuesToLocalVariables()
    for n, d in pairs(self.datarefs) do
        self:writeDatarefValueToLocalVariables(n)
    end
end

function flyWithLuaStub:writeDatarefValueToLocalVariables(globalDatarefIdName)
    local d = self.datarefs[globalDatarefIdName]
    for localVariableName, localVariable in pairs(d.localVariables) do
        local actualNewData = "nil"
        if (d.data ~= nil) then
            actualNewData = tostring(d.data)
        end

        localVariable.writeFunction = LOAD_LUA_STRING(localVariableName .. " = " .. actualNewData)
        luaUnit.assertNotNil(localVariable.writeFunction)
        localVariable.writeFunction()
    end
end

function flyWithLuaStub:closeWindowByTitle(windowTitle)
    local wasAnyWindowClosed = false

    for _, window in pairs(self.windows) do
        if (window.title == windowTitle) then
            self:closeWindowByReference(window)
            wasAnyWindowClosed = true
        end
    end

    luaUnit.assertIsTrue(wasAnyWindowClosed)
end

function flyWithLuaStub:isWindowOpen(windowReference)
    return windowReference.isVisible
end

function flyWithLuaStub:executeCommand(commandName)
    luaUnit.assertNotNil(commandName)
    local c = self.commands[commandName]
    luaUnit.assertNotNil(c)
    c.commandFunction()
end

function create_command(commandName, readableCommandName, commandExpressionString, something1, something2)
    flyWithLuaStub.commands[commandName] = {
        readableName = readableCommandName,
        commandFunction = LOAD_LUA_STRING(commandExpressionString)
    }
end

function add_macro(macroName, activateExpression, deactivateExpression, activateOrDeactivate)
    luaUnit.assertTableContains(
        {flyWithLuaStub.Constants.InitialStateActivate, flyWithLuaStub.Constants.InitialStateDeactivate},
        activateOrDeactivate
    )

    table.insert(
        flyWithLuaStub.macros,
        {
            name = macroName,
            activateFunction = LOAD_LUA_STRING(activateExpression),
            deactivateFunction = LOAD_LUA_STRING(deactivateExpression),
            activateInitially = activateOrDeactivate == flyWithLuaStub.Constants.InitialStateActivate,
            isActiveNow = false
        }
    )
end

function define_shared_DataRef(globalDatarefIdName, datarefType)
    luaUnit.assertNotNil(globalDatarefIdName)
    luaUnit.assertNotNil(datarefType)
    local d = {}
    d.type = datarefType
    d.localVariables = {}
    d.isInternallyDefinedDataref = false
    flyWithLuaStub.datarefs[globalDatarefIdName] = d
end

function dataref(localDatarefVariable, globalDatarefIdName, accessType)
    luaUnit.assertNotNil(localDatarefVariable)
    luaUnit.assertNotNil(globalDatarefIdName)
    luaUnit.assertNotNil(accessType)
    luaUnit.assertTableContains(
        {flyWithLuaStub.Constants.AccessTypeReadable, flyWithLuaStub.Constants.AccessTypeWritable},
        accessType
    )

    local d = flyWithLuaStub.datarefs[globalDatarefIdName]
    luaUnit.assertNotNil(d)
    local variable = d.localVariables[localDatarefVariable]
    if (variable == nil) then
        variable = {}
        d.localVariables[localDatarefVariable] = variable
    end

    variable.readFunction = LOAD_LUA_STRING("return " .. localDatarefVariable)
    luaUnit.assertNotNil(variable.readFunction)
    variable.accessType = accessType

    if (accessType == flyWithLuaStub.Constants.AccessTypeReadable) then
        flyWithLuaStub:writeDatarefValueToLocalVariables(globalDatarefIdName)
    end
end

function do_sometimes(doSometimesExpression)
    table.insert(flyWithLuaStub.doSometimesFunctions, LOAD_LUA_STRING(doSometimesExpression))
end

function do_often(doOftenExpression)
    table.insert(flyWithLuaStub.doOftenFunctions, LOAD_LUA_STRING(doOftenExpression))
end

function do_every_frame(doEveryFrameExpression)
    table.insert(flyWithLuaStub.doEveryFrameFunctions, LOAD_LUA_STRING(doEveryFrameExpression))
end

function XPLMFindDataRef(datarefName)
    luaUnit.assertNotNil(datarefName)

    local d = flyWithLuaStub.datarefs[datarefName]
    if (d == nil) then
        return nil
    end

    TRACK_ISSUE(
        "FlyWithLua",
        "deleting a dataref",
        "In tests, it works because the environment is reset completely. Accept FlyWithLua/X-Plane flaw for now."
    )
    if (not d.isInternallyDefinedDataref) then
        logMsg(
            ("FlyWithLua Stub: Looked for dataref name=%s that is NOT created via createSharedDatarefHandle. That means you're very likely working around an X-Plane/FlyWithLua issue."):format(
                datarefName
            )
        )
    end

    return datarefName
end

function float_wnd_create(width, height, something, whatever)
    local newWindow = {
        wasDestroyed = false,
        isVisible = true
    }
    table.insert(flyWithLuaStub.windows, newWindow)
    return newWindow
end

function XPLMSetDataf(datarefName, newDataAsFloat)
    luaUnit.assertNotNil(datarefName)
    luaUnit.assertNotNil(newDataAsFloat)

    local d = flyWithLuaStub.datarefs[datarefName]
    luaUnit.assertNotNil(d)
    luaUnit.assertEquals(d.type, flyWithLuaStub.Constants.DatarefTypeFloat)
    d.data = newDataAsFloat

    luaUnit.assertTrue(d.isInternallyDefinedDataref)
end

function XPLMSetDatai(datarefName, newDataAsInteger)
    luaUnit.assertNotNil(datarefName)
    luaUnit.assertNotNil(newDataAsInteger)

    local d = flyWithLuaStub.datarefs[datarefName]
    luaUnit.assertNotNil(d)
    luaUnit.assertEquals(d.type, flyWithLuaStub.Constants.DatarefTypeInteger)
    d.data = newDataAsInteger

    luaUnit.assertTrue(d.isInternallyDefinedDataref)
end

function XPLMSpeakString(string)
    luaUnit.assertNotNil(string)
    logMsg(("Speaking string=%s"):format(string))
    flyWithLuaStub.lastSpeakString = string
end

function flyWithLuaStub:getLastSpeakString()
    return self.lastSpeakString
end

function float_wnd_load_image(path)
    return 1
end

function float_wnd_set_title(window, newTitle)
    window.title = newTitle
end

function float_wnd_set_onclose(window, newCloseFunctionName)
    window.closeFunction = LOAD_LUA_STRING(newCloseFunctionName .. "()")
    window.closeFunctionName = newCloseFunctionName
end

function float_wnd_set_imgui_builder(window, newImguiBuilderFunctionName)
    window.imguiBuilderFunction = LOAD_LUA_STRING(newImguiBuilderFunctionName .. "()")
    window.imguiBuilderFunctionName = newImguiBuilderFunctionName
end

TRACK_ISSUE(
    "FlyWithLua",
    "float_wnd_set_visible does not show windows in FlyWithLua when called like this: float_wnd_set_visible(window, 1), but it should.",
    "Do not call this function for now and block using it for anything besides hiding."
)
function float_wnd_set_visible(window, intValue)
    luaUnit.assertEquals(intValue, 0) -- Only hiding works in FlyWithLua
    luaUnit.assertNotNil(window)
    luaUnit.assertTrue(intValue == 0 or intValue == 1)
    local boolValue = nil
    if (intValue == 0) then
        boolValue = false
    else
        boolValue = true
    end

    window.isVisible = boolValue
end

TRACK_ISSUE(
    "FlyWithLua",
    "float_wnd_get_visible is not available in FlyWithLua.",
    "Do not offer it, but leave a comment at least."
)
-- This function is not available in FlyWithLua, but it should be.
-- function float_wnd_get_visible(window)
--     luaUnit.assertNotNil(window)

--     if (window.isVisible) then
--         return 1
--     else
--         return 0
--     end
-- end

function float_wnd_destroy(window)
    window.wasDestroyed = true
    window.isVisible = false
end

return flyWithLuaStub
