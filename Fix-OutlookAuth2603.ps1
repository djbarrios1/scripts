Write-Host "Fixing Outlook Sign-In Issues... Please wait.`n"

# Ensure this is running as admin
If (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
    [Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "Please run this script as Administrator."
    exit
}

# Step 1: Kill relevant apps
Write-Host "Closing Outlook and OneDrive..."
Stop-Process -Name outlook -Force -ErrorAction SilentlyContinue
Stop-Process -Name onedrive -Force -ErrorAction SilentlyContinue

# Step 2: Reset App Packages
Write-Host "Resetting AAD Broker Plugin and CloudExperienceHost..."
Get-AppxPackage Microsoft.AAD.BrokerPlugin | Reset-AppxPackage -ErrorAction SilentlyContinue
Get-AppxPackage Microsoft.Windows.CloudExperienceHost | Reset-AppxPackage -ErrorAction SilentlyContinue

# Step 3: Clear Office Auth Registry Keys
Write-Host "Removing Office Identity and Internet keys..."
Remove-Item -Path "HKCU:\Software\Microsoft\Office\16.0\Common\Identity" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "HKCU:\Software\Microsoft\Office\16.0\Common\Internet" -Recurse -Force -ErrorAction SilentlyContinue

# Step 4: Enforce ADAL fallback (disables WebView2 sign-in)
Write-Host "Rewriting Identity auth settings to bypass Web Sign-In..."
New-Item -Path "HKCU:\Software\Microsoft\Office\16.0\Common\Identity" -Force | Out-Null
New-ItemProperty -Path "HKCU:\Software\Microsoft\Office\16.0\Common\Identity" -Name "EnableADAL" -Value 1 -PropertyType DWORD -Force
New-ItemProperty -Path "HKCU:\Software\Microsoft\Office\16.0\Common\Identity" -Name "DisableADALatopWAMOverride" -Value 1 -PropertyType DWORD -Force
New-ItemProperty -Path "HKCU:\Software\Microsoft\Office\16.0\Common\Identity" -Name "EnableWebSignIn" -Value 0 -PropertyType DWORD -Force
New-ItemProperty -Path "HKCU:\Software\Microsoft\Office\16.0\Common\Identity" -Name "UseWebSignIn" -Value 0 -PropertyType DWORD -Force

# Step 5: Clean Up Local Package Caches (if still present)
Write-Host "Removing leftover token handler folders (if they exist)..."
$folders = @(
    "$env:LOCALAPPDATA\Packages\Microsoft.AAD.BrokerPlugin_cw5n1h2txyewy",
    "$env:LOCALAPPDATA\Packages\Microsoft.Windows.CloudExperienceHost_cw5n1h2txyewy"
)
foreach ($folder in $folders) {
    if (Test-Path $folder) {
        Remove-Item -Path $folder -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "Deleted: $folder"
    }
}

Write-Host "`nFix complete. Please reboot the machine to finalize repairs."
Start-Sleep -Seconds 5
shutdown /r /t 15 /c "Restarting to finalize Outlook sign-in repair..."

exit
