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
local Globals = require("vatsimbrief-helper.globals")

TRACK_ISSUE("Tech Debt", "Move all the other global things to globals.lua")

local function numberIsNilOrZero(n)
  return n == nil or n == 0
end
local function numberIsNotNilOrZero(n)
  return not numberIsNilOrZero(n)
end
local function trim(s)
  return s:gsub("^%s*(.-)%s*$", "%1")
end
local function stringIsBlank(s)
  return s == nil or s == Globals.emptyString or trim(s) == ""
end
local function stringEndsWith(s, e)
  return Globals.stringIsEmpty(e) or s:sub(-(#e)) == e
end
local function stringStripTrailingCharacters(s, n)
  return s:sub(1, #s - n)
end
local function defaultIfBlank(s, d)
  if s == nil or Globals.stringIsEmpty(trim(s)) then
    return d
  else
    return s
  end
end
local function booleanToYesNo(b)
  if b then
    return "yes"
  else
    return "no"
  end
end

local OsType = {WINDOWS, UNIX_LIKE}
local OS
if package.config:sub(1, 1) == "/" then
  OS = OsType.UNIX_LIKE
else
  OS = OsType.WINDOWS
end

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
    return ""
  end
end

local function wrapStringAtMaxlengthWithPadding(str, maxLength, padding)
  local items = Globals.splitStringBySeparator(str, " ")
  local result = ""
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
  {"copas", "MIT License", "https://github.com/keplerproject/copas"},
  {"luasocket", "MIT License", "http://luaforge.net/projects/luasocket/"},
  {"binaryheap.lua", "MIT License", "https://github.com/Tieske/binaryheap.lua"},
  {"coxpcall", "(Free Software)", "https://github.com/keplerproject/coxpcall"},
  {"timerwheel.lua", "MIT License", "https://github.com/Tieske/timerwheel.lua"},
  -- Configuration handling
  {"LIP - Lua INI Parser", "MIT License", "https://github.com/Dynodzzo/Lua_INI_Parser"},
  -- Simbrief flightplan
  {"xml2lua", "MIT License", "https://github.com/manoelcampos/xml2lua"},
  {
    "Lua Event Bus",
    "MIT License",
    "https://github.com/prabirshrestha/lua-eventbus"
  }
}

for i = 1, #licensesOfDependencies do
  logMsg(
    ("Vatsimbrief Helper using '%s' with license '%s'. Project homepage: %s"):format(
      licensesOfDependencies[i][1],
      licensesOfDependencies[i][2],
      licensesOfDependencies[i][3]
    )
  )
end

-- Track opened windows centrally
local WindowStates = {}
local function trackWindowOpen(windowName, isOpen)
  WindowStates[windowName] = isOpen
end
local function atLeastOneWindowIsOpen()
  for windowName, isOpen in pairs(WindowStates) do
    if isOpen then
      return true
    end
  end
  return false
end

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
-- Configuration handling
--

local LIP = require("LIP")

local Configuration = {
  FilePath = SCRIPT_DIRECTORY .. "vatsimbrief-helper.ini",
  IsDirty = false,
  DumpDirtyConfigTimer = nil,
  File = {}
}

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
  if fileExists(Configuration.FilePath) then
    Configuration.File = LIP.load(Configuration.FilePath)
    logMsg(("Vatsimbrief configuration file '%s' loaded."):format(Configuration.FilePath))
  else
    logMsg(
      ("Vatsimbrief configuration file '%s' missing! Running without configuration settings."):format(
        Configuration.FilePath
      )
    )
  end
end

local function saveConfiguration()
  LIP.save(Configuration.FilePath, Configuration.File)
  Configuration.IsDirty = false
end

local function flagConfigurationDirty()
  Configuration.IsDirty = true
end

Configuration.DumpDirtyConfigTimer =
  timer.new(
  {
    delay = 1, -- Should be at most the amount of time between changing settings and closing the plug in ...
    recurring = true,
    params = {},
    initial_delay = 0,
    callback = function(timer_obj, params)
      if Configuration.IsDirty then
        saveConfiguration()
      end
    end
  }
)

local function setSetting(cat, key, value)
  if Configuration.File[cat] == nil then
    Configuration.File[cat] = {}
  end
  if type(value) == "string" then
    value = trim(value)
  end
  Configuration.File[cat][key] = value
end

local function getSetting(cat, key, defaultValue)
  if Configuration.File[cat] == nil then
    Configuration.File[cat] = {}
  end
  if Configuration.File[cat][key] == nil then
    return defaultValue
  end
  local value = Configuration.File[cat][key]
  if type(value) == "string" then
    value = trim(value)
  end
  return value
end

--- Specific configuration getters/setters

local function setConfiguredUserName(value)
  if Configuration.File.simbrief == nil then
    Configuration.File.simbrief = {}
  end
  Configuration.File.simbrief.username = trim(value)
end

local function getConfiguredSimbriefUserName()
  if Configuration.File.simbrief ~= nil and Globals.stringIsNotEmpty(Configuration.File.simbrief.username) then
    return Configuration.File.simbrief.username
  else
    -- Try to guess
    local altConfigurationFilePath = SCRIPT_DIRECTORY .. "simbrief_helper.ini"
    if fileExists(altConfigurationFilePath) then
      local altConfiguration = LIP.load(altConfigurationFilePath)
      if altConfiguration.simbrief ~= nil and Globals.stringIsNotEmpty(altConfiguration.simbrief.username) then
        local importedUsername = altConfiguration.simbrief.username
        setConfiguredUserName(importedUsername)
        saveConfiguration()
        logMsg(
          "Imported simbrief username '" ..
            importedUsername .. "' from configuration file '" .. altConfigurationFilePath .. "'"
        )
        return importedUsername
      end
    end
  end
  return ""
end

local function getConfiguredFlightPlanDownloads()
  local types = {}
  local destFolders = {}
  local destFileNames = {}
  if Configuration.File.flightplan ~= nil then
    local i = 1
    while true do
      local nextItem = Configuration.File.flightplan["flightPlanTypesForDownload" .. i .. "TypeName"]
      if nextItem == nil then
        break
      end
      table.insert(types, nextItem)
      local destFolder = Configuration.File.flightplan["flightPlanTypesForDownload" .. i .. "DestFolder"]
      if destFolder ~= nil then
        destFolders[nextItem] = destFolder
      end
      local destFileName = Configuration.File.flightplan["flightPlanTypesForDownload" .. i .. "DestFileName"]
      if destFileName ~= nil then
        destFileNames[nextItem] = destFileName
      end
      i = i + 1
    end
  end
  return types, destFolders, destFileNames
end

local function setConfiguredFlightPlanDownloads(enabledTypes, mapTypesToDestFolder, mapTypesToDestFileName)
  if Configuration.File.flightplan == nil then
    Configuration.File.flightplan = {}
  end

  -- Remove previous entries
  for k, v in pairs(Configuration.File.flightplan) do
    if k:find("flightPlanTypesForDownload") == 1 then
      Configuration.File.flightplan[k] = nil
    end
  end

  -- Add current entries
  for i = 1, #enabledTypes do
    Configuration.File.flightplan["flightPlanTypesForDownload" .. i .. "TypeName"] = enabledTypes[i]
    if mapTypesToDestFolder[enabledTypes[i]] ~= nil then
      Configuration.File.flightplan["flightPlanTypesForDownload" .. i .. "DestFolder"] =
        mapTypesToDestFolder[enabledTypes[i]]
    end
    if mapTypesToDestFileName[enabledTypes[i]] ~= nil then
      Configuration.File.flightplan["flightPlanTypesForDownload" .. i .. "DestFileName"] =
        mapTypesToDestFileName[enabledTypes[i]]
    end
  end
end

local function setConfiguredDeleteOldFlightPlansSetting(value)
  if Configuration.File.flightplan == nil then
    Configuration.File.flightplan = {}
  end
  local strValue
  if value then
    strValue = "yes"
  else
    strValue = "no"
  end
  Configuration.File.flightplan.deleteDownloadedFlightPlans = strValue
end

local function getConfiguredDeleteOldFlightPlansSetting()
  -- Unless it's clearly a YES, do NOT return to delete anything! Also in case the removal crashes on the system. We don't want that.

  if Configuration.File.flightplan == nil then
    Configuration.File.flightplan = {}
  end
  if Configuration.File.flightplan.deleteDownloadedFlightPlans == nil then
    return false
  end
  if trim(Configuration.File.flightplan.deleteDownloadedFlightPlans) == "yes" then
    return true
  else
    return false
  end
end

local function setConfiguredAutoRefreshAtcSetting(value)
  if Configuration.File.atc == nil then
    Configuration.File.atc = {}
  end
  local strValue
  if value then
    strValue = "yes"
  else
    strValue = "no"
  end
  Configuration.File.atc.autoRefresh = strValue
end

local function getConfiguredAutoRefreshAtcSettingDefaultTrue()
  local defaultValue = true
  if Configuration.File.atc == nil then
    Configuration.File.atc = {}
  end
  if Configuration.File.atc.autoRefresh == nil then
    return defaultValue
  end
  if trim(Configuration.File.atc.autoRefresh) == "yes" then
    return true
  elseif trim(Configuration.File.atc.autoRefresh) == "no" then
    return false
  else
    return defaultValue
  end
end

local function setConfiguredAutoRefreshFlightPlanSetting(value)
  if Configuration.File.flightplan == nil then
    Configuration.File.flightplan = {}
  end
  local strValue
  if value then
    strValue = "yes"
  else
    strValue = "no"
  end
  Configuration.File.flightplan.autoRefresh = strValue
end

local function getConfiguredAutoRefreshFlightPlanSettingDefaultFalse()
  local defaultValue = false
  if Configuration.File.flightplan == nil then
    Configuration.File.flightplan = {}
  end
  if Configuration.File.flightplan.autoRefresh == nil then
    return defaultValue
  end
  if trim(Configuration.File.flightplan.autoRefresh) == "yes" then
    return true
  elseif trim(Configuration.File.flightplan.autoRefresh) == "no" then
    return false
  else
    return defaultValue
  end
end

local function setConfiguredAtcWindowVisibility(value)
  if Configuration.File.atc == nil then
    Configuration.File.atc = {}
  end
  local strValue
  if value then
    strValue = "visible"
  else
    strValue = "hidden"
  end
  Configuration.File.atc.windowVisibility = strValue
end

local function getConfiguredAtcWindowVisibilityDefaultTrue()
  local defaultValue = true
  if Configuration.File.atc == nil then
    Configuration.File.atc = {}
  end
  if Configuration.File.atc.windowVisibility == nil then
    return defaultValue
  end
  if trim(Configuration.File.atc.windowVisibility) == "visible" then
    return true
  elseif trim(Configuration.File.atc.windowVisibility) == "hidden" then
    return false
  else
    return defaultValue
  end
end

local function setConfiguredFlightPlanWindowVisibility(value)
  if Configuration.File.flightplan == nil then
    Configuration.File.flightplan = {}
  end
  local strValue
  if value then
    strValue = "visible"
  else
    strValue = "hidden"
  end
  Configuration.File.flightplan.windowVisibility = strValue
end

local function getConfiguredFlightPlanWindowVisibility(defaultValue)
  if Configuration.File.flightplan == nil then
    Configuration.File.flightplan = {}
  end
  if Configuration.File.flightplan.windowVisibility == nil then
    return defaultValue
  end
  if trim(Configuration.File.flightplan.windowVisibility) == "visible" then
    return true
  elseif trim(Configuration.File.flightplan.windowVisibility) == "hidden" then
    return false
  else
    return defaultValue
  end
end

local function setConfiguredFlightPlanFontScaleSetting(value)
  if Configuration.File.flightplan == nil then
    Configuration.File.flightplan = {}
  end
  Configuration.File.flightplan.fontScale = string.format("%f", value)
end

local function getConfiguredFlightPlanFontScaleSettingDefault1()
  local defaultValue = 1.0
  if Configuration.File.flightplan == nil then
    Configuration.File.flightplan = {}
  end
  if Configuration.File.flightplan.fontScale == nil then
    return defaultValue
  end
  local number = tonumber(Configuration.File.flightplan.fontScale)
  if number == nil then
    return defaultValue
  else
    return number
  end
end

local function setConfiguredAtcFontScaleSetting(value)
  if Configuration.File.atc == nil then
    Configuration.File.atc = {}
  end
  Configuration.File.atc.fontScale = string.format("%f", value)
end

local function getConfiguredAtcFontScaleSettingDefault1()
  local defaultValue = 1.0
  if Configuration.File.atc == nil then
    Configuration.File.atc = {}
  end
  if Configuration.File.atc.fontScale == nil then
    return defaultValue
  end
  local number = tonumber(Configuration.File.atc.fontScale)
  if number == nil then
    return defaultValue
  else
    return number
  end
end

loadConfiguration() -- Initially load configuration synchronously so it's present below this line

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

  if
    type(content) ~= "string" or type(code) ~= "number" or type(headers) ~= "table" or type(status) ~= "string" or
      code == 404 or
      code == 500
   then
    logMsg(("Request URL: %s, FAILURE: Status = %s, code = %s"):format(url, status, code))
    errorCallback({errorCode = HttpDownloadErrors.NETWORK, userData = userData})
  else
    logMsg(
      ("Request URL: %s, duration: %.2fs, response status: %s, response length: %d bytes"):format(
        url,
        os.clock() - t0,
        status,
        #content
      )
    )
    --

    TRACK_ISSUE(
      "Tech Debt",
      MULTILINE_TEXT(
        "We tried to enable the library for HTTP redirects this way. However, we don't get out of http.request() w/o error:",
        "Request URL: http://www.simbrief.com/ofp/flightplans/EDDNEDDL_WAE_1601924120.rte,",
        "FAILURE: Status = nil, code = host or service not provided, or not known"
      ),
      "Treat everything below 500 as an error for now."
    )
    --[[ 
      
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
    ]] if
      code < 500
     then
      table.insert(
        SyncTasksAfterAsyncTasks,
        {callback = resultCallback, params = {responseBody = content, httpStatusCode = code, userData = userData}}
      )
    else
      errorCallback({errorCode = HttpDownloadErrors.INTERNAL_SERVER_ERROR, userData = userData})
    end
  end
end

local function windowVisibilityToInitialMacroState(humanReadableWindowIdentifier, windowIsVisible)
  if windowIsVisible then
    logMsg("Initially showing window '" .. humanReadableWindowIdentifier .. "'")
    return "activate"
  else
    return "deactivate"
  end
end

--
-- Download of Simbrief flight plans
--

local FlightPlanDownload = {
  WasTargetDirectoryCreated = false,
  -- Constants
  Directory = nil,
  RetryAfterSecs = nil,
  FilesForFlightplanId = "",
  FilesBaseUrl = "", -- Base URL for download, e.g. "http://www.simbrief.com/ofp/flightplans/"
  FileTypes = {}, -- Ordered array of types
  FileTypesAndNames = {}, -- Hash: Type to file name on server
  -- User config
  IsDownloadOfTypeEnabled = {}, -- FileType to "true" (enable download) or "false" (disable download)
  MapTypeToDestFolder = {},
  MapTypeToDestFileName = {},
  -- Download state
  MapTypeToDownloadedFileName = {}, -- When download complete
  SetOfDownloadingTypes = {}, -- When currently downloading, type name maps to "something"
  MapTypeToAttemptTimestamp = {} -- Type name maps to timestamp of last attempt
}

local FlightPlanDataForDownloadFileNames = {
  o = nil, -- Origin ICAO
  d = nil, -- Dest ICAO
  a = nil, -- Date
  t = nil -- Time
}

-- Init Constants
FlightPlanDownload.Directory = formatPathOsSpecific(SCRIPT_DIRECTORY .. "flight-plans" .. PATH_DELIMITER)
FlightPlanDownload.RetryAfterSecs = 120.0 -- MUST be float to pass printf("%f", this)
-- Load User config
local tmp, tmp2, tmp3 = getConfiguredFlightPlanDownloads()
for i = 1, #tmp do
  FlightPlanDownload.IsDownloadOfTypeEnabled[tmp[i]] = true
end
FlightPlanDownload.MapTypeToDestFolder = tmp2 -- When assigning directly, it gave some "redeclaration" warning... !?
FlightPlanDownload.MapTypeToDestFileName = tmp3 -- When assigning directly, it gave some "redeclaration" warning... !?

local function initConversionOfConfiguredDestFileNames(originIcao, destIcao)
  FlightPlanDataForDownloadFileNames.o = originIcao
  FlightPlanDataForDownloadFileNames.d = destIcao
  local t = os.time()
  FlightPlanDataForDownloadFileNames.a = os.date("%Y%m%d", t)
  FlightPlanDataForDownloadFileNames.t = os.date("%H%M%S", t)
end

local function resolveDestFileNamePlaceholder(placeholder)
  local c = placeholder:sub(2) -- Remove leading '%'
  if FlightPlanDataForDownloadFileNames[c] ~= nil then
    return FlightPlanDataForDownloadFileNames[c]
  else
    return placeholder -- Identity replacement leaves original string unchanged
  end
end

local function resolveConfiguredDestFileName(configuredDestFileName)
  return string.gsub(configuredDestFileName, "%%%a", resolveDestFileNamePlaceholder)
end

local function scanDirectoryForFilesOnUnixLikeOs(directory)
  if direcory:find("'") ~= nil then
    return nil
  end -- It's stated that the procedure does not work in this case
  local t = {}
  local pfile = assert(io.popen(("find '%s' -maxdepth 1 -print0 -type f"):format(directory), "r"))
  local list = pfile:read("*a")
  pfile:close()
  for f in s:gmatch("[^\0]+") do
    table.insert(t, f)
  end
  return t
end

local function scanDirectoryForFilesOnWindowsOs(directory)
  local t = {}
  for f in io.popen([[dir "]] .. directory .. [[" /b]]):lines() do
    table.insert(t, f)
  end
  return t
end

local function listDownloadedFlightPlans()
  local filenames
  if OS == OsType.WINDOWS then
    filenames = scanDirectoryForFilesOnWindowsOs(FlightPlanDownload.Directory)
  else -- OsType.UNIX_LIKE
    filenames = scanDirectoryForFilesOnUnixLikeOs(FlightPlanDownload.Directory)
  end
  if filenames == nil then
    return nil
  end
  for i = 1, #filenames do
    filenames[i] = FlightPlanDownload.Directory .. filenames[i]
  end
  return filenames
end

local function deleteDownloadedFlightPlansIfConfigured()
  if getConfiguredDeleteOldFlightPlansSetting() then
    local fileNames = listDownloadedFlightPlans()
    if fileNames == nil then
      logMsg("Failed to list flight plan files.")
    else
      logMsg("Attempting to delete " .. #fileNames .. " recent flight plan files")

      TRACK_ISSUE(
        "Tech Debt",
        "The listDirectory() implementation is very sloppy.",
        "In case it fails, disable the flight plan removal such that we don't crash again next time we're launched."
      )
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

local function pathWithSlash(path)
  local lastChar = path:sub(string.len(path))
  if lastChar == "/" or lastChar == "\\" then
    return path
  end
  return path .. PATH_DELIMITER
end

function processFlightPlanFileDownloadSuccess(httpRequest)
  local typeName = httpRequest.userData.typeName
  if httpRequest.userData.flightPlanId ~= FlightPlanDownload.FilesForFlightplanId then
    logMsg(
      "Discarding downloaded file of type '" ..
        httpRequest.userData.typeName ..
          "' for flight plan '" .. httpRequest.userData.flightPlanId .. "' as there's a new flight plan"
    )
  else
    local destDir
    if FlightPlanDownload.MapTypeToDestFolder[typeName] ~= nil then
      destDir = FlightPlanDownload.MapTypeToDestFolder[typeName]
    else
      destDir = FlightPlanDownload.Directory
    end

    local fileNameFormat = defaultIfBlank(FlightPlanDownload.MapTypeToDestFileName[typeName], "%a_%t_%o-%d")

    local targetFilePath =
      formatPathOsSpecific(pathWithSlash(destDir)) ..
      resolveConfiguredDestFileName(fileNameFormat) ..
        getExtensionOfFileName(FlightPlanDownload.FileTypesAndNames[typeName])

    local f = io.open(targetFilePath, "wb")
    if io.type(f) ~= "file" then
      logMsg("Failed to write data to file path: " .. targetFilePath)
    else
      f:write(httpRequest.responseBody)
      f:close()
    end
    FlightPlanDownload.MapTypeToDownloadedFileName[typeName] = targetFilePath -- Mark type as downloaded (the file name is the "proof of download" :-)
    FlightPlanDownload.SetOfDownloadingTypes[typeName] = false -- Mark download process as finished

    logMsg(
      ("Download of file of type '%s' to '%s' for flight plan '%s' succeeded after '%.03fs'"):format(
        typeName,
        targetFilePath,
        httpRequest.userData.flightPlanId,
        os.clock() - FlightPlanDownload.MapTypeToAttemptTimestamp[typeName]
      )
    )
  end
end

function processFlightPlanFileDownloadFailure(httpRequest)
  local typeName = httpRequest.userData.typeName
  if httpRequest.userData.flightPlanId ~= FlightPlanDownload.FilesForFlightplanId then
    logMsg(
      "Discarding failure for download of file of type '" ..
        typeName .. "' for flight plan '" .. httpRequest.userData.flightPlanId .. "'"
    )
  else
    logMsg(
      ("Download of file of type '%s' for flight plan '%s' FAILED after '%.03fs' -- reattempting after '%.fs'"):format(
        typeName,
        httpRequest.userData.flightPlanId,
        os.clock() - FlightPlanDownload.MapTypeToAttemptTimestamp[typeName],
        FlightPlanDownload.RetryAfterSecs
      )
    )
    FlightPlanDownload.SetOfDownloadingTypes[typeName] = false
  end
end

function downloadAllFlightplans()
  local now = 0 -- Optimization: Fetch only once, if necessary
  if #FlightPlanDownload.FileTypes > 0 then
    now = os.clock()
  end
  for i = 1, #FlightPlanDownload.FileTypes do -- For all types
    local typeName = FlightPlanDownload.FileTypes[i]
    downloadFlightplan(typeName, now, false)
  end
end

function downloadFlightplan(typeName, now, forceAnotherDownload)
  if now == nil then
    now = os.clock()
  end -- Singular call without timestamp
  if FlightPlanDownload.FilesForFlightplanId ~= nil then -- If there's a flightplan
    if FlightPlanDownload.IsDownloadOfTypeEnabled[typeName] == true then -- And download enabled by config
      if forceAnotherDownload or FlightPlanDownload.MapTypeToDownloadedFileName[typeName] == nil then -- Type not downloaded yet
        if forceAnotherDownload or FlightPlanDownload.SetOfDownloadingTypes[typeName] ~= true then -- And download not already running
          if
            forceAnotherDownload or FlightPlanDownload.MapTypeToAttemptTimestamp[typeName] == nil or -- And download was not attempted yet ...
              FlightPlanDownload.MapTypeToAttemptTimestamp[typeName] < now - FlightPlanDownload.RetryAfterSecs
           then -- ... or needs to be retried
            FlightPlanDownload.MapTypeToAttemptTimestamp[typeName] = now -- Save attempt timestamp for retrying later
            FlightPlanDownload.SetOfDownloadingTypes[typeName] = true -- Set immediately to prevent race conditions leading to multiple downloads launching. However, always remember to turn it off!
            local url = FlightPlanDownload.FilesBaseUrl .. FlightPlanDownload.FileTypesAndNames[typeName]
            logMsg(
              ("Download of file of type '%s' for flight plan '%s' starting"):format(
                typeName,
                FlightPlanDownload.FilesForFlightplanId
              )
            )

            TRACK_ISSUE(
              "Tech Debt",
              MULTILINE_TEXT(
                "We observed that the official URL redirects from www.simbrief.com/ofp/flightplans/<TypeName>",
                "to",
                "http://www.simbrief.com/system/briefing.fmsdl.php?formatget=flightplans/<TypeName>",
                "HTTP 301 Redirects are unfortunately not working with this library. :-(",
                "Temporary Workaround: Keep the final URL in hardcoded for now. Ouch.",
                "That's a ticking time bomb."
              )
            )
            --logMsg("File type of download: " .. FlightPlanDownload.FileTypesAndNames[typeName])
            if getExtensionOfFileName(FlightPlanDownload.FileTypesAndNames[typeName]) ~= ".pdf" then
              url =
                "http://www.simbrief.com/system/briefing.fmsdl.php?formatget=flightplans/" ..
                FlightPlanDownload.FileTypesAndNames[typeName]
            end
            copas.addthread(
              function()
                -- Note that the HTTP call must run in a copas thread, otherwise it will throw errors (something's always nil)
                performDefaultHttpGetRequest(
                  url,
                  processFlightPlanFileDownloadSuccess,
                  processFlightPlanFileDownloadFailure,
                  {typeName = typeName, flightPlanId = FlightPlanDownload.FilesForFlightplanId}
                )
              end
            )
          end
        end
      end
    end
  end
end

-- When a file plane has downloaded and the target path changed, it won't be downloaded as the flight plan actually WAS already downloaded.
-- However, when changing the file name or path for the downloaded file plan, one would expect another download to happen.
function downloadFlightPlanAgain(typeName)
  logMsg("Requesting (another) download of flight plan type '" .. typeName .. "'")
  downloadFlightplan(typeName, os.clock(), true)
end

local function isFlightplanFileDownloadEnabled(typeName)
  -- Note: Implement in at least O(log #TypeNames) as this method is called each frame during rendering of the configuration window
  return FlightPlanDownload.IsDownloadOfTypeEnabled[typeName] == true
end

local function setFlightplanFileDownloadEnabled(typeName, value)
  if type(FlightPlanDownload.IsDownloadOfTypeEnabled[typeName]) == "boolean" then -- Means, type is valid
    local stringValue
    if value then
      stringValue = "true"
    else
      stringValue = "false"
    end
    logMsg(("Set flight plan file download for type '%s' to '%s'"):format(typeName, stringValue))

    FlightPlanDownload.IsDownloadOfTypeEnabled[typeName] = value
  end
end

local function getFlightPlanDownloadDirectory(typeName)
  return FlightPlanDownload.MapTypeToDestFolder[typeName]
end

local function setFlightPlanDownloadDirectory(typeName, value)
  FlightPlanDownload.MapTypeToDestFolder[typeName] = value
  logMsg(("Set flight plan download directory for type '%s' to '%s'"):format(typeName, value))
end

local function getFlightPlanDownloadFileName(typeName)
  return FlightPlanDownload.MapTypeToDestFileName[typeName]
end

local function setFlightPlanDownloadFileName(typeName, value)
  FlightPlanDownload.MapTypeToDestFileName[typeName] = value
  logMsg(("Set flight plan download file name for type '%s' to '%s'"):format(typeName, value))
end

local function saveFlightPlanFilesForDownload()
  local enabledFileTypes = {}
  for fileType, downloadEnabled in pairs(FlightPlanDownload.IsDownloadOfTypeEnabled) do
    if downloadEnabled then
      logMsg(("Flight plan download for type '%s' enabled: '%s'"):format(fileType, booleanToYesNo(downloadEnabled)))
      table.insert(enabledFileTypes, fileType)
    end
  end
  setConfiguredFlightPlanDownloads(
    enabledFileTypes,
    FlightPlanDownload.MapTypeToDestFolder,
    FlightPlanDownload.MapTypeToDestFileName
  )
  saveConfiguration()
end

local function restartFlightPlanDownloads(flightPlanId, baseUrlForDownload, fileTypesAndNames)
  -- Store flightplan specific download information
  FlightPlanDownload.FilesForFlightplanId = flightPlanId
  FlightPlanDownload.FilesBaseUrl = baseUrlForDownload
  if not stringEndsWith(FlightPlanDownload.FilesBaseUrl, "/") then
    FlightPlanDownload.FilesBaseUrl = FlightPlanDownload.FilesBaseUrl .. "/"
  end
  FlightPlanDownload.FileTypesAndNames = fileTypesAndNames
  FlightPlanDownload.FileTypes = {}
  for fileType, fileName in pairs(fileTypesAndNames) do
    table.insert(FlightPlanDownload.FileTypes, fileType)
  end

  -- Update config: Add new types from the flight plan and remove those that disappeared from the flight plan for some reason...
  local configNew = {}
  for fileType, fileName in pairs(fileTypesAndNames) do
    configNew[fileType] = isFlightplanFileDownloadEnabled(fileType)
  end
  FlightPlanDownload.IsDownloadOfTypeEnabled = configNew

  -- Invalidate old flightplans in memory
  FlightPlanDownload.MapTypeToDownloadedFileName = {}
  FlightPlanDownload.SetOfDownloadingTypes = {}
  FlightPlanDownload.MapTypeToAttemptTimestamp = {}

  -- Create target directory of downloaded flight plans
  if FlightPlanDownload.WasTargetDirectoryCreated == false then
    -- Seems to open a console window (at least under windows) - make sure it only runs once
    os.execute("mkdir " .. FlightPlanDownload.Directory)
    FlightPlanDownload.WasTargetDirectoryCreated = true
  end

  -- Invalidate old flightplans on disk
  deleteDownloadedFlightPlansIfConfigured()
end

local function getFlightplanFileTypesArray()
  return FlightPlanDownload.FileTypes
end

do_sometimes("downloadAllFlightplans()")

--
-- Simbrief flight plans
--

local function removeLinebreaksFromString(s)
  return string.gsub(s, "\n", " ")
end

local xml2lua = require("xml2lua")
local simbriefFlightplanXmlHandler = require("xmlhandler.tree")

local SimbriefFlightplan = {}

local FlightplanId = nil -- PK to spot that a file plan changed

FlightPlan = {
  AirlineIcao = "",
  FlightNumber = 0
}

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

local FlightplanEstOut = 0
local FlightplanEstOff = 0
local FlightplanEstOn = 0
local FlightplanEstIn = 0
local FlightplanEstBlock = 0
local FlightplanEstAir = 0

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
  NO_DOWNLOAD_ATTEMPTED = {level = SimbriefFlightplanFetchStatusLevel.INFO},
  DOWNLOADING = {level = SimbriefFlightplanFetchStatusLevel.INFO},
  NO_ERROR = {level = SimbriefFlightplanFetchStatusLevel.INFO},
  UNKNOWN_DOWNLOAD_ERROR = {level = SimbriefFlightplanFetchStatusLevel.SYSTEM_RELATED},
  UNEXPECTED_HTTP_RESPONSE_STATUS = {level = SimbriefFlightplanFetchStatusLevel.SYSTEM_RELATED},
  UNEXPECTED_HTTP_RESPONSE = {level = SimbriefFlightplanFetchStatusLevel.SYSTEM_RELATED},
  NETWORK_ERROR = {level = SimbriefFlightplanFetchStatusLevel.SYSTEM_RELATED},
  INVALID_USER_NAME = {level = SimbriefFlightplanFetchStatusLevel.USER_RELATED},
  NO_FLIGHT_PLAN_CREATED = {level = SimbriefFlightplanFetchStatusLevel.USER_RELATED},
  UNKNOWN_ERROR_STATUS_RESPONSE_PAYLOAD = {level = SimbriefFlightplanFetchStatusLevel.SYSTEM_RELATED},
  NO_SIMBRIEF_USER_ID_ENTERED = {level = SimbriefFlightplanFetchStatusLevel.SYSTEM_RELATED}
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
  msg = "Could not download flight plan from Simbrief:\n" .. msg .. "."

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
  if httpRequest.errorCode == HttpDownloadErrors.INTERNAL_SERVER_ERROR then
    CurrentSimbriefFlightplanFetchStatus = SimbriefFlightplanFetchStatus.UNEXPECTED_HTTP_RESPONSE_STATUS
  elseif httpRequest.errorCode == HttpDownloadErrors.UNHANDLED_RESPONSE then
    CurrentSimbriefFlightplanFetchStatus = SimbriefFlightplanFetchStatus.UNEXPECTED_HTTP_RESPONSE
  elseif httpRequest.errorCode == HttpDownloadErrors.NETWORK then
    CurrentSimbriefFlightplanFetchStatus = SimbriefFlightplanFetchStatus.NETWORK_ERROR
  else
    CurrentSimbriefFlightplanFetchStatus = SimbriefFlightplanFetchStatus.UNKNOWN_DOWNLOAD_ERROR
  end
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

        FlightPlan.FlightNumber = SimbriefFlightplan.general.flight_number
        FlightPlan.AirlineIcao = SimbriefFlightplan.general.icao_airline

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
        if Globals.stringIsEmpty(FlightplanRoute) then
          FlightplanRoute = "(none)"
        end
        FlightplanAltRoute = SimbriefFlightplan.alternate.route
        if Globals.stringIsEmpty(FlightplanAltRoute) then
          FlightplanAltRoute = "(none)"
        end

        FlightplanEstOut = tonumber(SimbriefFlightplan.times.est_out)
        FlightplanEstOff = tonumber(SimbriefFlightplan.times.est_off)
        FlightplanEstOn = tonumber(SimbriefFlightplan.times.est_on)
        FlightplanEstIn = tonumber(SimbriefFlightplan.times.est_in)
        FlightplanEstBlock = tonumber(SimbriefFlightplan.times.est_block)
        FlightplanEstEnroute = tonumber(SimbriefFlightplan.times.est_time_enroute)

        -- TOC waypoint is identified by "TOC"
        -- It seems flightplans w/o route are also possible to create.
        local haveToc = false
        if SimbriefFlightplan.navlog ~= nil and SimbriefFlightplan.navlog.fix ~= nil then
          local indexOfToc = 1
          while indexOfToc <= #SimbriefFlightplan.navlog.fix and
            SimbriefFlightplan.navlog.fix[indexOfToc].ident ~= "TOC" do
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
          FlightplanAltMetar = ""
        end

        FlightplanAvgWindDir = tonumber(SimbriefFlightplan.general.avg_wind_dir)
        FlightplanAvgWindSpeed = tonumber(SimbriefFlightplan.general.avg_wind_spd)

        local filesDirectory = SimbriefFlightplan.files.directory
        local fileTypesAndNames = {[SimbriefFlightplan.files.pdf.name] = SimbriefFlightplan.files.pdf.link}
        for i = 1, #SimbriefFlightplan.files.file do
          local name = SimbriefFlightplan.files.file[i].name
          local link = SimbriefFlightplan.files.file[i].link
          fileTypesAndNames[name] = link
        end

        CurrentSimbriefFlightplanFetchStatus = SimbriefFlightplanFetchStatus.NO_ERROR

        initConversionOfConfiguredDestFileNames(FlightplanOriginIcao, FlightplanDestIcao)
        restartFlightPlanDownloads(FlightplanId, filesDirectory, fileTypesAndNames)
      end
    else
      logMsg(
        "Flight plan states that it's not valid. Reported status: " ..
          simbriefFlightplanXmlHandler.root.OFP.fetch.status
      )

      -- As of 10/2020, original message is <status>Error: Unknown UserID</status>
      if
        httpRequest.httpStatusCode == 400 and
          simbriefFlightplanXmlHandler.root.OFP.fetch.status:lower():find("unknown userid")
       then
        CurrentSimbriefFlightplanFetchStatus = SimbriefFlightplanFetchStatus.INVALID_USER_NAME
      elseif simbriefFlightplanXmlHandler.root.OFP.fetch.status:lower():find("no flight plan") then
        CurrentSimbriefFlightplanFetchStatus = SimbriefFlightplanFetchStatus.NO_FLIGHT_PLAN_CREATED
      else
        CurrentSimbriefFlightplanFetchStatus = SimbriefFlightplanFetchStatus.UNKNOWN_ERROR_STATUS_RESPONSE_PAYLOAD
      end
    end

    -- Display configuration window if there's something wrong with the user name
    if CurrentSimbriefFlightplanFetchStatus == SimbriefFlightplanFetchStatus.INVALID_USER_NAME then
      createVatsimbriefHelperControlWindow()
    end
  end
end

local function clearFlightplan()
  FlightplanId = nil
end

local function refreshFlightplanNow()
  copas.addthread(
    function()
      CurrentSimbriefFlightplanFetchStatus = SimbriefFlightplanFetchStatus.DOWNLOADING
      if Globals.stringIsNotEmpty(getConfiguredSimbriefUserName()) then
        local url = "http://www.simbrief.com/api/xml.fetcher.php?username=" .. getConfiguredSimbriefUserName()
        performDefaultHttpGetRequest(url, processNewFlightplan, processFlightplanDownloadFailure)
      else
        logMsg("Not fetching flight plan. No simbrief username configured.")
        CurrentSimbriefFlightplanFetchStatus = SimbriefFlightplanFetchStatus.NO_SIMBRIEF_USER_ID_ENTERED

        -- Display configuration window if there's something wrong with the user name
        createVatsimbriefHelperControlWindow()
      end
    end
  )
end

local refreshFlightplanTimer =
  timer.new(
  {
    delay = 60, -- Should be more than enough
    recurring = true,
    params = {},
    initial_delay = 0, -- Make sure we have information asap
    -- Usually, the user will have his username configured and flightplan already armed
    callback = function(timer_obj, params)
      if getConfiguredAutoRefreshFlightPlanSettingDefaultFalse() then
        refreshFlightplanNow()
      end
    end
  }
)

--
-- VATSIM data
--

local Datarefs = require("vatsimbrief-helper.state.datarefs")
local VatsimDataContainer = require("vatsimbrief-helper.components.vatsim_data_container")
local VatsimData = require("vatsimbrief-helper.state.vatsim_data")

local function processSuccessfulVatsimDataRequest(httpRequest)
  VatsimData.container:processSuccessfulHttpResponse(httpRequest)
end

local function processFailedVatsimDataRequest(httpRequest)
  VatsimData.container:processFailedHttpRequest(httpRequest)
end

TRACK_ISSUE(
  "Tech Debt",
  MULTILINE_TEXT(
    "Right after starting to implement the public interface, the Lua 200 local variables limit was crossed.",
    "For now, VatsimData is out of the main script. There are still some things missing that",
    "rely on configuration, which is still in the main script. Move that as well."
  )
)
local function refreshVatsimDataNow()
  if getConfiguredAtcWindowVisibilityDefaultTrue() then -- ATM, don't refresh when ATC window is not opened
    copas.addthread(
      function()
        VatsimDataContainer.CurrentFetchStatus = VatsimDataContainer.FetchStatus.DOWNLOADING
        local url = "http://data.vatsim.net/vatsim-data.txt"
        performDefaultHttpGetRequest(url, processSuccessfulVatsimDataRequest, processFailedVatsimDataRequest)
      end
    )
  else
    logMsg("ATC window is currently closed. No refresh of VATSIM data necessary.")
  end
end

local refreshVatsimDataTimer =
  timer.new(
  {
    delay = 60, -- Should be more than enough
    recurring = true,
    params = {},
    initial_delay = 0, -- Make sure we have information asap
    callback = function(timer_obj, params)
      if getConfiguredAutoRefreshAtcSettingDefaultTrue() then
        refreshVatsimDataNow()
      end
    end
  }
)

--
-- Public Interface
--

local PublicInterface = require("vatsimbrief-helper.public_interface")

--
-- Initialization and Main Thread
--
-- To deal with lazily initialized resources, the initialization method is retried automatically
-- until it succeeds once. For instance, it can check for datarefs and stop initialization if
-- a required dataref is not yet initialized.
--

local MainThread = require("vatsimbrief-helper.main_thread")

local LazyInitializationSingleton
do
  LazyInitialization = {
    vatsimbriefHelperIsInitialized = false,
    gaveUpAlready = false,
    triesSoFar = 0,
    Constants = {
      maxTries = 100
    }
  }

  function LazyInitialization:loop()
    MainThread.loop()
  end

  function LazyInitialization:_canInitializeNow()
    if (VHFHelperEventBus == nil) then
      return false
    end

    return true
  end

  function LazyInitialization:_initializeNow()
    VHFHelperEventBus.on(VHFHelperEventOnFrequencyChanged, onVHFHelperFrequencyChanged)
    Datarefs.bootstrap()
    do_every_frame("LazyInitialization:loop()")
  end

  function LazyInitialization:tryVatsimbriefHelperInit()
    if (self.gaveUpAlready or self.vatsimbriefHelperIsInitialized) then
      return
    end

    self.triesSoFar = self.triesSoFar + 1

    if (self.triesSoFar > self.Constants.maxTries) then
      logMsg(
        ("Vatsimbrief Helper: Lazy initialization is taking too long, giving up after %d tries."):format(
          self.triesSoFar - 1
        )
      )
      self.gaveUpAlready = true
      return
    end

    if (not self:_canInitializeNow()) then
      return
    end

    self:_initializeNow()
    logMsg("Vatsimbrief Helper: Lazy initialization finished.")
    self.vatsimbriefHelperIsInitialized = true
  end
end

do_often("LazyInitialization:tryVatsimbriefHelperInit()")

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
  WindowHandle = nil,
  KeyWidth = 11, -- If changing this, also change max value length
  MaxValueLengthUntilBreak = 79, -- 90 characters minus keyWidth of 11
  FlightplanWindowValuePaddingLeft = "",
  FontScale = getConfiguredFlightPlanFontScaleSettingDefault1() -- Cache font scale as it's needed during each draw.
}
FlightplanWindow.FlightplanWindowValuePaddingLeft = string.rep(" ", FlightplanWindow.KeyWidth)

local FlightplanWindowLastRenderedSimbriefFlightplanFetchStatus = CurrentSimbriefFlightplanFetchStatus
local FlightplanWindowFlightplanDownloadStatus = ""
local FlightplanWindowFlightplanDownloadStatusColor = 0

local function updateFlightPlanWindowTitle()
  if FlightplanWindow.WindowHandle ~= nil then
    -- Title also exists without the physical window, but for performance, only render if window exists
    local title = "Vatsimbrief Helper Flight Plan"
    if Globals.stringIsNotEmpty(FlightplanId) then
      title = title .. " for flight " .. FlightPlan.AirlineIcao .. FlightPlan.FlightNumber
    end

    float_wnd_set_title(FlightplanWindow.WindowHandle, title)
  end
end

local function createFlightplanTableEntry(name, value)
  return ("%-" .. FlightplanWindow.KeyWidth .. "s%s"):format(name .. ":", value)
end

function durationSecsToHHMM(s)
  s = tonumber(s)

  local hrs = math.floor(s / (60 * 60))
  s = s % (60 * 60)
  local mins = math.floor(s / 60)
  return ("%02d:%02d"):format(hrs, mins)
end

function buildVatsimbriefHelperFlightplanWindowCanvas()
  -- Invent a caching mechanism to prevent rendering the strings each frame
  local flightplanChanged = FlightplanWindowLastRenderedFlightplanId ~= FlightplanId
  local flightplanFetchStatusChanged =
    AtcWindowLastRenderedSimbriefFlightplanFetchStatus ~= CurrentSimbriefFlightplanFetchStatus
  local renderContent = flightplanChanged or flightplanFetchStatusChanged or not FlightplanWindowHasRenderedContent
  if renderContent then
    -- Render download status
    local statusType = CurrentSimbriefFlightplanFetchStatus.level
    if
      statusType == SimbriefFlightplanFetchStatusLevel.USER_RELATED or
        statusType == SimbriefFlightplanFetchStatusLevel.SYSTEM_RELATED
     then
      FlightplanWindowFlightplanDownloadStatus, FlightplanWindowFlightplanDownloadStatusColor =
        getSimbriefFlightplanFetchStatusMessageAndColor()
    else
      FlightplanWindowFlightplanDownloadStatus = ""
      FlightplanWindowFlightplanDownloadStatusColor = colorNormal
    end

    if Globals.stringIsEmpty(FlightplanId) then
      if CurrentSimbriefFlightplanFetchStatus == SimbriefFlightplanFetchStatus.DOWNLOADING then
        FlightplanWindowShowDownloadingMsg = true
      else
        FlightplanWindowShowDownloadingMsg = false -- Clear message if there's another message going on, e.g. a download error
      end
    else
      FlightplanWindowShowDownloadingMsg = false

      if Globals.stringIsNotEmpty(FlightplanAltIcao) then
        FlightplanWindowAirports = ("%s - %s / %s"):format(FlightplanOriginIcao, FlightplanDestIcao, FlightplanAltIcao)
      else
        FlightplanWindowAirports = ("%s - %s"):format(FlightplanOriginIcao, FlightplanDestIcao)
      end
      FlightplanWindowAirports = createFlightplanTableEntry("Airports", FlightplanWindowAirports)

      FlightplanWindowRoute =
        ("%s/%s %s %s/%s"):format(
        FlightplanOriginIcao,
        FlightplanOriginRunway,
        FlightplanRoute,
        FlightplanDestIcao,
        FlightplanDestRunway
      )
      FlightplanWindowRoute =
        wrapStringAtMaxlengthWithPadding(
        FlightplanWindowRoute,
        FlightplanWindow.MaxValueLengthUntilBreak,
        FlightplanWindow.FlightplanWindowValuePaddingLeft
      )
      FlightplanWindowRoute = createFlightplanTableEntry("Route", FlightplanWindowRoute)

      if Globals.stringIsNotEmpty(FlightplanAltIcao) then
        FlightplanWindowAltRoute =
          ("%s/%s %s %s/%s"):format(
          FlightplanDestIcao,
          FlightplanDestRunway,
          FlightplanAltRoute,
          FlightplanAltIcao,
          FlightplanAltRunway
        )
        FlightplanWindowAltRoute =
          wrapStringAtMaxlengthWithPadding(
          FlightplanWindowAltRoute,
          FlightplanWindow.MaxValueLengthUntilBreak,
          FlightplanWindow.FlightplanWindowValuePaddingLeft
        )
        FlightplanWindowAltRoute = createFlightplanTableEntry("Alt Route", FlightplanWindowAltRoute)
      else
        FlightplanWindowAltRoute = ""
      end

      local timeFormat = "%I:%M%p"
      FlightplanWindowSchedule =
        ("BLOCK=%s OUT=%s OFF=%s ENROUTE=%s ON=%s IN=%s"):format(
        durationSecsToHHMM(FlightplanEstBlock),
        os.date("!%I:%M%p", FlightplanEstOut),
        os.date("!%I:%M%p", FlightplanEstOff),
        durationSecsToHHMM(FlightplanEstEnroute),
        os.date("!%I:%M%p", FlightplanEstOn),
        os.date("!%I:%M%p", FlightplanEstIn)
      )
      FlightplanWindowSchedule = createFlightplanTableEntry("Schedule", FlightplanWindowSchedule)

      if Globals.stringIsNotEmpty(FlightplanAltIcao) then
        FlightplanWindowAltitudeAndTemp =
          ("ALT=%d/%d TEMP=%d°C"):format(FlightplanAltitude, FlightplanAltAltitude, FlightplanTocTemp)
      else
        FlightplanWindowAltitudeAndTemp = ("ALT=%d TEMP=%d°C"):format(FlightplanAltitude, FlightplanTocTemp)
      end
      FlightplanWindowAltitudeAndTemp = createFlightplanTableEntry("Cruise", FlightplanWindowAltitudeAndTemp)

      FlightplanWindowFuel =
        ("BLOCK=%d%s T/O=%d%s ALTN=%d%s RESERVE=%d%s"):format(
        FlightplanBlockFuel,
        FlightplanUnit,
        FlightplanTakeoffFuel,
        FlightplanUnit,
        FlightplanAltFuel,
        FlightplanUnit,
        FlightplanReserveFuel,
        FlightplanUnit
      )
      FlightplanWindowFuel = createFlightplanTableEntry("Fuel", FlightplanWindowFuel)

      FlightplanWindowWeights =
        ("CARGO=%d%s PAX=%d%s PAYLOAD=%d%s ZFW=%d%s"):format(
        FlightplanCargo,
        FlightplanUnit,
        FlightplanPax,
        FlightplanUnit,
        FlightplanPayload,
        FlightplanUnit,
        FlightplanZfw,
        FlightplanUnit
      )
      FlightplanWindowWeights = createFlightplanTableEntry("Weights", FlightplanWindowWeights)

      if Globals.stringIsNotEmpty(FlightplanAltIcao) then
        FlightplanWindowTrack =
          ("DIST=%d/%d BLOCKTIME=%s CI=%d WINDDIR=%d WINDSPD=%d"):format(
          FlightplanDistance,
          FlightplanAltDistance,
          durationSecsToHHMM(FlightplanEstBlock),
          FlightplanCostindex,
          FlightplanAvgWindDir,
          FlightplanAvgWindSpeed
        )
      else
        FlightplanWindowTrack =
          ("DIST=%d BLOCKTIME=%s CI=%d WINDDIR=%d WINDSPD=%d"):format(
          FlightplanDistance,
          durationSecsToHHMM(FlightplanEstBlock),
          FlightplanCostindex,
          FlightplanAvgWindDir,
          FlightplanAvgWindSpeed
        )
      end
      FlightplanWindowTrack = createFlightplanTableEntry("Track", FlightplanWindowTrack)

      FlightplanWindowMetars =
        ("%s\n%s%s"):format(
        FlightplanOriginMetar,
        FlightplanWindow.FlightplanWindowValuePaddingLeft,
        FlightplanDestMetar
      )
      if Globals.stringIsNotEmpty(FlightplanAltIcao) then
        FlightplanWindowMetars =
          FlightplanWindowMetars ..
          ("\n%s%s"):format(FlightplanWindow.FlightplanWindowValuePaddingLeft, FlightplanAltMetar)
      end
      FlightplanWindowMetars = createFlightplanTableEntry("METARs", FlightplanWindowMetars)

      updateFlightPlanWindowTitle()
    end

    FlightplanWindowLastRenderedSimbriefFlightplanFetchStatus = CurrentSimbriefFlightplanFetchStatus
    FlightplanWindowLastRenderedFlightplanId = FlightplanId
    FlightplanWindowHasRenderedContent = true
  end

  -- Paint
  imgui.SetWindowFontScale(FlightplanWindow.FontScale)

  if Globals.stringIsNotEmpty(FlightplanWindowFlightplanDownloadStatus) then
    imgui.PushStyleColor(imgui.constant.Col.Text, FlightplanWindowFlightplanDownloadStatusColor)
    imgui.TextUnformatted(FlightplanWindowFlightplanDownloadStatus)
    imgui.PopStyleColor()
  end

  if FlightplanWindowShowDownloadingMsg then
    imgui.PushStyleColor(imgui.constant.Col.Text, colorA320Blue)
    imgui.TextUnformatted("Downloading flight plan ...")
    imgui.PopStyleColor()
  elseif Globals.stringIsNotEmpty(FlightplanId) then
    imgui.TextUnformatted(FlightplanWindowAirports)
    imgui.TextUnformatted(FlightplanWindowRoute)
    if Globals.stringIsNotEmpty(FlightplanWindowAltRoute) then
      imgui.TextUnformatted(FlightplanWindowAltRoute)
    end
    imgui.TextUnformatted(FlightplanWindowSchedule)
    imgui.TextUnformatted(FlightplanWindowAltitudeAndTemp)
    imgui.TextUnformatted(FlightplanWindowFuel)
    imgui.TextUnformatted(FlightplanWindowWeights)
    imgui.TextUnformatted(FlightplanWindowTrack)
    imgui.TextUnformatted(FlightplanWindowMetars)
  end
end

function destroyVatsimbriefHelperFlightplanWindow()
  if FlightplanWindow.WindowHandle ~= nil then
    setConfiguredFlightPlanWindowVisibility(false)
    saveConfiguration()
    float_wnd_destroy(FlightplanWindow.WindowHandle)
    FlightplanWindow.WindowHandle = nil
    trackWindowOpen("flight-plan", false)
  end
end

function createVatsimbriefHelperFlightplanWindow()
  LazyInitialization:tryVatsimbriefHelperInit()
  if FlightplanWindow.WindowHandle == nil then -- "Singleton window"
    setConfiguredFlightPlanWindowVisibility(true)
    saveConfiguration()
    refreshFlightplanNow()
    local scaling = getConfiguredFlightPlanFontScaleSettingDefault1()
    FlightplanWindow.WindowHandle = float_wnd_create(650 * scaling, 210 * scaling, 1, true)
    updateFlightPlanWindowTitle()
    float_wnd_set_imgui_builder(FlightplanWindow.WindowHandle, "buildVatsimbriefHelperFlightplanWindowCanvas")
    float_wnd_set_onclose(FlightplanWindow.WindowHandle, "destroyVatsimbriefHelperFlightplanWindow")
    trackWindowOpen("flight-plan", true)
  end
end

function showVatsimbriefHelperFlightplanWindow(value)
  if value and FlightplanWindow.WindowHandle == nil then
    createVatsimbriefHelperFlightplanWindow()
  elseif not value and FlightplanWindow.WindowHandle ~= nil then
    destroyVatsimbriefHelperFlightplanWindow()
  end
end

function toggleFlightPlanWindow(value)
  showVatsimbriefHelperFlightplanWindow(FlightplanWindow.WindowHandle == nil)
end

local function initiallyShowFlightPlanWindow()
  return getConfiguredFlightPlanWindowVisibility(true)
end

add_macro(
  "Vatsimbrief Helper Flight Plan",
  "createVatsimbriefHelperFlightplanWindow()",
  "destroyVatsimbriefHelperFlightplanWindow()",
  windowVisibilityToInitialMacroState("Flight Plan", initiallyShowFlightPlanWindow())
)

--
-- Helper for inline ATC buttons
--

local SelectedAtcFrequenciesChangedTimestamp = nil
InlineButtonBlob = require("shared_components.inline_button_blob")
AtcStringInlineButtonBlob = require("vatsimbrief-helper.components.atc_inline_button_blob")

function onVHFHelperFrequencyChanged()
  SelectedAtcFrequenciesChangedTimestamp = os.clock()
end

local radioHelperOutdatedMessageShownAlready = false

TRACK_ISSUE(
  "Tech Debt",
  "Unsupported VR Radio Helper interface version: Make user aware (not only in Log.txt) of VR Radio Helper / Vatsimbrief Helper not being up-to-date."
)
local function isRadioHelperPanelActive()
  if (VHFHelperPublicInterface ~= nil) then
    if (VHFHelperPublicInterface.getInterfaceVersion() == 1 or VHFHelperPublicInterface.getInterfaceVersion() == 2) then
      return true
    else
      if (not radioHelperOutdatedMessageShownAlready) then
        logMsg(
          ("VR Radio Helper is installed, but uses an unsupported interface version=%d"):format(
            tostring(VHFHelperPublicInterface.getInterfaceVersion())
          )
        )
        radioHelperOutdatedMessageShownAlready = true
      end
    end
  end

  return false
end

--
-- ATC UI handling
--

local CHAR_WIDTH_PIXELS = 8
local LINE_HEIGHT_PIXELS = 18

local AtcWindow = {
  WindowHandle = nil,
  WidthInCharacters = 67,
  FontScale = getConfiguredAtcFontScaleSettingDefault1(),
  Stations = nil,
  StationsStatus = "",
  AtcsString = "",
  StationsSelection = nil,
  LastSelectedAtcFrequenciesChangedTimestamp = nil,
  AtcWindowLastRenderedFlightplanId = nil,
  LastRadioHelperInstalledState = nil
}

local AtcWindowLastAtcIdentifiersUpdatedTimestamp = nil
local AtcWindowHasRenderedContent = false

local Route = ""
local RouteSeparatorLine = ""

local AtcWindowLastRenderedSimbriefFlightplanFetchStatus = CurrentSimbriefFlightplanFetchStatus
local AtcWindowFlightplanDownloadStatus = ""
local AtcWindowFlightplanDownloadStatusColor = 0

local AtcWindowLastRenderedVatsimDataFetchStatus = CurrentVatsimDataFlightplanFetchStatus
local AtcWindowVatsimDataDownloadStatus = ""
local AtcWindowVatsimDataDownloadStatusColor = 0
local showVatsimDataIsDownloading = false
local showVatsimDataIsDisabled = false

function updateAtcWindowTitle()
  if AtcWindow.WindowHandle ~= nil then
    local title = ("Vatsimbrief Helper ATC (%s)"):format(os.date("!%H%MUTC")) -- '!' means "give me ZULU"
    if Globals.stringIsNotEmpty(FlightplanCallsign) then -- TODO: No, condition is, FlightPlanId is not empty, like in updateFlightplanWindowTitle()
      title = title .. " for " .. FlightplanCallsign
    end
    float_wnd_set_title(AtcWindow.WindowHandle, title)
  end
end

do_sometimes("updateAtcWindowTitle()") -- Update time in title

local function stationToNameFrequencyArray(info)
  local shortId

  -- Try to remove airport icao from ID
  local underscore = info.id:find("_")
  if underscore ~= nil then
    shortId = info.id:sub(underscore + 1)
  else
    shortId = info.id
  end

  -- Remove leading '_', e.g. _TWR
  while shortId:find("_") == 1 do
    shortId = shortId:sub(2)
  end

  -- Remove trailing zeros from frequency
  local strippedFrequency = info.frequency
  if stringEndsWith(strippedFrequency, "000") then
    strippedFrequency = stringStripTrailingCharacters(strippedFrequency, 3)
  elseif stringEndsWith(strippedFrequency, "00") then
    strippedFrequency = stringStripTrailingCharacters(strippedFrequency, 2)
  elseif stringEndsWith(strippedFrequency, "0") then
    strippedFrequency = stringStripTrailingCharacters(strippedFrequency, 1)
  end

  return {shortId, strippedFrequency}
end

local function assembleAirportStations(airportIcao, airportIata)
  local atis = {}
  local del = {}
  local gnd = {}
  local twr = {}
  local dep = {}
  local app = {}
  local other = {}

  local icaoPrefix = airportIcao .. "_"
  local iataPrefix = airportIata .. "_"
  for _, v in pairs(VatsimData.container.MapAtcIdentifiersToAtcInfo) do
    if v.id:find(icaoPrefix) == 1 or v.id:find(iataPrefix) == 1 then
      if stringEndsWith(v.id, "_ATIS") then
        table.insert(atis, stationToNameFrequencyArray(v))
      elseif stringEndsWith(v.id, "_DEL") then
        table.insert(del, stationToNameFrequencyArray(v))
      elseif stringEndsWith(v.id, "_GND") then
        table.insert(gnd, stationToNameFrequencyArray(v))
      elseif stringEndsWith(v.id, "_TWR") then
        table.insert(twr, stationToNameFrequencyArray(v))
      elseif stringEndsWith(v.id, "_DEP") then
        table.insert(dep, stationToNameFrequencyArray(v))
      elseif stringEndsWith(v.id, "_APP") then
        table.insert(app, stationToNameFrequencyArray(v))
      else
        table.insert(other, stationToNameFrequencyArray(v))
      end
    end
  end

  local collection = {}
  for _, v in pairs(atis) do
    table.insert(collection, v)
  end
  for _, v in pairs(del) do
    table.insert(collection, v)
  end
  for _, v in pairs(gnd) do
    table.insert(collection, v)
  end
  for _, v in pairs(twr) do
    table.insert(collection, v)
  end
  for _, v in pairs(dep) do
    table.insert(collection, v)
  end
  for _, v in pairs(app) do
    table.insert(collection, v)
  end
  for _, v in pairs(other) do
    table.insert(collection, v)
  end

  return collection
end

function buildVatsimbriefHelperAtcWindowCanvas()
  -- Invent a caching mechanism to prevent rendering the strings each frame
  local flightplanChanged = AtcWindow.AtcWindowLastRenderedFlightplanId ~= FlightplanId
  local atcIdentifiersUpdated =
    AtcWindowLastAtcIdentifiersUpdatedTimestamp ~= VatsimData.container.AtcIdentifiersUpdatedTimestamp
  local flightplanFetchStatusChanged =
    FlightplanWindowLastRenderedSimbriefFlightplanFetchStatus ~= CurrentSimbriefFlightplanFetchStatus
  local vatsimDataFetchStatusChanged =
    AtcWindowLastRenderedVatsimDataFetchStatus ~= VatsimDataContainer.CurrentFetchStatus
  local selectedAtcFrequenciesChanged =
    LastSelectedAtcFrequenciesChangedTimestamp == nil or
    SelectedAtcFrequenciesChangedTimestamp ~= LastSelectedAtcFrequenciesChangedTimestamp
  local radioHelperInstalledStateChanged = LastRadioHelperInstalledState ~= isRadioHelperPanelActive()
  local renderContent =
    flightplanChanged or atcIdentifiersUpdated or flightplanFetchStatusChanged or vatsimDataFetchStatusChanged or
    not AtcWindowHasRenderedContent or
    selectedAtcFrequenciesChanged or
    radioHelperInstalledStateChanged
  if renderContent then
    -- Render download status of flightplan
    local statusType = CurrentSimbriefFlightplanFetchStatus.level
    if
      statusType == SimbriefFlightplanFetchStatusLevel.USER_RELATED or
        statusType == SimbriefFlightplanFetchStatusLevel.SYSTEM_RELATED
     then
      AtcWindowFlightplanDownloadStatus, AtcWindowFlightplanDownloadStatusColor =
        getSimbriefFlightplanFetchStatusMessageAndColor()
    else
      AtcWindowFlightplanDownloadStatus = ""
      AtcWindowFlightplanDownloadStatusColor = colorNormal
    end

    -- Render download status of VATSIM data
    statusType = VatsimData.container.CurrentFetchStatus.level
    if statusType == VatsimDataContainer.FetchStatusLevel.SYSTEM_RELATED then
      AtcWindowVatsimDataDownloadStatus, AtcWindowVatsimDataDownloadStatusColor =
        getVatsimDataFetchStatusMessageAndColor()
    else
      AtcWindowVatsimDataDownloadStatus = ""
      AtcWindowVatsimDataDownloadStatusColor = colorNormal
    end

    -- Render route
    if Globals.stringIsNotEmpty(FlightplanId) then
      -- If there's a flightplan, render it
      if Globals.stringIsNotEmpty(FlightplanAltIcao) then
        -- Note: Once, the alt name was shown as well, but it takes too much space even though the value is pretty low
        -- Consequently, the alt name was removed in 11/2020
        -- local altName = .. " / " .. FlightplanAltName
        local altName = ""
        Route =
          FlightplanOriginIcao ..
          " - " ..
            FlightplanDestIcao ..
              " / " ..
                FlightplanAltIcao .. " (" .. FlightplanOriginName .. " to " .. FlightplanDestName .. altName .. ")"
      else
        Route =
          FlightplanOriginIcao ..
          " - " .. FlightplanDestIcao .. " (" .. FlightplanOriginName .. " to " .. FlightplanDestName .. ")"
      end
    else
      -- It's more beautiful to show the "downloading" status in the title where the route appears in a few seconds
      if CurrentSimbriefFlightplanFetchStatus == SimbriefFlightplanFetchStatus.DOWNLOADING then
        Route = "Downloading flight plan ..."
      else
        Route = "" -- Clear previous state, e.g. don't show "downloading" when there's already an error
      end
    end
    RouteSeparatorLine = string.rep("-", #Route)

    -- Try to render ATC data
    if numberIsNilOrZero(VatsimData.container.AtcIdentifiersUpdatedTimestamp) then -- We have NO ATC data (yet?)
      AtcWindow.StationsStatus = ""
      AtcWindow.Stations = nil
      AtcWindow.AtcsString = ""
      AtcWindow.StationsSelection = nil

      -- Only show "downloading" message when there is no VATSIM data yet and no other download status is rendered
      showVatsimDataIsDownloading =
        VatsimDataContainer.CurrentFetchStatus == VatsimDataContainer.FetchStatus.DOWNLOADING
      showVatsimDataIsDisabled =
        VatsimDataContainer.CurrentFetchStatus == VatsimDataContainer.FetchStatus.NO_DOWNLOAD_ATTEMPTED and
        getConfiguredAutoRefreshAtcSettingDefaultTrue() ~= true
    else
      showVatsimDataIsDownloading = false
      showVatsimDataIsDisabled = false
      if Globals.stringIsEmpty(FlightplanId) then
        AtcWindow.StationsStatus =
          ("Got %d ATC stations. Waiting for flight plan ..."):format(#VatsimData.container.MapAtcIdentifiersToAtcInfo)
        AtcWindow.Stations = nil
        AtcWindow.AtcsString = ""
        AtcWindow.StationsSelection = nil
      else
        if #VatsimData.container.MapAtcIdentifiersToAtcInfo == 0 then
          AtcWindow.StationsStatus = "No ATCs found. This will probably be a technical problem."
          AtcWindow.Stations = nil
          AtcWindow.AtcsString = ""
          AtcWindow.StationsSelection = nil
        else
          -- Build interactive version with clickable frequencies if Radio Helper is installed
          AtcWindow.StationsStatus = "" -- Show stations instead of explicit status ...
          AtcWindow.Stations = {} -- To be filled ...
          AtcWindow.AtcsString = "" -- To be filled ...
          AtcWindow.StationsSelection = nil -- To be filled ...

          -- Assemble list of stations and respective frequencies
          local consideredAirports = {
            {FlightplanOriginIcao, FlightplanOriginIata},
            {FlightplanDestIcao, FlightplanDestIata}
          }
          if Globals.stringIsNotEmpty(FlightplanAltIcao) then
            table.insert(consideredAirports, {FlightplanAltIcao, FlightplanAltIata})
          end

          for i = 1, #consideredAirports do
            local consideredAirport = consideredAirports[i]
            local consideredAirportIcao = consideredAirport[1]
            local consideredAirportIata = consideredAirport[2]

            local stations = assembleAirportStations(consideredAirportIcao, consideredAirportIata)

            local stationsEntryOfAirport = {consideredAirportIcao, stations}
            table.insert(AtcWindow.Stations, stationsEntryOfAirport)
          end

          -- Build interactive version if Radio Helper is installed
          AtcWindow.StationsSelection = AtcStringInlineButtonBlob:new()
          AtcWindow.StationsSelection:build(AtcWindow.Stations, isRadioHelperPanelActive(), AtcWindow.WidthInCharacters)
        end
      end
    end

    -- Update ATC window title now
    updateAtcWindowTitle()

    AtcWindowLastRenderedSimbriefFlightplanFetchStatus = CurrentSimbriefFlightplanFetchStatus
    AtcWindowLastRenderedVatsimDataFetchStatus = VatsimDataContainer.CurrentFetchStatus
    AtcWindow.AtcWindowLastRenderedFlightplanId = FlightplanId
    AtcWindowLastAtcIdentifiersUpdatedTimestamp = VatsimData.container.AtcIdentifiersUpdatedTimestamp
    LastSelectedAtcFrequenciesChangedTimestamp = SelectedAtcFrequenciesChangedTimestamp
    LastRadioHelperInstalledState = isRadioHelperPanelActive()
    AtcWindowHasRenderedContent = true
  end

  -- Paint
  imgui.SetWindowFontScale(AtcWindow.FontScale)

  if Globals.stringIsNotEmpty(AtcWindowFlightplanDownloadStatus) then
    imgui.PushStyleColor(imgui.constant.Col.Text, AtcWindowFlightplanDownloadStatusColor)
    imgui.TextUnformatted(AtcWindowFlightplanDownloadStatus)
    imgui.PopStyleColor()
  elseif Globals.stringIsNotEmpty(AtcWindowVatsimDataDownloadStatus) then
    -- Why elseif? For user comfort, we don't show Flightplan AND VATSIM errors at the same time.
    -- If the network is broken, this looks ugly.
    -- The flightplan error is much more generic and contains more infromation, e.g. that
    -- a user name is missing. Therefore, give it the preference.
    imgui.PushStyleColor(imgui.constant.Col.Text, AtcWindowVatsimDataDownloadStatusColor)
    imgui.TextUnformatted(AtcWindowVatsimDataDownloadStatus)
    imgui.PopStyleColor()
  end
  if Globals.stringIsNotEmpty(Route) then
    imgui.PushStyleColor(imgui.constant.Col.Text, colorA320Blue)
    imgui.TextUnformatted(Route)
    imgui.TextUnformatted(RouteSeparatorLine)
    imgui.PopStyleColor()
  end
  if getConfiguredAutoRefreshAtcSettingDefaultTrue() then -- Only show overaged data when auto refresh is on
    if VatsimData.container.AtcIdentifiersUpdatedTimestamp ~= nil then -- Show information if data is old
      local ageOfAtcDataMinutes =
        math.floor((os.clock() - VatsimData.container.AtcIdentifiersUpdatedTimestamp) * (1.0 / 60.0))
      if ageOfAtcDataMinutes >= 3 then
        imgui.PushStyleColor(imgui.constant.Col.Text, colorWarn)
        -- Note: Render text here as the minutes update every minute and not "on event" when a re-rendering occurs
        imgui.TextUnformatted(("No new VATSIM data for %d minutes!"):format(ageOfAtcDataMinutes))
        imgui.PopStyleColor()
      end
    end
  end
  if showVatsimDataIsDownloading then
    imgui.TextUnformatted("Downloading VATSIM data ...")
  end
  if Globals.stringIsNotEmpty(AtcWindow.StationsStatus) then
    imgui.TextUnformatted(AtcWindow.StationsStatus)
  end
  if AtcWindow.StationsSelection ~= nil then
    AtcWindow.StationsSelection:renderToCanvas()
  end
end

function destroyVatsimbriefHelperAtcWindow()
  if AtcWindow.WindowHandle ~= nil then
    setConfiguredAtcWindowVisibility(false)
    saveConfiguration()
    float_wnd_destroy(AtcWindow.WindowHandle)
    AtcWindow.WindowHandle = nil
    trackWindowOpen("atc", false)
  end
end

function createVatsimbriefHelperAtcWindow()
  LazyInitialization:tryVatsimbriefHelperInit()
  if AtcWindow.WindowHandle == nil then -- "Singleton window"
    setConfiguredAtcWindowVisibility(true)
    refreshVatsimDataNow()
    saveConfiguration()
    local scaling = getConfiguredAtcFontScaleSettingDefault1()
    local windowWidth = CHAR_WIDTH_PIXELS * AtcWindow.WidthInCharacters * scaling + 10
    local windowHeight = LINE_HEIGHT_PIXELS * 5 * scaling + 5
    AtcWindow.WindowHandle = float_wnd_create(windowWidth, windowHeight, 1, true)
    updateAtcWindowTitle()
    float_wnd_set_imgui_builder(AtcWindow.WindowHandle, "buildVatsimbriefHelperAtcWindowCanvas")
    float_wnd_set_onclose(AtcWindow.WindowHandle, "destroyVatsimbriefHelperAtcWindow")
    trackWindowOpen("atc", true)
  end
end

function showVatsimbriefHelperAtcWindow(value)
  if value and AtcWindow.WindowHandle == nil then
    createVatsimbriefHelperAtcWindow()
  elseif not value and AtcWindow.WindowHandle ~= nil then
    destroyVatsimbriefHelperAtcWindow()
  end
end

function toggleAtcWindow(value)
  showVatsimbriefHelperAtcWindow(AtcWindow.WindowHandle == nil)
end

local function initiallyShowAtcWindow()
  return getConfiguredAtcWindowVisibilityDefaultTrue()
end

add_macro(
  "Vatsimbrief Helper ATC",
  "createVatsimbriefHelperAtcWindow()",
  "destroyVatsimbriefHelperAtcWindow()",
  windowVisibilityToInitialMacroState("ATC", initiallyShowAtcWindow())
)

--
-- Control UI handling
--

local inputUserName = ""
local MENU_ITEM_OVERVIEW = 0
local MENU_ITEM_FLIGHTPLAN_DOWNLOAD = 1
local menuItem = MENU_ITEM_OVERVIEW

local MainMenuOptions = {
  ["General"] = MENU_ITEM_OVERVIEW,
  ["Flight Plan Download"] = MENU_ITEM_FLIGHTPLAN_DOWNLOAD
}

local ControlWindow = {
  mapFlightPlanDownloadTypeToDirTmp = {},
  mapFlightPlanDownloadTypeToFileNameTmp = {}
}

function buildVatsimbriefHelperControlWindowCanvas()
  imgui.SetWindowFontScale(1.5)

  -- Main menu
  local currentMenuItem = menuItem -- We get into race conditions when not copying before changing
  local i = 1
  for label, id in pairs(MainMenuOptions) do
    if i > 1 then
      imgui.SameLine()
    end
    local isCurrentMenuItem = id == currentMenuItem
    if isCurrentMenuItem then
      imgui.PushStyleColor(imgui.constant.Col.Button, 0xFFFA9642)
    end
    imgui.PushID(i)
    if imgui.Button(label) then
      menuItem = id
    end
    imgui.PopID()
    if isCurrentMenuItem then
      imgui.PopStyleColor()
    end
    i = i + 1
  end
  imgui.Separator()

  -- Simbrief user name is so important for us that we want to show it very prominently in case user attention is required
  local userNameInvalid =
    CurrentSimbriefFlightplanFetchStatus == SimbriefFlightplanFetchStatus.INVALID_USER_NAME or
    CurrentSimbriefFlightplanFetchStatus == SimbriefFlightplanFetchStatus.NO_SIMBRIEF_USER_ID_ENTERED
  if menuItem == MENU_ITEM_OVERVIEW or userNameInvalid then -- Always show setting when there's something wrong with the user name
    if userNameInvalid then
      imgui.PushStyleColor(imgui.constant.Col.Text, colorErr)
    end
    local changeFlag, newUserName = imgui.InputText("Simbrief Username", inputUserName, 255)
    if userNameInvalid then
      imgui.PopStyleColor()
    end
    if changeFlag then
      inputUserName = newUserName
    end
    imgui.SameLine()
    if imgui.Button("Set") then
      setConfiguredUserName(inputUserName)
      saveConfiguration()
      clearFlightplan()
      refreshFlightplanNow()
      inputUserName = "" -- Clear input line to keep user anonymous (in case he's streaming)
    end
  end

  -- Content canvas
  if menuItem == MENU_ITEM_OVERVIEW then
    imgui.TextUnformatted("") -- Linebreak
    imgui.TextUnformatted("Flight Plan")
    imgui.TextUnformatted("  ")
    imgui.SameLine()
    if imgui.Button(" Reload Flight Plan Now ") then
      clearFlightplan()
      refreshFlightplanNow()
    end
    --
    --[[ Remove auto reloading for flight plans. Might cause stuttering and should be done manually anyway.
         IRL, the pilot turns the page as well.

    imgui.SameLine()
    local changed, newVal = imgui.Checkbox("Auto Reload", getConfiguredAutoRefreshFlightPlanSettingDefaultFalse())
    if changed then
      setConfiguredAutoRefreshFlightPlanSetting(newVal)
      saveConfiguration()
    end ]] imgui.TextUnformatted(
      "  "
    )
    imgui.SameLine()
    local changed3, newVal3 =
      imgui.SliderFloat(
      "Flight Plan Font Scale",
      getConfiguredFlightPlanFontScaleSettingDefault1(),
      0.5,
      3,
      "Value: %.2f"
    )
    if changed3 then
      setConfiguredFlightPlanFontScaleSetting(newVal3)
      flagConfigurationDirty() -- Don't save immediately to reduce disk load
      FlightplanWindow.FontScale = newVal3
    end

    imgui.TextUnformatted("") -- Linebreak
    imgui.TextUnformatted("ATC")
    imgui.TextUnformatted("  ")
    imgui.SameLine()
    if imgui.Button(" Refresh ATC Data Now ") then
      TRACK_ISSUE("Tech Debt", "No test is covering this part. Stubs for copas/HTTP are still mising.")
      VatsimData.container:clear()
      refreshVatsimDataNow()
    end
    imgui.SameLine()
    imgui.TextUnformatted(" - ")
    imgui.SameLine()
    local changed2, newVal2 = imgui.Checkbox("Enable Auto Refresh", getConfiguredAutoRefreshAtcSettingDefaultTrue())
    if changed2 then
      setConfiguredAutoRefreshAtcSetting(newVal2)
      saveConfiguration()
    end
    imgui.TextUnformatted("  ")
    imgui.SameLine()
    local changed4, newVal4 =
      imgui.SliderFloat("ATC Data Font Scale", getConfiguredAtcFontScaleSettingDefault1(), 0.5, 3, "Value: %.2f")
    if changed4 then
      setConfiguredAtcFontScaleSetting(newVal4)
      flagConfigurationDirty() -- Don't save immediately to reduce disk load
      AtcWindow.FontScale = newVal4
    end
  elseif menuItem == MENU_ITEM_FLIGHTPLAN_DOWNLOAD then
    if FlightplanId == nil then
      imgui.TextUnformatted("Waiting for a flight plan ...")
    else
      local padding = "  "

      imgui.TextUnformatted("Please mark the flight plan types that you want to be downloaded.")
      imgui.TextUnformatted(
        "If no path is entered, the default folder will be used:\n" .. padding .. FlightPlanDownload.Directory
      )

      imgui.TextUnformatted(padding)
      imgui.SameLine()
      local changed, newVal =
        imgui.Checkbox(
        "Auto clean up stale flight plans from default folder",
        getConfiguredDeleteOldFlightPlansSetting()
      )
      if changed then
        setConfiguredDeleteOldFlightPlansSetting(newVal)
        saveConfiguration()
      -- deleteDownloadedFlightPlansIfConfigured() -- Better not that fast, without any confirmation
      end

      imgui.TextUnformatted("Default file name: <YYYYMMDD_HHMMSS>_<ORIG_ICAO>-<DEST_ICAO>.<EXTENSION>")
      imgui.TextUnformatted("File name format: %o - Source ICAO, %d - Dest ICAO, %a - Date, %t - Time")

      imgui.PushStyleColor(imgui.constant.Col.Text, colorWarn)
      imgui.TextUnformatted("Existing files will be overwritten!")
      imgui.PopStyleColor()

      imgui.TextUnformatted("") -- Blank line

      local fileTypes = getFlightplanFileTypesArray()
      local maxFileTypesLength = 0
      for i = 1, #fileTypes do
        if string.len(fileTypes[i]) > maxFileTypesLength then
          maxFileTypesLength = string.len(fileTypes[i])
        end
      end
      for i = 1, #fileTypes do
        local statusOnOff = isFlightplanFileDownloadEnabled(fileTypes[i])
        local nameWithPadding = string.format("%-" .. maxFileTypesLength .. "s", fileTypes[i])
        imgui.PushID(5 * i)
        local changed, enabled = imgui.Checkbox(nameWithPadding, statusOnOff)
        imgui.PopID()
        if changed then
          setFlightplanFileDownloadEnabled(fileTypes[i], enabled)
          saveFlightPlanFilesForDownload()
          if enabled then
            downloadFlightPlanAgain(fileTypes[i])
          end
        end
        if statusOnOff == true then
          --imgui.SameLine()
          local padding2 = "    "
          imgui.TextUnformatted(padding2 .. "(Dest Folder: ")
          imgui.SameLine()
          imgui.PushID(5 * i + 1)
          local savePath = false
          if imgui.Button("Set") then
            -- We don't want to save the config "on change" as it creates too much disk load again. Therefore, add this button.
            -- Save that button was clicked, for later use
            savePath = true
          end
          imgui.PopID()
          imgui.SameLine()
          imgui.PushID(5 * i + 2)
          if ControlWindow.mapFlightPlanDownloadTypeToDirTmp[fileTypes[i]] == nil then
            ControlWindow.mapFlightPlanDownloadTypeToDirTmp[fileTypes[i]] = getFlightPlanDownloadDirectory(fileTypes[i])
          end
          local pathChanged, path =
            imgui.InputText(
            "",
            defaultIfBlank(ControlWindow.mapFlightPlanDownloadTypeToDirTmp[fileTypes[i]], Globals.emptyString),
            255
          )
          if pathChanged then
            ControlWindow.mapFlightPlanDownloadTypeToDirTmp[fileTypes[i]] = path
          end
          imgui.PopID()
          imgui.SameLine()
          imgui.TextUnformatted(")")

          if savePath then
            local configuredDir = defaultIfBlank(ControlWindow.mapFlightPlanDownloadTypeToDirTmp[fileTypes[i]], nil)
            setFlightPlanDownloadDirectory(fileTypes[i], configuredDir)
            saveFlightPlanFilesForDownload()
            downloadFlightPlanAgain(fileTypes[i])
          end

          imgui.TextUnformatted(padding2 .. "(File Name: ")
          imgui.SameLine()
          imgui.PushID(5 * i + 3)
          local saveFileName = false
          if imgui.Button("Set") then
            -- We don't want to save the config "on change" as it creates too much disk load again. Therefore, add this button.
            -- Save that button was clicked, for later use
            saveFileName = true
          end
          imgui.PopID()
          imgui.SameLine()
          imgui.PushID(5 * i + 4)
          if ControlWindow.mapFlightPlanDownloadTypeToFileNameTmp[fileTypes[i]] == nil then
            ControlWindow.mapFlightPlanDownloadTypeToFileNameTmp[fileTypes[i]] =
              getFlightPlanDownloadFileName(fileTypes[i])
          end
          local fileNameChanged, fileName =
            imgui.InputText(
            "",
            defaultIfBlank(ControlWindow.mapFlightPlanDownloadTypeToFileNameTmp[fileTypes[i]], Globals.emptyString),
            255
          )
          if fileNameChanged then
            ControlWindow.mapFlightPlanDownloadTypeToFileNameTmp[fileTypes[i]] = fileName
          end
          imgui.PopID()
          imgui.SameLine()
          imgui.TextUnformatted(")")
          if saveFileName then
            local configuredFileName =
              defaultIfBlank(ControlWindow.mapFlightPlanDownloadTypeToFileNameTmp[fileTypes[i]], nil)
            setFlightPlanDownloadFileName(fileTypes[i], configuredFileName)
            saveFlightPlanFilesForDownload()
            downloadFlightPlanAgain(fileTypes[i])
          end
        end
      end
    end
  end
end

local vatsimbriefHelperControlWindow = nil

function destroyVatsimbriefHelperControlWindow()
  if vatsimbriefHelperControlWindow ~= nil then
    float_wnd_destroy(vatsimbriefHelperControlWindow)
    vatsimbriefHelperControlWindow = nil
    trackWindowOpen("control", false)
  end
end

function createVatsimbriefHelperControlWindow()
  LazyInitialization:tryVatsimbriefHelperInit()
  if vatsimbriefHelperControlWindow == nil then -- "Singleton window"
    vatsimbriefHelperControlWindow = float_wnd_create(900, 300, 1, true)
    float_wnd_set_title(vatsimbriefHelperControlWindow, "Vatsimbrief Helper Control")
    float_wnd_set_imgui_builder(vatsimbriefHelperControlWindow, "buildVatsimbriefHelperControlWindowCanvas")
    float_wnd_set_onclose(vatsimbriefHelperControlWindow, "destroyVatsimbriefHelperControlWindow")
    trackWindowOpen("control", true)
  end
end

local function showVatsimbriefHelperControlWindow(value)
  if value and vatsimbriefHelperControlWindow == nil then
    createVatsimbriefHelperControlWindow()
  elseif not value and vatsimbriefHelperControlWindow ~= nil then
    destroyVatsimbriefHelperControlWindow()
  end
end

function toggleControlWindow(value)
  showVatsimbriefHelperControlWindow(vatsimbriefHelperControlWindow == nil)
end

local function initiallyShowControlWindow()
  return Globals.stringIsEmpty(getConfiguredSimbriefUserName())
end

add_macro(
  "Vatsimbrief Helper Control",
  "createVatsimbriefHelperControlWindow()",
  "destroyVatsimbriefHelperControlWindow()",
  windowVisibilityToInitialMacroState("Control", initiallyShowControlWindow())
)

--- Command bindings for opening / closing windows
function toggleAllVatsimbriefWindows()
  if atLeastOneWindowIsOpen() then
    showVatsimbriefHelperControlWindow(false)
    showVatsimbriefHelperFlightplanWindow(false)
    showVatsimbriefHelperAtcWindow(false)
  else
    showVatsimbriefHelperControlWindow(true)
    showVatsimbriefHelperFlightplanWindow(true)
    showVatsimbriefHelperAtcWindow(initiallyShowAtcWindow()) -- Only show when necessary
  end
end

create_command(
  "FlyWithLua/Vatsimbrief Helper/ToggleWindows",
  "Toggle All Windows",
  "toggleAllVatsimbriefWindows()",
  "",
  ""
)
create_command(
  "FlyWithLua/Vatsimbrief Helper/ToggleFlightPlanWindow",
  "Toggle Flight Plan",
  "toggleFlightPlanWindow()",
  "",
  ""
)
create_command("FlyWithLua/Vatsimbrief Helper/ToggleAtcWindow", "Toggle ATC Window", "toggleAtcWindow()", "", "")
create_command(
  "FlyWithLua/Vatsimbrief Helper/ToggleControlWindow",
  "Toggle Control Window",
  "toggleControlWindow()",
  "",
  ""
)

vatsimbriefHelperPackageExport = {}
vatsimbriefHelperPackageExport.test = {}
vatsimbriefHelperPackageExport.test.LazyInitialization = LazyInitialization
vatsimbriefHelperPackageExport.test.Configuration = Configuration
vatsimbriefHelperPackageExport.test.VatsimData = VatsimData
vatsimbriefHelperPackageExport.test.computeDistanceOnEarth = Globals.computeDistanceOnEarth
return
