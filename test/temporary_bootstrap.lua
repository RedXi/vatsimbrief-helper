TestTemporaryBootstrap = {}

LuaIniParserStub = require("LIP")

function TestTemporaryBootstrap:testRunVatsimbriefHelperAtLessThanOneFramePerSecond()
    flyWithLuaStub:reset()
    local iniContent = {}
    iniContent.simbrief = {}
    iniContent.simbrief.username = "<<<<USERNAME>>>>>"
    iniContent.flightplan = {}
    iniContent.flightplan.windowVisibility = "visible"
    iniContent.flightplan.flightPlanTypesForDownload1TypeName = "vPilot"

    local dummyIniFilePath = SCRIPT_DIRECTORY .. "vatsimbrief-helper.ini"
    local iniFile = io.open(dummyIniFilePath, "w+b")
    iniFile:close()

    LuaIniParserStub:setFileContentBeforeLoad(iniContent)

    local vatsimbriefHelper = dofile("scripts/vatsimbrief-helper.lua")
    flyWithLuaStub:bootstrapAllMacros()

    local clock = os.clock
    while true do
        local t0 = clock()
        while clock() - t0 <= 3 do
        end

        flyWithLuaStub:runNextFrameAfterExternalWritesToDatarefs()
    end
end
