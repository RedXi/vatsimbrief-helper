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
            io.stdout:write("[92m>[0m")
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
    print("[91m" .. fail.msg .. "[0m")
    print("[94m" .. fail.stackTrace .. "[0m")
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

    if (self.result.successCount == 0 and self.result.errorCount == 0 and self.result.failureCount) then
        print(
            "[93mNo tests[0m found in .\\[94mtest\\test_suite.lua[0m (if that's intentional, consider adding at least one require/dofile for your main script)"
        )
    end
end

local ColorTapOutput = luaUnit.genericOutput.new() -- derived class
local TapOutput_MT = {__index = ColorTapOutput} -- metatable
ColorTapOutput.__class__ = "ColorTapOutput"

-- For a good reference for TAP format, check: http://testanything.org/tap-specification.html

function ColorTapOutput.new(runner)
    local t = luaUnit.genericOutput.new(runner, luaUnit.VERBOSITY_LOW)
    return setmetatable(t, TapOutput_MT)
end
function ColorTapOutput:startSuite()
    print("1.." .. self.result.selectedCount)
    print("# Started on " .. self.result.startDate)
end
function ColorTapOutput:startClass(className)
    if className ~= "[TestFunctions]" then
        print("[4m# Starting class: " .. className .. "[0m")
    end
end

function ColorTapOutput:updateStatus(node)
    if node:isSkipped() then
        io.stdout:write("[92mok[0m ", self.result.currentTestNumber, "\t# SKIP ", node.msg, "\n")
        return
    end

    io.stdout:write(" [91mnot ok[0m ", self.result.currentTestNumber, "\t[93m", node.testName, "[0m\n")
    if self.verbosity > luaUnit.VERBOSITY_LOW then
        print("[91m" .. luaUnit.private.prefixString("#   ", node.msg) .. "[0m")
        print("[94m" .. luaUnit.private.prefixString("#   ", node.stackTrace) .. "[0m")
    end
    if (node:isFailure() or node:isError()) and self.verbosity > luaUnit.VERBOSITY_DEFAULT then
        print(luaUnit.private.prefixString("#   ", node.stackTrace))
    end
end

function ColorTapOutput:endTest(node)
    if node:isSuccess() then
        io.stdout:write("[92m ok[0m     ", self.result.currentTestNumber, "\t", node.testName, "\n")
    end
end

function ColorTapOutput:endSuite()
    print("# " .. luaUnit.LuaUnit.statusLine(self.result))
    return self.result.notSuccessCount
end

local LuaUnitOutput = {
    ColorText = ColorTextOutput,
    ColorTap = ColorTapOutput
}

return LuaUnitOutput
