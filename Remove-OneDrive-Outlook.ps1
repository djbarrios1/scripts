
# ==============================================
# Remove-OneDrive-Outlook.ps1
# Fully removes OneDrive and Outlook (New)
# Cleans up after third-party uninstallers (e.g., Revo)
# ==============================================

Write-Host "`nStarting OneDrive and Outlook New cleanup..." -ForegroundColor Cyan

# --- Stop Running Processes ---
$processes = @("OneDrive", "outlook")
foreach ($proc in $processes) {
    Write-Host "Stopping process: $proc"
    Stop-Process -Name $proc -Force -ErrorAction SilentlyContinue
}

# --- Uninstall OneDrive via built-in method ---
$oneDriveSetup = "$env:SystemRoot\System32\OneDriveSetup.exe"
if (Test-Path $oneDriveSetup) {
    Write-Host "Running OneDrive uninstaller..."
    Start-Process $oneDriveSetup -ArgumentList "/uninstall" -Wait
} else {
    Write-Host "OneDriveSetup.exe not found. Skipping built-in uninstall..."
}

# --- Remove leftover folders ---
$folders = @(
    "$env:LOCALAPPDATA\Microsoft\OneDrive",
    "$env:PROGRAMDATA\Microsoft OneDrive",
    "$env:USERPROFILE\OneDrive",
    "$env:APPDATA\Microsoft\Outlook",
    "$env:LOCALAPPDATA\Packages\microsoft.windowscommunicationsapps*"
)
foreach ($folder in $folders) {
    if (Test-Path $folder) {
        Write-Host "Deleting folder: $folder"
        Remove-Item -Path $folder -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# --- Remove Registry Keys ---
$regKeys = @(
    "HKCU:\Software\Microsoft\OneDrive",
    "HKLM:\Software\Microsoft\OneDrive",
    "HKCU:\Software\Microsoft\Office\16.0\Outlook",
    "HKCU:\Software\Microsoft\Office\Outlook",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\OneDrive*"
)
foreach ($key in $regKeys) {
    if (Test-Path $key) {
        Write-Host "Removing registry key: $key"
        Remove-Item -Path $key -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# --- Prevent OneDrive from Reinstalling Automatically ---
Write-Host "Setting group policy to block OneDrive reinstall..."
New-Item -Path "HKLM:\Software\Policies\Microsoft\Windows\OneDrive" -Force | Out-Null
New-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows\OneDrive" -Name "DisableFileSync" -Value 1 -PropertyType DWORD -Force

Write-Host "`nCleanup complete. Please reboot the system to finalize." -ForegroundColor Green
Pause
