# Define a function to log messages with timestamps
function LogMessage {
    param (
        [string]$Message,
        [string]$Color = "White"
    )
    $Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    Write-Host "$Timestamp - $Message" -ForegroundColor $Color
}

# Validate COM port status at script start
if (-not $port -or -not ($port -is [System.IO.Ports.SerialPort]) -or -not $port.IsOpen) {
    LogMessage "COM port is not initialized or closed. Exiting." -Color "Red"
    exit 1
}

# Start logging
LogMessage "Starting Windows Update process..."

# Create Update Session
$Session = New-Object -ComObject Microsoft.Update.Session
$Searcher = $Session.CreateUpdateSearcher()

# Search for Updates
LogMessage "Searching for updates..."
$SearchResult = $Searcher.Search("IsInstalled=0")

# Check if updates are available
if ($SearchResult.Updates.Count -eq 0) {
    LogMessage "System already up-to-date" -Color "Green"
    $port.WriteLine('0')
    exit 0
}

# Display updates found
LogMessage "$($SearchResult.Updates.Count) update(s) found."
$UpdatesToInstall = New-Object -ComObject Microsoft.Update.UpdateColl
foreach ($Update in $SearchResult.Updates) {
    LogMessage "Update found: $($Update.Title)"
    $UpdatesToInstall.Add($Update) | Out-Null
}

# Process updates one by one (download + install)
foreach ($Update in $SearchResult.Updates) {
    LogMessage "Processing: $($Update.Title)" -Color "Cyan"

    # Download the update
    try {
        LogMessage "Downloading $($Update.Title)..."
        $Downloader = $Session.CreateUpdateDownloader()
        $SingleUpdateColl = New-Object -ComObject Microsoft.Update.UpdateColl
        $SingleUpdateColl.Add($Update) | Out-Null
        $Downloader.Updates = $SingleUpdateColl
        $DownloadResult = $Downloader.Download()

        if ($DownloadResult.ResultCode -ne 2) {
            LogMessage "Download failed (Result code: $($DownloadResult.ResultCode))"
            $port.WriteLine('1')
            exit 1
        }
        LogMessage "Downloaded successfully." -Color "Green"
    } catch {
        LogMessage "ERROR downloading $($Update.Title): $_" -Color "Red"
        $port.WriteLine('1')
        exit 1
    }

    # Install the update
    try {
        LogMessage "Installing $($Update.Title)..."
        $Installer = $Session.CreateUpdateInstaller()
        $Installer.Updates = $SingleUpdateColl
        $InstallResult = $Installer.Install()

        if ($InstallResult.ResultCode -ne 2) {
            LogMessage "Installation failed (Result code: $($InstallResult.ResultCode))"
            $port.WriteLine('1')
            exit 1
        }
        LogMessage "Installed successfully." -Color "Green"
    } catch {
        LogMessage "ERROR installing $($Update.Title): $_" -Color "Red"
        $port.WriteLine('1')
        exit 1
    }
}

LogMessage "Windows Update process completed."
$port.WriteLine('0')
exit 0
