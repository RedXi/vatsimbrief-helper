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

local function trim(s)
   return s:gsub("^%s*(.-)%s*$", "%1")
end

local function stringEndsWith(s, e)
  return stringIsEmpty(e) or s:sub(-#e) == e
end

local OsType = { WINDOWS, UNIX_LIKE }
local OS
if package.config:sub(1, 1) == '/' then OS = OsType.UNIX_LIKE else OS = OsType.WINDOWS end

local PATH_DELIMITER = package.config:sub(1, 1)
local function formatPathOsSpecific(path)
  local pathDelimiter = PATH_DELIMITER
  return path:gsub("[\\/]", pathDelimiter)
end

local function getExtensionOfFileName(s)
  local firstDot = s:find("%.")
  if firstDot ~= nil then
    return s:sub(firstDot)
  else
    return ''
  end
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

local function wrapStringAtMaxlengthWithPadding(str, maxLength, padding)
  local items = splitStringBySeparator(str, ' ')
  local result = ''
  local lineLength = 0
  for i = 1, #items do
    local item = items[i]
    local itemLength = string.len(item)
    if lineLength > 0 and lineLength + 1 + itemLength > maxLength then
      result = result .. "\n" .. padding
      lineLength = 0
    end
    if lineLength > 0 then
      result = result .. " "
      lineLength = lineLength + 1
    end
    result = result .. item
    lineLength = lineLength + itemLength
  end
  return result
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
  logMsg(("Vatsimbrief Helper using '%s' with license '%s'. Project homepage: %s")
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
    logMsg(("Vatsimbrief configuration file '%s' loaded."):format(ConfigurationFilePath))
  else
    logMsg(("Vatsimbrief configuration file '%s' missing! Running without configuration settings.")
      :format(ConfigurationFilePath))
  end
end

local function saveConfiguration()
  LIP.save(ConfigurationFilePath, VatsimbriefConfiguration);
end

local function getConfiguredSimbriefUserName()
  if VatsimbriefConfiguration.simbrief ~= nil and stringIsNotEmpty(VatsimbriefConfiguration.simbrief.username) then
    return trim(VatsimbriefConfiguration.simbrief.username)
  else
    return ''
  end
end

local function setConfiguredUserName(value)
  if VatsimbriefConfiguration.simbrief == nil then VatsimbriefConfiguration.simbrief = {} end
  VatsimbriefConfiguration.simbrief.username = trim(value)
end

local function getConfiguredFlightPlanFilesForDownloadAsList()
  local result = {}
  if VatsimbriefConfiguration.simbrief ~= nil then
    local i = 1
    while true do
      local nextItem = VatsimbriefConfiguration.simbrief['flightPlanTypesForDownload' .. i]
      if nextItem == nil then break end
      table.insert(result, nextItem)
      i = i + 1
    end
  end
  return result
end

local function setConfiguredFlightPlanFilesForDownloadAsList(value)
  if VatsimbriefConfiguration.simbrief == nil then VatsimbriefConfiguration.simbrief = {} end
  for i = 1, #value do VatsimbriefConfiguration.simbrief['flightPlanTypesForDownload' .. i] = value[i] end
end

local function setConfiguredDeleteOldFlightPlansSetting(value)
  if VatsimbriefConfiguration.simbrief == nil then VatsimbriefConfiguration.simbrief = {} end
  local strValue
  if value then strValue = 'yes' else strValue = 'no' end
  VatsimbriefConfiguration.simbrief.deleteDownloadedFlightPlans = strValue
end

local function getConfiguredDeleteOldFlightPlansSetting()
  -- Unless it's clearly a YES, do NOT return to delete anything! Also in case the removal crashes on the system. We don't want that.
  
  if VatsimbriefConfiguration.simbrief == nil then VatsimbriefConfiguration.simbrief = {} end
  if VatsimbriefConfiguration.simbrief.deleteDownloadedFlightPlans == nil then
    return false
  end
  if trim(VatsimbriefConfiguration.simbrief.deleteDownloadedFlightPlans) == 'yes' then
    return true
  else
    return false
  end
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
  INTERNAL_SERVER_ERROR = 2,
  UNHANDLED_RESPONSE = 3
}

local function performDefaultHttpGetRequest(url, resultCallback, errorCallback, userData, isRedirectedRequest)
  local t0 = os.clock()
  
  logMsg(("Requesting URL '%s' at time '%s'"):format(url, os.date("%X")))
  local content, code, headers, status = http.request(url)
  logMsg(("Request to URL '%s' finished"):format(url))

  if type(content) ~= "string" or type(code) ~= "number" or
      type(headers) ~= "table" or type(status) ~= "string" then
    logMsg(("Request URL: %s, FAILURE: Status = %s, code = %s"):format(url, status, code))
    errorCallback({ errorCode = HttpDownloadErrors.NETWORK, userData = userData })
  else
    logMsg(("Request URL: %s, duration: %.2fs, response status: %s, response length: %d bytes")
      :format(url, os.clock() - t0, status, #content))
    
    --[[ We tried to enable the library for HTTP redirects this way. However, we don't get out of http.request() w/o error:
      Request URL: http://www.simbrief.com/ofp/flightplans/EDDNEDDL_WAE_1601924120.rte, FAILURE: Status = nil, code = host or service not provided, or not known
      
    if status == 301 then -- Moved permanently
      local to = headers.location
      if to == nil then
        errorCallback({ errorCode = HttpDownloadErrors.UNHANDLED_RESPONSE, userData = userData })
      else
        if isRedirectedRequest then
          logMsg("Only attempting to redirect ONCE. Received second redirect, this time to '" .. to .. "'")
          errorCallback({ errorCode = HttpDownloadErrors.UNHANDLED_RESPONSE, userData = userData })
        else
          logMsg("Redirecting: '" .. url .. "' to '" .. to .. "'")
          performDefaultHttpGetRequest(to, resultCallback, errorCallback, userData, true)
        end
      end
    end
    ]]--
  
    if code < 500 then
      table.insert(SyncTasksAfterAsyncTasks, { callback = resultCallback, params = { responseBody = content, httpStatusCode = code, userData = userData } })
    else
      errorCallback({ errorCode = HttpDownloadErrors.INTERNAL_SERVER_ERROR, userData = userData })
    end
  end
end

--
-- Download of Simbrief flight plans
--

-- Constants
local FlightplanDownloadDirectory = formatPathOsSpecific(SCRIPT_DIRECTORY .. "flight-plans" .. PATH_DELIMITER)
local FlightplanDownloadRetryAfterSecs = 120.0 -- MUST be float to pass printf("%f", this)
-- Config from flightplan
local FlightplanDownloadFilesForFlightplanId = ''
local FlightplanDownloadFilesBaseUrl = '' -- Base URL for download, e.g. "http://www.simbrief.com/ofp/flightplans/"
local FlightplanDownloadFileTypes = {} -- Ordered array of types
local FlightplanDownloadFileTypesAndNames = {} -- Hash: Type to file name on server
local FlightplanDownloadLocalFilesName = ''
-- User config
local FlightplanDownloadConfig = {} -- FileType to "true" (enable download) or "false" (disable download)
local tmp = getConfiguredFlightPlanFilesForDownloadAsList()
for i = 1, #tmp do FlightplanDownloadConfig[tmp[i]] = true end
-- Download state
local FlightplanDownloadMapTypeToDownloadedFileName = {} -- When download complete
local FlightplanDownloadSetOfDownloadingTypes = {} -- When currently downloading, type name maps to "something"
local FlightplanDownloadMapTypeToAttemptTimestamp = {} -- Type name maps to timestamp of last attempt

function scanDirectoryForFilesOnUnixLikeOs(directory)
  if direcory:find("'") ~= nil then return nil end -- It's stated that the procedure does not work in this case
  local t = {}
  local pfile = assert(io.popen(("find '%s' -maxdepth 1 -print0 -type f"):format(directory), 'r'))
  local list = pfile:read('*a')
  pfile:close()
  for f in s:gmatch('[^\0]+') do table.insert(t, f) end
  return t
end

function scanDirectoryForFilesOnWindowsOs(directory)
  local t = {}
  for f in io.popen([[dir "]] .. directory .. [[" /b]]):lines() do table.insert(t, f) end
  return t
end

local function listDownloadedFlightPlans()
  local filenames
  if OS == OsType.WINDOWS then
    filenames = scanDirectoryForFilesOnWindowsOs(FlightplanDownloadDirectory)
  else -- OsType.UNIX_LIKE
    filenames = scanDirectoryForFilesOnUnixLikeOs(FlightplanDownloadDirectory)
  end
  if filenames == nil then return nil end
  for i = 1, #filenames do filenames[i] = FlightplanDownloadDirectory .. filenames[i] end
  return filenames
end

local function deleteDownloadedFlightPlansIfConfigured()
  if getConfiguredDeleteOldFlightPlansSetting() then
    local fileNames = listDownloadedFlightPlans()
    if fileNames == nil then
      logMsg("Failed to list flight plan files.")
    else
      logMsg("Attempting to delete " .. #fileNames .. " recent flight plan files")
      
      -- The listDirectory() implementation is very sloppy. In case it fails, disable
      -- the flight plan removal such that we don't crash again next time we're launched.
      setConfiguredDeleteOldFlightPlansSetting(false)
      saveConfiguration()
      
      for i = 1, #fileNames do
        os.remove(fileNames[i])
      end
      
      setConfiguredDeleteOldFlightPlansSetting(true)
      saveConfiguration()
    end
  end
end

function processFlightPlanFileDownloadSuccess(httpRequest)
  local typeName = httpRequest.userData.typeName
  if httpRequest.userData.flightPlanId ~= FlightplanDownloadFilesForFlightplanId then
    logMsg("Discarding downloaded file of type '" .. httpRequest.userData.typeName .. "' for flight plan '" .. httpRequest.userData.flightPlanId .. "' as there's a new flight plan")
  else
    local targetFileName = FlightplanDownloadDirectory .. httpRequest.userData.targetFileName
    local f = io.open(targetFileName, "w")
    if io.type(f) ~= 'file' then
      logMsg("Failed to write data to file path: " .. targetFileName)
    else
      f:write(httpRequest.responseBody)
      f:close()
    end
    FlightplanDownloadMapTypeToDownloadedFileName[typeName] = targetFileName
    FlightplanDownloadSetOfDownloadingTypes[typeName] = false
    
    logMsg(("Download of file of type '%s' to '%s' for flight plan '%s' succeeded after '%.03fs'"):format(
      typeName, targetFileName, httpRequest.userData.flightPlanId, os.clock() - FlightplanDownloadMapTypeToAttemptTimestamp[typeName]))
  end
end

function processFlightPlanFileDownloadFailure(httpRequest)
  local typeName = httpRequest.userData.typeName
  if httpRequest.userData.flightPlanId ~= FlightplanDownloadFilesForFlightplanId then
    logMsg("Discarding failure for download of file of type '" .. typeName .. "' for flight plan '" .. httpRequest.userData.flightPlanId .. "'")
  else
    logMsg(("Download of file of type '%s' for flight plan '%s' FAILED after '%.03fs' -- reattempting after '%.fs'"):format(
      typeName, httpRequest.userData.flightPlanId, os.clock() - FlightplanDownloadMapTypeToAttemptTimestamp[typeName], FlightplanDownloadRetryAfterSecs))
    FlightplanDownloadSetOfDownloadingTypes[typeName] = false
  end
end

function downloadFlightplans()
  local now = os.clock()
  if FlightplanDownloadFilesForFlightplanId ~= nil then -- If there's a flightplan
    for i = 1, #FlightplanDownloadFileTypes do -- For all types
      local typeName = FlightplanDownloadFileTypes[i]
      if FlightplanDownloadMapTypeToDownloadedFileName[types] == nil then -- Not downloaded yet
        if FlightplanDownloadConfig[typeName] == true then -- And download enabled by config
          if FlightplanDownloadSetOfDownloadingTypes[typeName] ~= true then -- And download not already running
            if FlightplanDownloadMapTypeToAttemptTimestamp[typeName] == nil -- And download was not attempted yet ...
              or FlightplanDownloadMapTypeToAttemptTimestamp[typeName] < now - FlightplanDownloadRetryAfterSecs then -- ... or needs to be retried
              FlightplanDownloadMapTypeToAttemptTimestamp[typeName] = now -- Save attempt timestamp for retrying later
              FlightplanDownloadSetOfDownloadingTypes[typeName] = true -- Set immediately to prevent race conditions leading to multiple downloads launching. However, always remember to turn it off!
              local url = FlightplanDownloadFilesBaseUrl .. "-" .. FlightplanDownloadFileTypesAndNames[typeName]
              local targetFileName = FlightplanDownloadLocalFilesName .. "_" .. typeName .. getExtensionOfFileName(FlightplanDownloadFileTypesAndNames[typeName])
              logMsg(("Download of file of type '%s' for flight plan '%s' starting"):format(typeName, FlightplanDownloadFilesForFlightplanId))
              -- We observed that the official URL redirects
              --  from www.simbrief.com/ofp/flightplans/<TypeName>
              -- to
              --  http://www.simbrief.com/system/briefing.fmsdl.php?formatget=flightplans/<TypeName>
              -- HTTP 301 Redirects are unfortunately not working with this library. :-(
              -- Keep the final URL in hardcoded for now. Ouch.
              if getExtensionOfFileName(FlightplanDownloadFileTypesAndNames[typeName]) ~= ".pdf" then
                url = "http://www.simbrief.com/system/briefing.fmsdl.php?formatget=flightplans/" .. FlightplanDownloadFileTypesAndNames[typeName]
              end
              copas.addthread(function() -- Note that the HTTP call must run in a copas thread, otherwise it will throw errors (something's always nil)
                performDefaultHttpGetRequest(url, processFlightPlanFileDownloadSuccess, processFlightPlanFileDownloadFailure,
                  { typeName = typeName, flightPlanId = FlightplanDownloadFilesForFlightplanId, targetFileName = targetFileName })
              end)
            end
          end
        end
      end
    end
  end
end

local function isFlightplanFileDownloadEnabled(typeName)
  -- Note: Implement in at least O(log #TypeNames) as this method is called each frame during rendering of the configuration window
  return FlightplanDownloadConfig[typeName] == true
end

local function setFlightplanFileDownloadEnabled(typeName, value)
  if type(FlightplanDownloadConfig[typeName]) == 'boolean' then
    local stringValue
    if value then stringValue = 'true' else stringValue = 'false' end
    logMsg(("Set flight plan file download for type '%s' to '%s'"):format(typeName, stringValue))
    FlightplanDownloadConfig[typeName] = value
  end
end

local function saveFlightPlanFilesForDownload()
  local enabledFileTypes = {}
  for fileType, downloadEnabled in pairs(FlightplanDownloadConfig) do
    if downloadEnabled then table.insert(enabledFileTypes, fileType) end
  end
  setConfiguredFlightPlanFilesForDownloadAsList(enabledFileTypes)
  saveConfiguration()
end

local function runFlightPlanDownloadForNewFlightPlan(flightPlanId, baseUrlForDownload, fileTypesAndNames, localFilesName)
  -- Store flightplan specific download information
  FlightplanDownloadFilesForFlightplanId = flightPlanId
  FlightplanDownloadFilesBaseUrl = baseUrlForDownload
  if not stringEndsWith(FlightplanDownloadFilesBaseUrl, '/') then FlightplanDownloadFilesBaseUrl = FlightplanDownloadFilesBaseUrl .. '/' end
  FlightplanDownloadFileTypesAndNames = fileTypesAndNames
  FlightplanDownloadFileTypes = {}
  FlightplanDownloadLocalFilesName = localFilesName
  for fileType, fileName in pairs(fileTypesAndNames) do table.insert(FlightplanDownloadFileTypes, fileType) end
  
  -- Update config: Add new types and remove those that are gone for some reason...
  local configNew = {}
  for fileType, fileName in pairs(fileTypesAndNames) do configNew[fileType] = isFlightplanFileDownloadEnabled(fileType) end
  FlightplanDownloadConfig = configNew
  
  -- Invalidate old flightplans in memory
  FlightplanDownloadMapTypeToDownloadedFileName = {}
  FlightplanDownloadSetOfDownloadingTypes = {}
  FlightplanDownloadMapTypeToAttemptTimestamp = {}
  
  -- Create target directory of downloaded flight plans
  os.execute("mkdir " .. FlightplanDownloadDirectory)
  
  -- Invalidate old flightplans on disk
  deleteDownloadedFlightPlansIfConfigured()
end

local function getFlightplanFileTypesArray()
  return FlightplanDownloadFileTypes
end

do_sometimes("downloadFlightplans()")

--
-- Simbrief flight plans
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
  UNEXPECTED_HTTP_RESPONSE = { level = SimbriefFlightplanFetchStatusLevel.SYSTEM_RELATED },
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
  elseif CurrentSimbriefFlightplanFetchStatus == SimbriefFlightplanFetchStatus.UNEXPECTED_HTTP_RESPONSE then
    msg = "Unhandled server response"
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

local function processFlightplanDownloadFailure(httpRequest)
  if httpRequest.errorCode == HttpDownloadErrors.INTERNAL_SERVER_ERROR then CurrentSimbriefFlightplanFetchStatus = SimbriefFlightplanFetchStatus.UNEXPECTED_HTTP_RESPONSE_STATUS
  elseif httpRequest.errorCode == HttpDownloadErrors.UNHANDLED_RESPONSE then CurrentSimbriefFlightplanFetchStatus = SimbriefFlightplanFetchStatus.UNEXPECTED_HTTP_RESPONSE
  elseif httpRequest.errorCode == HttpDownloadErrors.NETWORK then CurrentSimbriefFlightplanFetchStatus = SimbriefFlightplanFetchStatus.NETWORK_ERROR
  else CurrentSimbriefFlightplanFetchStatus = SimbriefFlightplanFetchStatus.UNKNOWN_DOWNLOAD_ERROR end
end

local function processNewFlightplan(httpRequest)
  if httpRequest.httpStatusCode ~= 200 and httpRequest.httpStatusCode ~= 400 then
    CurrentSimbriefFlightplanFetchStatus = SimbriefFlightplanFetchStatus.UNEXPECTED_HTTP_RESPONSE_STATUS
  else
    local parser = xml2lua.parser(simbriefFlightplanXmlHandler)
    parser:parse(httpRequest.responseBody)
    if httpRequest.httpStatusCode == 200 and simbriefFlightplanXmlHandler.root.OFP.fetch.status == "Success" then
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
        
        local filesDirectory = SimbriefFlightplan.files.directory
        local fileTypesAndNames = { [SimbriefFlightplan.files.pdf.name] = SimbriefFlightplan.files.pdf.link }
        for i = 1, #SimbriefFlightplan.files.file do
          local name = SimbriefFlightplan.files.file[i].name
          local link = SimbriefFlightplan.files.file[i].link
          fileTypesAndNames[name] = link
        end
        
        CurrentSimbriefFlightplanFetchStatus = SimbriefFlightplanFetchStatus.NO_ERROR
        
        downloadedFlightPlansFileName = ("%s_%s-%s"):format(os.date("%Y%m%d_%H%M%S"), FlightplanOriginIcao, FlightplanDestIcao)
        runFlightPlanDownloadForNewFlightPlan(FlightplanId, filesDirectory, fileTypesAndNames, downloadedFlightPlansFileName)
      end
    else
      logMsg("Flight plan states that it's not valid. Reported status: " .. simbriefFlightplanXmlHandler.root.OFP.fetch.status)
      
      -- As of 10/2020, original message is <status>Error: Unknown UserID</status>
      if httpRequest.httpStatusCode == 400 and simbriefFlightplanXmlHandler.root.OFP.fetch.status:lower():find('unknown userid') then
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

local function refreshFlightplanNow()
  copas.addthread(function()
    CurrentSimbriefFlightplanFetchStatus = SimbriefFlightplanFetchStatus.DOWNLOADING
    if getConfiguredSimbriefUserName() ~= nil then
      local url = "http://www.simbrief.com/api/xml.fetcher.php?username=" .. getConfiguredSimbriefUserName()
      performDefaultHttpGetRequest(url, processNewFlightplan, processFlightplanDownloadFailure)
    else
      logMsg("Not fetching flight plan. No simbrief username configured.")
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
  UNEXPECTED_HTTP_RESPONSE = { level = VatsimDataFetchStatusLevel.SYSTEM_RELATED },
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
  elseif CurrentVatsimDataFetchStatus == VatsimDataFetchStatus.UNEXPECTED_HTTP_RESPONSE then
    msg = "Unhandled server response"
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

local function processVatsimDataDownloadFailure(httpRequest)
  if httpRequest.errorCode == HttpDownloadErrors.INTERNAL_SERVER_ERROR then CurrentVatsimDataFetchStatus = VatsimDataFetchStatus.UNEXPECTED_HTTP_RESPONSE_STATUS
  elseif httpRequest.errorCode == HttpDownloadErrors.UNHANDLED_RESPONSE then CurrentVatsimDataFetchStatus = VatsimDataFetchStatus.UNEXPECTED_HTTP_RESPONSE
  elseif httpRequest.errorCode == HttpDownloadErrors.NETWORK then CurrentVatsimDataFetchStatus = VatsimDataFetchStatus.NETWORK_ERROR
  else CurrentVatsimDataFetchStatus = VatsimDataFetchStatus.UNKNOWN_DOWNLOAD_ERROR end
end

local function processNewVatsimData(httpRequest)
  if httpRequest.httpStatusCode ~= 200 then
    CurrentVatsimDataFetchStatus = VatsimDataFetchStatus.UNEXPECTED_HTTP_RESPONSE_STATUS
  else
    MapAtcIdentifiersToAtcInfo = {}
    local lines = splitStringBySeparator(httpRequest.responseBody, "\n")
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

local FlightplanWindow = {
  KeyWidth = 11, -- If changing this, also change max value length
  MaxValueLengthUntilBreak = 79, -- 90 characters minus keyWidth of 11
  FlightplanWindowValuePaddingLeft = '',
}
FlightplanWindow.FlightplanWindowValuePaddingLeft = string.rep(' ', FlightplanWindow.KeyWidth)

local FlightplanWindowLastRenderedSimbriefFlightplanFetchStatus = CurrentSimbriefFlightplanFetchStatus
local FlightplanWindowFlightplanDownloadStatus = ''
local FlightplanWindowFlightplanDownloadStatusColor = 0

local function createFlightplanTableEntry(name, value)
  return ("%-" .. FlightplanWindow.KeyWidth .. "s%s"):format(name .. ':', value)
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
      FlightplanWindowRoute = wrapStringAtMaxlengthWithPadding(FlightplanWindowRoute, FlightplanWindow.MaxValueLengthUntilBreak, FlightplanWindow.FlightplanWindowValuePaddingLeft)
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
      
      FlightplanWindowFuel = ("BLOCK=%d%s T/O=%d%s ALTN=%d%s RESERVE=%d%s"):format(
        FlightplanBlockFuel, FlightplanUnit,
        FlightplanTakeoffFuel, FlightplanUnit,
        FlightplanAltFuel, FlightplanUnit,
        FlightplanReserveFuel, FlightplanUnit)
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
      
      FlightplanWindowMetars = ("%s\n%s%s"):format(FlightplanOriginMetar, FlightplanWindow.FlightplanWindowValuePaddingLeft, FlightplanDestMetar)
      if stringIsNotEmpty(FlightplanAltIcao) then
        FlightplanWindowMetars = FlightplanWindowMetars .. ("\n%s%s"):format(FlightplanWindow.FlightplanWindowValuePaddingLeft, FlightplanAltMetar)
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
	vatsimbriefHelperFlightplanWindow = float_wnd_create(650, 210, 1, true)
	float_wnd_set_title(vatsimbriefHelperFlightplanWindow, "Vatsimbrief Helper Flight Plan")
	float_wnd_set_imgui_builder(vatsimbriefHelperFlightplanWindow, "buildVatsimbriefHelperFlightplanWindowCanvas")
	float_wnd_set_onclose(vatsimbriefHelperFlightplanWindow, "destroyVatsimbriefHelperFlightplanWindow")
end

add_macro("Vatsimbrief Helper Flight Plan", "createVatsimbriefHelperFlightplanWindow()", "destroyVatsimbriefHelperFlightplanWindow()", "activate")

--
-- ATC UI handling
--

local AtcWindow = {
  WidthInCharacters = 63
}

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
          local location = { FlightplanOriginIcao, FlightplanDestIcao }
          local frequencies = { renderAirportAtcToString(FlightplanOriginIcao, FlightplanOriginIata), renderAirportAtcToString(FlightplanDestIcao, FlightplanDestIata) }
          if stringIsNotEmpty(FlightplanAltIcao) then
            table.insert(location, FlightplanAltIcao)
            table.insert(frequencies, renderAirportAtcToString(FlightplanAltIcao, FlightplanAltIata))
          end
          local maxKeyLength = 0
          for i = 1, #location do if string.len(location[i]) > maxKeyLength then maxKeyLength = string.len(location[i]) end end
          local separatorBetweenLocationAndFrequencies = ": "
          maxKeyLength = maxKeyLength + string.len(separatorBetweenLocationAndFrequencies)
          local padding = string.rep(' ', maxKeyLength)
          local maxValueLength = AtcWindow.WidthInCharacters - maxKeyLength
          
          Atcs = ''
          for i = 1, #location do
            Atcs = Atcs .. ("%s%s%s\n"):format(location[i], separatorBetweenLocationAndFrequencies, wrapStringAtMaxlengthWithPadding(frequencies[i], maxValueLength, padding))
          end
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

function updateAtcWindowTitle()
  if vatsimbriefHelperAtcWindow ~= nil then
    float_wnd_set_title(vatsimbriefHelperAtcWindow, ("Vatsimbrief Helper ATC (%s)"):format(os.date("%H%MZ")))
  end
end

do_sometimes("updateAtcWindowTitle()")

function destroyVatsimbriefHelperAtcWindow()
	if vatsimbriefHelperAtcWindow then
		float_wnd_destroy(vatsimbriefHelperAtcWindow)
    vatsimbriefHelperAtcWindow = nil
	end
end

function createVatsimbriefHelperAtcWindow()
  tryVatsimbriefHelperInit()
	vatsimbriefHelperAtcWindow = float_wnd_create(560, 90, 1, true)
	updateAtcWindowTitle()
	float_wnd_set_imgui_builder(vatsimbriefHelperAtcWindow, "buildVatsimbriefHelperAtcWindowCanvas")
	float_wnd_set_onclose(vatsimbriefHelperAtcWindow, "destroyVatsimbriefHelperAtcWindow")
end

add_macro("Vatsimbrief Helper ATC", "createVatsimbriefHelperAtcWindow()", "destroyVatsimbriefHelperAtcWindow()", "activate")

--
-- Control UI handling
--

local inputUserName = ""
local MENU_ITEM_OVERVIEW = 0
local MENU_ITEM_FLIGHTPLAN_DOWNLOAD = 1
local menuItem = MENU_ITEM_OVERVIEW

local MainMenuOptions = {
  ["General"] = MENU_ITEM_OVERVIEW,
  ["Flightplan Download"] = MENU_ITEM_FLIGHTPLAN_DOWNLOAD
}

function buildVatsimbriefHelperControlWindowCanvas()
	imgui.SetWindowFontScale(1.5)
  
  -- Main menu
  local currentMenuItem = menuItem -- We get into race conditions when not copying before changing
  local i = 1
  for label, id in pairs(MainMenuOptions) do
    if i > 1 then imgui.SameLine() end
    local isCurrentMenuItem = id == currentMenuItem
    if isCurrentMenuItem then imgui.PushStyleColor(imgui.constant.Col.Button, 0xFFFA9642) end
    imgui.PushID(i)
    if imgui.Button(label) then
      menuItem = id
    end
    imgui.PopID()
    if isCurrentMenuItem then imgui.PopStyleColor() end
    i = i + 1
  end
  imgui.Separator()
  
  -- Simbrief user name is so important for us that we want to show it very prominently in case user attention is required
  local userNameInvalid = CurrentSimbriefFlightplanFetchStatus == SimbriefFlightplanFetchStatus
    or INVALID_USER_NAME or CurrentSimbriefFlightplanFetchStatus == SimbriefFlightplanFetchStatus.NO_SIMBRIEF_USER_ID_ENTERED
  if menuItem == MENU_ITEM_OVERVIEW or userNameInvalid then -- Always show setting when there's something wrong with the user name
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
      setConfiguredUserName(inputUserName)
      saveConfiguration()
      clearFlightplan()
      refreshFlightplanNow()
      inputUserName = '' -- Clear input line to keep user anonymous (in case he's streaming)
    end
  end
  
  -- Content canvas
  if menuItem == MENU_ITEM_OVERVIEW then
    if imgui.Button("Reload Flight Plan") then
      clearFlightplan()
      refreshFlightplanNow()
    end
    imgui.SameLine()
    if imgui.Button("Reload ATC") then
      clearAtcData()
      refreshVatsimDataNow()
    end
  elseif menuItem == MENU_ITEM_FLIGHTPLAN_DOWNLOAD then
    if FlightplanId == nil then
      imgui.TextUnformatted("Waiting for a flight plan ...")
    else
      imgui.TextUnformatted("Please mark the flight plan types that you want to be downloaded.\nDestination folder: " .. FlightplanDownloadDirectory)
      local changed, newVal = imgui.Checkbox("Remove recent flight plans from disk when fetching new ones", getConfiguredDeleteOldFlightPlansSetting())
      if changed then
        setConfiguredDeleteOldFlightPlansSetting(newVal)
        saveConfiguration()
        -- deleteDownloadedFlightPlansIfConfigured() -- Better not that fast, without any confirmation
      end
      imgui.TextUnformatted("")
      local fileTypes = getFlightplanFileTypesArray()
      for i = 1, #fileTypes do
        if i > 1 and i % 3 ~= 1 then imgui.SameLine() end
        imgui.PushID(i)
        local state
        local nameWithPadding = string.format("%-25s", fileTypes[i])
        local changed, newVal2 = imgui.Checkbox(nameWithPadding, isFlightplanFileDownloadEnabled(fileTypes[i]))
        if changed then
          setFlightplanFileDownloadEnabled(fileTypes[i], newVal2)
          saveFlightPlanFilesForDownload()
          downloadFlightplans()
        end
        imgui.PopID()
      end
    end
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
    vatsimbriefHelperControlWindow = float_wnd_create(900, 300, 1, true)
    float_wnd_set_title(vatsimbriefHelperControlWindow, "Vatsimbrief Helper Control")
    float_wnd_set_imgui_builder(vatsimbriefHelperControlWindow, "buildVatsimbriefHelperControlWindowCanvas")
    float_wnd_set_onclose(vatsimbriefHelperControlWindow, "destroyVatsimbriefHelperControlWindow")
  end
end

add_macro("Vatsimbrief Helper Control", "createVatsimbriefHelperControlWindow()", "destroyVatsimbriefHelperControlWindow()", "deactivate")
