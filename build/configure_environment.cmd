@REM DO NOT change this file to setup your local environment. Instead, run any task at least once and look up these two files:
@REM - LOCAL_ENVIRONMENT_CONFIGURATION.cmd
@REM - build_configuration.cmd
call .\build\set_default_environment.cmd
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
        set GIT_EXECUTABLE=%DEFAULT_GIT_EXECUTABLE%
        goto :label_append_to_local_environment
    )

    set LUA_DEFAULT_MODULES_PATH=%LUA_DEFAULT_MODULES_PATH:"=%
    set XPLANE_PATH=%XPLANE_PATH:"=%

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
        set GITHUB_REPO_URL=%DEFAULT_GITHUB_REPO_URL%
        goto :label_append_to_local_configuration
    )

    set READABLE_SCRIPT_NAME=%READABLE_SCRIPT_NAME:"=%
    set RELEASE_FILE_NAME_PREFIX=%RELEASE_FILE_NAME_PREFIX:"=%
    set GITHUB_REPO_URL=%GITHUB_REPO_URL:"=%

set TASK_OUTPUT_FOLDER_PATH=.\TEMP\TASK_OUTPUT
if not exist %TASK_OUTPUT_FOLDER_PATH% (
    mkdir %TASK_OUTPUT_FOLDER_PATH%
)

goto :label_end

    :label_append_to_local_configuration
        call .\build\set_default_to_current_configuration.cmd
        del build_configuration.cmd
        goto :label_regenerate_build_configuration

    :label_append_to_local_environment
        call .\build\set_default_to_current_environment.cmd
        del LOCAL_ENVIRONMENT_CONFIGURATION.cmd
        goto :label_regenerate_local_environment

:label_end
