@echo off
call .\build\configure_environment.cmd

xcopy /Y /S /E scripts\* "%XPLANE_PATH%\Resources\plugins\FlyWithLua\Scripts"
xcopy /Y /S /E modules\* "%XPLANE_PATH%\Resources\plugins\FlyWithLua\Modules"