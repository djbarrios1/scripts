# Fix-ExcelPrintDialogIssue.ps1
Write-Host "`n=== Fixing Excel Print Dialog Lock Issue ===`n"

# 1. Close Excel if open
Write-Host "Closing Excel processes..."
Stop-Process -Name "EXCEL" -Force -ErrorAction SilentlyContinue

# 2. Remove Excel printer cache registry keys
$excelVersion = "16.0"  # Adjust if using older version (e.g., 15.0 = Office 2013)

$registryPaths = @(
    "HKCU:\Software\Microsoft\Office\$excelVersion\Excel\Options",
    "HKCU:\Software\Microsoft\Office\$excelVersion\Common\Print",
    "HKCU:\Software\Microsoft\Office\$excelVersion\Word\Options"
)

foreach ($path in $registryPaths) {
    if (Test-Path $path) {
        try {
            Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
            Write-Host "Removed registry key: $path"
        } catch {
            Write-Warning "Failed to remove registry key: $path - $_"
        }
    } else {
        Write-Host "Registry key not found: $path"
    }
}

# 3. Rename startup templates if they exist
$personalTemplate = "$env:APPDATA\Microsoft\Excel\XLSTART\Personal.xlsb"
$normalTemplate = "$env:APPDATA\Microsoft\Templates\Normal.dotm"

if (Test-Path $personalTemplate) {
    Rename-Item $personalTemplate -NewName "Personal_backup.xlsb" -Force
    Write-Host "Backed up Personal.xlsb"
}

if (Test-Path $normalTemplate) {
    Rename-Item $normalTemplate -NewName "Normal_backup.dotm" -Force
    Write-Host "Backed up Normal.dotm"
}

# 4. Summary
Write-Host "`n✅ Fix completed. Please relaunch Excel and test print functionality."
Write-Host "If problem persists, try opening Excel in safe mode: excel /safe"
Write-Host "Or perform a Quick Repair via Control Panel."

