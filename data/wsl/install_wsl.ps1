# Install WSL from the GitHub release page without the GitHub API
#
# "wsl --install" and "wsl --update" look up the latest release with the
# GitHub API. The API has a rate limit per IP address and fails with
# "Forbidden (403)" when the openQA workers have used it up.
#
# Usage: install_wsl.ps1 [-Tag 3.0.3]
param(
    [string]$Tag
)

$ErrorActionPreference = 'Stop'

if (-not $Tag) {
    # releases/latest redirects to the newest release that is not a pre-release
    $headers = curl.exe --silent --show-error --head https://github.com/microsoft/WSL/releases/latest
    $Tag = (($headers | Select-String -Pattern '^location:\s*(\S+)').Matches.Groups[1].Value -split '/')[-1]
    if (-not $Tag) { throw 'Could not find the latest WSL release' }
}

$assets = curl.exe --silent --show-error --location "https://github.com/microsoft/WSL/releases/expanded_assets/$Tag"
$path = ($assets | Select-String -Pattern 'href="([^"]*x64\.msi)"').Matches.Groups[1].Value
if (-not $path) { throw "No x64 msi in the WSL release $Tag" }

$msi = Join-Path $env:TEMP (Split-Path $path -Leaf)
curl.exe --silent --show-error --location --fail --output $msi "https://github.com$path"
if ($LASTEXITCODE -ne 0) { throw "Could not download $path" }

# 3010 means that a restart is needed, the test reboots later
$process = Start-Process msiexec -ArgumentList "/i `"$msi`" /qn /norestart" -Wait -PassThru
if ($process.ExitCode -notin 0, 3010) { throw "msiexec failed with exit code $($process.ExitCode)" }

Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -All -NoRestart | Out-Null

[Console]::OutputEncoding = [System.Text.Encoding]::Unicode
wsl --version
