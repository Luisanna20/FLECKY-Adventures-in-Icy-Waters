@echo off
setlocal
set "PROJECT_DIR=%~dp0"
set "GODOT_EXE=%PROJECT_DIR%tools\Godot_v4.6.3-stable_win64.exe"

if not exist "%GODOT_EXE%" (
    echo [FLAKI] Godot executable was not found:
    echo %GODOT_EXE%
    echo.
    pause
    exit /b 2
)

cd /d "%PROJECT_DIR%"
"%GODOT_EXE%" --editor --path "%PROJECT_DIR%." %*
set "FLAKI_EXIT_CODE=%ERRORLEVEL%"

if not "%FLAKI_EXIT_CODE%"=="0" (
    echo.
    echo [FLAKI] Godot editor could not start. Error code: %FLAKI_EXIT_CODE%
    echo.
    pause
)

endlocal & exit /b %FLAKI_EXIT_CODE%
