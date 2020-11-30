local flyWithLuaStub = require("xplane_fly_with_lua_stub")
local eventBusStub = require("eventbus")

TestInitialization = {}

function TestInitialization:setUp()
    VHFHelperEventBus = nil
    TestHighLevel:createDatarefsAndBootstrapVatsimbriefHelper()
end

function TestInitialization:testLazyInitializationIsGivingUpEventually()
    luaUnit.assertEquals(vatsimbriefHelperPackageExport.test.LazyInitialization.gaveUpAlready, false)
    for i = 1, vatsimbriefHelperPackageExport.test.LazyInitialization.Constants.maxTries * 10 do
        vatsimbriefHelperPackageExport.test.LazyInitialization:tryVatsimbriefHelperInit()
    end
    luaUnit.assertEquals(vatsimbriefHelperPackageExport.test.LazyInitialization.gaveUpAlready, true)
end

function TestInitialization:testLazyInitializationIsCatchingUpEventuallyWhenConditionsAreMet()
    luaUnit.assertEquals(vatsimbriefHelperPackageExport.test.LazyInitialization.vatsimbriefHelperIsInitialized, false)

    VHFHelperEventBus = eventBusStub.new()
    vatsimbriefHelperPackageExport.test.LazyInitialization:tryVatsimbriefHelperInit()

    luaUnit.assertEquals(vatsimbriefHelperPackageExport.test.LazyInitialization.vatsimbriefHelperIsInitialized, true)
end
