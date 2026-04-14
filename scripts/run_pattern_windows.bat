@echo off
setlocal EnableExtensions
chcp 65001 >nul
set "PYTHONIOENCODING=utf-8"
set "PYTHONUTF8=1"

cd /d "%~dp0\.."

set "TASK_FILE="
set "FORCE_SETUP_AUTOMATION=0"
set "PAUSE_ON_ERROR=1"
set "EXIT_CODE=0"

:parse_args
if "%~1"=="" goto after_parse

if /I "%~1"=="--help" goto show_help
if /I "%~1"=="-h" goto show_help

if /I "%~1"=="--task-file" (
  if "%~2"=="" (
    echo [ERROR] --task-file requires a value.
    set "EXIT_CODE=1"
    goto pause_and_exit
  )
  set "TASK_FILE=%~f2"
  shift
  shift
  goto parse_args
)

if /I "%~1"=="--setup-automation" (
  set "FORCE_SETUP_AUTOMATION=1"
  shift
  goto parse_args
)

if /I "%~1"=="--no-pause-on-error" (
  set "PAUSE_ON_ERROR=0"
  shift
  goto parse_args
)

if "%TASK_FILE%"=="" (
  set "TASK_FILE=%~f1"
  shift
  goto parse_args
)

echo [ERROR] Unknown argument: %~1
echo Use --help for usage.
set "EXIT_CODE=1"
goto pause_and_exit

:after_parse
if "%TASK_FILE%"=="" (
  echo [ERROR] task JSON path is required.
  echo Use --help for usage.
  set "EXIT_CODE=1"
  goto pause_and_exit
)

if not exist "%TASK_FILE%" (
  echo [ERROR] task file was not found:
  echo         %TASK_FILE%
  set "EXIT_CODE=1"
  goto pause_and_exit
)

if not exist "pubspec.yaml" (
  echo [ERROR] pubspec.yaml was not found.
  echo Run this script from the Navi_front project.
  set "EXIT_CODE=1"
  goto pause_and_exit
)

set "NEEDS_AUTOMATION_SETUP=0"
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
  echo [1/2] Preparing local automation environment...
  powershell -ExecutionPolicy Bypass -File scripts\setup_automation_env.ps1
  if errorlevel 1 (
    set "EXIT_CODE=%errorlevel%"
    goto pause_and_exit
  )
) else (
  echo [1/2] Automation environment is ready.
)

echo [2/2] Running pattern automation task...
echo        Task file: %TASK_FILE%

call .\.venv-server\Scripts\python.exe -m local_server.app.simulation.pattern_agent_scenario "%TASK_FILE%"
set "EXIT_CODE=%errorlevel%"

echo Finished with exit code %EXIT_CODE%.
goto pause_and_exit

:show_help
echo Usage:
echo   run_pattern_windows.bat [task.json]
echo   run_pattern_windows.bat --task-file task.json [--setup-automation] [--no-pause-on-error]
echo.
echo Task JSON shape:
echo   {
echo     "site": "https://example.com",
echo     "user_request": "Route from Songnae Station to Seoul Station"
echo   }
echo.
echo Sample file:
echo   scripts\examples\pattern_task.sample.json
echo.
echo Optional fields:
echo   - intent: precomputed structured intent
echo   - host_bias: lightweight host bias metadata
echo   - metadata: extra execution metadata
echo.
echo Examples:
echo   run_pattern_windows.bat C:\temp\pattern_task.json
echo   run_pattern_windows.bat --task-file C:\temp\pattern_task.json
echo   run_pattern_windows.bat --setup-automation C:\temp\pattern_task.json
set "EXIT_CODE=0"
goto finalize

:pause_and_exit
if not "%EXIT_CODE%"=="0" (
  if "%PAUSE_ON_ERROR%"=="1" (
    echo.
    echo Press any key to close this window...
    pause >nul
  )
)

:finalize
exit /b %EXIT_CODE%
