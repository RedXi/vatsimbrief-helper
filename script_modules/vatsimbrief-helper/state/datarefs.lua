VatsimbriefHelperCurrentLatitudeReadDataref = 0
VatsimbriefHelperCurrentLongitudeReadDataref = 0

local M = {}
M.bootstrap = function()
    dataref("VatsimbriefHelperCurrentLatitudeReadDataref", "sim/flightmodel/position/latitude", "readable")
    dataref("VatsimbriefHelperCurrentLongitudeReadDataref", "sim/flightmodel/position/longitude", "readable")
end
return M
