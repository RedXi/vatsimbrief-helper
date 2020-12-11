local EventBus = require("eventbus")

local vatsimbriefHelperStub = {
    frequencyToAtcInfosMap = {}
}

vatsimbriefHelperStub.frequencyToAtcInfosMap["129.200"] = {
    {id = "TPA_GND", description = "Just testing"},
    {id = "SEA_GND", description = "Online until appx 2300z / How am I doing?"},
    {id = "CYVR_GND", description = "Vancouver Ground^§Charts at www.fltplan.com^§Info at czvr.vatcan.ca"}
}

vatsimbriefHelperStub.ownCallSign = "THATSME"

vatsimbriefHelperStub.testVatsimClients = {
    {
        type = "Plane",
        callSign = vatsimbriefHelperStub.ownCallSign,
        latitude = "6.1708",
        longitude = "-75.4276",
        altitude = "39000.0",
        heading = "270.0",
        groundSpeed = "450",
        currentDistance = 0.0
    },
    {
        type = "Plane",
        callSign = "DLH53N",
        latitude = "8.0",
        longitude = "-76.0",
        altitude = "24000.0",
        heading = "183.0",
        groundSpeed = "409",
        currentDistance = 10.0
    },
    {
        type = "Plane",
        callSign = "DLH62X",
        latitude = "7.0",
        longitude = "-76.0",
        altitude = "13000.0",
        heading = "51.0",
        groundSpeed = "220",
        currentDistance = 20.0
    },
    {
        type = "Plane",
        callSign = "DLH57D",
        latitude = "10.0",
        longitude = "-73.0",
        altitude = "23000.0",
        heading = "355.0",
        groundSpeed = "320",
        currentDistance = 30.0
    },
    {
        type = "Station",
        id = "SKRG_APP",
        latitude = "5.0",
        longitude = "-75.0",
        frequency = "118.000",
        currentDistance = 40.0
    }
}

local hiddenInterface = {
    getInterfaceVersion = function()
        return 2
    end,
    getAtcStationsForFrequencyClosestFirst = function(fullFrequencyString)
        return vatsimbriefHelperStub.frequencyToAtcInfosMap[fullFrequencyString]
    end,
    getOwnCallSign = function()
        return vatsimbriefHelperStub.ownCallSign
    end,
    getAllVatsimClientsClosestFirstWithTimestamp = function()
        return vatsimbriefHelperStub.testVatsimClients, 0
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
