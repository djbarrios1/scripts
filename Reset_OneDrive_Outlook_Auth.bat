@echo off
setlocal
set LOG=%TEMP%\auth_cleanup_log.txt

:: Check for Admin Privileges
net session >nul 2>&1
if %errorlevel% NEQ 0 (
    echo This script must be run as Administrator.
    echo Right-click and choose "Run as Administrator".
    pause
    exit /b
)

echo ============================================
echo   Resetting OneDrive and Outlook Auth Cache
echo ============================================
echo Logging to: %LOG%
echo.

echo ==== KILLING PROCESSES ==== >> "%LOG%"
echo Closing OneDrive and Outlook...
taskkill /f /im onedrive.exe >> "%LOG%" 2>&1
taskkill /f /im outlook.exe >> "%LOG%" 2>&1

echo. >> "%LOG%"
echo ==== DELETING TOKEN CACHE FOLDERS ==== >> "%LOG%"
echo Deleting OneAuth, IdentityCache, and WebView2 folders...
rmdir /s /q "%LocalAppData%\Microsoft\OneAuth" >> "%LOG%" 2>&1
rmdir /s /q "%LocalAppData%\Microsoft\IdentityCache" >> "%LOG%" 2>&1
rmdir /s /q "%LocalAppData%\Microsoft\OneDrive" >> "%LOG%" 2>&1
rmdir /s /q "%LocalAppData%\Packages\Microsoft.AAD.BrokerPlugin_cw5n1h2txyewy" >> "%LOG%" 2>&1
rmdir /s /q "%LocalAppData%\Packages\Microsoft.Windows.CloudExperienceHost_cw5n1h2txyewy" >> "%LOG%" 2>&1

echo. >> "%LOG%"
echo ==== CLEARING CREDENTIAL MANAGER ENTRIES ==== >> "%LOG%"
echo Removing saved credentials...
for /f "tokens=*" %%a in ('cmdkey /list ^| findstr /i "Microsoft OneDrive Azure WindowsLive SSO"') do (
    for /f "tokens=2 delims=:" %%b in ("%%a") do (
        echo Deleting credential: %%b >> "%LOG%"
        cmdkey /delete:%%b >nul 2>&1
    )
)

echo. >> "%LOG%"
echo ==== REGISTRY CLEANUP (HKCU) ==== >> "%LOG%"
echo Removing Office identity and internet keys...
reg delete "HKCU\Software\Microsoft\Office\16.0\Common\Identity" /f >> "%LOG%" 2>&1
reg delete "HKCU\Software\Microsoft\Office\16.0\Common\Internet" /f >> "%LOG%" 2>&1

echo.
echo All cleanup steps complete. A system reboot is required.
echo A reboot will occur in 15 seconds. Cancel now if needed.
pause

shutdown /r /t 15 /c "Restarting to finalize OneDrive and Outlook auth fix..."
