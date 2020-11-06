TestTemporaryBootstrap = {}

function TestTemporaryBootstrap:testRunVatsimbriefHelperAtOneFramePerSecond()
    flyWithLuaStub:reset()
    local vatsimbriefHelper = dofile("scripts/vatsimbrief-helper.lua")
    vatsimbriefHelperPackageExport.test.Configuration.flightplan = {}
    vatsimbriefHelperPackageExport.test.Configuration.flightplan.windowVisibility = "visible"
    vatsimbriefHelperPackageExport.test.Configuration.File.simbrief = {}
    vatsimbriefHelperPackageExport.test.Configuration.File.simbrief.username = "<<<USERNAME>>>>"
    vatsimbriefHelperPackageExport.test.Configuration.File.flightplan = {}
    vatsimbriefHelperPackageExport.test.Configuration.File.flightplan.flightPlanTypesForDownload1TypeName = "vPilot"
    flyWithLuaStub:bootstrapAllMacros()

    local clock = os.clock
    while true do
        local t0 = clock()
        while clock() - t0 <= 1 do
            flyWithLuaStub:runNextFrameAfterExternalWritesToDatarefs()
        end
    end
end
