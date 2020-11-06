@echo off
set DEV_ENV_EXTRACT_FOLDER=.\TEMP\BOILERPLATE

if exist %DEV_ENV_EXTRACT_FOLDER% (
    rmdir /S /Q %DEV_ENV_EXTRACT_FOLDER%
)

xcopy /Y /S /E .vscode\ %DEV_ENV_EXTRACT_FOLDER%\.vscode\
xcopy /Y /S /E .\build\ %DEV_ENV_EXTRACT_FOLDER%\build\
xcopy /Y .\test-framework\*.* %DEV_ENV_EXTRACT_FOLDER%\test-framework\*.*
xcopy /Y /S /E .\test-framework\test-dependencies\ %DEV_ENV_EXTRACT_FOLDER%\test-framework\test-dependencies\
xcopy /Y .\DEVELOPMENT_ENVIRONMENT.md %DEV_ENV_EXTRACT_FOLDER%\
xcopy /Y .\.gitignore %DEV_ENV_EXTRACT_FOLDER%\

echo.
echo [92mOK[0m: Extracted generic parts of current development environment to [94m%DEV_ENV_EXTRACT_FOLDER%[0m
echo Copy its contents to your other FlyWithLua projects to obtain a fresh copy of test stubs and build tasks.
echo.
echo Opening extract folder ...
start "" %DEV_ENV_EXTRACT_FOLDER%