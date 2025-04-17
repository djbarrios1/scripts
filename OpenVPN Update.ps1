try {
    # Get the installed version of OpenVPN (Option 1: from Uninstall registry key)
    $currentVersion = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\OpenVPN').DisplayVersion

    # Fetch the latest version from OpenVPN's community downloads page
    $pageContent = Invoke-WebRequest -Uri 'https://openvpn.net/community-downloads/' -UseBasicParsing

    # Extract the latest version number from the page content
    $latestVersion = $pageContent.Content | Select-String -Pattern 'Latest version (\d+\.\d+\.\d+)' | ForEach-Object { $_.Matches[0].Groups[1].Value }

    # Extract the correct download URL for the latest version
    $updateURL = $pageContent.Links | Where-Object { $_.href -like "*openvpn-install-*$latestVersion.exe" } | Select-Object -First 1 | ForEach-Object { $_.href }

    # Check if there's a newer version available
    if ($latestVersion -ne $currentVersion) {
        Write-Output "Updating OpenVPN from version $currentVersion to $latestVersion."

        # Download and install the latest version
        Invoke-WebRequest -Uri $updateURL -OutFile "$env:TEMP\openvpn-update.exe"
        
        # Silent installation of the update
        Start-Process "$env:TEMP\openvpn-update.exe" -ArgumentList '/S' -Wait
        
        # Clean up the installer
        Remove-Item "$env:TEMP\openvpn-update.exe"

        Write-Output "Update completed successfully."
    } else {
        Write-Output "OpenVPN is already up to date (version $currentVersion)."
    }
}
catch {
    Write-Error "An error occurred during the update process: $_"
}
