CurrentLatitudeReadDataref = 0
CurrentLongitudeReadDataref = 0

local M = {}
M.bootstrap = function()
    dataref("CurrentLatitudeReadDataref", "sim/flightmodel/position/latitude", "readable")
    dataref("CurrentLongitudeReadDataref", "sim/flightmodel/position/longitude", "readable")
end
return M
