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

echo.

if %TAG%==TAGLESS (
    echo [93mTagless[0m[92m [92mrelease packages successfully generated[0m. Here they are:
) else (
    echo [92mRelease packages for version [0m[93m%TAG%[0m[92m successfully generated[0m. Here they are:
)
echo.
echo     [94m%RELEASE_PACKAGE_FOLDER_PATH%\%RELEASE_FILE_NAME_PREFIX%-%TAG%-%COMMIT_HASH%.exe[0m
echo     [94m%RELEASE_PACKAGE_FOLDER_PATH%\%RELEASE_FILE_NAME_PREFIX%-%TAG%-%COMMIT_HASH%.zip[0m

if %TAG%==TAGLESS (
    echo.
    echo Your release is tagless, which is not a problem.
    echo If you like to tag it, [93muse git to tag[0m the current repository HEAD and re-run this task.
    echo [93mPush the tag[0m to git right after to see it in the Github 'Draft Release' page.
    goto :label_end
)

set OPEN_RELEASE_PAGES_TIMEOUT=5
setlocal enabledelayedexpansion

set DEFAULT_GITHUB_REPO_URL_WITHOUT_QUOTES=%DEFAULT_GITHUB_REPO_URL:"=%

if !GITHUB_REPO_URL!==!DEFAULT_GITHUB_REPO_URL_WITHOUT_QUOTES! (
    echo.
    echo You didn't set a [93mGithub URL[0m for your project yet. If you like to have a prepared 'Draft Release' page open after generating
    echo a new tagged release, update the Github project URL in [94m.\build_configuration.cmd[0m and re-run this task.
    echo.
    echo Opening release package folder in %OPEN_RELEASE_PAGES_TIMEOUT% seconds ...
    timeout /T %OPEN_RELEASE_PAGES_TIMEOUT%
    start "" .
) else (
    echo.
    echo Opening release package folder and Github 'Draft Release' in %OPEN_RELEASE_PAGES_TIMEOUT% seconds ...
    timeout /T %OPEN_RELEASE_PAGES_TIMEOUT%
    start "" %GITHUB_REPO_URL%/releases/new?tag=%TAG%^&title=RELEASE_TITLE_HERE^&body=RELEASE_DESCRIPTION_HERE
    start "" .
)

:label_end