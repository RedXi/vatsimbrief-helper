TestTemporaryBootstrap = {}

LuaIniParserStub = require("LIP")

function TestTemporaryBootstrap:_busyWait(seconds)
    local t0 = os.clock()
    while os.clock() - t0 < seconds do
    end
end

function TestTemporaryBootstrap:testRunVatsimbriefHelper()
    flyWithLuaStub:reset()
    local iniContent = {}
    iniContent.simbrief = {}
    local invalidUsername = "<<<SIMBRIEF USERNAME HERE>>>"
    iniContent.simbrief.username = invalidUsername
    luaUnit.assertNotEquals(iniContent.simbrief.username, invalidUsername)
    iniContent.flightplan = {}
    iniContent.flightplan.deleteDownloadedFlightPlans = "yes"
    iniContent.flightplan.windowVisibility = "visible"
    iniContent.flightplan.flightPlanTypesForDownload1TypeName = "vPilot"

    local dummyIniFilePath = SCRIPT_DIRECTORY .. "vatsimbrief-helper.ini"
    local iniFile = io.open(dummyIniFilePath, "w+b")
    iniFile:close()

    LuaIniParserStub:setFileContentBeforeLoad(iniContent)

    local vatsimbriefHelper = dofile("scripts/vatsimbrief-helper.lua")
    flyWithLuaStub:bootstrapAllMacros()

    os.execute('start "" ' .. SCRIPT_DIRECTORY)

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
