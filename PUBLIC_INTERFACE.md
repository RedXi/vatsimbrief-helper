## Vatsimbrief Helper Public Interface
Vatsimbrief Helper offers a public API via a global `VatsimbriefHelperPublicInterface`:
```text
if (VatsimbriefHelperPublicInterface ~= nil and VatsimbriefHelperPublicInterface.getInterfaceVersion() == 1) then
		-- Call method on VatsimbriefHelperPublicInterface
		...
	end
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