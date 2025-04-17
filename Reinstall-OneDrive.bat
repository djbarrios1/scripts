@echo off
setlocal
echo ===============================
echo OneDrive Reinstallation Script
echo ===============================

:: Kill running OneDrive if active
taskkill /f /im OneDrive.exe >nul 2>&1

:: Check for OneDriveSetup in System32
if exist "%SystemRoot%\System32\OneDriveSetup.exe" (
    echo Reinstalling OneDrive from System32...
    "%SystemRoot%\System32\OneDriveSetup.exe" /install
    goto done
)

:: Check 32-bit fallback location
if exist "%SystemRoot%\SysWOW64\OneDriveSetup.exe" (
    echo Reinstalling OneDrive from SysWOW64...
    "%SystemRoot%\SysWOW64\OneDriveSetup.exe" /install
    goto done
)

:: If neither found, direct user to download
echo OneDrive setup executable not found on this system.
echo Opening Microsoft download page...
start https://www.microsoft.com/en-us/microsoft-365/onedrive/download
goto end

:done
echo.
echo OneDrive reinstall initiated. It may take a few seconds to appear.
echo You can manually start it with:
echo %LOCALAPPDATA%\Microsoft\OneDrive\OneDrive.exe

:end
pause
