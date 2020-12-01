local emitVatsimDataUpdateEventInMainThreadSoon = false
local function emitVatsimDataUpdateEvent()
    emitVatsimDataUpdateEventInMainThreadSoon = true
end

TRACK_ISSUE("Tech Debt", "Replace specific vatsim update event method by generic MainThread.do(f) method.")
local M = {}
M.emitVatsimDataUpdateEvent = emitVatsimDataUpdateEvent
M.loop = function()
    if (emitVatsimDataUpdateEventInMainThreadSoon) then
        VatsimbriefHelperEventBus.emit(VatsimbriefHelperEventOnVatsimDataRefreshed)
        emitVatsimDataUpdateEventInMainThreadSoon = false
    end
end
return M
