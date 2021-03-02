local Globals = require("vatsimbrief-helper.globals")
local VatsimDataContainer = require("vatsimbrief-helper.components.vatsim_data_container")
local flyWithLuaStub = require("xplane_fly_with_lua_stub")
local Utilities = require("test_utilities")

TestVatsimDataContainer = {}

function TestVatsimDataContainer:setUp()
    TestHighLevel:createDatarefsAndBootstrapVatsimbriefHelper()
    self.VatsimData = self:getFreshTestVatsimDataContainer()
end

function TestVatsimDataContainer:getFreshTestVatsimDataContainer(sourceVatsimDataTxtOrNil)
    local newContainer = VatsimDataContainer:new()
    local dummyHttpRequest = {
        httpStatusCode = 200,
        responseBody = Globals.readAllContentFromFile(sourceVatsimDataTxtOrNil or "test/test-vatsim-data.txt")
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

if (false) then
    function TestVatsimDataContainer:testGenerateCrowdedTestData()
        dataref("VatsimbriefHelperCurrentLatitudeReadDataref", "sim/flightmodel/position/latitude", "readable")
        dataref("VatsimbriefHelperCurrentLongitudeReadDataref", "sim/flightmodel/position/longitude", "readable")

        local eddmPos = {48.3537, 11.7751}

        local latDataref = flyWithLuaStub.datarefs["sim/flightmodel/position/latitude"]
        local lonDataref = flyWithLuaStub.datarefs["sim/flightmodel/position/longitude"]

        latDataref.data = eddmPos[1]
        lonDataref.data = eddmPos[2]

        local crowdedContainer = self:getFreshTestVatsimDataContainer("test/test-vatsim-data-europe-crowded.txt")

        local outputText = "local allVatsimClientsWhenEuropeIsCrowded = {\n"
        for _, c in ipairs(crowdedContainer.AllVatsimClients) do
            outputText = outputText .. "\t{\n"
            outputText = outputText .. '\t\ttype = "' .. c.type .. '",\n'
            if (c.type == "Plane") then
                outputText = outputText .. '\t\tcallSign = "' .. c.callSign .. '",\n'
                outputText = outputText .. '\t\taltitude = "' .. c.altitude .. '",\n'
                outputText = outputText .. '\t\tgroundSpeed = "' .. c.groundSpeed .. '",\n'
                outputText = outputText .. '\t\theading = "' .. c.heading .. '",\n'
            else
                outputText = outputText .. '\t\tid = "' .. c.id .. '",\n'
                outputText = outputText .. '\t\tfrequency = "' .. c.frequency .. '",\n'
            end

            outputText = outputText .. '\t\tvatsimClientId = "' .. c.vatsimClientId .. '",\n'
            outputText = outputText .. '\t\tlatitude = "' .. c.latitude .. '",\n'
            outputText = outputText .. '\t\tlongitude = "' .. c.longitude .. '",\n'
            outputText = outputText .. "\t\tcurrentDistance = " .. c.currentDistance .. ",\n"

            outputText = outputText .. "\t},\n"
        end
        outputText = outputText .. "}\n"
        outputText = outputText .. "return allVatsimClientsWhenEuropeIsCrowded"

        Utilities.overwriteContentInFile("test/allVatsimClientsWhenEuropeIsCrowded.lua", outputText)
    end
end

function TestVatsimDataContainer:_findAtcInfoById(atcInfos, stationId)
    for _, atcInfo in pairs(atcInfos) do
        if (atcInfo.id == stationId) then
            return atcInfo
        end
    end

    return nil
end

function TestVatsimDataContainer:_findClientByTypeAndName(allVatsimClients, clientType, clientName)
    for _, client in ipairs(allVatsimClients) do
        if
            (client.type == VatsimDataContainer.ClientType.PLANE and clientType == VatsimDataContainer.ClientType.PLANE and
                client.callSign == clientName)
         then
            return client
        end

        if
            (client.type == VatsimDataContainer.ClientType.STATION and
                clientType == VatsimDataContainer.ClientType.STATION and
                client.id == clientName)
         then
            return client
        end
    end
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

function TestVatsimDataContainer:testClientInfoTableIsCorrect()
    local station =
        self:_findClientByTypeAndName(
        self.VatsimData.AllVatsimClients,
        VatsimDataContainer.ClientType.STATION,
        "SCEL_ATIS"
    )
    luaUnit.assertEquals(station.id, "SCEL_ATIS")
    luaUnit.assertEquals(station.frequency, "132.700")
    luaUnit.assertEquals(station.latitude, "-33.39444")
    luaUnit.assertEquals(station.longitude, "-70.7938")

    local plane =
        self:_findClientByTypeAndName(self.VatsimData.AllVatsimClients, VatsimDataContainer.ClientType.PLANE, "RYR14")
    luaUnit.assertEquals(plane.callSign, "RYR14")
    luaUnit.assertEquals(plane.latitude, "54.65995")
    luaUnit.assertEquals(plane.longitude, "-6.21772")
    luaUnit.assertEquals(plane.altitude, "234")
    luaUnit.assertEquals(plane.heading, "245")
    luaUnit.assertEquals(plane.groundSpeed, "0")
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

function TestVatsimDataContainer:testClientsAreSortedByCurrentDistance()
    local cs = self.VatsimData.AllVatsimClients
    local lastD = 0.0
    for _, client in ipairs(cs) do
        luaUnit.assertTrue(client.currentDistance >= lastD)
        lastD = client.currentDistance
    end
end
