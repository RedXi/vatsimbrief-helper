local vatsimbriefHelper = dofile("scripts/vatsimbrief-helper.lua")
flyWithLuaStub:suppressLogMessagesBeginningWith("Vatsimbrief Helper using '")

require("shared_components.test_suite")

require("test_public_interface")
require("test_high_level")
require("test_initialization")
require("test_atc_inline_button_blob")
require("test_vatsim_data_container")
