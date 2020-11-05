@REM DO NOT change this file to setup your local environment. Instead, run any task at least once and look up these two files:
@REM - LOCAL_ENVIRONMENT_CONFIGURATION.cmd
@REM - build_configuration.cmd
set DEFAULT_NSIS_EXECUTABLE="C:\Program Files (x86)\NSIS\makensis.exe"
set DEFAULT_LUA_EXECUTABLE="C:\Program Files (x86)\Lua\5.1\lua.exe"
set DEFAULT_LUA_DEFAULT_MODULES_PATH="C:\Program Files (x86)\Lua\5.1\lua"
set DEFAULT_SEVEN_ZIP_EXECUTABLE="C:\Program Files\7-Zip\7z.exe"
set DEFAULT_PACKETSENDER_EXECUTABLE="C:\Program Files\PacketSender\packetsender.com"
set DEFAULT_XPLANE_PATH="C:\X-Plane 11"
set DEFAULT_GIT_EXECUTABLE="C:\Program Files\Git\bin\git.exe"

:label_regenerate_local_environment
if not exist LOCAL_ENVIRONMENT_CONFIGURATION.cmd (
    (
        echo set NSIS_EXECUTABLE=%DEFAULT_NSIS_EXECUTABLE%
        echo set LUA_EXECUTABLE=%DEFAULT_LUA_EXECUTABLE%
        echo set LUA_DEFAULT_MODULES_PATH=%DEFAULT_LUA_DEFAULT_MODULES_PATH%
        echo set SEVEN_ZIP_EXECUTABLE=%DEFAULT_SEVEN_ZIP_EXECUTABLE%
        echo set PACKETSENDER_EXECUTABLE=%DEFAULT_PACKETSENDER_EXECUTABLE%
        echo set XPLANE_PATH=%DEFAULT_XPLANE_PATH%
        echo set GIT_EXECUTABLE=%DEFAULT_GIT_EXECUTABLE%
    ) > LOCAL_ENVIRONMENT_CONFIGURATION.cmd
)

call LOCAL_ENVIRONMENT_CONFIGURATION.cmd

if not defined GIT_EXECUTABLE (
    set DEFAULT_NSIS_EXECUTABLE=%NSIS_EXECUTABLE%
    set DEFAULT_LUA_EXECUTABLE=%LUA_EXECUTABLE%
    set DEFAULT_LUA_DEFAULT_MODULES_PATH=%LUA_DEFAULT_MODULES_PATH%
    set DEFAULT_SEVEN_ZIP_EXECUTABLE=%SEVEN_ZIP_EXECUTABLE%
    set DEFAULT_PACKETSENDER_EXECUTABLE=%PACKETSENDER_EXECUTABLE%
    set DEFAULT_XPLANE_PATH=%XPLANE_PATH%
    del LOCAL_ENVIRONMENT_CONFIGURATION.cmd
    goto :label_regenerate_local_environment
)

set LUA_DEFAULT_MODULES_PATH=%LUA_DEFAULT_MODULES_PATH:"=%
set XPLANE_PATH=%XPLANE_PATH:"=%

set DEFAULT_READABLE_SCRIPT_NAME="___UPDATE build_configuration_cmd"
set DEFAULT_RELEASE_FILE_NAME_PREFIX="___UPDATE_build_configuration_cmd"
set DEFAULT_GITHUB_REPO_URL="https://github.com/____UPDATE_REPO_URL_in_build_configuration_cmd"

:label_regenerate_build_configuration
if not exist build_configuration.cmd (
    (
        echo set READABLE_SCRIPT_NAME=%DEFAULT_READABLE_SCRIPT_NAME%
        echo set RELEASE_FILE_NAME_PREFIX=%DEFAULT_RELEASE_FILE_NAME_PREFIX%
        echo set GITHUB_REPO_URL=%DEFAULT_GITHUB_REPO_URL%
    ) > build_configuration.cmd
)

call build_configuration.cmd

if not defined GITHUB_REPO_URL (
    set DEFAULT_READABLE_SCRIPT_NAME=%READABLE_SCRIPT_NAME%
    set DEFAULT_RELEASE_FILE_NAME_PREFIX=%RELEASE_FILE_NAME_PREFIX%
    del build_configuration.cmd
    goto :label_regenerate_build_configuration
)

set READABLE_SCRIPT_NAME=%READABLE_SCRIPT_NAME:"=%
set RELEASE_FILE_NAME_PREFIX=%RELEASE_FILE_NAME_PREFIX:"=%
set GITHUB_REPO_URL=%GITHUB_REPO_URL:"=%

set TASK_OUTPUT_FOLDER_PATH=.\TEMP\TASK_OUTPUT
if not exist %TASK_OUTPUT_FOLDER_PATH% (
    mkdir %TASK_OUTPUT_FOLDER_PATH%
)