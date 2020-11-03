@REM DO NOT change this file to setup your local environment. Instead, run any task at least once and look up LOCAL_ENVIRONMENT_CONFIGURATION.cmd
if not exist LOCAL_ENVIRONMENT_CONFIGURATION.cmd (
    (
        echo set NSIS_EXECUTABLE="C:\Program Files (x86)\NSIS\makensis.exe"
        echo set LUA_EXECUTABLE="C:\Program Files (x86)\Lua\5.1\lua.exe"
        echo set LUA_DEFAULT_MODULES_PATH="C:\Program Files (x86)\Lua\5.1\lua"
        echo set SEVEN_ZIP_EXECUTABLE="C:\Program Files\7-Zip\7z.exe"
        echo set PACKETSENDER_EXECUTABLE="C:\Program Files\PacketSender\packetsender.exe"
        echo set XPLANE_PATH="C:\X-Plane 11"
    ) > LOCAL_ENVIRONMENT_CONFIGURATION.cmd
)

call LOCAL_ENVIRONMENT_CONFIGURATION.cmd

set LUA_DEFAULT_MODULES_PATH=%LUA_DEFAULT_MODULES_PATH:"=%
set XPLANE_PATH=%XPLANE_PATH:"=%