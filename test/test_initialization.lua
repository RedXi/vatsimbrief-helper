local flyWithLuaStub = require("xplane_fly_with_lua_stub")
local eventBusStub = require("eventbus")

TestInitialization = {}

function TestInitialization:setUp()
    VHFHelperEventBus = nil
end

function TestInitialization:testLazyInitializationIsGivingUpEventually()
    local vatsimbriefHelper = dofile("scripts/vatsimbrief-helper.lua")
    flyWithLuaStub:reset()
    flyWithLuaStub:bootstrapScriptUserInterface()
    flyWithLuaStub:runNextFrameAfterExternalWritesToDatarefs()

    luaUnit.assertEquals(vatsimbriefHelperPackageExport.test.LazyInitialization.gaveUpAlready, false)
    for i = 1, vatsimbriefHelperPackageExport.test.LazyInitialization.Constants.maxTries * 10 do
        flyWithLuaStub:runNextFrameAfterExternalWritesToDatarefs()
    end
    luaUnit.assertEquals(vatsimbriefHelperPackageExport.test.LazyInitialization.gaveUpAlready, true)
end

function TestInitialization:testLazyInitializationIsCatchingUpEventuallyWhenConditionsAreMet()
    local vatsimbriefHelper = dofile("scripts/vatsimbrief-helper.lua")
    flyWithLuaStub:reset()
    flyWithLuaStub:bootstrapScriptUserInterface()
    flyWithLuaStub:runNextFrameAfterExternalWritesToDatarefs()

    luaUnit.assertEquals(vatsimbriefHelperPackageExport.test.LazyInitialization.vatsimbriefHelperIsInitialized, false)

    VHFHelperEventBus = eventBusStub.new()
    flyWithLuaStub:runNextFrameAfterExternalWritesToDatarefs()

    luaUnit.assertEquals(vatsimbriefHelperPackageExport.test.LazyInitialization.vatsimbriefHelperIsInitialized, true)
end
