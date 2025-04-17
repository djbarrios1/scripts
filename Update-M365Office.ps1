# Update-M365Office.ps1

Write-Host "Checking for Microsoft 365 Office update..." -ForegroundColor Cyan

# Define the Click-to-Run executable path
$officeC2RPath = "${env:ProgramFiles}\Common Files\Microsoft Shared\ClickToRun\OfficeC2RClient.exe"

# Check if Click-to-Run exists
if (Test-Path $officeC2RPath) {
    Write-Host "Microsoft Office Click-to-Run detected. Starting update..." -ForegroundColor Green
    Start-Process -FilePath $officeC2RPath -ArgumentList "/update user" -Wait
    Write-Host "Office update process completed." -ForegroundColor Green
}
else {
    Write-Warning "Office Click-to-Run was not found. Microsoft 365 Office might not be installed on this machine or it's an MSI-based install."
}
