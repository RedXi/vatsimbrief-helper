@echo off
call .\build\configure_environment.cmd

%PACKETSENDER_EXECUTABLE% --ascii --udp localhost 49000 CMND\00FlyWithLua/debugging/reload_scripts\00 > %TASK_OUTPUT_FOLDER_PATH%\buildAndReloadFlyWithLua.txt
if %ERRORLEVEL% NEQ 41 (goto :label_send_error)

goto :label_send_ok

:label_send_error
echo [91mSending FlyWithLua reload package to X-Plane instance failed[0m.
exit(%ERRORLEVEL%)

:label_send_ok
set FWL_PREFS_INI_PATH="%XPLANE_PATH%\Resources\plugins\FlyWithLua\fwl_prefs.ini"
echo [92mOK[0m: Reload-all-Lua-script-files packet sent successfully. To not be required to manually move erroneous scripts back from Quarantine, consider enabling developer mode in %FWL_PREFS_INI_PATH%

set ERRORLEVEL=0
exit(0)
