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

SCRIPT_DIRECTORY = os.getenv("TEMP_TEST_SCRIPT_FOLDER") .. "\\"
local invalidPlaneIcao = "...."
PLANE_ICAO = invalidPlaneIcao

flyWithLuaStub = {
    Constants = {
        AccessTypeReadable = "readable",
        AccessTypeWritable = "writable",
        DatarefTypeInteger = "Int",
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
    planeIcao = nil
}

function logMsg(stringToLog)
    if (type(stringToLog) ~= "string") then
        stringToLog = tostring(stringToLog)
    end

    if (stringToLog ~= nil) then
        if
            (flyWithLuaStub.suppressLogMessageString ~= nil and
                stringToLog:sub(1, #flyWithLuaStub.suppressLogMessageString) == flyWithLuaStub.suppressLogMessageString)
         then
            return
        end
    end

    print("TEST LOG: " .. stringToLog)
end

function flyWithLuaStub:suppressLogMessagesBeginningWith(stringBeginning)
    flyWithLuaStub.suppressLogMessageString = stringBeginning
end

function flyWithLuaStub:setPlaneIcao(value)
    self.planeIcao = value
    PLANE_ICAO = value
end

function flyWithLuaStub:reset()
    self:setPlaneIcao(invalidPlaneIcao)
    self.datarefs = {}
    self.windows = {}
    self.doSometimesFunctions = {}
    self.doOftenFunctions = {}
    self.doEveryFrameFunctions = {}
    self.macros = {}
end

function flyWithLuaStub:createSharedDatarefHandle(datarefId, datarefType, initialData)
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

function flyWithLuaStub:activateMacro(macroName, activate)
    for _, macro in pairs(self.macros) do
        if (macro.name == macroName) then
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
end

function flyWithLuaStub:isMacroActive(macroName)
    for _, macro in pairs(self.macros) do
        if (macro.name == macroName) then
            return macro.isActiveNow
        end
    end

    return false
end

function flyWithLuaStub:closeWindowByHandle(window)
    luaUnit.assertTrue(window.isOpen)
    luaUnit.assertFalse(window.wasDestroyed)
    window.closeFunction()
    window.isOpen = false
end

function flyWithLuaStub:_callAllFunctionsInTable(functionTable)
    for _, f in pairs(functionTable) do
        f()
    end
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
        if (not w.wasDestroyed and w.isOpen) then
            w.imguiBuilderFunction()
        end
    end

    imguiStub:endFrame()
end

function flyWithLuaStub:runNextCompleteFrameAfterExternalWritesToDatarefs()
    self:runAllDoSometimesFunctions()
    self:runAllDoOftenFunctions()
    self:runAllDoEveryFrameFunctions()

    self:readbackAllWritableDatarefs()

    self:runImguiFrame()
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

function flyWithLuaStub:writeDatarefValueToLocalVariables(globalDatarefIdName)
    local d = self.datarefs[globalDatarefIdName]
    for localVariableName, localVariable in pairs(d.localVariables) do
        localVariable.writeFunction = loadstring(localVariableName .. " = " .. d.data)
        localVariable.writeFunction()
    end
end

function flyWithLuaStub:closeWindowByTitle(windowTitle)
    for _, window in pairs(self.windows) do
        if (window.title == nil) then
            logMsg(
                ("Warning: Titleless window imgui builder=%s onclose=%s found."):format(
                    window.imguiBuilderFunctionName or "NIL",
                    window.closeFunctionName or "NIL"
                )
            )
        elseif (window.title == windowTitle) then
            self:closeWindowByHandle(window)
        end
    end
end

function create_command(commandName, readableCommandName, toggleExpressionName, something1, something2)
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
            activateFunction = loadstring(activateExpression),
            deactivateFunction = loadstring(deactivateExpression),
            activateInitially = activateOrDeactivate == flyWithLuaStub.Constants.InitialStateActivate,
            isActiveNow = false
        }
    )
end

function define_shared_DataRef(globalDatarefIdName, datarefType)
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
    local variable = d.localVariables[localDatarefVariable]
    if (variable == nil) then
        variable = {}
        d.localVariables[localDatarefVariable] = variable
    end

    variable.readFunction = loadstring("return " .. localDatarefVariable)
    variable.accessType = accessType

    if (accessType == flyWithLuaStub.Constants.AccessTypeReadable) then
        flyWithLuaStub:writeDatarefValueToLocalVariables(globalDatarefIdName)
    end
end

function do_sometimes(doSometimesExpression)
    table.insert(flyWithLuaStub.doSometimesFunctions, loadstring(doSometimesExpression))
end

function do_often(doOftenExpression)
    table.insert(flyWithLuaStub.doOftenFunctions, loadstring(doOftenExpression))
end

function do_every_frame(doEveryFrameExpression)
    table.insert(flyWithLuaStub.doEveryFrameFunctions, loadstring(doEveryFrameExpression))
end

function XPLMFindDataRef(datarefName)
    luaUnit.assertNotNil(datarefName)
    local d = flyWithLuaStub.datarefs[datarefName]
    if (d == nil) then
        return nil
    end

    luaUnit.assertTrue(d.isInternallyDefinedDataref)

    return datarefName
end

function XPLMSetDatai(datarefName, newDataAsInteger)
    local d = flyWithLuaStub.datarefs[datarefName]
    luaUnit.assertNotNil(d)
    luaUnit.assertEquals(d.type, flyWithLuaStub.Constants.DatarefTypeInteger)
    d.data = newDataAsInteger

    luaUnit.assertTrue(d.isInternallyDefinedDataref)
end

function float_wnd_create(width, height, something, whatever)
    local newWindow = {
        wasDestroyed = false,
        isOpen = true
    }
    table.insert(flyWithLuaStub.windows, newWindow)
    return newWindow
end

function float_wnd_set_title(window, newTitle)
    window.title = newTitle
end

function float_wnd_set_onclose(window, newCloseFunctionName)
    window.closeFunction = loadstring(newCloseFunctionName .. "()")
    window.closeFunctionName = newCloseFunctionName
end

function float_wnd_set_imgui_builder(window, newImguiBuilderFunctionName)
    window.imguiBuilderFunction = loadstring(newImguiBuilderFunctionName .. "()")
    window.imguiBuilderFunctionName = newImguiBuilderFunctionName
end

function float_wnd_destroy(window)
    window.wasDestroyed = true
    window.isOpen = false
end

return flyWithLuaStub
