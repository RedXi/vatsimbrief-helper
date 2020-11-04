local luaUnit = require("luaunit")
local ColorTextOutput = luaUnit.genericOutput.new() -- derived class
local ColorTextOutput_MT = {__index = ColorTextOutput} -- metatable
ColorTextOutput.__class__ = "ColorTextOutput"
function ColorTextOutput.new(runner)
    local t = luaUnit.genericOutput.new(runner, luaUnit.VERBOSITY_DEFAULT)
    t.errorList = {}
    return setmetatable(t, ColorTextOutput_MT)
end
function ColorTextOutput:startSuite()
    if self.verbosity > luaUnit.VERBOSITY_DEFAULT then
        print("Started on " .. self.result.startDate)
    end
end
function ColorTextOutput:startTest(testName)
    if self.verbosity > luaUnit.VERBOSITY_DEFAULT then
        io.stdout:write("    ", self.result.currentNode.testName, " ... ")
    end
end
function ColorTextOutput:endTest(node)
    if node:isSuccess() then
        if self.verbosity > luaUnit.VERBOSITY_DEFAULT then
            io.stdout:write("Ok\n")
        else
            io.stdout:write("[92m.[0m")
            io.stdout:flush()
        end
    else
        if self.verbosity > luaUnit.VERBOSITY_DEFAULT then
            --[[
                -- find out when to do this:
                if self.verbosity > luaUnit.VERBOSITY_DEFAULT then
                    print( node.stackTrace )
                end
                ]]
            print(node.status)
            print(node.msg)
        else
            -- write only the first character of status E, F or S
            io.stdout:write("[91m")
            io.stdout:write(string.sub(node.status, 1, 1))
            io.stdout:write("[0m")
            io.stdout:flush()
        end
    end
end
function ColorTextOutput:displayOneFailedTest(index, fail)
    print(index .. ") " .. fail.testName)
    print("[91m")
    print(fail.msg)
    print("[0m")
    print(fail.stackTrace)
    print()
end
function ColorTextOutput:displayErroredTests()
    if #self.result.errorTests ~= 0 then
        print("Tests with errors:")
        print("------------------")
        for i, v in ipairs(self.result.errorTests) do
            self:displayOneFailedTest(i, v)
        end
    end
end
function ColorTextOutput:displayFailedTests()
    if #self.result.failedTests ~= 0 then
        print("Failed tests:")
        print("-------------")
        for i, v in ipairs(self.result.failedTests) do
            self:displayOneFailedTest(i, v)
        end
    end
end
function ColorTextOutput:endSuite()
    if self.verbosity > luaUnit.VERBOSITY_DEFAULT then
        print("=========================================================")
    else
        print()
    end
    self:displayErroredTests()
    self:displayFailedTests()
    print(luaUnit.LuaUnit.statusLine(self.result))
    if self.result.notSuccessCount == 0 then
        print("OK")
    end
end
local LuaUnitOutput = {
    ColorText = ColorTextOutput
}

return LuaUnitOutput
