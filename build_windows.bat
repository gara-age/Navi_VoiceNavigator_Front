@echo off
setlocal EnableExtensions EnableDelayedExpansion

cd /d "%~dp0"

echo.
echo ==========================================
echo Navi Voice Navigator - Windows Build
echo ==========================================
echo Project Root: %CD%
echo.

where flutter >nul 2>nul
if errorlevel 1 (
  echo [ERROR] flutter command was not found.
  echo Install Flutter on Windows and add it to PATH first.
  exit /b 1
)

if not exist "windows\CMakeLists.txt" (
  echo [ERROR] Windows desktop project files were not found.
  exit /b 1
)

if not defined VOICE_NAVIGATOR_ROOT (
  set "VOICE_NAVIGATOR_ROOT=%CD%"
)

echo [1/4] Enabling Windows desktop support...
call flutter config --enable-windows-desktop
if errorlevel 1 (
  echo [ERROR] Failed to enable Windows desktop support.
  exit /b 1
)

echo [2/4] Fetching Dart and Flutter packages...
call flutter pub get
if errorlevel 1 (
  echo [ERROR] flutter pub get failed.
  exit /b 1
)

set "BUILD_CMD=flutter build windows --release"

if defined AGENT_API_BASE_URL (
  echo [INFO] Using AGENT_API_BASE_URL from environment.
  set "BUILD_CMD=%BUILD_CMD% --dart-define=AGENT_API_BASE_URL=%AGENT_API_BASE_URL%"
)

echo [3/4] Building Windows executable...
call %BUILD_CMD%
if errorlevel 1 (
  echo [ERROR] Windows build failed.
  exit /b 1
)

set "OUTPUT_EXE=build\windows\x64\runner\Release\navi_front.exe"
echo [4/4] Build completed.
echo.
echo Output EXE:
echo   %CD%\%OUTPUT_EXE%
echo.

if exist "%OUTPUT_EXE%" (
  echo You can run the built app from:
  echo   %CD%\%OUTPUT_EXE%
) else (
  echo [WARN] Build finished but the expected EXE path was not found.
)

endlocal
