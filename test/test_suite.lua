local vatsimbriefHelper = dofile("scripts/vatsimbrief-helper.lua")
flyWithLuaStub:suppressLogMessagesContaining(
    {
        "Vatsimbrief Helper using '",
        "Vatsimbrief configuration file '.\\TEMP\\TEST_RUN\\vatsimbrief-helper.ini' missing! Running without configuration settings.",
        "Processed Vatsim data: 1016 lines, 154 ATC, 0 w/o ID or frequency, 0 w/o callsign, 43 w/o description, 1 w/o 2D location, 0 w/o 3D location",
        "Initially showing window"
    }
)

require("shared_components.test_suite")

require("test_public_interface")
require("test_high_level")
require("test_initialization")
require("test_atc_inline_button_blob")
require("test_vatsim_data_container")
