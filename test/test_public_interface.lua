local Globals = require("vatsimbrief-helper.globals")
local VatsimData = require("vatsimbrief-helper.state.vatsim_data")

TestPublicInterface = {}

function TestPublicInterface:testGettingStationsWorks()
    local dummyHttpRequest = {
        httpStatusCode = 200,
        responseBody = Globals.readAllContentFromFile("test/test-vatsim-data.txt")
    }

    TestHighLevel:createDatarefsAndBootstrapVatsimbriefHelper()
    vatsimbriefHelperPackageExport.test.VatsimData.container:processSuccessfulHttpResponse(dummyHttpRequest)

    local atcInfos = VatsimbriefHelperPublicInterface.getAtcStationsForFrequencyClosestFirst("121.700")
    luaUnit.assertEquals(#atcInfos, 3)
    luaUnit.assertEquals(atcInfos[1].id, "TPA_GND")
    luaUnit.assertEquals(atcInfos[2].id, "SEA_GND")
    luaUnit.assertEquals(atcInfos[3].id, "CYVR_GND")
end
