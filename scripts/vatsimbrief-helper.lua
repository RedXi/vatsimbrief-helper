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

local function performDefaultHttpGetRequest(url, callback)
  local t0 = os.clock()
  
  local content, code, headers, status = http.request(url)

  if type(content) ~= "string" or type(code) ~= "number" or
      type(headers) ~= "table" or type(status) ~= "string" then
    print(("Request URL: %s, FAILURE"):format(url))
    return nil -- Err
  end
  
  print(("Request URL: %s, duration: %.2fs, response status: %s, response length: %d bytes")
    :format(url, os.clock() - t0, status, #content))
  
  if code >= 200 and code < 300 then
    table.insert(SyncTasksAfterAsyncTasks, { callback = callback, params = { httpResponse = content } })
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

local FlightplanInitialAltitude = 0
local FlightplanAltAltitude = 0
local FlightplanTocTemp = 0

local FlightplanBlockFuel = 0
local FlightplanReserveFuel = 0
local FlightplanTakeoffFuel = 0

local FlightplanUnit = ""

local FlightplanCargo = 0
local FlightplanPax = 0
local FlightplanPayload = 0
local FlightplanZfw = 0

local FlightplanDistance = 0
local FlightplanAltDistance = 0
local FlightplanCostindex = 0

local function processNewFlightplan(params)
  local parser = xml2lua.parser(simbriefFlightplanXmlHandler)
  parser:parse(params.httpResponse)
  if simbriefFlightplanXmlHandler.root.OFP.fetch.status == "Success" then
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
      FlightplanAltRoute = SimbriefFlightplan.alternate.route
      
      FlightplanSchedOut = tonumber(SimbriefFlightplan.times.sched_out)
      FlightplanSchedOff = tonumber(SimbriefFlightplan.times.sched_off)
      FlightplanSchedOn = tonumber(SimbriefFlightplan.times.sched_on)
      FlightplanSchedIn = tonumber(SimbriefFlightplan.times.sched_in)
      FlightplanSchedBlock = tonumber(SimbriefFlightplan.times.sched_block)
      
      -- TOC waypoint is identified by "TOC"
      local indexOfToc = 1
      while indexOfToc <= #SimbriefFlightplan.navlog.fix and SimbriefFlightplan.navlog.fix[indexOfToc].ident ~= "TOC" do
        indexOfToc = indexOfToc + 1
      end
      if indexOfToc <= #SimbriefFlightplan.navlog.fix then
        FlightplanAltitude = tonumber(SimbriefFlightplan.navlog.fix[indexOfToc].altitude_feet)
        FlightplanTocTemp = tonumber(SimbriefFlightplan.navlog.fix[indexOfToc].oat)
      else
        -- No TOC found!?
        FlightplanAltitude = tonumber(SimbriefFlightplan.general.initial_altitude)
        FlightplanTocTemp = 9999 -- Some "bad" value
      end
      FlightplanAltAltitude = tonumber(SimbriefFlightplan.alternate.cruise_altitude)
      
      FlightplanBlockFuel = tonumber(SimbriefFlightplan.fuel.plan_ramp)
      FlightplanReserveFuel = tonumber(SimbriefFlightplan.fuel.min_takeoff)
      FlightplanTakeoffFuel = tonumber(SimbriefFlightplan.fuel.reserve)
      
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
      FlightplanAltMetar = removeLinebreaksFromString(SimbriefFlightplan.weather.altn_metar)
    end
  else
    print("Flight plan states that it's not valid.")
  end
end

local function clearFlightplan()
  FlightplanId = nil
end

local function flightplanCanBeDownloaded()
  return VatsimbriefConfiguration.simbrief ~= nil and stringIsNotEmpty(VatsimbriefConfiguration.simbrief.username)
end

local function refreshFlightplanNow()
  copas.addthread(function()
    if flightplanCanBeDownloaded() then
      local url = "http://www.simbrief.com/api/xml.fetcher.php?username=" .. VatsimbriefConfiguration.simbrief.username
      performDefaultHttpGetRequest(url, processNewFlightplan)
    else
      print("Not fetching flightplan. No simbrief username configured.")
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

local function processNewVatsimData(params)
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
end

local function refreshVatsimDataNow()
  copas.addthread(function()
    local url = "http://cluster.data.vatsim.net/vatsim-data.txt"
    performDefaultHttpGetRequest(url, processNewVatsimData)
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

local FlightplanWindowStatusMsg = ""

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
  local renderContent = flightplanChanged or not FlightplanWindowHasRenderedContent
  if renderContent then
    if stringIsEmpty(FlightplanId) then
      if flightplanCanBeDownloaded() then
        FlightplanWindowStatusMsg = "Downloading flightplan ..."
      else
        FlightplanWindowStatusMsg = "Please enter Simbrief user name in configuration window."
      end
    else
      FlightplanWindowStatusMsg = ""
      
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
        FlightplanWindowAltitudeAndTemp = ("ALT=%d/%d TEMP=%d°C"):format(FlightplanInitialAltitude, FlightplanAltAltitude, FlightplanTocTemp)
      else
        FlightplanWindowAltitudeAndTemp = ("ALT=%d TEMP=%d°C"):format(FlightplanInitialAltitude, FlightplanTocTemp)
      end
      FlightplanWindowAltitudeAndTemp = createFlightplanTableEntry("CRZ", FlightplanWindowAltitudeAndTemp)
      
      FlightplanWindowFuel = ("BLOCK=%d%s RESERVE=%d%s T/O=%d%s"):format(
        FlightplanBlockFuel, FlightplanUnit,
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
        FlightplanWindowTrack = ("DIST=%d/%d BLOCKTIME=%s CI=%d"):format(
          FlightplanDistance, FlightplanAltDistance, timespanToHm(FlightplanSchedBlock), FlightplanCostindex)
      else
        FlightplanWindowTrack = ("DIST=%d BLOCKTIME=%s CI=%d"):format(
          FlightplanDistance, timespanToHm(FlightplanSchedBlock), FlightplanCostindex)
      end
      FlightplanWindowTrack = createFlightplanTableEntry("Track", FlightplanWindowTrack)
      
      FlightplanWindowMetars = ("%s\n%s%s"):format(FlightplanOriginMetar, string.rep(' ', FlightplanWindowKeyWidth), FlightplanDestMetar)
      if stringIsNotEmpty(FlightplanAltIcao) then
        FlightplanWindowMetars = FlightplanWindowMetars .. ("\n%s%s"):format(string.rep(' ', FlightplanWindowKeyWidth), FlightplanAltMetar)
      end
      FlightplanWindowMetars = createFlightplanTableEntry("METARs", FlightplanWindowMetars)
    end
    
    FlightplanWindowLastRenderedFlightplanId = FlightplanId
    FlightplanWindowHasRenderedContent = true
  end
  
  -- Paint
  imgui.SetWindowFontScale(1.0)
  if stringIsNotEmpty(FlightplanWindowStatusMsg) then
    imgui.TextUnformatted(FlightplanWindowStatusMsg)
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
	end
end

function createVatsimbriefHelperFlightplanWindow()
  tryVatsimbriefHelperInit()
	vatsimbriefHelperControlWindow = float_wnd_create(800, 200, 1, true)
	float_wnd_set_title(vatsimbriefHelperControlWindow, "Vatsimbrief Helper Flightplan")
	float_wnd_set_imgui_builder(vatsimbriefHelperControlWindow, "buildVatsimbriefHelperFlightplanWindowCanvas")
	float_wnd_set_onclose(vatsimbriefHelperControlWindow, "destroyVatsimbriefHelperFlightplanWindow")
end

add_macro("Vatsimbrief Helper Flightplan", "createVatsimbriefHelperFlightplanWindow()", "destroyVatsimbriefHelperFlightplanWindow()", "deactivate")

--
-- Control UI handling
--

local inputUserName = ""

function buildVatsimbriefHelperControlWindowCanvas()
	imgui.SetWindowFontScale(1.0)
  
  local changeFlag, newUserName = imgui.InputText("Simbrief Username", inputUserName, 255)
  if changeFlag then inputUserName = newUserName end
  imgui.SameLine()
  if imgui.Button("Set") then
    if VatsimbriefConfiguration.simbrief == nil then VatsimbriefConfiguration.simbrief = {} end
    VatsimbriefConfiguration.simbrief.username = inputUserName
    saveConfiguration()
    clearFlightplan()
    refreshFlightplanNow()
    inputUserName = '' -- Clear input line to keep user anonymous (in case he's streaming)
  end
  
  if imgui.Button("Reload Flightplan") then
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
	end
end

function createVatsimbriefHelperControlWindow()
  tryVatsimbriefHelperInit()
	vatsimbriefHelperControlWindow = float_wnd_create(560, 80, 1, true)
	float_wnd_set_title(vatsimbriefHelperControlWindow, "Vatsimbrief Helper Control")
	float_wnd_set_imgui_builder(vatsimbriefHelperControlWindow, "buildVatsimbriefHelperControlWindowCanvas")
	float_wnd_set_onclose(vatsimbriefHelperControlWindow, "destroyVatsimbriefHelperWindow")
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

local a320Blue = 0xFFFFDDAA

function buildVatsimbriefHelperAtcWindowCanvas()
	-- Invent a caching mechanism to prevent rendering the strings each frame
  local flightplanChanged = AtcWindowLastRenderedFlightplanId ~= FlightplanId
  local atcIdentifiersUpdated = AtcWindowLastAtcIdentifiersUpdatedTimestamp ~= AtcIdentifiersUpdatedTimestamp
  local renderContent = flightplanChanged or atcIdentifiersUpdated or not AtcWindowHasRenderedContent
  if renderContent then
    if stringIsEmpty(FlightplanId) then
      if flightplanCanBeDownloaded() then
        Route = "Downloading flightplan ..."
      else
        Route = "Please enter Simbrief user name in configuration window."
      end
    else
      if stringIsNotEmpty(FlightplanAltIcao) then
        Route = FlightplanCallsign .. ":  " .. FlightplanOriginIcao .. " - " .. FlightplanDestIcao .. " / " .. FlightplanAltIcao
          .. " (" .. FlightplanOriginName .. " to " .. FlightplanDestName .. " / " .. FlightplanAltName .. ")"
      else
        Route = FlightplanCallsign .. ":  " .. FlightplanOriginIcao .. " - " .. FlightplanDestIcao
          .. " (" .. FlightplanOriginName .. " to " .. FlightplanDestName .. ")"
      end
    end
    RouteSeparatorLine = string.rep("-", #Route)
    
    if numberIsNilOrZero(AtcIdentifiersUpdatedTimestamp) then
      Atcs = "Downloading VATSIM ATC data ..."
    elseif stringIsEmpty(FlightplanId) then
      Atcs = ("Got %d ATC stations. Waiting for flightplan ..."):format(#MapAtcIdentifiersToAtcInfo)
    else
      if #MapAtcIdentifiersToAtcInfo == 0 then
        Atcs = 'No ATCs found. This will probably be a technical problem.'
      else
        Atcs = FlightplanOriginIcao .. ": " .. renderAirportAtcToString(FlightplanOriginIcao, FlightplanOriginIata)
          .. "\n" .. FlightplanDestIcao .. ": " .. renderAirportAtcToString(FlightplanDestIcao, FlightplanDestIata)
        if stringIsNotEmpty(FlightplanAltIcao) then Atcs = Atcs .. "\n" .. FlightplanAltIcao .. ": " .. renderAirportAtcToString(FlightplanAltIcao, FlightplanAltIata) end
      end
    end
    
    AtcWindowLastRenderedFlightplanId = FlightplanId
    AtcWindowLastAtcIdentifiersUpdatedTimestamp = AtcIdentifiersUpdatedTimestamp
    AtcWindowHasRenderedContent = true
  end
	
  -- Paint
  imgui.SetWindowFontScale(1.0)
  
  imgui.PushStyleColor(imgui.constant.Col.Text, a320Blue)
  imgui.TextUnformatted(Route)
  imgui.TextUnformatted(RouteSeparatorLine)
  imgui.PopStyleColor()
  
  if AtcIdentifiersUpdatedTimestamp ~= nil then
    local ageOfAtcDataMinutes = math.floor((os.clock() - AtcIdentifiersUpdatedTimestamp) * (1.0 / 60.0))
    if ageOfAtcDataMinutes >= 3 then
      imgui.PushStyleColor(imgui.constant.Col.Text, 0xFF8888FF)
      imgui.TextUnformatted(("No ATC data for %d minutes!"):format(ageOfAtcDataMinutes))
      imgui.PopStyleColor()
    end
  end
  imgui.TextUnformatted(Atcs)
end

local vatsimbriefHelperAtcWindow = nil

function destroyVatsimbriefHelperAtcWindow()
	if vatsimbriefHelperAtcWindow then
		float_wnd_destroy(vatsimbriefHelperAtcWindow)
	end
end

function createVatsimbriefHelperAtcWindow()
  tryVatsimbriefHelperInit()
	vatsimbriefHelperAtcWindow = float_wnd_create(560, 90, 1, true)
	float_wnd_set_title(vatsimbriefHelperAtcWindow, "Vatsimbrief Helper ATC")
	float_wnd_set_imgui_builder(vatsimbriefHelperAtcWindow, "buildVatsimbriefHelperAtcWindowCanvas")
	float_wnd_set_onclose(vatsimbriefHelperAtcWindow, "destroyVatsimbriefHelperWindow")
end

add_macro("Vatsimbrief Helper ATC", "createVatsimbriefHelperAtcWindow()", "destroyVatsimbriefHelperAtcWindow()", "deactivate")

-- Initially open some windows
createVatsimbriefHelperAtcWindow()
createVatsimbriefHelperFlightplanWindow()
if not flightplanCanBeDownloaded() then
  createVatsimbriefHelperControlWindow()
end
