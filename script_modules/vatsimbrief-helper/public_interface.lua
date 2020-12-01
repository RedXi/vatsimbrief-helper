local VatsimData = require("vatsimbrief-helper.state.vatsim_data")

TRACK_ISSUE(
    "Public Interface",
    MULTILINE_TEXT(
        "Interface users can (and will, because it's Lua) easily break the VatsimDataContainer.",
        "Copy all retrieved data to avoid issues. This function is usually called on frequency change only."
    ),
    "Accept the minor delay in external synchronous threads for now."
)
VatsimbriefHelperPublicInterface = {
    getInterfaceVersion = function()
        return 1
    end,
    getAtcStationsForFrequencyClosestFirst = function(fullFrequencyString)
        local atcInfos = VatsimData.container:getAtcStationsForFrequencyClosestFirst(fullFrequencyString)
        if (atcInfos == nil) then
            return nil
        end

        local atcInfosCopy = {}
        for _, atcInfo in ipairs(atcInfos) do
            local newAtcInfo = {
                id = atcInfo.id,
                description = atcInfo.description
            }
            table.insert(atcInfosCopy, newAtcInfo)
        end
        return atcInfosCopy
    end
}

VatsimbriefHelperEventOnVatsimDataRefreshed = "EventBus_EventName_VatsimbriefHelperEventOnVatsimDataRefreshed"

local EventBus = require("eventbus")
VatsimbriefHelperEventBus = EventBus.new()

M = {}
return M
