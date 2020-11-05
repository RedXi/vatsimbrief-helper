@echo off
call .\build\configure_environment.cmd

set TASK_OUTPUT_FILENAME=%TASK_OUTPUT_FOLDER_PATH%\copyToXPlane.txt
echo Files copied by task copyToXPlane: > %TASK_OUTPUT_FILENAME%

xcopy /Y /S /E .\scripts\* "%XPLANE_PATH%\Resources\plugins\FlyWithLua\Scripts\*" >> %TASK_OUTPUT_FILENAME%
if %ERRORLEVEL% NEQ 0 (goto :label_copy_error)

xcopy /Y /S /E .\modules\* "%XPLANE_PATH%\Resources\plugins\FlyWithLua\Modules\*" >> %TASK_OUTPUT_FILENAME%
if %ERRORLEVEL% NEQ 0 (goto :label_copy_error)

goto :label_copying_ok

:label_copy_error
echo [91mCopying files failed[0m. Lookup %TASK_OUTPUT_FILENAME% to find out what happened.
exit(%ERRORLEVEL%)

:label_copying_ok
echo [92mOK[0m: Copied files to X-Plane. In case you'd like to see which ones, look up [94m%TASK_OUTPUT_FILENAME%[0m (they end up in releases as well).
exit(0)