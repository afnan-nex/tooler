# Self-elevation to admin
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

# Configuration
$ToolDir = [Environment]::GetFolderPath('CommonApplicationData') + '\tooler'
$ExePath = Join-Path $ToolDir 'tooler.exe'
$DownloadUrl = 'https://raw.githubusercontent.com/afnan-nex/tooler/main/cpp-binary/tooler.exe'

# Create directory
[System.IO.Directory]::CreateDirectory($ToolDir) | Out-Null

# Kill existing process
Get-Process | Where-Object { $_.Name -like '*tooler*' } | Stop-Process -Force -ErrorAction SilentlyContinue

# Wait
Start-Sleep -Seconds 2

# Remove old exe
if (Test-Path $ExePath) { Remove-Item $ExePath -Force -ErrorAction Stop }

# Copy local binary if present in workspace/parent, otherwise download from GitHub
$localBinary = Join-Path $PSScriptRoot "tooler.exe"
if (-not (Test-Path $localBinary)) {
    $localBinary = Join-Path $PSScriptRoot "..\cs-binary\tooler.exe"
}

if (Test-Path $localBinary) {
    Write-Host "Copying local tooler.exe to $ExePath..." -ForegroundColor Cyan
    Copy-Item $localBinary $ExePath -Force
} else {
    Write-Host "Downloading tooler.exe from repository..." -ForegroundColor Cyan
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri ($DownloadUrl + '?v=' + (Get-Random)) -OutFile $ExePath -Headers @{'Cache-Control'='no-cache'}
}

# Add to machine/system PATH
$SystemPath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
if ($SystemPath -notlike ('*' + $ToolDir + '*')) {
    [Environment]::SetEnvironmentVariable('Path', ($SystemPath.TrimEnd(';') + ';' + $ToolDir), 'Machine')
}

# Add to user PATH
$UserPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($UserPath -notlike ('*' + $ToolDir + '*')) {
    [Environment]::SetEnvironmentVariable('Path', ($UserPath.TrimEnd(';') + ';' + $ToolDir), 'User')
}

# Add to current session PATH immediately
if ($env:Path -notlike ('*' + $ToolDir + '*')) {
    $env:Path = $env:Path.TrimEnd(';') + ";$ToolDir"
}

# Done
Write-Host ""
Write-Host "SUCCESS: tooler.exe installed to $ToolDir and added to SYSTEM, USER, and SESSION PATH!" -ForegroundColor Green
Write-Host "You can now type 'tooler' in any Command Prompt or PowerShell window." -ForegroundColor Cyan
Write-Host ""
Read-Host "Press Enter to exit..."
