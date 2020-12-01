local Globals = require("vatsimbrief-helper.globals")

local VatsimDataContainer
do
  VatsimDataContainer = {}

  VatsimDataContainer.FetchStatusLevel = {
    INFO = 0,
    SYSTEM_RELATED = 1
  }

  VatsimDataContainer.FetchStatus = {
    NO_DOWNLOAD_ATTEMPTED = {level = VatsimDataContainer.FetchStatusLevel.INFO},
    DOWNLOADING = {level = VatsimDataContainer.FetchStatusLevel.INFO},
    NO_ERROR = {level = VatsimDataContainer.FetchStatusLevel.INFO},
    UNKNOWN_DOWNLOAD_ERROR = {level = VatsimDataContainer.FetchStatusLevel.SYSTEM_RELATED},
    UNEXPECTED_HTTP_RESPONSE_STATUS = {level = VatsimDataContainer.FetchStatusLevel.SYSTEM_RELATED},
    UNEXPECTED_HTTP_RESPONSE = {level = VatsimDataContainer.FetchStatusLevel.SYSTEM_RELATED},
    NETWORK_ERROR = {level = VatsimDataContainer.FetchStatusLevel.SYSTEM_RELATED}
  }

  function VatsimDataContainer:new()
    local newInstanceWithState = {
      MapAtcIdentifiersToAtcInfo = {},
      MapAtcFrequenciesToAtcInfos = {},
      AtcIdentifiersUpdatedTimestamp = nil,
      CurrentFetchStatus = VatsimDataContainer.FetchStatus.NO_DOWNLOAD_ATTEMPTED
    }

    TRACK_ISSUE(
      "Tech Debt",
      "MapAtcIdentifiersToAtcInfo never mapped identifiers to ATC info. It was an auto-index-key table. Leave it like that for now.",
      TRIGGER_ISSUE_IF(loadstring("newInstanceWithState.MapAtcIdentifiersToAtcInfo") == nil)
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
    local lines = Globals.splitStringBySeparator(httpRequest.responseBody, "\n")
    self:_processAtcLinesOnly(lines)
    self:_sortStationsForFrequencyByCurrentDistance()

    self.AtcIdentifiersUpdatedTimestamp = os.clock()
    self.CurrentFetchStatus = VatsimDataContainer.FetchStatus.NO_ERROR
  end

  function VatsimDataContainer:getAtcStationsForFrequencyClosestFirst(fullFrequencyString)
    return self.MapAtcFrequenciesToAtcInfos[fullFrequencyString]
  end

  function VatsimDataContainer:_processAtcLinesOnly(lines)
    local linesWithoutIdOrFrequency = 0
    local linesWithoutDescription = 0
    local linesWithoutLocation = 0
    local linesAtc = 0
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
      if line:find(":ATC:") ~= nil then
        linesAtc = linesAtc + 1
        local parts = Globals.splitStringBySeparator(line, ":")
        if table.getn(parts) >= 5 and parts[4] == "ATC" then
          local newId = parts[1]
          local newFrequency = parts[5]
          local newLatitude = parts[6]
          local newLongitude = parts[7]
          local newDescription = parts[45]

          if (not Globals.stringIsEmpty(newId) and not Globals.stringIsEmpty(newFrequency)) then
            local newAtcInfo = {
              id = newId,
              frequency = newFrequency,
              description = newDescription
            }

            if (Globals.stringIsEmpty(newDescription)) then
              linesWithoutDescription = linesWithoutDescription + 1
            end

            if (not Globals.stringIsEmpty(newLatitude) and not Globals.stringIsEmpty(newLongitude)) then
              local latNum = tonumber(newLatitude)
              local lonNum = tonumber(newLongitude)
              if (latNum == 0.0 or lonNum == 0.0) then
                linesWithoutLocation = linesWithoutLocation + 1
              else
                newAtcInfo.latitude = latNum
                newAtcInfo.longitude = lonNum
              end
            else
              linesWithoutLocation = linesWithoutLocation + 1
            end

            table.insert(self.MapAtcIdentifiersToAtcInfo, newAtcInfo)

            if (self.MapAtcFrequenciesToAtcInfos[newFrequency] == nil) then
              self.MapAtcFrequenciesToAtcInfos[newFrequency] = {}
            end

            local atcInfos = self.MapAtcFrequenciesToAtcInfos[newFrequency]
            table.insert(atcInfos, newAtcInfo)
          else
            linesWithoutIdOrFrequency = linesWithoutIdOrFrequency + 1
          end
        end
      end
    end

    logMsg(
      ("Processed Vatsim data: %d lines, %d ATC, %d w/o ID or frequency, %d w/o description, %d w/o location"):format(
        #lines,
        linesAtc,
        linesWithoutIdOrFrequency,
        linesWithoutDescription,
        linesWithoutLocation
      )
    )
  end

  TRACK_ISSUE(
    "Vatsim Data",
    "To actually get a meaningful station name, use the closest station and not an arbitrary duplicate around the planet.",
    "Add datarefs to read current latitude and longitude and sort duplicate frequencies in Vatsim data."
  )
  function VatsimDataContainer:_sortStationsForFrequencyByCurrentDistance()
    local lat = CurrentLatitudeReadDataref
    local lon = CurrentLongitudeReadDataref

    for _, atcInfo in ipairs(self.MapAtcIdentifiersToAtcInfo) do
      if (atcInfo.latitude == nil) then
        atcInfo.currentDistance = math.huge
      else
        atcInfo.currentDistance = Globals.computeDistanceOnEarth({lat, lon}, {atcInfo.latitude, atcInfo.longitude})
      end
    end

    local compareFunction = function(atcInfo1, atcInfo2)
      return atcInfo1.currentDistance < atcInfo2.currentDistance
    end

    for frequency, atcInfos in pairs(self.MapAtcFrequenciesToAtcInfos) do
      table.sort(atcInfos, compareFunction)
    end
  end

  function VatsimDataContainer:getVatsimDataFetchStatusMessageAndColor()
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
    msg = "Could not download VATSIM data:\n" .. msg .. "."

    local color
    if self.CurrentFetchStatus.level == self.FetchStatusLevel.INFO then
      color = colorNormal
    elseif self.CurrentFetchStatus.level == self.FetchStatusLevel.SYSTEM_RELATED then
      color = colorWarn
    elseif self.CurrentFetchStatus.level == self.FetchStatusLevel.USER_RELATED then
      color = colorA320Blue
    else
      color = colorNormal
    end

    return msg, color
  end

  function VatsimDataContainer:processFailedHttpRequest(httpRequest)
    if httpRequest.errorCode == HttpDownloadErrors.INTERNAL_SERVER_ERROR then
      self.CurrentFetchStatus = VatsimDataContainer.FetchStatus.UNEXPECTED_HTTP_RESPONSE_STATUS
    elseif httpRequest.errorCode == HttpDownloadErrors.UNHANDLED_RESPONSE then
      self.CurrentFetchStatus = VatsimDataContainer.FetchStatus.UNEXPECTED_HTTP_RESPONSE
    elseif httpRequest.errorCode == HttpDownloadErrors.NETWORK then
      self.CurrentFetchStatus = VatsimDataContainer.FetchStatus.NETWORK_ERROR
    else
      self.CurrentFetchStatus = VatsimDataContainer.FetchStatus.UNKNOWN_DOWNLOAD_ERROR
    end
  end
end
return VatsimDataContainer
