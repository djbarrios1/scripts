# Update-All-WithOffice.ps1

# Ensure Chocolatey is installed
if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "Chocolatey not found. Installing..."
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
}

# Update all Chocolatey packages
Write-Host "Updating all Chocolatey packages..."
choco upgrade all -y --ignore-checksums --no-progress

# Trigger Office update (Click-to-Run)
Write-Host "Checking for Microsoft Office updates..."
$officeClient = "${env:ProgramFiles}\Common Files\Microsoft Shared\ClickToRun\OfficeC2RClient.exe"
if (Test-Path $officeClient) {
    Start-Process -FilePath $officeClient -ArgumentList "/update user" -Wait
    Write-Host "Office update initiated."
} else {
    Write-Host "Office Click-to-Run client not found. Skipping Office update."
}

# Log the update
$logPath = "$env:ProgramData\choco-updates\update-log.txt"
New-Item -ItemType Directory -Path (Split-Path $logPath) -Force | Out-Null
"Update run completed at $(Get-Date)" | Out-File -FilePath $logPath -Append
