local emitVatsimDataUpdateEventInMainThreadSoon = false
local function emitVatsimDataUpdateEvent()
    emitVatsimDataUpdateEventInMainThreadSoon = true
end

local M = {}
M.emitVatsimDataUpdateEvent = emitVatsimDataUpdateEvent
M.loop = function()
    if (emitVatsimDataUpdateEventInMainThreadSoon) then
        VatsimbriefHelperEventBus.emit(VatsimbriefHelperEventOnVatsimDataRefreshed)
        emitVatsimDataUpdateEventInMainThreadSoon = false
    end
end
return M
