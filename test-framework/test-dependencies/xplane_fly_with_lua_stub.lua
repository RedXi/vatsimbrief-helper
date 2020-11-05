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

SCRIPT_DIRECTORY = "."

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
    userInterfaceIsActive = false,
    suppressLogMessageString = nil
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

function flyWithLuaStub:reset()
    self.datarefs = {}
    self.windows = {}
    self.userInterfaceIsActive = false
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

function flyWithLuaStub:bootstrapScriptUserInterface()
    if (self.initialActivationState == self.Constants.InitialStateActivate) then
        self.activateScriptFunction()
        self.userInterfaceIsActive = true
    end
end

function flyWithLuaStub:shutdownScriptUserInterface()
    self.deactivateScriptFunction()
    self.userInterfaceIsActive = false
end

function flyWithLuaStub:closeWindow(window)
    luaUnit.assertTrue(window.isOpen)
    luaUnit.assertFalse(window.wasDestroyed)
    window.closeFunction()
    window.isOpen = false
end

function flyWithLuaStub:runNextFrameAfterExternalWritesToDatarefs()
    if (self.doSometimesFunction ~= nil) then
        self.doSometimesFunction()
    end
    if (self.doOftenFunction ~= nil) then
        self.doOftenFunction()
    end
    if (self.doEveryFrameFunction ~= nil) then
        self.doEveryFrameFunction()
    end

    self:readbackAllWritableDatarefs()

    if (not flyWithLuaStub.userInterfaceIsActive) then
        return
    end

    imguiStub:startFrame()

    for _, w in pairs(flyWithLuaStub.windows) do
        if (not w.wasDestroyed and w.isOpen) then
            w.imguiBuilderFunction()
        end
    end

    imguiStub:endFrame()
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

function create_command(commandName, readableCommandName, toggleExpressionName, something1, something2)
end

function add_macro(readableScriptName, activateExpression, deactivateExpression, activateOrDeactivate)
    flyWithLuaStub.activateScriptFunction = loadstring(activateExpression)
    flyWithLuaStub.deactivateScriptFunction = loadstring(deactivateExpression)

    luaUnit.assertTableContains(
        {flyWithLuaStub.Constants.InitialStateActivate, flyWithLuaStub.Constants.InitialStateDeactivate},
        activateOrDeactivate
    )
    flyWithLuaStub.initialActivationState = activateOrDeactivate
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
    flyWithLuaStub.doSometimesFunction = loadstring(doSometimesExpression)
end

function do_often(doOftenExpression)
    flyWithLuaStub.doOftenFunction = loadstring(doOftenExpression)
end

function do_every_frame(doEveryFrameExpression)
    flyWithLuaStub.doEveryFrameFunction = loadstring(doEveryFrameExpression)
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
end

function float_wnd_set_onclose(window, newCloseFunctionName)
    window.closeFunction = loadstring(newCloseFunctionName .. "()")
end

function float_wnd_set_imgui_builder(window, newImguiBuilderFunctionName)
    window.imguiBuilderFunction = loadstring(newImguiBuilderFunctionName .. "()")
end

function float_wnd_destroy(window)
    window.wasDestroyed = true
    window.isOpen = false
end

return flyWithLuaStub
