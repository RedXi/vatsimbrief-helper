local luaUnitOutput = require("luaunit_output")
local luaUnit = require("luaunit")
local flyWithLuaStub = require("xplane_fly_with_lua_stub")
local imguiStub = require("imgui_stub")

-- Put your tests in test_suite.lua
require("test_suite")

local runner = luaUnit.LuaUnit.new()
runner:setOutput(luaUnitOutput.ColorText)
os.exit(runner:runSuite())
