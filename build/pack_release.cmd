@echo off
call .\build\configure_environment.cmd

for /F "tokens=*" %%h in ('git tag --points-at HEAD') do (SET TAG=%%h)
if not defined TAG (set tag=TAGLESS)

for /F "tokens=*" %%h in ('git rev-parse --short HEAD') do (SET COMMIT_HASH=%%h)

if %ERRORLEVEL% GTR 0 (
    exit(%ERRORLEVEL%)
)

set RELEASE_PACKAGE_FOLDER_PATH=RELEASE_PACKAGE

if exist %RELEASE_PACKAGE_FOLDER_PATH% (
    rmdir /S /Q %RELEASE_PACKAGE_FOLDER_PATH%
)

mkdir %RELEASE_PACKAGE_FOLDER_PATH%

%NSIS_EXECUTABLE% "/XOutFile ..\%RELEASE_PACKAGE_FOLDER_PATH%\%RELEASE_FILE_NAME_PREFIX%-%TAG%-%COMMIT_HASH%.exe" build\generate-installer.nsi
if %ERRORLEVEL% NEQ 0 (
    echo [91mNSIS Installer generation failed[0m.
    exit(%ERRORLEVEL%)
)

mkdir %RELEASE_PACKAGE_FOLDER_PATH%\Modules
mkdir %RELEASE_PACKAGE_FOLDER_PATH%\Scripts

xcopy /Y /S /E scripts\* %RELEASE_PACKAGE_FOLDER_PATH%\Scripts\*
xcopy /Y /S /E modules\* %RELEASE_PACKAGE_FOLDER_PATH%\Modules\*

cd %RELEASE_PACKAGE_FOLDER_PATH%

%SEVEN_ZIP_EXECUTABLE% a -r %RELEASE_FILE_NAME_PREFIX%-%TAG%-%COMMIT_HASH%.zip Modules Scripts
if %ERRORLEVEL% NEQ 0 (
    echo [91mZIP release package generation failed[0m.
    exit(%ERRORLEVEL%)
)

if %TAG%==TAGLESS (
    echo [93m%TAG%[0m[92m [92mrelease packages successfully generated[0m. Here they are:
) else (
    echo [92mRelease packages for version [0m[93m%TAG%[0m[92m successfully generated[0m. Here they are:
)
echo.
echo     - %RELEASE_PACKAGE_FOLDER_PATH%\%RELEASE_FILE_NAME_PREFIX%-%TAG%-%COMMIT_HASH%.exe
echo     - %RELEASE_PACKAGE_FOLDER_PATH%\%RELEASE_FILE_NAME_PREFIX%-%TAG%-%COMMIT_HASH%.zip

if %TAG%==TAGLESS (
    echo.
    echo Your release is tagless, which is not a problem.
    echo If you like to tag it, use git to tag the current repository HEAD and re-run this task.
)
