local vatsimbriefHelper = dofile("scripts/vatsimbrief-helper.lua")
flyWithLuaStub:suppressLogMessagesContaining(
    {
        "Vatsimbrief Helper using '",
        "Vatsimbrief configuration file '.\\TEMP\\TEST_RUN\\vatsimbrief-helper.ini' missing! Running without configuration settings.",
        "Processed Vatsim data: 1016 lines, 154 ATC, 0 w/o ID or frequency, 58 w/o description, 1 w/o location"
    }
)

require("shared_components.test_suite")

require("test_public_interface")
require("test_high_level")
require("test_initialization")
require("test_atc_inline_button_blob")
require("test_vatsim_data_container")
