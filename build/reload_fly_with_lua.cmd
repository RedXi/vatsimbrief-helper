@echo off
call .\build\configure_environment.cmd
if %ERRORLEVEL% NEQ 0 exit /B %ERRORLEVEL%

set TASK_OUTPUT_FILENAME=%TASK_OUTPUT_FOLDER_PATH%\buildAndReloadFlyWithLua.txt

%PACKETSENDER_EXECUTABLE% --ascii --udp localhost 49000 CMND\00FlyWithLua/debugging/reload_scripts\00 > %TASK_OUTPUT_FILENAME%
if %ERRORLEVEL% NEQ 41 (goto :label_send_error)

goto :label_send_ok

:label_send_error
echo [91mSending FlyWithLua reload package to X-Plane instance failed[0m.
exit(%ERRORLEVEL%)

:label_send_ok
echo [92mOK[0m: Reload-all-Lua-script-files packet sent successfully. Logs from running scripts are going to [94m"%XPLANE_PATH%\Log.txt"[0m

set FWL_PREFS_INI_PATH="%XPLANE_PATH%\Resources\plugins\FlyWithLua\fwl_prefs.ini"

setlocal enabledelayedexpansion
set FILTERED_INI_PATH=%TASK_OUTPUT_FOLDER_PATH%\copyToXPlane_filtered_fwl_prefs.ini

echo. > %FILTERED_INI_PATH%

for /F "tokens=*" %%A in ('type %FWL_PREFS_INI_PATH%') do (
    set line=%%A
    echo !line: =! >> %FILTERED_INI_PATH%
)

for /F "tokens=1,2 delims==" %%A in ('type !TASK_OUTPUT_FOLDER_PATH!\copyToXPlane_filtered_fwl_prefs.ini') do (
    if %%A==DeveloperMode set DEV_MODE_SETTING=%%B
)

if %DEV_MODE_SETTING%==0 (
    echo.
    echo Your FlyWithLua installation has [93mdeveloper mode disabled[0m and moves erroneous scripts to Quarantine automatically.
    echo To remove yourself from the burden of moving them back back manually from Quarantine, consider enabling developer mode in [94m%FWL_PREFS_INI_PATH%[0m
)

set ERRORLEVEL=0
exit /B %ERRORLEVEL%
