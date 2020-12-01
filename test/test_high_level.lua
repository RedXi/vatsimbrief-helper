LuaIniParserStub = require("LIP")

TestHighLevel = {
    Constants = {
        SkrgPos = {6.1708, -75.4276}
    }
}

function TestHighLevel:createDatarefsAndBootstrapVatsimbriefHelper()
    flyWithLuaStub:reset()
    flyWithLuaStub:createSharedDatarefHandle(
        "sim/flightmodel/position/latitude",
        flyWithLuaStub.Constants.DatarefTypeFloat,
        self.Constants.SkrgPos[1]
    )
    flyWithLuaStub:createSharedDatarefHandle(
        "sim/flightmodel/position/longitude",
        flyWithLuaStub.Constants.DatarefTypeFloat,
        self.Constants.SkrgPos[2]
    )
    dofile("scripts/vatsimbrief-helper.lua")
end

function TestHighLevel:_busyWait(seconds)
    local t0 = os.clock()
    while os.clock() - t0 < seconds do
    end
end

function TestHighLevel:testRunVatsimbriefHelper()
    local invalidUsername = "<<<INVALID_SIMBRIEF_USERNAME>>>"
    local username = nil or invalidUsername
    local ENABLED = false
    if (not ENABLED) then
        return
    end

    flyWithLuaStub:reset()
    local iniContent = {}
    iniContent.simbrief = {}
    iniContent.simbrief.username = username
    luaUnit.assertNotEquals(iniContent.simbrief.username, invalidUsername)
    iniContent.flightplan = {}
    iniContent.flightplan.deleteDownloadedFlightPlans = "yes"
    iniContent.flightplan.windowVisibility = "visible"
    iniContent.flightplan.flightPlanTypesForDownload1TypeName = "vPilot"

    local dummyIniFilePath = SCRIPT_DIRECTORY .. "vatsimbrief-helper.ini"
    local iniFile = io.open(dummyIniFilePath, "w+b")
    iniFile:write("Thats a dummy file, never read from and never written to.")
    iniFile:close()

    LuaIniParserStub.setFileContentBeforeLoad(iniContent)

    local vatsimbriefHelper = dofile("scripts/vatsimbrief-helper.lua")
    flyWithLuaStub:bootstrapAllMacros()

    -- os.execute('start "" ' .. SCRIPT_DIRECTORY)

    local lastDoOftenTime = 0
    local lastDoSometimesTime = 0
    local lastDoEveryFrameTime = 0

    local const = {
        DoEveryFrameTimeout = 1.0 / 60.0,
        DoOftenTimeout = 1,
        DoSometimesTimeout = 10
    }

    while true do
        local now = os.clock()

        if (now - lastDoSometimesTime > const.DoSometimesTimeout) then
            flyWithLuaStub:runAllDoSometimesFunctions()
            flyWithLuaStub:readbackAllWritableDatarefs()
            lastDoSometimesTime = now
        end

        if (now - lastDoOftenTime > const.DoOftenTimeout) then
            flyWithLuaStub:runAllDoOftenFunctions()
            flyWithLuaStub:readbackAllWritableDatarefs()
            lastDoOftenTime = now
        end

        if (now - lastDoEveryFrameTime > const.DoEveryFrameTimeout) then
            flyWithLuaStub:runAllDoEveryFrameFunctions()
            flyWithLuaStub:readbackAllWritableDatarefs()
            flyWithLuaStub:runImguiFrame()
            self:_busyWait(const.DoEveryFrameTimeout)
            lastDoEveryFrameTime = now
        end
    end
end
