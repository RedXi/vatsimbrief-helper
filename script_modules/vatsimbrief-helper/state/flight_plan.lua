TRACK_ISSUE(
    "Tech Debt",
    MULTILINE_TEXT(
        "To expose current callsign via public interface, the value FlightplanCallsign needs to be stored outside the main script to avoid require loops.",
        "Since there's still a lot of stuff to move out of the main script, manually store the call sign here for now. Move the rest later."
    )
)

local FlightplanCallsign

local M = {}
M.setCallSign = function(newCallSign)
    FlightplanCallsign = newCallSign
end
M.getCallSign = function()
    return FlightplanCallsign
end
return M
