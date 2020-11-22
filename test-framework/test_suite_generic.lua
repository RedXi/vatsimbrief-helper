local luaUnitOutput = require("luaunit_output")
local luaUnit = require("luaunit")
local flyWithLuaStub = require("xplane_fly_with_lua_stub")
local imguiStub = require("imgui_stub")

local issueTracker = require("issue_tracker")

-- Put your tests in test/test_suite.lua
require("test_suite")

local runner = luaUnit.LuaUnit.new()
-- runner:setOutput(luaUnitOutput.ColorText)
runner:setOutput(luaUnitOutput.ColorTap)
local runnerResult = runner:runSuite()
issueTracker:printSummary()
os.exit(runnerResult)
