@echo off
call .\build\configure_environment.cmd
if %ERRORLEVEL% NEQ 0 exit /B %ERRORLEVEL%

setlocal enabledelayedexpansion

for /F "tokens=*" %%h in ('%GIT_EXECUTABLE% tag --points-at HEAD') do (set TAG=%%h)
if not defined TAG (set tag=TAGLESS)

for /F "tokens=*" %%h in ('%GIT_EXECUTABLE% rev-parse --short HEAD') do (set COMMIT_HASH=%%h)

if %ERRORLEVEL% GTR 0 (
    exit(%ERRORLEVEL%)
)

set RELEASE_PACKAGE_FOLDER_PATH=.\TEMP\RELEASE_PACKAGE

if exist %RELEASE_PACKAGE_FOLDER_PATH% (
    rmdir /S /Q %RELEASE_PACKAGE_FOLDER_PATH%
)

mkdir %RELEASE_PACKAGE_FOLDER_PATH%

mkdir %RELEASE_PACKAGE_FOLDER_PATH%\Modules
mkdir %RELEASE_PACKAGE_FOLDER_PATH%\Scripts

if not exist script_modules\%RELEASE_FILE_NAME_PREFIX% (
    mkdir script_modules\%RELEASE_FILE_NAME_PREFIX%
)

echo %TAG%> script_modules\%RELEASE_FILE_NAME_PREFIX%\release_tag.txt
echo %COMMIT_HASH%> script_modules\%RELEASE_FILE_NAME_PREFIX%\release_commit_hash.txt

xcopy /Y /S /E scripts\* %RELEASE_PACKAGE_FOLDER_PATH%\Scripts\*
xcopy /Y /S /E script_modules\* %RELEASE_PACKAGE_FOLDER_PATH%\Modules\*
xcopy /Y /S /E modules\* %RELEASE_PACKAGE_FOLDER_PATH%\Modules\*

%NSIS_EXECUTABLE% "/XOutFile ..\%RELEASE_PACKAGE_FOLDER_PATH%\%RELEASE_FILE_NAME_PREFIX%-%TAG%-%COMMIT_HASH%.exe" .\build\generate-installer.nsi
if %ERRORLEVEL% NEQ 0 (
    echo [91mNSIS Installer generation failed[0m.
    exit(%ERRORLEVEL%)
)

cd %RELEASE_PACKAGE_FOLDER_PATH%

%SEVEN_ZIP_EXECUTABLE% a -r %RELEASE_FILE_NAME_PREFIX%-%TAG%-%COMMIT_HASH%.zip Modules Scripts
if %ERRORLEVEL% NEQ 0 (
    echo [91mZIP release package generation failed[0m.
    exit(%ERRORLEVEL%)
)

echo.

if %TAG%==TAGLESS (
    echo [93mTagless[0m[92m [92mrelease packages successfully generated[0m. Here they are:
    echo.
    echo     %RELEASE_PACKAGE_FOLDER_PATH%\%RELEASE_FILE_NAME_PREFIX%-%TAG%-%COMMIT_HASH%.exe
    echo     %RELEASE_PACKAGE_FOLDER_PATH%\%RELEASE_FILE_NAME_PREFIX%-%TAG%-%COMMIT_HASH%.zip
) else (
    echo [92mRelease packages for version %TAG% successfully generated[0m. Here they are:
    echo.
    echo     [94m%RELEASE_PACKAGE_FOLDER_PATH%\%RELEASE_FILE_NAME_PREFIX%-[92m%TAG%[0m[94m-%COMMIT_HASH%.exe[0m
    echo     [94m%RELEASE_PACKAGE_FOLDER_PATH%\%RELEASE_FILE_NAME_PREFIX%-[92m%TAG%[0m[94m-%COMMIT_HASH%.zip[0m
)

if %TAG%==TAGLESS (
    echo.
    echo Your release is tagless, which is not a problem.
    echo If you like to tag it, use git to [93mtag the current repository HEAD[0m and [93mpush the tag[0m
    echo right after to see it in the Github 'Draft Release' page when re-running this task.
    goto :label_end
) else (
    echo.
    echo Don't forget to push the release tag to make Github recognize it in the 'Draft Release' page.
)

set OPEN_RELEASE_PAGES_TIMEOUT=5

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

    set KNOWN_ISSUES_FILE_PATH=.\..\..\script_modules\!RELEASE_FILE_NAME_PREFIX!\known_issues_url_encoded.txt
    
    set KNOWN_ISSUES=---YOUR-MANUAL-CHANGELOG-HERE---%%0a%%0a
    for /F "tokens=*" %%A in (!KNOWN_ISSUES_FILE_PATH!) do (
        set KNOWN_ISSUES=!KNOWN_ISSUES!%%A
    )

    start "" %GITHUB_REPO_URL%/releases/new?tag=%TAG%^&title=---RELEASE-TITLE-HERE---^&body=!KNOWN_ISSUES!
    start "" .
)

goto :label_end

:label_end
exit /B %ERRORLEVEL%