@echo off
call .\build\configure_environment.cmd
if %ERRORLEVEL% NEQ 0 exit /B %ERRORLEVEL%

set TASK_OUTPUT_FILENAME=%TASK_OUTPUT_FOLDER_PATH%\copyToXPlane.txt
echo Files copied by task copyToXPlane (also copied to releases): > %TASK_OUTPUT_FILENAME%
echo ============================================================ >> %TASK_OUTPUT_FILENAME%

set SCRIPTS_TARGET_PATH="%XPLANE_PATH%\Resources\plugins\FlyWithLua\Scripts\*"
set MODULES_TARGET_PATH="%XPLANE_PATH%\Resources\plugins\FlyWithLua\Modules\*"

echo Scripts to %SCRIPTS_TARGET_PATH%: >> %TASK_OUTPUT_FILENAME%
xcopy /Y /S /E /F .\scripts\* %SCRIPTS_TARGET_PATH% >> %TASK_OUTPUT_FILENAME%
if %ERRORLEVEL% NEQ 0 (goto :label_copy_error)
echo. >> %TASK_OUTPUT_FILENAME%

if not exist .\script_modules mkdir .\script_modules
if not exist .\script_modules\%RELEASE_FILE_NAME_PREFIX% mkdir .\script_modules\%RELEASE_FILE_NAME_PREFIX%

for /F %%A in ('dir /a-d-s-h /b .\scripts ^| find /V /C ""') do set SCRIPTS_FOLDER_FILES_COUNT=%%A
if %SCRIPTS_FOLDER_FILES_COUNT% NEQ 1 (
    echo To successfully run a script within FlyWithLua, the [94m.\scripts[0m folder needs to contain [93mexactly one[0m *.lua file.
    echo.
    echo Currently, [94m.\scripts[0m [91mcontains %SCRIPTS_FOLDER_FILES_COUNT% files[0m.
    echo.
    echo If you need more than one file, place everything besides the single main script in [94m.\script_modules\%RELEASE_FILE_NAME_PREFIX%[0m.
    echo All files in [94m.\script_modules[0m are copied to the FlyWithLua modules folder as well, so [93mkeep them in a custom subfolder[0m.
    echo.
    set ERRORLEVEL=1
    goto :label_copy_error
)

for /F %%A in ('dir /a-d-s-h /b .\script_modules ^| find /V /C ""') do set SCRIPT_MODULES_FOLDER_FILES_COUNT=%%A
if %SCRIPT_MODULES_FOLDER_FILES_COUNT% NEQ 0 (
    echo To not accidentally overwrite files in the FlyWithLua modules folder, all additional files besides the main script in [94m.\scripts[0m
    echo should be in a [93mcustom subfolder[0m, preferably [94m.\script_modules\%RELEASE_FILE_NAME_PREFIX%[0m.
    echo.
    echo Currently, [94m..\script_modules[0m [91mcontains %SCRIPT_MODULES_FOLDER_FILES_COUNT% files[0m.
    echo.
    echo Place all additional scripts in [94m.\script_modules\%RELEASE_FILE_NAME_PREFIX%[0m and re-run this task.
    echo.
    set ERRORLEVEL=1
    goto :label_copy_error
) else (
    echo If you see a File Not Found, don't worry. That's fine.
)

echo Script Modules to %MODULES_TARGET_PATH%: >> %TASK_OUTPUT_FILENAME%
xcopy /Y /S /E /F .\script_modules\* %MODULES_TARGET_PATH% >> %TASK_OUTPUT_FILENAME%
if %ERRORLEVEL% NEQ 0 (goto :label_copy_error)
echo. >> %TASK_OUTPUT_FILENAME%

echo Modules to %MODULES_TARGET_PATH%: >> %TASK_OUTPUT_FILENAME%
xcopy /Y /S /E /F .\modules\* %MODULES_TARGET_PATH% >> %TASK_OUTPUT_FILENAME%
if %ERRORLEVEL% NEQ 0 (goto :label_copy_error)
echo. >> %TASK_OUTPUT_FILENAME%

goto :label_copying_ok

:label_copy_error
    echo [91mCopying files failed[0m. Lookup %TASK_OUTPUT_FILENAME% to find out what happened.
    exit /b %ERRORLEVEL%

:label_copying_ok
    echo [92mOK[0m: Copied files to [94m"%XPLANE_PATH%"[0m. In case you'd like to see which ones, look up [94m%TASK_OUTPUT_FILENAME%[0m (they end up in releases as well).
    exit /b 0
