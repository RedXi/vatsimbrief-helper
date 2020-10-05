--[[

  https://github.com/RedXi/vatsimbrief-helper

--]]
--[[

MIT License

Copyright (c) 2020 RedXi

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

--]]

emptyString = ""

local function stringIsEmpty(s)
  return s == nil or s == emptyString
end

local function stringIsNotEmpty(s)
  return not stringIsEmpty(s)
end

local function numberIsNilOrZero(n)
  return n == nil or n == 0
end

local function numberIsNotNilOrZero(n)
  return not numberIsNilOrZero(n)
end

function trim(s)
   return s:gsub("^%s*(.-)%s*$", "%1")
end

-- Color schema
local colorA320Blue = 0xFFFFDDAA
local colorNormal = 0xFFFFFFFF
local colorWarn = 0xFF55FFFF
local colorErr = 0xFF5555FF

-- Make sure to consider licenses.
local licensesOfDependencies = {
  -- Async HTTP: copas + dependencies.
  { "copas", "MIT License", "https://github.com/keplerproject/copas" },
  { "luasocket", "MIT License", "http://luaforge.net/projects/luasocket/" },
  { "binaryheap.lua", "MIT License", "https://github.com/Tieske/binaryheap.lua" },
  { "coxpcall", "(Free Software)", "https://github.com/keplerproject/coxpcall" },
  { "timerwheel.lua", "MIT License", "https://github.com/Tieske/timerwheel.lua" },
  
  -- Configuration handling
  { "LIP - Lua INI Parser", "MIT License", "https://github.com/Dynodzzo/Lua_INI_Parser" },
  
  -- Simbrief flightplan
  { "xml2lua", "MIT License", "https://github.com/manoelcampos/xml2lua" }
}

for i = 1, #licensesOfDependencies do
  print(("Vatsimbrief Helper using '%s' with license '%s'. Project homepage: %s")
    :format(licensesOfDependencies[i][1], licensesOfDependencies[i][2], licensesOfDependencies[i][3]))
end

--
-- Configuration handling
--

local LIP = require("LIP")

local ConfigurationFilePath = SCRIPT_DIRECTORY .. "vatsimbrief-helper.ini"

local VatsimbriefConfiguration = {}

local function fileExists(name)
  local f = io.open(name, "r")
  if f ~= nil then
    io.close(f)
    return true
  else
    return false
  end
end

local function loadConfiguration()
  if fileExists(ConfigurationFilePath) then
    VatsimbriefConfiguration = LIP.load(ConfigurationFilePath);
    print(("Vatsimbrief configuration file '%s' loaded."):format(ConfigurationFilePath))
  else
    print(("Vatsimbrief configuration file '%s' missing! Running without configuration settings.")
      :format(ConfigurationFilePath))
  end
end

local function saveConfiguration()
  LIP.save(ConfigurationFilePath, VatsimbriefConfiguration);
end

loadConfiguration() -- Initially load configuration synchronously so it's present below this line

--
-- Init concurrency
--

local copas = require("copas")
local timer = require("copas.timer")

local SyncTasksAfterAsyncTasks = {}

function tickConcurrentTasks()
    -- Run async tasks
    copas.step(0.01)
    
    -- The following was invented after spotting that even print statements
    -- trigger the multitasking timeout, making serious processing of results
    -- obtained from asynchronous execution difficult.
    -- Asynchronous operations can now add jobs they want to be executed
    -- synchronously.
    for _, job in pairs(SyncTasksAfterAsyncTasks) do
      job.callback(job.params)
    end
    SyncTasksAfterAsyncTasks = {}
end

do_often("tickConcurrentTasks()")

--
-- Async HTTP
--

local http = require("copas.http")

local HttpDownloadErrors = {
  NETWORK = 1,
  INTERNAL_SERVER_ERROR = 2
}

local function performDefaultHttpGetRequest(url, resultCallback, errorCallback)
  local t0 = os.clock()
  
  local content, code, headers, status = http.request(url)

  if type(content) ~= "string" or type(code) ~= "number" or
      type(headers) ~= "table" or type(status) ~= "string" then
    print(("Request URL: %s, FAILURE"):format(url))
    errorCallback({ errorCode = HttpDownloadErrors.NETWORK })
  else
    print(("Request URL: %s, duration: %.2fs, response status: %s, response length: %d bytes")
      :format(url, os.clock() - t0, status, #content))
  
    if code < 500 then
      table.insert(SyncTasksAfterAsyncTasks, { callback = resultCallback, params = { httpResponse = content, httpStatusCode = code } })
    else
      errorCallback({ errorCode = HttpDownloadErrors.INTERNAL_SERVER_ERROR })
    end
  end
end

--
-- Simbrief flightplan
--

local function removeLinebreaksFromString(s)
  return string.gsub(s, "\n", "")
end

local xml2lua = require("xml2lua")
local simbriefFlightplanXmlHandler = require("xmlhandler.tree")

local SimbriefFlightplan = {}

local FlightplanId = nil -- PK to spot that a file plan changed

local FlightplanOriginIcao = ""
local FlightplanOriginIata = ""
local FlightplanOriginName = ""
local FlightplanOriginRunway = ""
local FlightplanOriginMetar = ""

local FlightplanDestIcao = ""
local FlightplanDestIata = ""
local FlightplanDestName = ""
local FlightplanDestRunway = ""
local FlightplanDestMetar = ""

local FlightplanAltIcao = ""
local FlightplanAltIata = ""
local FlightplanAltName = ""
local FlightplanAltRunway = ""
local FlightplanAltMetar = ""

local FlightplanCallsign = ""

local FlightplanRoute = ""
local FlightplanAltRoute = ""

local FlightplanSchedOut = 0
local FlightplanSchedOff = 0
local FlightplanSchedOn = 0
local FlightplanSchedIn = 0
local FlightplanSchedBlock = 0

local FlightplanAltitude = 0
local FlightplanAltAltitude = 0
local FlightplanTocTemp = 0

local FlightplanBlockFuel = 0
local FlightplanReserveFuel = 0
local FlightplanTakeoffFuel = 0
local FlightplanAltFuel = 0

local FlightplanUnit = ""

local FlightplanCargo = 0
local FlightplanPax = 0
local FlightplanPayload = 0
local FlightplanZfw = 0

local FlightplanDistance = 0
local FlightplanAltDistance = 0
local FlightplanCostindex = 0

local FlightplanAvgWindDir = 0
local FlightplanAvgWindSpeed = 0

local SimbriefFlightplanFetchStatusLevel = {
  INFO = 0,
  USER_RELATED = 1,
  SYSTEM_RELATED = 2
}
local SimbriefFlightplanFetchStatus = {
  NO_DOWNLOAD_ATTEMPTED = { level = SimbriefFlightplanFetchStatusLevel.INFO },
  DOWNLOADING = { level = SimbriefFlightplanFetchStatusLevel.INFO },
  NO_ERROR = { level = SimbriefFlightplanFetchStatusLevel.INFO },
  UNKNOWN_DOWNLOAD_ERROR = { level = SimbriefFlightplanFetchStatusLevel.SYSTEM_RELATED },
  UNEXPECTED_HTTP_RESPONSE_STATUS = { level = SimbriefFlightplanFetchStatusLevel.SYSTEM_RELATED },
  NETWORK_ERROR = { level = SimbriefFlightplanFetchStatusLevel.SYSTEM_RELATED },
  INVALID_USER_NAME = { level = SimbriefFlightplanFetchStatusLevel.USER_RELATED },
  NO_FLIGHT_PLAN_CREATED = { level = SimbriefFlightplanFetchStatusLevel.USER_RELATED },
  UNKNOWN_ERROR_STATUS_RESPONSE_PAYLOAD = { level = SimbriefFlightplanFetchStatusLevel.SYSTEM_RELATED },
  NO_SIMBRIEF_USER_ID_ENTERED = { level = SimbriefFlightplanFetchStatusLevel.SYSTEM_RELATED }
}
local CurrentSimbriefFlightplanFetchStatus = SimbriefFlightplanFetchStatus.NO_DOWNLOAD_ATTEMPTED
local function getSimbriefFlightplanFetchStatusMessageAndColor()
  local msg
  if CurrentSimbriefFlightplanFetchStatus == SimbriefFlightplanFetchStatus.NO_DOWNLOAD_ATTEMPTED then
    msg = "Download pending"
  elseif CurrentSimbriefFlightplanFetchStatus == SimbriefFlightplanFetchStatus.DOWNLOADING then
    msg = "Downloading"
  elseif CurrentSimbriefFlightplanFetchStatus == SimbriefFlightplanFetchStatus.NO_ERROR then
    msg = "No error"
  elseif CurrentSimbriefFlightplanFetchStatus == SimbriefFlightplanFetchStatus.UNKNOWN_DOWNLOAD_ERROR then
    msg = "Unknown error while downloading"
  elseif CurrentSimbriefFlightplanFetchStatus == SimbriefFlightplanFetchStatus.UNEXPECTED_HTTP_RESPONSE_STATUS then
    msg = "Unexpected server response"
  elseif CurrentSimbriefFlightplanFetchStatus == SimbriefFlightplanFetchStatus.NETWORK_ERROR then
    msg = "Network error"
  elseif CurrentSimbriefFlightplanFetchStatus == SimbriefFlightplanFetchStatus.INVALID_USER_NAME then
    msg = "Please set a correct Simbrief user name in the Control window"
  elseif CurrentSimbriefFlightplanFetchStatus == SimbriefFlightplanFetchStatus.NO_FLIGHT_PLAN_CREATED then
    msg = "No flight plan found. Please create one first in Simbrief."
  elseif CurrentSimbriefFlightplanFetchStatus == SimbriefFlightplanFetchStatus.UNKNOWN_ERROR_STATUS_RESPONSE_PAYLOAD then
    msg = "Unhandled response status message"
  elseif CurrentSimbriefFlightplanFetchStatus == SimbriefFlightplanFetchStatus.NO_SIMBRIEF_USER_ID_ENTERED then
    msg = "Please enter your Simbrief user name it in the Control window"
  else
    msg = "Unknown error '" .. (CurrentSimbriefFlightplanFetchStatus or "(none)") .. "'"
  end
  msg = "Could not download flight plan from Simbrief: " .. msg .. "."
  
  local color
  if CurrentSimbriefFlightplanFetchStatus.level == SimbriefFlightplanFetchStatusLevel.INFO then
    color = colorNormal
  elseif CurrentSimbriefFlightplanFetchStatus.level == SimbriefFlightplanFetchStatusLevel.SYSTEM_RELATED then
    color = colorWarn
  elseif CurrentSimbriefFlightplanFetchStatus.level == SimbriefFlightplanFetchStatusLevel.USER_RELATED then
    color = colorA320Blue
  else
    color = colorNormal
  end
  
  return msg, color
end

local function processFlightplanDownloadFailure(params)
  if params.errorCode == HttpDownloadErrors.INTERNAL_SERVER_ERROR then CurrentSimbriefFlightplanFetchStatus = SimbriefFlightplanFetchStatus.UNEXPECTED_HTTP_RESPONSE_STATUS
  elseif params.errorCode == HttpDownloadErrors.NETWORK then CurrentSimbriefFlightplanFetchStatus = SimbriefFlightplanFetchStatus.NETWORK_ERROR
  else CurrentSimbriefFlightplanFetchStatus = SimbriefFlightplanFetchStatus.UNKNOWN_DOWNLOAD_ERROR end
end

local function processNewFlightplan(params)
  if params.httpStatusCode ~= 200 and params.httpStatusCode ~= 400 then
    CurrentSimbriefFlightplanFetchStatus = SimbriefFlightplanFetchStatus.UNEXPECTED_HTTP_RESPONSE_STATUS
  else
    local parser = xml2lua.parser(simbriefFlightplanXmlHandler)
    parser:parse(params.httpResponse)
    if params.httpStatusCode == 200 and simbriefFlightplanXmlHandler.root.OFP.fetch.status == "Success" then
      SimbriefFlightplan = simbriefFlightplanXmlHandler.root.OFP
      
      newFlightplanId = SimbriefFlightplan.params.request_id .. "|" .. SimbriefFlightplan.params.time_generated
        -- We just guess that this PK definition yields "enough uniqueness"
      if newFlightplanId ~= FlightplanId then -- Flightplan changed
        FlightplanId = newFlightplanId
        
        FlightplanOriginIcao = SimbriefFlightplan.origin.icao_code
        FlightplanOriginIata = SimbriefFlightplan.origin.iata_code
        FlightplanOriginName = SimbriefFlightplan.origin.name
        FlightplanOriginRunway = SimbriefFlightplan.origin.plan_rwy
        
        FlightplanDestIcao = SimbriefFlightplan.destination.icao_code
        FlightplanDestIata = SimbriefFlightplan.destination.iata_code
        FlightplanDestName = SimbriefFlightplan.destination.name
        FlightplanDestRunway = SimbriefFlightplan.destination.plan_rwy
        
        FlightplanAltIcao = SimbriefFlightplan.alternate.icao_code
        FlightplanAltIata = SimbriefFlightplan.alternate.iata_code
        FlightplanAltName = SimbriefFlightplan.alternate.name
        FlightplanAltRunway = SimbriefFlightplan.alternate.plan_rwy
        
        FlightplanCallsign = SimbriefFlightplan.atc.callsign
        
        FlightplanRoute = SimbriefFlightplan.general.route
        if stringIsEmpty(FlightplanRoute) then FlightplanRoute = "(none)" end
        FlightplanAltRoute = SimbriefFlightplan.alternate.route
        if stringIsEmpty(FlightplanAltRoute) then FlightplanAltRoute = "(none)" end
        
        FlightplanSchedOut = tonumber(SimbriefFlightplan.times.sched_out)
        FlightplanSchedOff = tonumber(SimbriefFlightplan.times.sched_off)
        FlightplanSchedOn = tonumber(SimbriefFlightplan.times.sched_on)
        FlightplanSchedIn = tonumber(SimbriefFlightplan.times.sched_in)
        FlightplanSchedBlock = tonumber(SimbriefFlightplan.times.sched_block)
        
        -- TOC waypoint is identified by "TOC"
        -- It seems flightplans w/o route are also possible to create.
        local haveToc = false
        if SimbriefFlightplan.navlog ~= nil and SimbriefFlightplan.navlog.fix ~= nil then
          local indexOfToc = 1
          while indexOfToc <= #SimbriefFlightplan.navlog.fix and SimbriefFlightplan.navlog.fix[indexOfToc].ident ~= "TOC" do
            indexOfToc = indexOfToc + 1
          end
          if indexOfToc <= #SimbriefFlightplan.navlog.fix then
            FlightplanAltitude = tonumber(SimbriefFlightplan.navlog.fix[indexOfToc].altitude_feet)
            FlightplanTocTemp = tonumber(SimbriefFlightplan.navlog.fix[indexOfToc].oat)
            haveToc = true
          end
        end
        if not haveToc then
          -- No TOC found!?
          FlightplanAltitude = tonumber(SimbriefFlightplan.general.initial_altitude)
          FlightplanTocTemp = 9999 -- Some "bad" value
        end
        FlightplanAltAltitude = tonumber(SimbriefFlightplan.alternate.cruise_altitude)
        
        FlightplanBlockFuel = tonumber(SimbriefFlightplan.fuel.plan_ramp)
        FlightplanReserveFuel = tonumber(SimbriefFlightplan.fuel.reserve)
        FlightplanTakeoffFuel = tonumber(SimbriefFlightplan.fuel.min_takeoff)
        FlightplanAltFuel = tonumber(SimbriefFlightplan.fuel.alternate_burn)
        
        FlightplanUnit = SimbriefFlightplan.params.units
        
        FlightplanCargo = tonumber(SimbriefFlightplan.weights.cargo)
        FlightplanPax = tonumber(SimbriefFlightplan.weights.pax_count)
        FlightplanPayload = tonumber(SimbriefFlightplan.weights.payload)
        FlightplanZfw = tonumber(SimbriefFlightplan.weights.est_zfw)
        
        FlightplanDistance = SimbriefFlightplan.general.route_distance
        FlightplanAltDistance = SimbriefFlightplan.alternate.distance
        FlightplanCostindex = SimbriefFlightplan.general.costindex
        
        FlightplanOriginMetar = removeLinebreaksFromString(SimbriefFlightplan.weather.orig_metar)
        FlightplanDestMetar = removeLinebreaksFromString(SimbriefFlightplan.weather.dest_metar)
        if type(SimbriefFlightplan.weather.altn_metar) == "string" then
          FlightplanAltMetar = removeLinebreaksFromString(SimbriefFlightplan.weather.altn_metar)
        else
          FlightplanAltMetar = ''
        end
        
        FlightplanAvgWindDir = tonumber(SimbriefFlightplan.general.avg_wind_dir)
        FlightplanAvgWindSpeed = tonumber(SimbriefFlightplan.general.avg_wind_spd)
        
        CurrentSimbriefFlightplanFetchStatus = SimbriefFlightplanFetchStatus.NO_ERROR
      end
    else
      print("Flight plan states that it's not valid. Reported status: " .. simbriefFlightplanXmlHandler.root.OFP.fetch.status)
      
      -- As of 10/2020, original message is <status>Error: Unknown UserID</status>
      if params.httpStatusCode == 400 and simbriefFlightplanXmlHandler.root.OFP.fetch.status:lower():find('unknown userid') then
        CurrentSimbriefFlightplanFetchStatus = SimbriefFlightplanFetchStatus.INVALID_USER_NAME
      elseif simbriefFlightplanXmlHandler.root.OFP.fetch.status:lower():find('no flight plan') then
        CurrentSimbriefFlightplanFetchStatus = SimbriefFlightplanFetchStatus.NO_FLIGHT_PLAN_CREATED
      else
        CurrentSimbriefFlightplanFetchStatus = SimbriefFlightplanFetchStatus.UNKNOWN_ERROR_STATUS_RESPONSE_PAYLOAD
      end
    end
    
    -- Display configuration window if there's something wrong with the user name
    if CurrentSimbriefFlightplanFetchStatus == SimbriefFlightplanFetchStatus.INVALID_USER_NAME then createVatsimbriefHelperControlWindow() end
  end
end

local function clearFlightplan()
  FlightplanId = nil
end

local function userHasEnteredHisSimbriefUsername()
  return VatsimbriefConfiguration.simbrief ~= nil and stringIsNotEmpty(VatsimbriefConfiguration.simbrief.username)
end

local function refreshFlightplanNow()
  copas.addthread(function()
    CurrentSimbriefFlightplanFetchStatus = SimbriefFlightplanFetchStatus.DOWNLOADING
    if userHasEnteredHisSimbriefUsername() then
      local url = "http://www.simbrief.com/api/xml.fetcher.php?username=" .. VatsimbriefConfiguration.simbrief.username
      performDefaultHttpGetRequest(url, processNewFlightplan, processFlightplanDownloadFailure)
    else
      print("Not fetching flight plan. No simbrief username configured.")
      CurrentSimbriefFlightplanFetchStatus = SimbriefFlightplanFetchStatus.NO_SIMBRIEF_USER_ID_ENTERED
      
      -- Display configuration window if there's something wrong with the user name
      createVatsimbriefHelperControlWindow()
    end
  end)
end

local refreshFlightplanTimer = timer.new({
  delay = 60, -- Should be more than enough
  recurring = true,
  params = {},
  initial_delay = 0, -- Make sure we have information asap
    -- Usually, the user will have his username configured and flightplan already armed
  callback = function(timer_obj, params) refreshFlightplanNow() end
})

--
-- VATSIM data
--

local MapAtcIdentifiersToAtcInfo = {}
local AtcIdentifiersUpdatedTimestamp = nil

local VatsimDataFetchStatusLevel = {
  INFO = 0,
  SYSTEM_RELATED = 1
}
local VatsimDataFetchStatus = {
  NO_DOWNLOAD_ATTEMPTED = { level = VatsimDataFetchStatusLevel.INFO },
  DOWNLOADING = { level = VatsimDataFetchStatusLevel.INFO },
  NO_ERROR = { level = VatsimDataFetchStatusLevel.INFO },
  UNKNOWN_DOWNLOAD_ERROR = { level = VatsimDataFetchStatusLevel.SYSTEM_RELATED },
  UNEXPECTED_HTTP_RESPONSE_STATUS = { level = VatsimDataFetchStatusLevel.SYSTEM_RELATED },
  NETWORK_ERROR = { level = VatsimDataFetchStatusLevel.SYSTEM_RELATED }
}
local CurrentVatsimDataFetchStatus = VatsimDataFetchStatus.NO_DOWNLOAD_ATTEMPTED
local function getVatsimDataFetchStatusMessageAndColor()
  local msg
  if CurrentVatsimDataFetchStatus == VatsimDataFetchStatus.NO_DOWNLOAD_ATTEMPTED then
    msg = "Download pending"
  elseif CurrentVatsimDataFetchStatus == VatsimDataFetchStatus.DOWNLOADING then
    msg = "Downloading"
  elseif CurrentVatsimDataFetchStatus == VatsimDataFetchStatus.NO_ERROR then
    msg = "No error"
  elseif CurrentVatsimDataFetchStatus == VatsimDataFetchStatus.UNKNOWN_DOWNLOAD_ERROR then
    msg = "Unknown error while downloading"
  elseif CurrentVatsimDataFetchStatus == VatsimDataFetchStatus.UNEXPECTED_HTTP_RESPONSE_STATUS then
    msg = "Unexpected server response"
  elseif CurrentVatsimDataFetchStatus == VatsimDataFetchStatus.NETWORK_ERROR then
    msg = "Network error"
  else
    msg = "Unknown error '" .. (CurrentVatsimDataFetchStatus or "(none)") .. "'"
  end
  msg = "Could not download VATSIM data: " .. msg .. "."
  
  local color
  if CurrentVatsimDataFetchStatus.level == VatsimDataFetchStatusLevel.INFO then
    color = colorNormal
  elseif CurrentVatsimDataFetchStatus.level == VatsimDataFetchStatusLevel.SYSTEM_RELATED then
    color = colorWarn
  elseif CurrentVatsimDataFetchStatus.level == VatsimDataFetchStatusLevel.USER_RELATED then
    color = colorA320Blue
  else
    color = colorNormal
  end
  
  return msg, color
end

local function splitStringBySeparator(str, separator)
  -- I wonder why lua does not offer a simple function like this. Pretty annoying.
  local result = {}
  local c0 = 1 -- Offset of next chunk
  while true do
    i = str:find(separator, c0) -- Find "next" occurrence
    if i == nil then break end
    c1 = i - 1 -- Index of last char of next chunk
    local chunk
    if c1 > c0 then
      chunk = str:sub(c0, c1)
    else
      chunk = ""
    end
    table.insert(result, chunk)
    c0 = c0 + #chunk + #separator
  end
  
  -- Append string after last separator
  if c0 <= #str then
    chunk = str:sub(c0)
  else
    chunk = ""
  end
  table.insert(result, chunk)
  return result
end

local function processVatsimDataDownloadFailure(params)
  if params.errorCode == HttpDownloadErrors.INTERNAL_SERVER_ERROR then CurrentVatsimDataFetchStatus = VatsimDataFetchStatus.UNEXPECTED_HTTP_RESPONSE_STATUS
  elseif params.errorCode == HttpDownloadErrors.NETWORK then CurrentVatsimDataFetchStatus = VatsimDataFetchStatus.NETWORK_ERROR
  else CurrentVatsimDataFetchStatus = VatsimDataFetchStatus.UNKNOWN_DOWNLOAD_ERROR end
end

local function processNewVatsimData(params)
  if params.httpStatusCode ~= 200 then
    CurrentVatsimDataFetchStatus = VatsimDataFetchStatus.UNEXPECTED_HTTP_RESPONSE_STATUS
  else
    MapAtcIdentifiersToAtcInfo = {}
    local lines = splitStringBySeparator(params.httpResponse, "\n")
    for _, line in ipairs(lines) do
      -- Example line: SBWJ_APP:1030489:hamilton junior:ATC:119.000:-23.37825:-46.84175:0:0::::::SINGAPORE:100:4:0:5:159::::::::::::0:0:0:0:ATIS B 2200Z   ^Â§SBRJ VMC QNH 1007 DEP/ARR RWY 20LRNAV D/E^Â§SBGL VMC QNH 1008  DEP/ARR RWY 10 ILS X:20201002211135:20201002211135:0:0:0:
      
      -- Filter ATC lines heuristically not to waste time for splitting the line into parts
      if line:find(":ATC:") ~= nil then
        local parts = splitStringBySeparator(line, ':')
        if table.getn(parts) >= 5 and parts[4] == 'ATC' then
          table.insert(MapAtcIdentifiersToAtcInfo, { id = parts[1], frequency = parts[5] })
        end
      end
    end
    
    AtcIdentifiersUpdatedTimestamp = os.clock()
    
    CurrentVatsimDataFetchStatus = VatsimDataFetchStatus.NO_ERROR
  end
end

local function refreshVatsimDataNow()
  copas.addthread(function()
    CurrentVatsimDataFetchStatus = VatsimDataFetchStatus.DOWNLOADING
    local url = "http://cluster.data.vatsim.net/vatsim-data.txt"
    performDefaultHttpGetRequest(url, processNewVatsimData, processVatsimDataDownloadFailure)
  end)
end

local function clearAtcData()
  AtcIdentifiersUpdatedTimestamp = nil
end

local refreshVatsimDataTimer = timer.new({
  delay = 60, -- Should be more than enough
  recurring = true,
  params = {},
  initial_delay = 0, -- Make sure we have information asap
  callback = function(timer_obj, params) refreshVatsimDataNow() end
})

--
-- Initialization
--
-- To deal with lazyly initialized resources, the initialization method is retried automatically
-- until it succeeds once. For instance, it can check for datarefs and stop initialization if
-- a required dataref is not yet initialized.
--

local vatsimbriefHelperIsInitialized = false

function tryVatsimbriefHelperInit()
	if vatsimbriefHelperIsInitialized then
		return
	end
	
	vatsimbriefHelperIsInitialized = true
end

do_often("tryVatsimbriefHelperInit()")

--
-- Flightplan UI handling
--

local FlightplanWindowLastRenderedFlightplanId = nil
local FlightplanWindowLastAtcIdentifiersUpdatedTimestamp = nil
local FlightplanWindowHasRenderedContent = false

local FlightplanWindowShowDownloadingMsg = false

local FlightplanWindowAirports = ""
local FlightplanWindowRoute = ""
local FlightplanWindowAltRoute = ""
local FlightplanWindowSchedule = ""
local FlightplanWindowAltitudeAndTemp = ""
local FlightplanWindowFuel = ""
local FlightplanWindowWeights = ""
local FlightplanWindowTrack = ""
local FlightplanWindowMetars = ""

local FlightplanWindowKeyWidth = 14

local FlightplanWindowLastRenderedSimbriefFlightplanFetchStatus = CurrentSimbriefFlightplanFetchStatus
local FlightplanWindowFlightplanDownloadStatus = ''
local FlightplanWindowFlightplanDownloadStatusColor = 0

local function createFlightplanTableEntry(name, value)
  return ("%-" .. FlightplanWindowKeyWidth .. "s%s"):format(name .. ':', value)
end

function timespanToHm(s)
  local seconds = tonumber(s)
  
  local hrs = math.floor(seconds / (60 * 60))
  seconds = seconds % hrs * 60 * 60
  local mins = math.floor(seconds / 60)
  seconds = seconds % mins * 60
  local secs = math.floor(seconds)
  return ("%02d:%02d"):format(hrs, mins)
end

function buildVatsimbriefHelperFlightplanWindowCanvas()
	-- Invent a caching mechanism to prevent rendering the strings each frame
  local flightplanChanged = FlightplanWindowLastRenderedFlightplanId ~= FlightplanId
  local flightplanFetchStatusChanged = AtcWindowLastRenderedSimbriefFlightplanFetchStatus ~= CurrentSimbriefFlightplanFetchStatus
  local renderContent = flightplanChanged or flightplanFetchStatusChanged or not FlightplanWindowHasRenderedContent
  if renderContent then
    -- Render download status
    local statusType = CurrentSimbriefFlightplanFetchStatus.level
    if statusType == SimbriefFlightplanFetchStatusLevel.USER_RELATED or statusType == SimbriefFlightplanFetchStatusLevel.SYSTEM_RELATED then
      FlightplanWindowFlightplanDownloadStatus, FlightplanWindowFlightplanDownloadStatusColor = getSimbriefFlightplanFetchStatusMessageAndColor()
    else
      FlightplanWindowFlightplanDownloadStatus = ''
      FlightplanWindowFlightplanDownloadStatusColor = colorNormal
    end
    
    if stringIsEmpty(FlightplanId) then
      if CurrentSimbriefFlightplanFetchStatus == SimbriefFlightplanFetchStatus.DOWNLOADING then
        FlightplanWindowShowDownloadingMsg = true
      else
        FlightplanWindowShowDownloadingMsg = false -- Clear message if there's another message going on, e.g. a download error
      end
    else
      FlightplanWindowShowDownloadingMsg = false
      
      if stringIsNotEmpty(FlightplanAltIcao) then
        FlightplanWindowAirports = ("%s - %s / %s"):format(FlightplanOriginIcao, FlightplanDestIcao, FlightplanAltIcao)
      else
        FlightplanWindowAirports = ("%s - %s"):format(FlightplanOriginIcao, FlightplanDestIcao)
      end
      FlightplanWindowAirports = createFlightplanTableEntry("Airports", FlightplanWindowAirports)
      
      FlightplanWindowRoute = ("%s/%s %s %s/%s"):format(FlightplanOriginIcao, FlightplanOriginRunway, FlightplanRoute, FlightplanDestIcao, FlightplanDestRunway)
      FlightplanWindowRoute = createFlightplanTableEntry("Route", FlightplanWindowRoute)
      
      if stringIsNotEmpty(FlightplanAltIcao) then
        FlightplanWindowAltRoute = ("%s/%s %s %s/%s"):format(FlightplanDestIcao, FlightplanDestRunway, FlightplanAltRoute, FlightplanAltIcao, FlightplanAltRunway)
        FlightplanWindowAltRoute = createFlightplanTableEntry("Alt Route", FlightplanWindowAltRoute)
      else
        FlightplanWindowAltRoute = ""
      end
      
      local timeFormat = "%I:%M%p"
      FlightplanWindowSchedule = ("OUT=%s OFF=%s BLOCK=%s ON=%s IN=%s"):format(
        os.date("%I:%M%p", FlightplanSchedOut),
        os.date("%I:%M%p", FlightplanSchedOn),
        timespanToHm(FlightplanSchedBlock),
        os.date("%I:%M%p", FlightplanSchedIn),
        os.date("%I:%M%p", FlightplanSchedBlock))
      FlightplanWindowSchedule = createFlightplanTableEntry("Schedule", FlightplanWindowSchedule)
      
      if stringIsNotEmpty(FlightplanAltIcao) then
        FlightplanWindowAltitudeAndTemp = ("ALT=%d/%d TEMP=%d°C"):format(FlightplanAltitude, FlightplanAltAltitude, FlightplanTocTemp)
      else
        FlightplanWindowAltitudeAndTemp = ("ALT=%d TEMP=%d°C"):format(FlightplanAltitude, FlightplanTocTemp)
      end
      FlightplanWindowAltitudeAndTemp = createFlightplanTableEntry("Cruise", FlightplanWindowAltitudeAndTemp)
      
      FlightplanWindowFuel = ("BLOCK=%d%s ALTN=%d%s RESERVE=%d%s T/O=%d%s"):format(
        FlightplanBlockFuel, FlightplanUnit,
        FlightplanAltFuel, FlightplanUnit,
        FlightplanReserveFuel, FlightplanUnit,
        FlightplanTakeoffFuel, FlightplanUnit)
      FlightplanWindowFuel = createFlightplanTableEntry("Fuel", FlightplanWindowFuel)
      
      FlightplanWindowWeights = ("CARGO=%d%s PAX=%d%s PAYLOAD=%d%s ZFW=%d%s"):format(
        FlightplanCargo, FlightplanUnit,
        FlightplanPax, FlightplanUnit,
        FlightplanPayload, FlightplanUnit,
        FlightplanZfw, FlightplanUnit)
      FlightplanWindowWeights = createFlightplanTableEntry("Weights", FlightplanWindowWeights)
      
      if stringIsNotEmpty(FlightplanAltIcao) then
        FlightplanWindowTrack = ("DIST=%d/%d BLOCKTIME=%s CI=%d WINDDIR=%d WINDSPD=%d"):format(
          FlightplanDistance, FlightplanAltDistance, timespanToHm(FlightplanSchedBlock), FlightplanCostindex, FlightplanAvgWindDir, FlightplanAvgWindSpeed)
      else
        FlightplanWindowTrack = ("DIST=%d BLOCKTIME=%s CI=%d WINDDIR=%d WINDSPD=%d"):format(
          FlightplanDistance, timespanToHm(FlightplanSchedBlock), FlightplanCostindex, FlightplanAvgWindDir, FlightplanAvgWindSpeed)
      end
      FlightplanWindowTrack = createFlightplanTableEntry("Track", FlightplanWindowTrack)
      
      FlightplanWindowMetars = ("%s\n%s%s"):format(FlightplanOriginMetar, string.rep(' ', FlightplanWindowKeyWidth), FlightplanDestMetar)
      if stringIsNotEmpty(FlightplanAltIcao) then
        FlightplanWindowMetars = FlightplanWindowMetars .. ("\n%s%s"):format(string.rep(' ', FlightplanWindowKeyWidth), FlightplanAltMetar)
      end
      FlightplanWindowMetars = createFlightplanTableEntry("METARs", FlightplanWindowMetars)
    end
    
    FlightplanWindowLastRenderedSimbriefFlightplanFetchStatus = CurrentSimbriefFlightplanFetchStatus
    FlightplanWindowLastRenderedFlightplanId = FlightplanId
    FlightplanWindowHasRenderedContent = true
  end
  
  -- Paint
  imgui.SetWindowFontScale(1.0)
  
  if stringIsNotEmpty(FlightplanWindowFlightplanDownloadStatus) then
    imgui.PushStyleColor(imgui.constant.Col.Text, FlightplanWindowFlightplanDownloadStatusColor)
    imgui.TextUnformatted(FlightplanWindowFlightplanDownloadStatus)
    imgui.PopStyleColor()
  end
  
  if FlightplanWindowShowDownloadingMsg then
    imgui.PushStyleColor(imgui.constant.Col.Text, colorA320Blue)
    imgui.TextUnformatted("Downloading flight plan ...")
    imgui.PopStyleColor()
  else
    imgui.TextUnformatted(FlightplanWindowAirports)
    imgui.TextUnformatted(FlightplanWindowRoute)
    if stringIsNotEmpty(FlightplanWindowAltRoute) then imgui.TextUnformatted(FlightplanWindowAltRoute) end
    imgui.TextUnformatted(FlightplanWindowSchedule)
    imgui.TextUnformatted(FlightplanWindowAltitudeAndTemp)
    imgui.TextUnformatted(FlightplanWindowFuel)
    imgui.TextUnformatted(FlightplanWindowWeights)
    imgui.TextUnformatted(FlightplanWindowTrack)
    imgui.TextUnformatted(FlightplanWindowMetars)
  end
end

local vatsimbriefHelperFlightplanWindow = nil

function destroyVatsimbriefHelperFlightplanWindow()
	if vatsimbriefHelperFlightplanWindow then
		float_wnd_destroy(vatsimbriefHelperFlightplanWindow)
    vatsimbriefHelperFlightplanWindow = nil
	end
end

function createVatsimbriefHelperFlightplanWindow()
  tryVatsimbriefHelperInit()
	vatsimbriefHelperControlWindow = float_wnd_create(800, 200, 1, true)
	float_wnd_set_title(vatsimbriefHelperControlWindow, "Vatsimbrief Helper Flight Plan")
	float_wnd_set_imgui_builder(vatsimbriefHelperControlWindow, "buildVatsimbriefHelperFlightplanWindowCanvas")
	float_wnd_set_onclose(vatsimbriefHelperControlWindow, "destroyVatsimbriefHelperFlightplanWindow")
end

add_macro("Vatsimbrief Helper Flight Plan", "createVatsimbriefHelperFlightplanWindow()", "destroyVatsimbriefHelperFlightplanWindow()", "deactivate")

--
-- Control UI handling
--

local inputUserName = ""

function buildVatsimbriefHelperControlWindowCanvas()
	imgui.SetWindowFontScale(1.0)
  
  local userNameInvalid = CurrentSimbriefFlightplanFetchStatus == SimbriefFlightplanFetchStatus.INVALID_USER_NAME or CurrentSimbriefFlightplanFetchStatus == SimbriefFlightplanFetchStatus.NO_SIMBRIEF_USER_ID_ENTERED
  if userNameInvalid then
    imgui.PushStyleColor(imgui.constant.Col.Text, colorErr)
  end
  local changeFlag, newUserName = imgui.InputText("Simbrief Username", inputUserName, 255)
  if userNameInvalid then
    imgui.PopStyleColor()
  end
  if changeFlag then inputUserName = newUserName end
  imgui.SameLine()
  if imgui.Button("Set") then
    if VatsimbriefConfiguration.simbrief == nil then VatsimbriefConfiguration.simbrief = {} end
    VatsimbriefConfiguration.simbrief.username = trim(inputUserName)
    saveConfiguration()
    clearFlightplan()
    refreshFlightplanNow()
    inputUserName = '' -- Clear input line to keep user anonymous (in case he's streaming)
  end
  
  if imgui.Button("Reload Flight Plan") then
    clearFlightplan()
    refreshFlightplanNow()
  end
  imgui.SameLine()
  if imgui.Button("Reload ATC") then
    clearAtcData()
    refreshVatsimDataNow()
  end
end

local vatsimbriefHelperControlWindow = nil

function destroyVatsimbriefHelperControlWindow()
	if vatsimbriefHelperControlWindow then
		float_wnd_destroy(vatsimbriefHelperControlWindow)
    vatsimbriefHelperControlWindow = nil
	end
end

function createVatsimbriefHelperControlWindow()
  tryVatsimbriefHelperInit()
  if vatsimbriefHelperControlWindow == nil then -- "Singleton window"
    vatsimbriefHelperControlWindow = float_wnd_create(560, 80, 1, true)
    float_wnd_set_title(vatsimbriefHelperControlWindow, "Vatsimbrief Helper Control")
    float_wnd_set_imgui_builder(vatsimbriefHelperControlWindow, "buildVatsimbriefHelperControlWindowCanvas")
    float_wnd_set_onclose(vatsimbriefHelperControlWindow, "destroyVatsimbriefHelperControlWindow")
  end
end

add_macro("Vatsimbrief Helper Control", "createVatsimbriefHelperControlWindow()", "destroyVatsimbriefHelperControlWindow()", "deactivate")

--
-- ATC UI handling
--

local AtcWindowLastRenderedFlightplanId = nil
local AtcWindowLastAtcIdentifiersUpdatedTimestamp = nil
local AtcWindowHasRenderedContent = false

local Route = ""
local RouteSeparatorLine = ""
local Atcs = ""

local AtcWindowLastRenderedSimbriefFlightplanFetchStatus = CurrentSimbriefFlightplanFetchStatus
local AtcWindowFlightplanDownloadStatus = ''
local AtcWindowFlightplanDownloadStatusColor = 0

local AtcWindowLastRenderedVatsimDataFetchStatus = CurrentVatsimDataFlightplanFetchStatus
local AtcWindowVatsimDataDownloadStatus = ''
local AtcWindowVatsimDataDownloadStatusColor = 0
local showVatsimDataIsDownloading = false

local function stringEndsWith(str, ending)
   return ending == "" or str:sub(-#ending) == ending
end

local function renderAtcString(info)
  local shortId
  
  -- Try to remove airport icao from ID
  local underscore = info.id:find('_')
  if underscore ~= nil then
    shortId = info.id:sub(underscore + 1)
  else
    shortId = info.id
  end
  
  -- Remove leading '_', e.g. _TWR
  while shortId:find('_') == 1 do
    shortId = shortId:sub(2)
  end
  
  return shortId .. '=' .. info.frequency
end

local function renderAirportAtcToString(airportIcao, airportIata)
  local atis = {}
  local del = {}
  local gnd = {}
  local twr = {}
  local dep = {}
  local app = {}
  local other = {}
  
  local icaoPrefix = airportIcao .. '_'
  local iataPrefix = airportIata .. '_'
  for _, v in pairs(MapAtcIdentifiersToAtcInfo) do
    if v.id:find(icaoPrefix) == 1 or v.id:find(iataPrefix) == 1 then
      if stringEndsWith(v.id, "_ATIS") then
        table.insert(atis, renderAtcString(v))
      elseif stringEndsWith(v.id, "_DEL") then
        table.insert(del, renderAtcString(v))
      elseif stringEndsWith(v.id, "_GND") then
        table.insert(gnd, renderAtcString(v))
      elseif stringEndsWith(v.id, "_TWR") then
        table.insert(twr, renderAtcString(v))
      elseif stringEndsWith(v.id, "_DEP") then
        table.insert(dep, renderAtcString(v))
      elseif stringEndsWith(v.id, "_APP") then
        table.insert(app, renderAtcString(v))
      else
        table.insert(other, renderAtcString(v))
      end
    end
  end
  
  local collection = {}
  for _, v in pairs(atis) do table.insert(collection, v) end
  for _, v in pairs(del) do table.insert(collection, v) end
  for _, v in pairs(gnd) do table.insert(collection, v) end
  for _, v in pairs(twr) do table.insert(collection, v) end
  for _, v in pairs(dep) do table.insert(collection, v) end
  for _, v in pairs(app) do table.insert(collection, v) end  
  for _, v in pairs(other) do table.insert(collection, v) end  
  
  if #collection == 0 then
    return "-"
  else
    return table.concat(collection, " ")
  end
end

function buildVatsimbriefHelperAtcWindowCanvas()
	-- Invent a caching mechanism to prevent rendering the strings each frame
  local flightplanChanged = AtcWindowLastRenderedFlightplanId ~= FlightplanId
  local atcIdentifiersUpdated = AtcWindowLastAtcIdentifiersUpdatedTimestamp ~= AtcIdentifiersUpdatedTimestamp
  local flightplanFetchStatusChanged = AtcWindowLastRenderedSimbriefFlightplanFetchStatus ~= CurrentSimbriefFlightplanFetchStatus
  local vatsimDataFetchStatusChanged = AtcWindowLastRenderedVatsimDataFetchStatus ~= CurrentVatsimDataFetchStatus
  local renderContent = flightplanChanged or atcIdentifiersUpdated or flightplanFetchStatusChanged or vatsimDataFetchStatusChanged or not AtcWindowHasRenderedContent
  if renderContent then    
    -- Render download status of flightplan
    local statusType = CurrentSimbriefFlightplanFetchStatus.level
    if statusType == SimbriefFlightplanFetchStatusLevel.USER_RELATED or statusType == SimbriefFlightplanFetchStatusLevel.SYSTEM_RELATED then
      AtcWindowFlightplanDownloadStatus, AtcWindowFlightplanDownloadStatusColor = getSimbriefFlightplanFetchStatusMessageAndColor()
    else
      AtcWindowFlightplanDownloadStatus = ''
      AtcWindowFlightplanDownloadStatusColor = colorNormal
    end
    
    -- Render download status of VATSIM data
    statusType = CurrentVatsimDataFetchStatus.level
    if statusType == VatsimDataFetchStatusLevel.SYSTEM_RELATED then
      AtcWindowVatsimDataDownloadStatus, AtcWindowVatsimDataDownloadStatusColor = getVatsimDataFetchStatusMessageAndColor()
    else
      AtcWindowVatsimDataDownloadStatus = ''
      AtcWindowVatsimDataDownloadStatusColor = colorNormal
    end
    
    -- Render route
    if stringIsNotEmpty(FlightplanId) then
      -- If there's a flightplan, render it
      if stringIsNotEmpty(FlightplanAltIcao) then
        Route = FlightplanCallsign .. ":  " .. FlightplanOriginIcao .. " - " .. FlightplanDestIcao .. " / " .. FlightplanAltIcao
          .. " (" .. FlightplanOriginName .. " to " .. FlightplanDestName .. " / " .. FlightplanAltName .. ")"
      else
        Route = FlightplanCallsign .. ":  " .. FlightplanOriginIcao .. " - " .. FlightplanDestIcao
          .. " (" .. FlightplanOriginName .. " to " .. FlightplanDestName .. ")"
      end
    else
      -- It's more beautiful to show the "downloading" status in the title where the route appears in a few seconds
      if CurrentSimbriefFlightplanFetchStatus == SimbriefFlightplanFetchStatus.DOWNLOADING then
        Route = "Downloading flight plan ..."
      else
        Route = '' -- Clear previous state, e.g. don't show "downloading" when there's already an error
      end
    end
    RouteSeparatorLine = string.rep("-", #Route)
    
    -- Try to render ATC data
    if numberIsNilOrZero(AtcIdentifiersUpdatedTimestamp) then
      Atcs = ''
      -- Only show "downloading" message when there is no VATSIM data yet and no other download status is rendered
      showVatsimDataIsDownloading = CurrentVatsimDataFetchStatus == VatsimDataFetchStatus.DOWNLOADING
    else
      showVatsimDataIsDownloading = false
      if stringIsEmpty(FlightplanId) then
        Atcs = ("Got %d ATC stations. Waiting for flight plan ..."):format(#MapAtcIdentifiersToAtcInfo)
      else
        if #MapAtcIdentifiersToAtcInfo == 0 then
          Atcs = 'No ATCs found. This will probably be a technical problem.'
        else
          Atcs = FlightplanOriginIcao .. ": " .. renderAirportAtcToString(FlightplanOriginIcao, FlightplanOriginIata)
            .. "\n" .. FlightplanDestIcao .. ": " .. renderAirportAtcToString(FlightplanDestIcao, FlightplanDestIata)
          if stringIsNotEmpty(FlightplanAltIcao) then Atcs = Atcs .. "\n" .. FlightplanAltIcao .. ": " .. renderAirportAtcToString(FlightplanAltIcao, FlightplanAltIata) end
        end
      end
    end
    
    AtcWindowLastRenderedSimbriefFlightplanFetchStatus = CurrentSimbriefFlightplanFetchStatus
    AtcWindowLastRenderedVatsimDataFetchStatus = CurrentVatsimDataFetchStatus
    AtcWindowLastRenderedFlightplanId = FlightplanId
    AtcWindowLastAtcIdentifiersUpdatedTimestamp = AtcIdentifiersUpdatedTimestamp
    AtcWindowHasRenderedContent = true
  end
	
  -- Paint
  imgui.SetWindowFontScale(1.0)
  
  if stringIsNotEmpty(AtcWindowFlightplanDownloadStatus) then
    imgui.PushStyleColor(imgui.constant.Col.Text, AtcWindowFlightplanDownloadStatusColor)
    imgui.TextUnformatted(AtcWindowFlightplanDownloadStatus)
    imgui.PopStyleColor()
  elseif stringIsNotEmpty(AtcWindowVatsimDataDownloadStatus) then
    -- Why elseif? For user comfort, we don't show Flightplan AND VATSIM errors at the same time.
    -- If the network is broken, this looks ugly.
    -- The flightplan error is much more generic and contains more infromation, e.g. that
    -- a user name is missing. Therefore, give it the preference.
    imgui.PushStyleColor(imgui.constant.Col.Text, AtcWindowVatsimDataDownloadStatusColor)
    imgui.TextUnformatted(AtcWindowVatsimDataDownloadStatus)
    imgui.PopStyleColor()
  end
  if stringIsNotEmpty(Route) then
    imgui.PushStyleColor(imgui.constant.Col.Text, colorA320Blue)
    imgui.TextUnformatted(Route)
    imgui.TextUnformatted(RouteSeparatorLine)
    imgui.PopStyleColor()
  end
  if AtcIdentifiersUpdatedTimestamp ~= nil then -- Show information if data is old
    local ageOfAtcDataMinutes = math.floor((os.clock() - AtcIdentifiersUpdatedTimestamp) * (1.0 / 60.0))
    if ageOfAtcDataMinutes >= 3 then
      imgui.PushStyleColor(imgui.constant.Col.Text, colorWarn)
      -- Note: Render text here as the minutes update every minute and not "on event" when a re-rendering occurs
      imgui.TextUnformatted(("No new VATSIM data for %d minutes!"):format(ageOfAtcDataMinutes))
      imgui.PopStyleColor()
    end
  end
  if showVatsimDataIsDownloading then
    imgui.TextUnformatted("Downloading VATSIM data ...")
  end
  if stringIsNotEmpty(Atcs) then
    imgui.TextUnformatted(Atcs)
  end
end

local vatsimbriefHelperAtcWindow = nil

function destroyVatsimbriefHelperAtcWindow()
	if vatsimbriefHelperAtcWindow then
		float_wnd_destroy(vatsimbriefHelperAtcWindow)
    vatsimbriefHelperAtcWindow = nil
	end
end

function createVatsimbriefHelperAtcWindow()
  tryVatsimbriefHelperInit()
	vatsimbriefHelperAtcWindow = float_wnd_create(560, 90, 1, true)
	float_wnd_set_title(vatsimbriefHelperAtcWindow, "Vatsimbrief Helper ATC")
	float_wnd_set_imgui_builder(vatsimbriefHelperAtcWindow, "buildVatsimbriefHelperAtcWindowCanvas")
	float_wnd_set_onclose(vatsimbriefHelperAtcWindow, "destroyVatsimbriefHelperAtcWindow")
end

add_macro("Vatsimbrief Helper ATC", "createVatsimbriefHelperAtcWindow()", "destroyVatsimbriefHelperAtcWindow()", "deactivate")

-- Initially open some windows
createVatsimbriefHelperAtcWindow()
createVatsimbriefHelperFlightplanWindow()
