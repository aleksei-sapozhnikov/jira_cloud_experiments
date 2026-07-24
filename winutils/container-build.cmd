@echo off
setlocal EnableExtensions

rem Resolve the repository root independently of the current directory.
for %%I in ("%~dp0..") do set "REPO_ROOT=%%~fI"

call :find_container_runtime
if errorlevel 1 goto :error

pushd "%REPO_ROOT%" >nul 2>&1
if errorlevel 1 (
  echo ERROR: Unable to enter repository directory: %REPO_ROOT%
  goto :error
)

echo Building jira-cloud-iac-dev with %CONTAINER_RUNTIME%...
%CONTAINER_RUNTIME% build -t jira-cloud-iac-dev .
set "EXIT_CODE=%ERRORLEVEL%"

popd

if not "%EXIT_CODE%"=="0" goto :error_with_code

echo Build completed successfully.
echo.
echo All done. Press any key to exit.
pause >nul
exit /b 0

:find_container_runtime
where docker >nul 2>&1
if not errorlevel 1 (
  set "CONTAINER_RUNTIME=docker"
  exit /b 0
)

where podman >nul 2>&1
if not errorlevel 1 (
  set "CONTAINER_RUNTIME=podman"
  exit /b 0
)

echo ERROR: Neither Docker nor Podman was found in PATH.
echo Install Docker Desktop, Docker CLI, or Podman and try again.
exit /b 1

:error
set "EXIT_CODE=%ERRORLEVEL%"
if "%EXIT_CODE%"=="0" set "EXIT_CODE=1"
goto :show_error

:error_with_code
if "%EXIT_CODE%"=="0" set "EXIT_CODE=1"

:show_error
echo.
echo The build command failed with exit code %EXIT_CODE%.
echo Press any key to close this window.
pause >nul
exit /b %EXIT_CODE%
