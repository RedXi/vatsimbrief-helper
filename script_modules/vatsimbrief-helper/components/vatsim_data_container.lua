local Globals = require("vatsimbrief-helper.globals")
local MainThread = require("vatsimbrief-helper.main_thread")

local VatsimDataContainer
do
  VatsimDataContainer = {}

  VatsimDataContainer.ClientType = {
    STATION = "Station",
    PLANE = "Plane"
  }

  VatsimDataContainer.FetchStatusLevel = {
    INFO = 0,
    SYSTEM_RELATED = 1
  }

  VatsimDataContainer.FetchStatus = {
    NO_DOWNLOAD_ATTEMPTED = {
      level = VatsimDataContainer.FetchStatusLevel.INFO,
      nameForDebugging = "NO_DOWNLOAD_ATTEMPTED"
    },
    DOWNLOADING = {level = VatsimDataContainer.FetchStatusLevel.INFO, nameForDebugging = "DOWNLOADING"},
    NO_ERROR = {level = VatsimDataContainer.FetchStatusLevel.INFO, nameForDebugging = "NO_ERROR"},
    UNKNOWN_DOWNLOAD_ERROR = {
      level = VatsimDataContainer.FetchStatusLevel.SYSTEM_RELATED,
      nameForDebugging = "UNKNOWN_DOWNLOAD_ERROR"
    },
    UNEXPECTED_HTTP_RESPONSE_STATUS = {
      level = VatsimDataContainer.FetchStatusLevel.SYSTEM_RELATED,
      nameForDebugging = "UNEXPECTED_HTTP_RESPONSE_STATUS"
    },
    UNEXPECTED_HTTP_RESPONSE = {
      level = VatsimDataContainer.FetchStatusLevel.SYSTEM_RELATED,
      nameForDebugging = "UNEXPECTED_HTTP_RESPONSE"
    },
    NETWORK_ERROR = {level = VatsimDataContainer.FetchStatusLevel.SYSTEM_RELATED, nameForDebugging = "NETWORK_ERROR"}
  }

  function VatsimDataContainer:getUpdateTimestamp()
    return self.AtcIdentifiersUpdatedTimestamp
  end

  function VatsimDataContainer:new()
    local newInstanceWithState = {
      MapAtcIdentifiersToAtcInfo = {},
      MapAtcFrequenciesToAtcInfos = {},
      AtcIdentifiersUpdatedTimestamp = nil,
      AllVatsimClients = {},
      CurrentFetchStatus = VatsimDataContainer.FetchStatus.NO_DOWNLOAD_ATTEMPTED
    }

    TRACK_ISSUE(
      "Tech Debt",
      "MapAtcIdentifiersToAtcInfo never mapped identifiers to ATC info. It was an auto-index-key table. Leave it like that for now.",
      TRIGGER_ISSUE_IF(loadstring("newInstanceWithState.MapAtcIdentifiersToAtcInfo") ~= nil)
    )

    setmetatable(newInstanceWithState, self)
    self.__index = self
    return newInstanceWithState
  end

  function VatsimDataContainer:clear()
    self.AtcIdentifiersUpdatedTimestamp = nil
  end

  function VatsimDataContainer:processSuccessfulHttpResponse(httpRequest)
    if httpRequest.httpStatusCode ~= 200 then
      self.CurrentFetchStatus = VatsimDataContainer.FetchStatus.UNEXPECTED_HTTP_RESPONSE_STATUS
      return
    end

    self.MapAtcIdentifiersToAtcInfo = {}
    self.MapAtcFrequenciesToAtcInfos = {}
    self.AllVatsimClients = {}
    local lines = Globals.splitStringBySeparator(httpRequest.responseBody, "\n")
    self:_processAllLines(lines)
    self:_sortStationsForFrequencyByCurrentDistance()
    self:_sortAllClientsByCurrentDistance()

    self.AtcIdentifiersUpdatedTimestamp = os.clock()
    self.CurrentFetchStatus = VatsimDataContainer.FetchStatus.NO_ERROR
    MainThread.emitVatsimDataUpdateEvent()
  end

  function VatsimDataContainer:getAtcStationsForFrequencyClosestFirst(fullFrequencyString)
    return self.MapAtcFrequenciesToAtcInfos[fullFrequencyString]
  end

  function VatsimDataContainer:getAllVatsimClientsClosestFirst()
    return self.AllVatsimClients
  end

  function VatsimDataContainer:_processAllLines(lines)
    local linesWithoutIdOrFrequency = 0
    local linesWithoutCallSign = 0
    local linesWithoutDescription = 0
    local linesWithoutLocation2D = 0
    local linesWithoutLocation3D = 0
    local linesAtc = 0
    local linesPlane = 0
    TRACK_ISSUE(
      "Vatsim Data",
      MULTILINE_TEXT(
        "ATC lines can contain no readable name or an unknown location. That's fine and will be handled gracefully.",
        "If duplicate stations AND frequencies are found, nothing should break, but it also doesn't make much sense."
      ),
      "Add potential duplicates and behave normally."
    )

    for _, line in ipairs(lines) do
      -- Example line: VVTS_GND:1377201:HyeonSeok Lee:ATC:121.900:10.82056:106.66083:0:0::::::SINGAPORE:100:2:0:3:20::::::::::::0:0:0:0:Tan Son Nhat Ground^Â§Charts are available at www.vclvacc.net/download/charts/^Â§PDC availavle via private message.:20201129121118:20201129121118:0:0:0:
      -- Example line: SBWJ_APP:1030489:hamilton junior:ATC:119.000:-23.37825:-46.84175:0:0::::::SINGAPORE:100:4:0:5:159::::::::::::0:0:0:0:ATIS B 2200Z   ^Â§SBRJ VMC QNH 1007 DEP/ARR RWY 20LRNAV D/E^Â§SBGL VMC QNH 1008  DEP/ARR RWY 10 ILS X:20201002211135:20201002211135:0:0:0:
      -- Example line: RYR14:1534687:Callum Bygrave :PILOT::54.65995:-6.21772:234:0:B737/L:410:EGAA:FL220:EGKK:UK-1:100:1:7537:0:0:4:I:230:250:0:45:2:30:EGAA:/r/ XSquawkBox:EGAA/25 DCT VAKPO L15 KEPAD L151 KIDLI ASTR2B EGKK/ASTRA.I26L:0:0:0:0::20201129225622:20201129225622:245:30.27:1025:
      local parts = Globals.splitStringBySeparatorNew(line, ":")

      if (#parts >= 5) then
        if (parts[4] == "ATC") then
          linesAtc = linesAtc + 1
          local newId = parts[1]
          local newVatsimClientId = parts[2]
          local newFrequency = parts[5]
          local newLatitude = parts[6]
          local newLongitude = parts[7]
          local newDescription = parts[36]

          if
            (not Globals.stringIsEmpty(newId) and not Globals.stringIsEmpty(newVatsimClientId) and
              not Globals.stringIsEmpty(newFrequency))
           then
            local newAtcInfo = {
              id = newId,
              frequency = newFrequency,
              description = newDescription
            }

            if (Globals.stringIsEmpty(newDescription)) then
              linesWithoutDescription = linesWithoutDescription + 1
            end

            local hasPosition = false
            if (not Globals.stringIsEmpty(newLatitude) and not Globals.stringIsEmpty(newLongitude)) then
              hasPosition = true
              local latNum = tonumber(newLatitude)
              local lonNum = tonumber(newLongitude)
              if (latNum == 0.0 or lonNum == 0.0) then
                linesWithoutLocation2D = linesWithoutLocation2D + 1
              else
                newAtcInfo.latitude = latNum
                newAtcInfo.longitude = lonNum
              end
            else
              linesWithoutLocation2D = linesWithoutLocation2D + 1
            end

            table.insert(self.MapAtcIdentifiersToAtcInfo, newAtcInfo)

            if (self.MapAtcFrequenciesToAtcInfos[newFrequency] == nil) then
              self.MapAtcFrequenciesToAtcInfos[newFrequency] = {}
            end

            local atcInfos = self.MapAtcFrequenciesToAtcInfos[newFrequency]
            table.insert(atcInfos, newAtcInfo)

            if (hasPosition) then
              local newClient = {
                type = VatsimDataContainer.ClientType.STATION,
                id = newId,
                vatsimClientId = newVatsimClientId,
                frequency = newFrequency,
                latitude = newLatitude or "0.0",
                longitude = newLongitude or "0.0"
              }
              table.insert(self.AllVatsimClients, newClient)
            end
          else
            linesWithoutIdOrFrequency = linesWithoutIdOrFrequency + 1
          end
        elseif (parts[4] == "PILOT") then
          linesPlane = linesPlane + 1
          local newCallSign = parts[1]
          local newVatsimClientId = parts[2]
          local newLatitude = parts[6]
          local newLongitude = parts[7]
          local newAltitude = parts[8]
          local newGroundSpeed = parts[9]
          local newHeading = parts[39]

          if (not Globals.stringIsEmpty(newCallSign) and not Globals.stringIsEmpty(newVatsimClientId)) then
            if
              (not Globals.stringIsEmpty(newLatitude) and not Globals.stringIsEmpty(newLongitude) and
                not Globals.stringIsEmpty(newAltitude) and
                not Globals.stringIsEmpty(newGroundSpeed) and
                not Globals.stringIsEmpty(newHeading))
             then
              local newClient = {
                type = VatsimDataContainer.ClientType.PLANE,
                callSign = newCallSign,
                vatsimClientId = newVatsimClientId,
                latitude = newLatitude,
                longitude = newLongitude,
                altitude = newAltitude,
                heading = newHeading,
                groundSpeed = newGroundSpeed
              }

              table.insert(self.AllVatsimClients, newClient)
            else
              linesWithoutLocation3D = linesWithoutLocation3D + 1
            end
          else
            linesWithoutCallSign = linesWithoutCallSign + 1
          end
        end
      end
    end

    logMsg(
      ("Processed Vatsim data: %d lines, %d ATC, %d w/o ID or frequency, %d w/o callsign, %d w/o description, %d w/o 2D location, %d w/o 3D location"):format(
        #lines,
        linesAtc,
        linesWithoutIdOrFrequency,
        linesWithoutCallSign,
        linesWithoutDescription,
        linesWithoutLocation2D,
        linesWithoutLocation3D
      )
    )
  end

  TRACK_ISSUE(
    "Vatsim Data",
    "To actually get a meaningful station name, use the closest station and not an arbitrary duplicate around the planet.",
    "Add datarefs to read current latitude and longitude and sort duplicate frequencies in Vatsim data."
  )
  VatsimDataContainer._distanceCompareFunction = function(oneObject, anotherObject)
    return oneObject.currentDistance < anotherObject.currentDistance
  end

  VatsimDataContainer._computeAndStoreCurrentDistanceForObject = function(anObject, currentLat, currentLon)
    if (anObject.latitude == nil) then
      anObject.currentDistance = math.huge
    else
      anObject.currentDistance =
        Globals.computeDistanceOnEarth({currentLat, currentLon}, {anObject.latitude, anObject.longitude})
    end
  end

  function VatsimDataContainer:_sortStationsForFrequencyByCurrentDistance()
    local lat = VatsimbriefHelperCurrentLatitudeReadDataref
    local lon = VatsimbriefHelperCurrentLongitudeReadDataref

    for _, atcInfo in ipairs(self.MapAtcIdentifiersToAtcInfo) do
      VatsimDataContainer._computeAndStoreCurrentDistanceForObject(atcInfo, lat, lon)
    end

    for frequency, atcInfos in pairs(self.MapAtcFrequenciesToAtcInfos) do
      table.sort(atcInfos, VatsimDataContainer._distanceCompareFunction)
    end
  end

  function VatsimDataContainer:_sortAllClientsByCurrentDistance()
    local lat = VatsimbriefHelperCurrentLatitudeReadDataref
    local lon = VatsimbriefHelperCurrentLongitudeReadDataref

    for _, client in ipairs(self.AllVatsimClients) do
      VatsimDataContainer._computeAndStoreCurrentDistanceForObject(client, lat, lon)
    end

    table.sort(self.AllVatsimClients, VatsimDataContainer._distanceCompareFunction)
  end

  function VatsimDataContainer:getVatsimDataFetchStatusMessageAndLevel()
    local msg
    if self.CurrentFetchStatus == VatsimDataContainer.FetchStatus.NO_DOWNLOAD_ATTEMPTED then
      msg = "Download pending"
    elseif self.CurrentFetchStatus == VatsimDataContainer.FetchStatus.DOWNLOADING then
      msg = "Downloading"
    elseif self.CurrentFetchStatus == VatsimDataContainer.FetchStatus.NO_ERROR then
      msg = "No error"
    elseif self.CurrentFetchStatus == VatsimDataContainer.FetchStatus.UNKNOWN_DOWNLOAD_ERROR then
      msg = "Unknown error while downloading"
    elseif self.CurrentFetchStatus == VatsimDataContainer.FetchStatus.UNEXPECTED_HTTP_RESPONSE_STATUS then
      msg = "Unexpected server response"
    elseif self.CurrentFetchStatus == VatsimDataContainer.FetchStatus.UNEXPECTED_HTTP_RESPONSE then
      msg = "Unhandled server response"
    elseif self.CurrentFetchStatus == VatsimDataContainer.FetchStatus.NETWORK_ERROR then
      msg = "Network error"
    else
      msg = "Unknown error '" .. (self.CurrentFetchStatus or "(none)") .. "'"
    end
    msg = "Could not download VATSIM data: " .. msg .. "."

    return msg, self.CurrentFetchStatus.level
  end

  function VatsimDataContainer:processFailedHttpRequest(fetchStatus)
    self.CurrentFetchStatus = fetchStatus
  end

  function VatsimDataContainer:getCurrentFetchStatus()
    return self.CurrentFetchStatus
  end

  function VatsimDataContainer:getCurrentFetchStatusLevel()
    return self.CurrentFetchStatus.level
  end

  function VatsimDataContainer:noteDownloadIsStarting()
    self.CurrentFetchStatus = VatsimDataContainer.FetchStatus.DOWNLOADING
  end
end
return VatsimDataContainer
