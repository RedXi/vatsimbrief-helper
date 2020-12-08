local EventBus = require("eventbus")

local vatsimbriefHelperStub = {
    frequencyToAtcInfosMap = {}
}

vatsimbriefHelperStub.frequencyToAtcInfosMap["129.200"] = {
    {id = "TPA_GND", description = "Just testing"},
    {id = "SEA_GND", description = "Online until appx 2300z / How am I doing?"},
    {id = "CYVR_GND", description = "Vancouver Ground^§Charts at www.fltplan.com^§Info at czvr.vatcan.ca"}
}

local hiddenInterface = {
    getInterfaceVersion = function()
        return 1
    end,
    getAtcStationsForFrequencyClosestFirst = function(fullFrequencyString)
        return vatsimbriefHelperStub.frequencyToAtcInfosMap[fullFrequencyString]
    end
}

VatsimbriefHelperEventOnVatsimDataRefreshed = "EventBus_EventName_VatsimbriefHelperEventOnVatsimDataRefreshed "

function vatsimbriefHelperStub:activateInterface()
    VatsimbriefHelperPublicInterface = hiddenInterface
    VatsimbriefHelperEventBus = EventBus.new()
end

function vatsimbriefHelperStub:deactivateInterface()
    VatsimbriefHelperPublicInterface = nil
    VatsimbriefHelperEventBus = nil
end

function vatsimbriefHelperStub:emitVatsimDataRefreshEvent()
    VatsimbriefHelperEventBus.emit(VatsimbriefHelperEventOnVatsimDataRefreshed)
end

return vatsimbriefHelperStub
