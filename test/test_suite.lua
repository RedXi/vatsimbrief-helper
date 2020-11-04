local luaUnitOutput = require("luaunit_output")
local luaUnit = require("luaunit")
local flyWithLuaStub = require("xplane_fly_with_lua_stub")
local imguiStub = require("imgui_stub")

local vhfHelper = dofile("scripts/vatsimbrief-helper.lua")
flyWithLuaStub:suppressLogMessagesBeginningWith("Vatsimbrief Helper using '")

require("test_inline_button_blob")

local runner = luaUnit.LuaUnit.new()
runner:setOutput(luaUnitOutput.ColorText)
os.exit(runner:runSuite())
