@echo off
call .\build\configure_environment.cmd

%PACKETSENDER_EXECUTABLE% --quiet --ascii --udp localhost 49000 CMND\00FlyWithLua/debugging/reload_scripts\00
if %ERRORLEVEL% NEQ 41 exit(%ERRORLEVEL%)

echo OK: Reload-all-Lua-script-files packet sent successfully
set ERRORLEVEL=0
exit(0)

