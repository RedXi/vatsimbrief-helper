local Globals = require("vatsimbrief-helper.globals")
local VatsimDataContainer = require("vatsimbrief-helper.components.vatsim_data_container")
local flyWithLuaStub = require("xplane_fly_with_lua_stub")

TestVatsimDataContainer = {}

function TestVatsimDataContainer:setUp()
    TestHighLevel:createDatarefsAndBootstrapVatsimbriefHelper()
    self.VatsimData = self:getFreshTestVatsimDataContainer()
end

function TestVatsimDataContainer:getFreshTestVatsimDataContainer()
    local newContainer = VatsimDataContainer:new()
    local dummyHttpRequest = {
        httpStatusCode = 200,
        responseBody = Globals.readAllContentFromFile("test/test-vatsim-data.txt")
    }

    local beforeTime = os.clock()
    newContainer:processSuccessfulHttpResponse(dummyHttpRequest)
    local afterTime = os.clock()
    local t_diff = afterTime - beforeTime
    local MaxDiff = 1.0 / 30.0
    TRACK_ISSUE(
        "Optimization",
        MULTILINE_TEXT(
            ("Processing new Vatsim data takes too long t_diff=%f > MaxDiff=%f"):format(t_diff, MaxDiff),
            "It runs asynchronously anyway, but something is probably wrong if it takes that long."
        ),
        TRIGGER_ISSUE_IF(t_diff > MaxDiff)
    )

    return newContainer
end

function TestVatsimDataContainer:_findAtcInfoById(atcInfos, stationId)
    for _, atcInfo in pairs(atcInfos) do
        if (atcInfo.id == stationId) then
            return atcInfo
        end
    end

    return nil
end

function TestVatsimDataContainer:testAtcInfoTableIsCorrect()
    local tsid = "MUFH_G_CTR"
    local atcInfo = self:_findAtcInfoById(self.VatsimData.MapAtcIdentifiersToAtcInfo, tsid)

    luaUnit.assertEquals(atcInfo.id, tsid)
    luaUnit.assertEquals(atcInfo.frequency, "133.700")
    luaUnit.assertEquals(
        atcInfo.description,
        "Havana Center / voice English & Spanish^§For charts and scenery visit havana.vatcar.org"
    )
    luaUnit.assertEquals(atcInfo.latitude, tonumber("21.99509"))
    luaUnit.assertEquals(atcInfo.longitude, tonumber("-83.83585"))
end

function TestVatsimDataContainer:testAtcInfosPerFrequencyAreCorrect()
    local tf = "121.700"

    local atcInfos = self.VatsimData.MapAtcFrequenciesToAtcInfos[tf]
    luaUnit.assertEquals(#atcInfos, 3)
    luaUnit.assertEquals(self:_findAtcInfoById(atcInfos, "SEA_GND").frequency, tf)
    luaUnit.assertEquals(self:_findAtcInfoById(atcInfos, "TPA_GND").frequency, tf)
    luaUnit.assertEquals(self:_findAtcInfoById(atcInfos, "CYVR_GND").frequency, tf)
end

function TestVatsimDataContainer:testStationAppearsInBothMaps()
    local tsid = "MIA_AL_CTR"
    local atcInfo = self:_findAtcInfoById(self.VatsimData.MapAtcIdentifiersToAtcInfo, tsid)
    local atcInfos = self.VatsimData.MapAtcFrequenciesToAtcInfos[atcInfo.frequency]
    local found = false
    for _, atcInfo in ipairs(atcInfos) do
        if (atcInfo.id == tsid) then
            found = true
            break
        end
    end

    luaUnit.assertIsTrue(found)
end

function TestVatsimDataContainer:testDistanceComputationMakesSense()
    local eddePos = {50.9792, 10.9572}
    local d = Globals.computeDistanceOnEarth(TestHighLevel.Constants.SkrgPos, eddePos)
    luaUnit.assertIsTrue(d > 9000.0)
    luaUnit.assertIsTrue(d < 9500.0)
end

function TestVatsimDataContainer:testDuplicateFrequenciesAreSortedByCurrentDistance()
    local tf = "119.100"
    local PalmBeachTower = "PBI_TWR" -- About 2000 km
    local CordobaApproach = "SACO_APP" -- About 4000 km
    local CordobaControl = "SACO_X_APP" -- Same as SACO_APP
    local LisbonApproach = "LPPT_APP" -- About 7000 km

    local atcInfos = self.VatsimData.MapAtcFrequenciesToAtcInfos[tf]
    luaUnit.assertEquals(#atcInfos, 4)
    luaUnit.assertEquals(atcInfos[1].id, PalmBeachTower)
    luaUnit.assertEquals(atcInfos[2].id, CordobaApproach)
    luaUnit.assertEquals(atcInfos[3].id, CordobaControl)
    luaUnit.assertEquals(atcInfos[4].id, LisbonApproach)
end
