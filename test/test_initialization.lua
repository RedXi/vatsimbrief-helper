local flyWithLuaStub = require("xplane_fly_with_lua_stub")
local eventBusStub = require("eventbus")

TestInitialization = {}

function TestInitialization:setUp()
    VHFHelperEventBus = nil
end

function TestInitialization:testLazyInitializationIsGivingUpEventually()
    flyWithLuaStub:reset()
    local vatsimbriefHelper = dofile("scripts/vatsimbrief-helper.lua")

    luaUnit.assertEquals(vatsimbriefHelperPackageExport.test.LazyInitialization.gaveUpAlready, false)
    for i = 1, vatsimbriefHelperPackageExport.test.LazyInitialization.Constants.maxTries * 10 do
        vatsimbriefHelperPackageExport.test.LazyInitialization:tryVatsimbriefHelperInit()
    end
    luaUnit.assertEquals(vatsimbriefHelperPackageExport.test.LazyInitialization.gaveUpAlready, true)
end

function TestInitialization:testLazyInitializationIsCatchingUpEventuallyWhenConditionsAreMet()
    flyWithLuaStub:reset()
    local vatsimbriefHelper = dofile("scripts/vatsimbrief-helper.lua")

    luaUnit.assertEquals(vatsimbriefHelperPackageExport.test.LazyInitialization.vatsimbriefHelperIsInitialized, false)

    VHFHelperEventBus = eventBusStub.new()
    vatsimbriefHelperPackageExport.test.LazyInitialization:tryVatsimbriefHelperInit()

    luaUnit.assertEquals(vatsimbriefHelperPackageExport.test.LazyInitialization.vatsimbriefHelperIsInitialized, true)
end
