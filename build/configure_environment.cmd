@REM DO NOT change this file to setup your local environment. Instead, run any task at least once and look up LOCAL_ENVIRONMENT_CONFIGURATION.cmd
:label_regenerate_local_environment
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

if not exist build_configuration.cmd (
    (
        echo set READABLE_SCRIPT_NAME="___UPDATE build_configuration_cmd"
        echo set RELEASE_FILE_NAME_PREFIX="___UPDATE_build_configuration_cmd"
    ) > build_configuration.cmd
)

call build_configuration.cmd

set READABLE_SCRIPT_NAME=%READABLE_SCRIPT_NAME:"=%
set RELEASE_FILE_NAME_PREFIX=%RELEASE_FILE_NAME_PREFIX:"=%
