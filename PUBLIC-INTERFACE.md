## Vatsimbrief Helper Public Interface
Vatsimbrief Helper offers a public API via a global `VatsimbriefHelperPublicInterface`:
```text
if (VatsimbriefHelperPublicInterface ~= nil and VatsimbriefHelperPublicInterface.getInterfaceVersion() == 1) then
  -- Setup event listener
  ...
  -- Call method on VatsimbriefHelperPublicInterface
  ...
end
```

To retrieve a list of all ATC stations in the Vatsim network for a given frequency:
```text
local atcInfos = VatsimbriefHelperPublicInterface.getAtcStationsForFrequencyClosestFirst("129.200")
```
`getAtcStationsForFrequencyClosestFirst` returns a distance-sorted list of all stations with the specified frequency:
```text
atcInfos = {
  { id = "TPA_GND", description = nil}, -- Closest station
  { id = "SEA_GND", description = "Online until appx 2300z / How am I doing?"},
  { id = "CYVR_GND", description = "Vancouver Ground^§Charts at www.fltplan.com^§Info at czvr.vatcan.ca"}
}
```

Get all Vatsim clients currently connected to the Vatsim network:
```text
local vatsimClients, timestamp = VatsimbriefHelperPublicInterface.getAllVatsimClientsClosestFirstWithTimestamp()
```

`getAllVatsimClientsClosestFirstWithTimestamp` returns a distance-sorted list of all Vatsim clients:
```text
timestamp = { 22342.343 } -- os.clock() at the time Vatsim data was updated
vatsimClients = {
  {
    -- Planes have altitude, heading and groundSpeed
    -- Planes have a callSign
    type = "Plane",
    callSign = "OWN_CALLSIGN", -- To find out if a plane is your own plane, use getOwnCallSign(), see below
    vatsimClientId = "23895389539"
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
    vatsimClientId = "3252352323",
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
    vatsimClientId = "215476763534",
    latitude = "7.0",
    longitude = "-76.0",
    altitude = "13000.0",
    heading = "51.0",
    groundSpeed = "220",
    currentDistance = 20.0
  },
  {
    -- Stations have a frequency
    -- Stations have a id
    type = "Station",
    id = "SKRG_APP",
    vatsimClientId = "884848237",
    latitude = "5.0",
    longitude = "-75.0",
    frequency = "118.000",
    currentDistance = 40.0
  }
}
```

`getOwnCallSign` returns your own callsign as filed in Simbrief:
```text
ownCallSign = VatsimbriefHelperPublicInterface.getOwnCallSign()
```

```text
ownCallSign = "OWN_CALLSIGN"
```

Use the `VatsimbriefHelperEventOnVatsimDataRefreshed` event to listen to ATC data updates:
```text
function onVatsimDataRefreshed()
  -- Do something when Vatsim data has been downloaded successfully a moment ago
  ...
end

-- Start listening
if (VatsimbriefHelperEventBus ~= nil) then
  VatsimbriefHelperEventBus.on(VatsimbriefHelperEventOnVatsimDataRefreshed, onVatsimDataRefreshed)
end

-- Run your app
...

-- Stop listening
VatsimbriefHelperEventBus.off(VatsimbriefHelperEventOnVatsimDataRefreshed, onVatsimDataRefreshed)
```
