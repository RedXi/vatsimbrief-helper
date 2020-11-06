@echo off
call .\build\configure_environment.cmd

set TASK_OUTPUT_FILENAME=%TASK_OUTPUT_FOLDER_PATH%\copyToXPlane.txt
echo Files copied by task copyToXPlane (also copied to releases): > %TASK_OUTPUT_FILENAME%
echo ============================================================ >> %TASK_OUTPUT_FILENAME%

set SCRIPTS_TARGET_PATH="%XPLANE_PATH%\Resources\plugins\FlyWithLua\Scripts\*"
set MODULES_TARGET_PATH="%XPLANE_PATH%\Resources\plugins\FlyWithLua\Modules\*"

echo Scripts to %SCRIPTS_TARGET_PATH%: >> %TASK_OUTPUT_FILENAME%
xcopy /Y /S /E .\scripts\* %SCRIPTS_TARGET_PATH% >> %TASK_OUTPUT_FILENAME%
if %ERRORLEVEL% NEQ 0 (goto :label_copy_error)
echo. >> %TASK_OUTPUT_FILENAME%

echo Modules to %MODULES_TARGET_PATH%: >> %TASK_OUTPUT_FILENAME%
xcopy /Y /S /E .\modules\* %MODULES_TARGET_PATH% >> %TASK_OUTPUT_FILENAME%
if %ERRORLEVEL% NEQ 0 (goto :label_copy_error)
echo. >> %TASK_OUTPUT_FILENAME%

goto :label_copying_ok

:label_copy_error
echo [91mCopying files failed[0m. Lookup %TASK_OUTPUT_FILENAME% to find out what happened.
exit(%ERRORLEVEL%)

:label_copying_ok
echo [92mOK[0m: Copied files to [94m"%XPLANE_PATH%"[0m. In case you'd like to see which ones, look up [94m%TASK_OUTPUT_FILENAME%[0m (they end up in releases as well).
exit(0)
