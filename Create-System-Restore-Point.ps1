<#
.SYNOPSIS
    Creates a system restore point with logging and checks if restore is enabled.

.NOTES
    Must be run as Administrator.
    Tested on Windows 10 and 11.
#>

# Configuration
$drive = "C:\"
$logFile = "$PSScriptRoot\RestorePointLog_$(Get-Date -Format 'yyyyMMdd').log"
$restorePointName = "ManualRestore_$(Get-Date -Format 'yyyyMMdd_HHmmss')"

# Logging function
function Write-Log {
    param ([string]$message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "$timestamp - $message"
    Write-Output $entry
    Add-Content -Path $logFile -Value $entry
}

# Ensure script is run as Administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "ERROR: This script must be run as Administrator." -ForegroundColor Red
    Write-Log "ERROR: Script not run as Administrator. Exiting."
    exit 1
}

Write-Log "Starting restore point script."

# Check if System Restore is enabled
try {
    $srstatus = Get-ComputerRestorePoint -ErrorAction Stop
    Write-Log "System Restore appears to be enabled. Proceeding."
}
catch {
    # Double-check using COM object (in case Get-ComputerRestorePoint throws on clean systems)
    $srClient = New-Object -ComObject 'SystemRestore.SystemRestore'
    if ($srClient.DisableSR("C:\") -eq $true) {
        Write-Log "System Restore is DISABLED on drive C:. Aborting."
        Write-Host "System Restore is disabled on C:. Enable it before running this script." -ForegroundColor Yellow
        exit 1
    } else {
        Write-Log "System Restore seems enabled. Proceeding."
    }
}

# Create Restore Point
try {
    CheckPoint-Computer -Description $restorePointName -RestorePointType "MODIFY_SETTINGS"
    Write-Host "Restore point '$restorePointName' created successfully." -ForegroundColor Green
    Write-Log "Restore point '$restorePointName' created successfully."
}
catch {
    Write-Host "ERROR: Failed to create restore point." -ForegroundColor Red
    Write-Log "ERROR: Failed to create restore point. $_"
    exit 1
}

Write-Log "Script completed."
