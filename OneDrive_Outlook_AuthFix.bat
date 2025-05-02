@echo off
echo =====================================
echo Cleaning up OneDrive and Outlook Auth
echo =====================================

:: Kill processes
echo Closing OneDrive and Outlook...
taskkill /f /im onedrive.exe >nul 2>&1
taskkill /f /im outlook.exe >nul 2>&1

:: Delete auth/token folders
echo Deleting WebView2 and auth token caches...
rmdir /s /q "%LocalAppData%\Microsoft\OneAuth"
rmdir /s /q "%LocalAppData%\Microsoft\IdentityCache"
rmdir /s /q "%LocalAppData%\Microsoft\OneDrive"
rmdir /s /q "%LocalAppData%\Packages\Microsoft.AAD.BrokerPlugin_cw5n1h2txyewy"
rmdir /s /q "%LocalAppData%\Packages\Microsoft.Windows.CloudExperienceHost_cw5n1h2txyewy"

:: Clear credential manager entries
echo Removing saved credentials related to Microsoft services...
for /f "tokens=*" %%a in ('cmdkey /list ^| findstr /i "Microsoft OneDrive Azure WindowsLive SSO"') do (
    for /f "tokens=2 delims=:" %%b in ("%%a") do (
        cmdkey /delete:%%b >nul 2>&1
    )
)

echo.
echo Cleanup complete. A reboot is required.
pause

shutdown /r /t 15 /c "Restarting to finalize OneDrive and Outlook auth fix..."
