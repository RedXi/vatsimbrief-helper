@echo off
call .\build\configure_environment.cmd

cd %1
set LUA_PATH=%1\scripts\?.lua;%1\test\?.lua;%1\test-framework\?.lua;%1\test-framework\test-dependencies\?.lua;%1\test-framework\no-test-dependencies\?.lua;%LUA_DEFAULT_MODULES_PATH%\?.lua
%LUA_EXECUTABLE% %2