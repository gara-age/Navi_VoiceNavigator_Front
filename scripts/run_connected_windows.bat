@echo off
setlocal EnableExtensions

cd /d "%~dp0\.."

set "AGENT_API_BASE_URL=https://kky.tail0a6d17.ts.net/agent/plan"
set "DEVICE=windows"
set "SKIP_PUB_GET=0"
set "FORCE_SETUP_AUTOMATION=0"
set "NEEDS_AUTOMATION_SETUP=0"
set "EXTRA_ARGS="

:parse_args
if "%~1"=="" goto after_parse

if /I "%~1"=="--help" goto show_help
if /I "%~1"=="-h" goto show_help

if /I "%~1"=="--api-url" (
  if "%~2"=="" (
    echo [ERROR] --api-url requires a value.
    exit /b 1
  )
  set "AGENT_API_BASE_URL=%~2"
  shift
  shift
  goto parse_args
)

if /I "%~1"=="--device" (
  if "%~2"=="" (
    echo [ERROR] --device requires a value.
    exit /b 1
  )
  set "DEVICE=%~2"
  shift
  shift
  goto parse_args
)

if /I "%~1"=="--skip-pub-get" (
  set "SKIP_PUB_GET=1"
  shift
  goto parse_args
)

if /I "%~1"=="--setup-automation" (
  set "FORCE_SETUP_AUTOMATION=1"
  shift
  goto parse_args
)

set "EXTRA_ARGS=%EXTRA_ARGS% %~1"
shift
goto parse_args

:after_parse
where flutter >nul 2>nul
if errorlevel 1 (
  echo [ERROR] flutter command was not found.
  echo Install Flutter and add it to PATH first.
  exit /b 1
)

if not exist "pubspec.yaml" (
  echo [ERROR] pubspec.yaml was not found.
  echo Run this script from the Navi_front project.
  exit /b 1
)

if "%FORCE_SETUP_AUTOMATION%"=="1" (
  set "NEEDS_AUTOMATION_SETUP=1"
) else (
  if not exist ".venv-server\Scripts\python.exe" (
    set "NEEDS_AUTOMATION_SETUP=1"
    echo [INFO] Automation Python environment was not found.
  ) else (
    .\.venv-server\Scripts\python.exe -m playwright --version >nul 2>nul
    if errorlevel 1 (
      set "NEEDS_AUTOMATION_SETUP=1"
      echo [INFO] Playwright was not available in .venv-server.
    )
  )
)

if "%NEEDS_AUTOMATION_SETUP%"=="1" (
  echo [1/4] Preparing local automation environment...
  powershell -ExecutionPolicy Bypass -File scripts\setup_automation_env.ps1
  if errorlevel 1 exit /b %errorlevel%
) else (
  echo [1/4] Automation environment is ready.
)

if "%SKIP_PUB_GET%" neq "1" (
  echo [2/4] Running flutter pub get...
  call flutter pub get
  if errorlevel 1 exit /b %errorlevel%
) else (
  echo [2/4] Skipping flutter pub get...
)

echo [3/4] Launching Flutter app...
echo        Device: %DEVICE%
echo        AGENT_API_BASE_URL: %AGENT_API_BASE_URL%

call flutter run -d %DEVICE% --dart-define=AGENT_API_BASE_URL=%AGENT_API_BASE_URL%%EXTRA_ARGS%
set "EXIT_CODE=%errorlevel%"

echo [4/4] Finished with exit code %EXIT_CODE%.
exit /b %EXIT_CODE%

:show_help
echo Usage:
echo   run_connected_windows.bat [--api-url URL] [--device DEVICE] [--skip-pub-get] [--setup-automation] [extra flutter args]
echo.
echo Examples:
echo   run_connected_windows.bat
echo   run_connected_windows.bat --setup-automation
echo   run_connected_windows.bat --api-url https://example.com/agent/plan
echo   run_connected_windows.bat --skip-pub-get --verbose
exit /b 0
