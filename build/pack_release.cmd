@echo off
call .\build\configure_environment.cmd

for /F "tokens=*" %%h in ('git tag --points-at HEAD') do (SET TAG=%%h)
if not defined TAG (set tag=TAGLESS)

for /F "tokens=*" %%h in ('git rev-parse --short HEAD') do (SET COMMIT_HASH=%%h)

if %ERRORLEVEL% GTR 0 (
    exit /b
)

set RELEASE_PACKAGE_FOLDER_PATH=RELEASE_PACKAGE

if exist %RELEASE_PACKAGE_FOLDER_PATH% (
    rmdir /S /Q %RELEASE_PACKAGE_FOLDER_PATH%
)

mkdir %RELEASE_PACKAGE_FOLDER_PATH%

%NSIS_EXECUTABLE% "/XOutFile ..\%RELEASE_PACKAGE_FOLDER_PATH%\%1-%TAG%-%COMMIT_HASH%.exe" build\generate-installer.nsi
if %ERRORLEVEL% GTR 0 (
    exit /b
)

mkdir %RELEASE_PACKAGE_FOLDER_PATH%\Modules
mkdir %RELEASE_PACKAGE_FOLDER_PATH%\Scripts

xcopy /Y /S /E scripts\* %RELEASE_PACKAGE_FOLDER_PATH%\Scripts\*
xcopy /Y /S /E modules\* %RELEASE_PACKAGE_FOLDER_PATH%\Modules\*

cd %RELEASE_PACKAGE_FOLDER_PATH%

%SEVEN_ZIP_EXECUTABLE% a -r %1-%TAG%-%COMMIT_HASH%.zip Modules Scripts