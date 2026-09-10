# ============================================================
#  Tools Installer -> Tooler Migration & Updater
#  by AFNAN (https://github.com/afnan-nex/tooler)
# ============================================================

# Ensure Administrator Privileges
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

[Console]::Title = "Tools Installer -> Tooler Updater"
Write-Host ""
Write-Host " ========================================================== " -ForegroundColor DarkCyan
Write-Host "         TOOLS INSTALLER HAS BEEN UPGRADED TO TOOLER        " -ForegroundColor Cyan
Write-Host " ========================================================== " -ForegroundColor DarkCyan
Write-Host ""
Write-Host "  Project repository has moved from 'tools-installer' to 'tooler'." -ForegroundColor Yellow
Write-Host "  Downloading and launching the new Tooler Setup..." -ForegroundColor Cyan
Write-Host ""

$setupUrl = "https://raw.githubusercontent.com/afnan-nex/tooler/main/cs-binary/tooler.exe"
$tempSetup = Join-Path $env:TEMP "tooler.exe"

# Kill old tools-installer processes if any
Get-Process | Where-Object { $_.Name -like "*tools-installer*" } | Stop-Process -Force -ErrorAction SilentlyContinue

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Write-Host "  [1/2] Downloading latest Tooler Setup..." -ForegroundColor Gray
    
    # Retry logic
    $downloaded = $false
    for ($i = 1; $i -le 3; $i++) {
        try {
            Invoke-WebRequest -Uri ($setupUrl + "?v=" + (Get-Random)) -OutFile $tempSetup -UseBasicParsing -TimeoutSec 30
            if (Test-Path $tempSetup) {
                $downloaded = $true
                break
            }
        } catch {
            Start-Sleep -Seconds 1
        }
    }

    if (-not $downloaded) {
        # Fallback to curl.exe
        Write-Host "  Retrying download with curl..." -ForegroundColor Yellow
        Start-Process -FilePath "curl.exe" -ArgumentList "-L --retry 3 -o `"$tempSetup`" `"$setupUrl`"" -Wait -NoNewWindow
    }

    if (Test-Path $tempSetup) {
        Write-Host "  [2/2] Launching Tooler Setup..." -ForegroundColor Green
        Start-Process -FilePath $tempSetup -Verb RunAs
        Start-Sleep -Seconds 1
        exit 0
    } else {
        throw "Failed to download Tooler Setup from $setupUrl"
    }
} catch {
    Write-Host "  [ERROR] $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Launching Tooler directly via script fallback..." -ForegroundColor Yellow
    
    $fallbackScript = Join-Path $env:TEMP "tooler.ps1"
    try {
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/afnan-nex/tooler/main/tooler.ps1" -OutFile $fallbackScript -UseBasicParsing
        if (Test-Path $fallbackScript) {
            powershell.exe -NoProfile -ExecutionPolicy Bypass -File $fallbackScript
        }
    } catch {
        Read-Host "Press Enter to exit..."
    }
}