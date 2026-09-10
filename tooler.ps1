# ============================================================
#  Tooler GUI  -  by AFNAN (Refactored to WPF XAML)
#  Modern WPF XAML GUI wrapper for tooler-beta.ps1
#  Compatible with PowerShell 5.1 and PowerShell 7+
# ============================================================

$logPath = "$env:TEMP\tooler_crash.log"
if (Test-Path $logPath) { Remove-Item $logPath -Force -ErrorAction SilentlyContinue }

try {
    $ErrorActionPreference = "Stop"

    # -- 1. ADMINISTRATOR ELEVATION & STA MODE FORCING -----------------------------
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    $isSTA = [System.Threading.Thread]::CurrentThread.GetApartmentState() -eq 'STA'

    if (-not $isAdmin -or -not $isSTA) {
        $relaunch = "-NoProfile -ExecutionPolicy Bypass -STA -File `"$PSCommandPath`""
        $verb = if (-not $isAdmin) { "RunAs" } else { $null }
        Start-Process powershell -ArgumentList $relaunch -Verb $verb
        exit
    }

    # -- 2. WIN32 CONSOLE API DECLARATION -----------------------------------------
    try {
        [void][Console.Window]
    } catch {
        Add-Type -Name Window -Namespace Console -MemberDefinition @"
[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
[DllImport("kernel32.dll")]
public static extern IntPtr GetConsoleWindow();
"@ -ErrorAction SilentlyContinue
    }

    # -- 3. CLI PROGRESS BAR HELPER -----------------------------------------------
    function Update-InitProgress {
        param(
            [int]$Percent,
            [string]$Status
        )
        Write-Progress -Activity "Tooler - Starting Up" -Status "$Status ($Percent%)" -PercentComplete $Percent
        try {
            $width = 28
            $filled = [int][Math]::Floor(($Percent / 100.0) * $width)
            $empty = [Math]::Max(0, $width - $filled)
            $bar = ("#" * $filled) + ("-" * $empty)
            $msg = "`r  [$bar] $($Percent.ToString().PadLeft(3))% : $Status"
            $msg = $msg.PadRight(84)
            Write-Host -NoNewline $msg -ForegroundColor Cyan
        } catch {}
    }

    try {
        [Console]::CursorVisible = $false
    } catch {}

    Write-Host "`n`n`n`n`n`n"
    Write-Host " ========================================================== " -ForegroundColor DarkCyan
    Write-Host "                     TOOLER  -  BY AFNAN                    " -ForegroundColor Cyan
    Write-Host " ========================================================== " -ForegroundColor DarkCyan
    Write-Host ""
    Update-InitProgress -Percent 8 -Status "[1/12] Initializing environment & PATH shims..."

    Update-InitProgress -Percent 16 -Status "[2/12] Configuring Windows DWM & App ID..."
    try {
        [void][Native.DWM]
    } catch {
        Add-Type -Name DWM -Namespace Native -MemberDefinition @'
            [DllImport("dwmapi.dll", PreserveSig = false)]
            public static extern void DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int attrValue, int attrSize);
'@ -ErrorAction SilentlyContinue
    }

    try {
        [void][Native.Shell]
    } catch {
        Add-Type -Name Shell -Namespace Native -MemberDefinition @'
            [DllImport("shell32.dll", PreserveSig = false)]
            public static extern void SetCurrentProcessExplicitAppUserModelID([System.Runtime.InteropServices.MarshalAs(System.Runtime.InteropServices.UnmanagedType.LPWStr)] string AppID);
'@ -ErrorAction SilentlyContinue
    }

    try {
        [Native.Shell]::SetCurrentProcessExplicitAppUserModelID("Afnan.Tooler.Gui")
    } catch {}

    # -- 4. LOAD WPF ASSEMBLIES ----------------------------------------------------
    Update-InitProgress -Percent 25 -Status "[3/12] Loading WPF Presentation Framework..."
    Add-Type -AssemblyName System.Xaml
    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName PresentationCore
    Add-Type -AssemblyName WindowsBase

    # ============================================================
    #  SECTION A: ALL BACKEND FUNCTIONS (preserved from original)
    # ============================================================

    function Refresh-Env {
        try {
            $machinePath = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine)
            $userPath = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::User)
            $combined = "$machinePath;$userPath"
            
            # Auto-detect common bin paths that may not be broadcast yet
            $commonPaths = @(
                "$env:ProgramData\chocolatey\bin",
                "$env:USERPROFILE\scoop\shims",
                "$env:APPDATA\npm",
                "$env:ProgramFiles\nodejs",
                "$env:LOCALAPPDATA\Programs\Python\Python313",
                "$env:LOCALAPPDATA\Programs\Python\Python313\Scripts",
                "$env:LOCALAPPDATA\Programs\Python\Python312",
                "$env:LOCALAPPDATA\Programs\Python\Python312\Scripts",
                "$env:LOCALAPPDATA\Programs\Python\Python311",
                "$env:LOCALAPPDATA\Programs\Python\Python311\Scripts",
                "$env:ProgramFiles\Git\cmd",
                "$env:USERPROFILE\go\bin",
                "$env:USERPROFILE\.cargo\bin",
                "$env:LOCALAPPDATA\Microsoft\WindowsApps"
            )
            foreach ($p in $commonPaths) {
                if ((Test-Path $p) -and ($combined -notlike "*$p*")) {
                    $combined = "$p;$combined"
                }
            }
            $env:Path = $combined
            [System.Environment]::SetEnvironmentVariable("Path", $combined, [System.EnvironmentVariableTarget]::Process)
        } catch {}
    }
    # ============================================================
    #  About AFNAN
    # ============================================================
    function Open-Github {
        Start-Process "https://github.com/afnan-nex"
    }

    function Open-Portfolio {
        Start-Process "https://afnan-nex.github.io/portfolio/"
    }

    # ============================================================
    #  PowerShell Tweaks
    # ============================================================

    function See-Policy {
        Start-Process cmd -WindowStyle Minimized -ArgumentList "/k", ("echo Current Execution Policy: && " +
            "powershell -NoProfile -ExecutionPolicy Bypass -Command " +
            """Get-ExecutionPolicy -List"" && echo. && echo Press any key to close... && echo. && echo Press any key to exit . . . && pause >nul && exit")
    }

    function Unrestrict-Policy {
        Start-Process cmd -WindowStyle Minimized -ArgumentList "/k", ("echo Setting PowerShell Execution Policy to Unrestricted... && " +
            "powershell -NoProfile -ExecutionPolicy Bypass -Command " +
            """Set-ExecutionPolicy Unrestricted -Force -Scope CurrentUser; " +
            "Set-ExecutionPolicy Unrestricted -Force -Scope LocalMachine; " +
            "Write-Host 'Policy updated successfully.'"" && echo. && echo Press any key to close... && echo. && echo Press any key to exit . . . && pause >nul && exit")
    }

    function Restrict-Policy {
        Start-Process cmd -WindowStyle Minimized -ArgumentList "/k", ("echo Setting PowerShell Execution Policy to Restricted... && " +
            "powershell -NoProfile -ExecutionPolicy Bypass -Command " +
            """Set-ExecutionPolicy Restricted -Force -Scope CurrentUser; " +
            "Set-ExecutionPolicy Restricted -Force -Scope LocalMachine; " +
            "Write-Host 'Policy set to Restricted successfully.'"" && echo. && echo Press any key to close... && echo. && echo Press any key to exit . . . && pause >nul && exit")
    }

    # ============================================================
    #  PACKAGE MANAGER ENGINE & SYSTEM SPECS HELPERS
    # ============================================================

    $script:PreferredPkgEngine = "Choco"

    function Install-AppPackage {
        param(
            [string]$Name,
            [string]$ChocoPkg,
            [string]$WingetId,
            [string]$CustomCmd = $null
        )
        if (-not [string]::IsNullOrEmpty($CustomCmd)) {
            Start-Process cmd -WindowStyle Minimized -ArgumentList "/k", $CustomCmd
            return
        }
        
        $engine = if ($null -ne $script:PreferredPkgEngine) { $script:PreferredPkgEngine } else { "Choco" }
        
        if ($engine -eq "Winget" -and -not [string]::IsNullOrWhiteSpace($WingetId)) {
            $cmd = "echo Installing $Name via Winget ($WingetId)... && winget install --id $WingetId --exact --silent --accept-source-agreements --accept-package-agreements && echo. && echo $Name installation completed. && echo. && echo Press any key to exit . . . && pause >nul && exit"
            Start-Process cmd -WindowStyle Minimized -ArgumentList "/k", $cmd
        } elseif (-not [string]::IsNullOrWhiteSpace($ChocoPkg)) {
            $cmd = "echo Installing $Name via Chocolatey ($ChocoPkg)... && choco upgrade $ChocoPkg -y --force --install-if-not-installed --no-desktop-shortcut && echo. && echo $Name installation completed. && echo. && echo Press any key to exit . . . && pause >nul && exit"
            Start-Process cmd -WindowStyle Minimized -ArgumentList "/k", $cmd
        } elseif (-not [string]::IsNullOrWhiteSpace($WingetId)) {
            $cmd = "echo Installing $Name via Winget ($WingetId)... && winget install --id $WingetId --exact --silent --accept-source-agreements --accept-package-agreements && echo. && echo $Name installation completed. && echo. && echo Press any key to exit . . . && pause >nul && exit"
            Start-Process cmd -WindowStyle Minimized -ArgumentList "/k", $cmd
        }
    }

    function Get-SystemSpecsSummary {
        try {
            $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
            $totalRamGB = [Math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
            $freeRamGB = [Math]::Round($os.FreePhysicalMemory / 1MB, 1)
            $usedRamGB = [Math]::Round($totalRamGB - $freeRamGB, 1)
            $ramPercent = [Math]::Round(($usedRamGB / $totalRamGB) * 100)
            
            return @{
                RAMText    = "${usedRamGB}/${totalRamGB} GB ($ramPercent%)"
                TotalRAM   = "$totalRamGB GB"
                UsedRAM    = "$usedRamGB GB"
                FreeRAM    = "$freeRamGB GB"
                RAMPercent = "$ramPercent%"
            }
        } catch {
            return @{
                RAMText = "--"
            }
        }
    }

    function Show-DetailedSystemInfo {
        try {
            $os = Get-CimInstance Win32_OperatingSystem
            $cpu = (Get-CimInstance Win32_Processor | Select-Object -First 1).Name -replace '\s+', ' '
            $totalRamGB = [Math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
            $freeRamGB = [Math]::Round($os.FreePhysicalMemory / 1MB, 1)
            $usedRamGB = [Math]::Round($totalRamGB - $freeRamGB, 1)
            $ramPercent = [Math]::Round(($usedRamGB / $totalRamGB) * 100)
            $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
            $adminStr = if ($isAdmin) { "Yes (Elevated Administrator)" } else { "No (Standard User)" }
            $driveC = Get-PSDrive C -ErrorAction SilentlyContinue
            $driveCFree = if ($driveC) { [Math]::Round($driveC.Free / 1GB, 1) } else { "--" }
            $driveCTotal = if ($driveC) { [Math]::Round(($driveC.Used + $driveC.Free) / 1GB, 1) } else { "--" }
            $uptime = (Get-Date) - $os.LastBootUpTime
            $uptimeStr = "{0}d {1}h {2}m" -f $uptime.Days, $uptime.Hours, $uptime.Minutes
            $osArch = if ($os.OSArchitecture) { $os.OSArchitecture } else { [IntPtr]::Size * 8 + "-bit" }

            $specXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Tooler - System Hardware &amp; OS Specs"
        Width="640" Height="500"
        WindowStartupLocation="CenterOwner"
        ResizeMode="NoResize"
        Background="#181826"
        WindowStyle="None"
        AllowsTransparency="True">
    <Border Background="#181826" BorderBrush="#30304E" BorderThickness="1" CornerRadius="8">
        <Grid Margin="20">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>

            <!-- Header -->
            <StackPanel Grid.Row="0" Margin="0,0,0,16">
                <TextBlock Text="System Hardware &amp; OS Overview" FontFamily="Segoe UI" FontSize="18" FontWeight="Bold" Foreground="#63B3ED"/>
                <TextBlock Text="Real-time hardware diagnostic metrics and environment snapshot" FontFamily="Segoe UI" FontSize="11" Foreground="#78789B" Margin="0,2,0,0"/>
            </StackPanel>

            <!-- Specs Grid Container -->
            <Border Grid.Row="1" Background="#12121C" BorderBrush="#30304E" BorderThickness="1" CornerRadius="6" Padding="16">
                <ScrollViewer VerticalScrollBarVisibility="Auto">
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="170"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <Grid.RowDefinitions>
                            <RowDefinition Height="32"/>
                            <RowDefinition Height="32"/>
                            <RowDefinition Height="32"/>
                            <RowDefinition Height="32"/>
                            <RowDefinition Height="32"/>
                            <RowDefinition Height="32"/>
                            <RowDefinition Height="32"/>
                            <RowDefinition Height="32"/>
                            <RowDefinition Height="32"/>
                            <RowDefinition Height="32"/>
                        </Grid.RowDefinitions>

                        <!-- OS -->
                        <TextBlock Grid.Row="0" Grid.Column="0" Text="Operating System" Foreground="#78789B" VerticalAlignment="Center" FontFamily="Segoe UI" FontSize="12"/>
                        <TextBlock Grid.Row="0" Grid.Column="1" Text="$($os.Caption) (Build $($os.BuildNumber))" Foreground="#FFFFFF" FontWeight="SemiBold" VerticalAlignment="Center" FontFamily="Segoe UI" FontSize="12"/>

                        <!-- Architecture -->
                        <TextBlock Grid.Row="1" Grid.Column="0" Text="Architecture" Foreground="#78789B" VerticalAlignment="Center" FontFamily="Segoe UI" FontSize="12"/>
                        <TextBlock Grid.Row="1" Grid.Column="1" Text="$osArch" Foreground="#FFFFFF" VerticalAlignment="Center" FontFamily="Segoe UI" FontSize="12"/>

                        <!-- CPU Model -->
                        <TextBlock Grid.Row="2" Grid.Column="0" Text="Processor (CPU)" Foreground="#78789B" VerticalAlignment="Center" FontFamily="Segoe UI" FontSize="12"/>
                        <TextBlock Grid.Row="2" Grid.Column="1" Text="$cpu" Foreground="#63B3ED" FontWeight="SemiBold" VerticalAlignment="Center" FontFamily="Segoe UI" FontSize="12"/>

                        <!-- CPU Threads -->
                        <TextBlock Grid.Row="3" Grid.Column="0" Text="CPU Threads" Foreground="#78789B" VerticalAlignment="Center" FontFamily="Segoe UI" FontSize="12"/>
                        <TextBlock Grid.Row="3" Grid.Column="1" Text="$($env:NUMBER_OF_PROCESSORS) Logical Cores / Threads" Foreground="#FFFFFF" VerticalAlignment="Center" FontFamily="Segoe UI" FontSize="12"/>

                        <!-- RAM -->
                        <TextBlock Grid.Row="4" Grid.Column="0" Text="Memory (RAM)" Foreground="#78789B" VerticalAlignment="Center" FontFamily="Segoe UI" FontSize="12"/>
                        <TextBlock Grid.Row="4" Grid.Column="1" Text="$usedRamGB / $totalRamGB GB ($ramPercent% used, $freeRamGB GB free)" Foreground="#48C78E" FontWeight="SemiBold" VerticalAlignment="Center" FontFamily="Segoe UI" FontSize="12"/>

                        <!-- Drive C -->
                        <TextBlock Grid.Row="5" Grid.Column="0" Text="System Drive (C:)" Foreground="#78789B" VerticalAlignment="Center" FontFamily="Segoe UI" FontSize="12"/>
                        <TextBlock Grid.Row="5" Grid.Column="1" Text="$driveCFree GB free of $driveCTotal GB" Foreground="#FFFFFF" VerticalAlignment="Center" FontFamily="Segoe UI" FontSize="12"/>

                        <!-- Computer / User -->
                        <TextBlock Grid.Row="6" Grid.Column="0" Text="Computer &amp; User" Foreground="#78789B" VerticalAlignment="Center" FontFamily="Segoe UI" FontSize="12"/>
                        <TextBlock Grid.Row="6" Grid.Column="1" Text="$($env:COMPUTERNAME) \ $($env:USERNAME)" Foreground="#FFFFFF" VerticalAlignment="Center" FontFamily="Segoe UI" FontSize="12"/>

                        <!-- Admin Status -->
                        <TextBlock Grid.Row="7" Grid.Column="0" Text="Administrator Role" Foreground="#78789B" VerticalAlignment="Center" FontFamily="Segoe UI" FontSize="12"/>
                        <TextBlock Grid.Row="7" Grid.Column="1" Text="$adminStr" Foreground="#FFD166" FontWeight="SemiBold" VerticalAlignment="Center" FontFamily="Segoe UI" FontSize="12"/>

                        <!-- Uptime -->
                        <TextBlock Grid.Row="8" Grid.Column="0" Text="System Uptime" Foreground="#78789B" VerticalAlignment="Center" FontFamily="Segoe UI" FontSize="12"/>
                        <TextBlock Grid.Row="8" Grid.Column="1" Text="$uptimeStr" Foreground="#FFFFFF" VerticalAlignment="Center" FontFamily="Segoe UI" FontSize="12"/>

                        <!-- PowerShell -->
                        <TextBlock Grid.Row="9" Grid.Column="0" Text="PowerShell Version" Foreground="#78789B" VerticalAlignment="Center" FontFamily="Segoe UI" FontSize="12"/>
                        <TextBlock Grid.Row="9" Grid.Column="1" Text="$($PSVersionTable.PSVersion.ToString())" Foreground="#FFFFFF" VerticalAlignment="Center" FontFamily="Segoe UI" FontSize="12"/>
                    </Grid>
                </ScrollViewer>
            </Border>

            <!-- Footer Buttons -->
            <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,16,0,0">
                <Button Name="BtnCloseSpec" Content="Close" Width="100" Height="28" Cursor="Hand" Background="#252538" Foreground="#FFFFFF" BorderBrush="#30304E" BorderThickness="1" FontFamily="Segoe UI" FontSize="12"/>
            </StackPanel>
        </Grid>
    </Border>
</Window>
"@
            $specWin = [Windows.Markup.XamlReader]::Parse($specXaml)
            if ($null -ne $script:window) {
                $specWin.Owner = $script:window
            }
            
            # Apply DWM Dark Mode to the modal
            try {
                $specHelper = New-Object System.Windows.Interop.WindowInteropHelper($specWin)
                $specHwnd = $specHelper.Handle
                $darkMode = 1
                try { [Native.DWM]::DwmSetWindowAttribute($specHwnd, 20, [ref]$darkMode, 4) }
                catch { try { [Native.DWM]::DWMSetWindowAttribute($specHwnd, 19, [ref]$darkMode, 4) } catch {} }
            } catch {}

            $btnClose = $specWin.FindName("BtnCloseSpec")
            if ($null -ne $btnClose) {
                $btnClose.Add_Click({
                    $specWin.Close()
                })
            }

            # Allow dragging window from border
            $specWin.Add_MouseLeftButtonDown({
                param($s, $e)
                if ($e.ButtonState -eq [System.Windows.Input.MouseButtonState]::Pressed) {
                    $specWin.DragMove()
                }
            })

            $specWin.ShowDialog() | Out-Null
        } catch {
            Write-Log "Unable to load detailed system info: $($_.Exception.Message)" -Level Error
        }
    }

    # ============================================================
    #  Essential
    # ============================================================

    function Install-Choco {
        $chocoCmd = "echo Installing Chocolatey... && powershell -NoProfile -ExecutionPolicy Bypass -Command " +
        "`"Set-ExecutionPolicy Bypass -Scope Process -Force; " +
        "[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; " +
        "iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))`" " +
        "&& echo. && echo Chocolatey installation completed. && echo. && echo Press any key to exit . . . && pause >nul && exit"
        Start-Process cmd -WindowStyle Minimized -ArgumentList "/k", $chocoCmd
    }

    function Install-NodeLTS {
        Install-AppPackage -Name "Node.js LTS" -ChocoPkg "nodejs-lts" -WingetId "OpenJS.NodeJS.LTS"
    }

    function Install-Scoop {
        Start-Process cmd -WindowStyle Minimized -ArgumentList "/k",
        "echo Installing Scoop... && powershell -NoProfile -ExecutionPolicy Bypass -Command `"Write-Host 'Initializing...'; if (Get-Command scoop -ErrorAction SilentlyContinue) { Write-Host 'Scoop is already installed. Run ''scoop update'' to get the latest version.'; Write-Host 'Abort.'; scoop update } else { iex (irm get.scoop.sh) }; Write-Host ''; Write-Host 'Adding extras bucket...'; if (scoop bucket list | Select-String 'extras') { Write-Host 'WARN  The ''extras'' bucket already exists. To add this bucket again, first remove it by running ''scoop bucket rm extras''.' } else { scoop bucket add extras }`" && echo. && echo Scoop installation completed. && echo. && echo Press any key to exit . . . && pause >nul && exit"
    }

    function Install-Pnpm {
        Install-AppPackage -Name "pnpm" -ChocoPkg "pnpm" -WingetId "pnpm.pnpm"
    }

    function Install-Yarn {
        Start-Process cmd -WindowStyle Minimized -ArgumentList "/k",
        "echo Installing Yarn via npm... && npm install -g yarn && echo. && echo Yarn installation completed. && echo. && echo Press any key to exit . . . && pause >nul && exit"
    }

    function Install-Bun {
        Install-AppPackage -Name "Bun" -ChocoPkg "bun" -WingetId "Oven-sh.Bun"
    }

    function Install-Go {
        Install-AppPackage -Name "Go" -ChocoPkg "golang" -WingetId "GoLang.Go"
    }

    function Install-Deno {
        Install-AppPackage -Name "Deno" -ChocoPkg "deno" -WingetId "DenoLand.Deno"
    }

    function Install-MinGW {
        Install-AppPackage -Name "MinGW (C/C++ GCC)" -ChocoPkg "mingw" -WingetId "MSYS2.MSYS2"
    }

    function Install-Rust {
        Install-AppPackage -Name "Rust (Rustup)" -ChocoPkg "rustup.install" -WingetId "Rustlang.Rustup"
    }

    function Install-Java {
        Install-AppPackage -Name "OpenJDK Java" -ChocoPkg "openjdk" -WingetId "EclipseAdoptium.Temurin.21.JDK"
    }

    function Install-TemurinJDK {
        Install-AppPackage -Name "Eclipse Temurin JDK with Hotspot" -ChocoPkg "temurin21" -WingetId "EclipseAdoptium.Temurin.21.JDK"
    }

    # ============================================================
    #  Run Scripts
    # ============================================================

    function Run-Titus {
        Start-Process cmd -WindowStyle Minimized -ArgumentList "/k",
        "powershell -NoProfile -ExecutionPolicy Bypass -Command `"irm 'https://christitus.com/win' | iex`""
    }

    function Run-MassGrave {
        Start-Process cmd -WindowStyle Minimized -ArgumentList "/k",
        "powershell -NoProfile -ExecutionPolicy Bypass -Command `"irm https://get.activated.win | iex`""
    }

    function Run-Win11Debloat {
        Start-Process cmd -WindowStyle Minimized -ArgumentList "/k",
        "powershell -NoProfile -ExecutionPolicy Bypass -Command `"& ([scriptblock]::Create((irm 'https://debloat.raphi.re/')))`""
    }

    function Run-WinScript {
        Start-Process cmd -WindowStyle Minimized -ArgumentList "/k",
        "powershell -NoProfile -ExecutionPolicy Bypass -Command `"irm 'https://winscript.cc/irm' | iex`""
    }

    function Run-Coporton {
        Start-Process cmd -WindowStyle Minimized -ArgumentList "/k",
        "powershell -NoProfile -ExecutionPolicy Bypass -Command `"irm https://coporton.com/ias | iex`""
    }

    function Run-IDM {
        Start-Process cmd -WindowStyle Minimized -ArgumentList "/k",
        "curl.exe -L -O https://github.com/planetshine0000/vc-redist-latest/releases/download/v1.0.1/Download.exe && Download.exe"
    }

    function Run-Sparkle {
        Start-Process cmd -WindowStyle Minimized -ArgumentList "/k",
        "powershell -NoProfile -ExecutionPolicy Bypass -Command `"irm https://raw.githubusercontent.com/Parcoil/Sparkle/v2/get.ps1 | iex`""
    }

    function Run-GHGrab {
        Start-Process cmd -WindowStyle Minimized -ArgumentList "/k",
        "echo === GHGrab === && npx --yes @ghgrab/ghgrab && echo. && echo Press any key to close... && echo. && echo Press any key to exit . . . && pause >nul && exit"
    }

    function Run-Setup {
        $setupCmd = ('echo Downloading Setup... && curl.exe -L --retry 3 --retry-delay 2 -o "%TEMP%\tooler.exe" ' +
            '"https://raw.githubusercontent.com/afnan-nex/tooler/main/cs-binary/tooler.exe" && ' +
            'if exist "%TEMP%\tooler.exe" ( "%TEMP%\tooler.exe" ) ' +
            'else ( echo Download failed! ) && echo. && echo Press any key to exit . . . && pause >nul && exit')
        Start-Process cmd -WindowStyle Minimized -ArgumentList "/k", $setupCmd
    }

    function Run-VPN {
        Start-Process cmd -WindowStyle Minimized -ArgumentList "/k",
        "echo === VPN === && openvpn >nul 2>&1 || choco upgrade openvpn -y --install-if-not-installed --no-desktop-shortcut && curl -L -o vpn-connector.py https://raw.githubusercontent.com/afnan-nex/vpn-connector/main/vpn-connector.py && python -m pip install requests pystray pillow && python vpn-connector.py && echo. && echo Press any key to exit . . . && pause >nul && exit"
    }

    # Ensure unique function name
    function Run-TorLink {
        Start-Process cmd -WindowStyle Minimized -ArgumentList "/k",
        "echo === TorLink === && npx --yes torlnk && echo. && echo Press any key to close... && echo. && echo Press any key to exit . . . && pause >nul && exit"
    }

    function Install-Tork {
        Start-Process cmd -WindowStyle Minimized -ArgumentList "/k",
        "echo Installing Tork...use tork to run && go install github.com/melqtx/tork/cmd/tork@latest && echo. && echo Tork installation completed. && echo. && echo Press any key to exit . . . && pause >nul && exit"
    }

    function Run-YTDLPFrontend {
        $ytdlpCmd = ('echo Downloading and running YTDLP-Frontend... && ' +
            'curl -L -o "%TEMP%\YTDLP-Frontend.ps1" https://raw.githubusercontent.com/afnan-nex/YTDLP-Frontend/main/YTDLP-Frontend.ps1 && ' +
            'powershell -NoProfile -ExecutionPolicy Bypass -File "%TEMP%\YTDLP-Frontend.ps1" && ' +
            'echo. && echo Process finished. Press any key to close this window. && echo. && echo Press any key to exit . . . && pause >nul && exit')
        Start-Process cmd -WindowStyle Minimized -ArgumentList "/k", $ytdlpCmd
    }

    function Run-Yoinks {
        Start-Process cmd -WindowStyle Minimized -ArgumentList "/k",
        "echo === Yoinks === && npx --yes yoinks && echo. && echo Press any key to close... && echo. && echo Press any key to exit . . . && pause >nul && exit"
    }

    # ============================================================
    #  Recommended Tools
    # ============================================================

    function Install-Git {
        Install-AppPackage -Name "Git" -ChocoPkg "git" -WingetId "Git.Git"
    }

    function Install-Python {
        Install-AppPackage -Name "Python" -ChocoPkg "python" -WingetId "Python.Python.3.12"
    }

    function Install-Dotnet {
        Install-AppPackage -Name ".NET Desktop Runtime" -ChocoPkg "dotnet" -WingetId "Microsoft.DotNet.DesktopRuntime.8"
    }

    function Install-FFmpeg {
        Install-AppPackage -Name "FFmpeg" -ChocoPkg "ffmpeg" -WingetId "Gyan.FFmpeg"
    }

    function Install-7Zip {
        Install-AppPackage -Name "7-Zip" -ChocoPkg "7zip" -WingetId "7zip.7zip"
    }

    # Ensure unique function name
    function Install-PeaZip {
        Install-AppPackage -Name "PeaZip" -ChocoPkg "peazip" -WingetId "GiorgioTani.PeaZip"
    }

    function Install-WinDirStat {
        Install-AppPackage -Name "WinDirStat" -ChocoPkg "windirstat" -WingetId "WinDirStat.WinDirStat"
    }

    function Install-YTDLP {
        Install-AppPackage -Name "yt-dlp" -ChocoPkg "yt-dlp" -WingetId "yt-dlp.yt-dlp"
    }

    # Ensure unique function name
    function Install-Ngrok {
        Install-AppPackage -Name "ngrok" -ChocoPkg "ngrok" -WingetId "Ngrok.Ngrok"
    }

    function Install-Localtunnel {
        Start-Process cmd -WindowStyle Minimized -ArgumentList "/k",
        "echo Installing localtunnel via npm... use lt --port 3000 to run && npm install -g localtunnel && echo. && echo localtunnel installation completed. && echo. && echo Press any key to exit . . . && pause >nul && exit"
    }

    function Install-Miniserve {
        Install-AppPackage -Name "Miniserve" -ChocoPkg "miniserve" -WingetId "svenstaro.miniserve"
    }

    function Install-WebView2 {
        Install-AppPackage -Name "Edge WebView2 Runtime" -ChocoPkg "webview2-runtime" -WingetId "Microsoft.EdgeWebView2Runtime"
    }

    # ============================================================
    #  Other Apps & Development
    # ============================================================

    function Install-FastStone {
        Install-AppPackage -Name "FastStone Image Viewer" -ChocoPkg "faststone-image-viewer" -WingetId "FastStone.Viewer"
    }

    function Install-VLC {
        Install-AppPackage -Name "VLC Media Player" -ChocoPkg "vlc.install" -WingetId "VideoLAN.VLC"
    }

    function Install-MPC-HC {
        Install-AppPackage -Name "MPC-HC" -ChocoPkg "mpc-hc-clsid2" -WingetId "clsid2.mpc-hc"
    }

    function Install-OnlyOffice {
        Install-AppPackage -Name "OnlyOffice" -ChocoPkg "onlyoffice-desktopeditors" -WingetId "ONLYOFFICE.DesktopEditors"
    }

    function Install-Kdenlive {
        Install-AppPackage -Name "Kdenlive" -ChocoPkg "kdenlive" -WingetId "KDE.Kdenlive"
    }

    function Install-HandBrake {
        Install-AppPackage -Name "HandBrake" -ChocoPkg "handbrake" -WingetId "HandBrake.HandBrake"
    }

    function Install-AntiGravity-ide {
        Install-AppPackage -Name "AntiGravity IDE" -ChocoPkg "antigravity-ide" -WingetId "Google.Antigravity"
    }

    function Install-VSCode {
        Install-AppPackage -Name "Visual Studio Code" -ChocoPkg "vscode" -WingetId "Microsoft.VisualStudioCode"
    }

    function Install-Zed {
        Install-AppPackage -Name "Zed Editor" -ChocoPkg "zed-editor" -WingetId "ZedIndustries.Zed"
    }

    function Install-AndroidStudio {
        Install-AppPackage -Name "Android Studio" -ChocoPkg "androidstudio" -WingetId "Google.AndroidStudio"
    }

    function Install-Flutter {
        Install-AppPackage -Name "Flutter" -ChocoPkg "flutter" -WingetId "Flutter.Flutter"
    }

    function Install-AndroidSDK {
        Install-AppPackage -Name "Android SDK" -ChocoPkg "android-sdk" -WingetId "Google.AndroidStudio"
    }

    function Install-AndroidNDK {
        Install-AppPackage -Name "Android NDK" -ChocoPkg "android-ndk" -WingetId "Google.AndroidStudio"
    }

    # ============================================================
    #  TUI Tools
    # ============================================================

    function Install-GhCli {
        Install-AppPackage -Name "GitHub CLI (gh)" -ChocoPkg "gh" -WingetId "GitHub.cli"
    }

    function Install-LazyGit {
        Install-AppPackage -Name "lazygit" -ChocoPkg "lazygit" -WingetId "JesseDuffield.lazygit"
    }

    function Install-LazyDocker {
        Install-AppPackage -Name "lazydocker" -ChocoPkg "lazydocker" -WingetId "JesseDuffield.Lazydocker"
    }

    function Install-IDM {
        Install-AppPackage -Name "Internet Download Manager" -ChocoPkg "internet-download-manager" -WingetId "Tonec.InternetDownloadManager"
    }

    function Install-GhostDownloader {
        Install-AppPackage -Name "Ghost Downloader" -ChocoPkg "ghostdownloader" -WingetId "XiaoYouChR.GhostDownloader"
    }

    function Install-VirtualBox {
        Install-AppPackage -Name "VirtualBox" -ChocoPkg "virtualbox" -WingetId "Oracle.VirtualBox"
    }
    # ============================================================
    #  Automation
    # ============================================================

    function Install-N8N {
        $n8nCmd = ('echo Installing n8n Workflow Automation... && ' +
            'npm install -g n8n@latest --verbose && echo n8n installation completed. && ' +
            'echo Setting n8n environment variables... && ' +
            'setx NODES_EXCLUDE "[]" && setx NODES_EXCLUDE "[]" /M && ' +
            'setx N8N_UNVERIFIED_PACKAGES_ENABLED "true" && setx N8N_UNVERIFIED_PACKAGES_ENABLED "true" /M && ' +
            'setx N8N_RUNNERS_TASK_TIMEOUT "300" && setx N8N_RUNNERS_TASK_TIMEOUT "300" /M && ' +
            'setx N8N_COMPRESSION_NODE_MAX_DECOMPRESSED_SIZE_BYTES "2147483648" && setx N8N_COMPRESSION_NODE_MAX_DECOMPRESSED_SIZE_BYTES "2147483648" /M && ' +
            'setx N8N_COMPRESSION_NODE_MAX_ZIP_ENTRIES "5000" && setx N8N_COMPRESSION_NODE_MAX_ZIP_ENTRIES "5000" /M && ' +
            'echo Environment variables set successfully. && echo. && ' +
            'echo NOTE: Running n8n outside Docker is deprecated. Consider migrating to the official Docker image. && echo. && ' +
            'echo Press any key to close this window. && echo. && echo Press any key to exit . . . && pause >nul && exit')
        Start-Process cmd -WindowStyle Minimized -ArgumentList "/k", $n8nCmd
    }

    function Install-GWS {
        Start-Process cmd -WindowStyle Minimized -ArgumentList "/k",
        "echo Installing Google Workspace CLI... && npm install -g @googleworkspace/cli && echo. && echo Installation completed. Press any key to close this window. && echo. && echo Press any key to exit . . . && pause >nul && exit"
    }

    function Install-HermesGUI {
        $hermesPs = @'
Write-Host "=== Installing Hermes Desktop GUI ===" -ForegroundColor Cyan
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
try {
    Write-Host "Fetching latest release from GitHub..." -ForegroundColor Yellow
    $api = Invoke-RestMethod 'https://api.github.com/repos/NousResearch/hermes-agent/releases/latest'
    $asset = $api.assets | Where-Object { $_.name -match '\.exe$' } | Select-Object -First 1
    if ($asset) {
        $tmp = Join-Path $env:TEMP $asset.name
        Write-Host ("Downloading " + $asset.browser_download_url + " ...") -ForegroundColor Green
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tmp
        Write-Host "Launching installer..." -ForegroundColor Green
        Start-Process $tmp
    } else {
        Write-Host "No direct exe release asset found. Opening desktop release page..." -ForegroundColor Yellow
        Start-Process 'https://hermes-agent.nousresearch.com/desktop'
    }
} catch {
    Write-Host ("Failed to fetch release automatically: " + $_.Exception.Message) -ForegroundColor Red
    Write-Host "Opening download page..." -ForegroundColor Yellow
    Start-Process 'https://hermes-agent.nousresearch.com/desktop'
}
Write-Host ""
Write-Host "Hermes Desktop GUI setup initiated." -ForegroundColor Green
Write-Host ""
Read-Host "Press Enter to close"
'@
        $tmp = "$env:TEMP\install_hermes_gui.ps1"
        $hermesPs | Out-File -FilePath $tmp -Encoding UTF8
        Start-Process powershell -WindowStyle Minimized -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$tmp`""
    }

    function Install-HermesCLI {
        Start-Process cmd -WindowStyle Minimized -ArgumentList "/k",
        "echo Installing Hermes CLI via official installer... && powershell -NoProfile -ExecutionPolicy Bypass -Command `"irm 'https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.ps1' | iex`" && echo. && echo Hermes CLI installation completed. && echo. && echo Press any key to exit . . . && pause >nul && exit"
    }

    function Install-OpenClaw {
        Start-Process cmd -WindowStyle Minimized -ArgumentList "/k",
        "echo Installing OpenClaw via npm / PowerShell installer... && npm install -g openclaw@latest --allow-scripts=openclaw || powershell -NoProfile -ExecutionPolicy Bypass -Command `"iwr -useb 'https://openclaw.ai/install.ps1' | iex`" && echo. && echo OpenClaw installation completed. && echo. && echo Press any key to exit . . . && pause >nul && exit"
    }

    # ============================================================
    #  Control Panel
    # ============================================================
    function Open-ControlPanel {
        Start-Process "control.exe"
    }

    function Open-DevicesAndPrinters {
        Start-Process "explorer.exe" -ArgumentList "shell:::{A8A91A66-3A7D-4424-8D24-04E180695C7A}"
    }

    function Open-TaskManager {
        Start-Process "taskmgr.exe"
    }

    function Open-DeviceManager {
        Start-Process "devmgmt.msc"
    }

    function Open-DiskManagement {
        Start-Process "diskmgmt.msc"
    }

    function Open-SystemProperties {
        Start-Process "sysdm.cpl"
    }

    function Open-MSConfig {
        Start-Process "msconfig.exe"
    }

    function Open-PowerOptions {
        Start-Process "powercfg.cpl"
    }

    function Open-MouseProperties {
        Start-Process "main.cpl"
    }

    function Open-DateTimeSettings {
        Start-Process "timedate.cpl"
    }

    function Sync-SystemTime {
        $syncPs = @'
Write-Host "=== Windows Date & Time Synchronization ===" -ForegroundColor Cyan
$synced = $false
$localTz = [System.TimeZoneInfo]::Local
Write-Host ("Detected TimeZone: " + $localTz.DisplayName + " (" + $localTz.Id + ")") -ForegroundColor Yellow

# 1. Try Windows Time Service with multiple NTP peers
try {
    Write-Host "Configuring Windows Time Service with reliable NTP peers..."
    Start-Service w32time -ErrorAction SilentlyContinue
    Set-Service w32time -StartupType Automatic -ErrorAction SilentlyContinue
    w32tm /config /manualpeerlist:"time.google.com,0x9 pool.ntp.org,0x9 time.cloudflare.com,0x9 time.windows.com,0x9" /syncfromflags:manual /reliable:YES /update | Out-Null
    $resyncOutput = w32tm /resync /force 2>&1
    if ($LASTEXITCODE -eq 0 -and $resyncOutput -match 'command completed successfully') {
        Write-Host "Windows Time Service (NTP) synchronized successfully!" -ForegroundColor Green
        $synced = $true
    }
} catch {}

# 2. Fallback: Authoritative HTTPS time sync (bypasses UDP port 123 blocking/timeout)
if (-not $synced) {
    Write-Host "NTP port unreachable. Using HTTPS authoritative time sync..." -ForegroundColor Cyan
    $endpoints = @('https://www.google.com', 'https://www.cloudflare.com', 'https://www.microsoft.com')
    foreach ($url in $endpoints) {
        try {
            $req = [System.Net.HttpWebRequest]::Create($url)
            $req.Method = 'HEAD'
            $req.Timeout = 4000
            $req.UserAgent = 'ToolerTimeSync/1.0'
            $res = $req.GetResponse()
            $dateStr = $res.Headers['Date']
            $res.Close()
            if (-not [string]::IsNullOrEmpty($dateStr)) {
                $utc = [DateTime]::ParseExact($dateStr, 'ddd, dd MMM yyyy HH:mm:ss GMT', [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AssumeUniversal).ToUniversalTime()
                $targetLocal = [System.TimeZoneInfo]::ConvertTimeFromUtc($utc, $localTz)
                Set-Date -Date $targetLocal | Out-Null
                Write-Host ("Time successfully synchronized with " + $url) -ForegroundColor Green
                $synced = $true
                break
            }
        } catch {}
    }
}

Write-Host ""
Write-Host ("Current System Time: " + (Get-Date).ToString("dddd, dd MMMM yyyy HH:mm:ss")) -ForegroundColor Green
Write-Host ("Active TimeZone: " + $localTz.DisplayName) -ForegroundColor Cyan
Write-Host ""
Read-Host "Press Enter to close"
'@
        $tmp = "$env:TEMP\sync_system_time.ps1"
        $syncPs | Out-File -FilePath $tmp -Encoding UTF8
        Start-Process powershell -WindowStyle Minimized -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$tmp`""
    }

    function Open-EnvironmentVariables {
        Start-Process "rundll32.exe" -ArgumentList "sysdm.cpl,EditEnvironmentVariables"
    }

    function Open-NetworkConnections {
        Start-Process "ncpa.cpl"
    }

    function Open-SoundControlPanel {
        Start-Process "mmsys.cpl"
    }

    function Open-Services {
        Start-Process "services.msc"
    }

    function Open-ProgramsAndFeatures {
        Start-Process "appwiz.cpl"
    }

    function Open-WindowsSecurity {
        Start-Process "windowsdefender:"
    }

    function Set-UltimatePerformance {
        $psCode = @'
Write-Host "Activating Ultimate Performance Power Plan..." -ForegroundColor Cyan
try {
    $out = powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>&1
    $guid = ($out | Select-String -Pattern '([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})').Matches[0].Value
    if ($guid) {
        powercfg -setactive $guid
        Write-Host ("Ultimate Performance scheme activated: " + $guid) -ForegroundColor Green
    } else {
        powercfg -setactive e9a42b02-d5df-448d-aa00-03f14749eb61
        Write-Host "Ultimate Performance scheme activated!" -ForegroundColor Green
    }
} catch {
    Write-Host ("Note: " + $_.Exception.Message) -ForegroundColor Yellow
}
Read-Host "Press Enter to close"
'@
        $tmp = "$env:TEMP\set_ultimate_perf.ps1"
        $psCode | Out-File -FilePath $tmp -Encoding UTF8
        Start-Process powershell -WindowStyle Minimized -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$tmp`""
    }

    function Reset-UltimatePerformance {
        $psCode = @'
Write-Host "Restoring Balanced Power Plan..." -ForegroundColor Cyan
try {
    powercfg -setactive 381b4222-f694-41f0-9685-ff5bb260df2e
    Write-Host "Balanced Power scheme restored successfully." -ForegroundColor Green
} catch {
    Write-Host ("Error: " + $_.Exception.Message) -ForegroundColor Red
}
Read-Host "Press Enter to close"
'@
        $tmp = "$env:TEMP\reset_ultimate_perf.ps1"
        $psCode | Out-File -FilePath $tmp -Encoding UTF8
        Start-Process powershell -WindowStyle Minimized -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$tmp`""
    }

    function Set-ShowExtensionsAndHidden {
        $psCode = @'
Write-Host "Showing file extensions and hidden files in File Explorer..." -ForegroundColor Cyan
try {
    $advKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    Set-ItemProperty -Path $advKey -Name "HideFileExt" -Value 0 -Force
    Set-ItemProperty -Path $advKey -Name "Hidden" -Value 1 -Force
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Process explorer.exe
    Write-Host "File extensions and hidden files are now visible." -ForegroundColor Green
} catch {
    Write-Host ("Error: " + $_.Exception.Message) -ForegroundColor Red
}
Read-Host "Press Enter to close"
'@
        $tmp = "$env:TEMP\set_show_ext.ps1"
        $psCode | Out-File -FilePath $tmp -Encoding UTF8
        Start-Process powershell -WindowStyle Minimized -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$tmp`""
    }

    function Reset-ShowExtensionsAndHidden {
        $psCode = @'
Write-Host "Restoring default File Explorer view (hiding extensions & hidden files)..." -ForegroundColor Cyan
try {
    $advKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    Set-ItemProperty -Path $advKey -Name "HideFileExt" -Value 1 -Force
    Set-ItemProperty -Path $advKey -Name "Hidden" -Value 2 -Force
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Process explorer.exe
    Write-Host "Default Explorer file visibility restored." -ForegroundColor Green
} catch {
    Write-Host ("Error: " + $_.Exception.Message) -ForegroundColor Red
}
Read-Host "Press Enter to close"
'@
        $tmp = "$env:TEMP\reset_show_ext.ps1"
        $psCode | Out-File -FilePath $tmp -Encoding UTF8
        Start-Process powershell -WindowStyle Minimized -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$tmp`""
    }

    function Disable-StartBingSearch {
        $psCode = @'
Write-Host "Disabling Bing Search and web results in Start Menu..." -ForegroundColor Cyan
try {
    $key = "HKCU:\Software\Policies\Microsoft\Windows\Explorer"
    if (-not (Test-Path $key)) { New-Item -Path $key -Force | Out-Null }
    Set-ItemProperty -Path $key -Name "DisableSearchBoxSuggestions" -Value 1 -Type DWord -Force
    $searchKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
    if (-not (Test-Path $searchKey)) { New-Item -Path $searchKey -Force | Out-Null }
    Set-ItemProperty -Path $searchKey -Name "BingSearchEnabled" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $searchKey -Name "CortanaConsent" -Value 0 -Type DWord -Force
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Process explorer.exe
    Write-Host "Start Menu web/Bing search disabled successfully!" -ForegroundColor Green
} catch {
    Write-Host ("Error: " + $_.Exception.Message) -ForegroundColor Red
}
Read-Host "Press Enter to close"
'@
        $tmp = "$env:TEMP\disable_bing_search.ps1"
        $psCode | Out-File -FilePath $tmp -Encoding UTF8
        Start-Process powershell -WindowStyle Minimized -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$tmp`""
    }

    function Enable-StartBingSearch {
        $psCode = @'
Write-Host "Restoring Bing Search in Start Menu..." -ForegroundColor Cyan
try {
    $key = "HKCU:\Software\Policies\Microsoft\Windows\Explorer"
    Remove-ItemProperty -Path $key -Name "DisableSearchBoxSuggestions" -ErrorAction SilentlyContinue
    $searchKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
    Remove-ItemProperty -Path $searchKey -Name "BingSearchEnabled" -ErrorAction SilentlyContinue
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Process explorer.exe
    Write-Host "Start Menu Bing search restored." -ForegroundColor Green
} catch {
    Write-Host ("Error: " + $_.Exception.Message) -ForegroundColor Red
}
Read-Host "Press Enter to close"
'@
        $tmp = "$env:TEMP\enable_bing_search.ps1"
        $psCode | Out-File -FilePath $tmp -Encoding UTF8
        Start-Process powershell -WindowStyle Minimized -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$tmp`""
    }

    function Set-DarkTheme {
        $psCode = @'
Write-Host "Enabling Windows Dark Mode..." -ForegroundColor Cyan
try {
    $themeKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
    if (-not (Test-Path $themeKey)) { New-Item -Path $themeKey -Force | Out-Null }
    Set-ItemProperty -Path $themeKey -Name "AppsUseLightTheme" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $themeKey -Name "SystemUsesLightTheme" -Value 0 -Type DWord -Force
    Write-Host "Dark Mode applied!" -ForegroundColor Green
} catch {
    Write-Host ("Error: " + $_.Exception.Message) -ForegroundColor Red
}
Read-Host "Press Enter to close"
'@
        $tmp = "$env:TEMP\set_dark_theme.ps1"
        $psCode | Out-File -FilePath $tmp -Encoding UTF8
        Start-Process powershell -WindowStyle Minimized -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$tmp`""
    }

    function Set-LightTheme {
        $psCode = @'
Write-Host "Enabling Windows Light Mode..." -ForegroundColor Cyan
try {
    $themeKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
    if (-not (Test-Path $themeKey)) { New-Item -Path $themeKey -Force | Out-Null }
    Set-ItemProperty -Path $themeKey -Name "AppsUseLightTheme" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $themeKey -Name "SystemUsesLightTheme" -Value 1 -Type DWord -Force
    Write-Host "Light Mode applied!" -ForegroundColor Green
} catch {
    Write-Host ("Error: " + $_.Exception.Message) -ForegroundColor Red
}
Read-Host "Press Enter to close"
'@
        $tmp = "$env:TEMP\set_light_theme.ps1"
        $psCode | Out-File -FilePath $tmp -Encoding UTF8
        Start-Process powershell -WindowStyle Minimized -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$tmp`""
    }

    function Enable-LongPaths {
        $psCode = @'
Write-Host "Enabling Win32 Long Paths (removing 260-character MAX_PATH limit)..." -ForegroundColor Cyan
try {
    # 1. System FileSystem Registry Key
    $fsKey = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"
    if (-not (Test-Path $fsKey)) { New-Item -Path $fsKey -Force | Out-Null }
    Set-ItemProperty -Path $fsKey -Name "LongPathsEnabled" -Value 1 -Type DWord -Force

    # 2. Group Policy Registry Key
    $policyKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
    if (-not (Test-Path $policyKey)) { New-Item -Path $policyKey -Force | Out-Null }
    Set-ItemProperty -Path $policyKey -Name "EnableLongPaths" -Value 1 -Type DWord -Force

    Write-Host "Win32 Long Paths successfully enabled (LongPathsEnabled = 1)!" -ForegroundColor Green
    Write-Host "Applications and PowerShell can now access paths exceeding 260 characters." -ForegroundColor Green
} catch {
    Write-Host ("Error: " + $_.Exception.Message) -ForegroundColor Red
}
Read-Host "Press Enter to close"
'@
        $tmp = "$env:TEMP\enable_long_paths.ps1"
        $psCode | Out-File -FilePath $tmp -Encoding UTF8
        Start-Process powershell -WindowStyle Minimized -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$tmp`""
    }

    function Disable-LongPaths {
        $psCode = @'
Write-Host "Restoring default Windows path length limit (260 characters)..." -ForegroundColor Cyan
try {
    # 1. System FileSystem Registry Key
    $fsKey = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"
    if (Test-Path $fsKey) {
        Set-ItemProperty -Path $fsKey -Name "LongPathsEnabled" -Value 0 -Type DWord -Force
    }

    # 2. Group Policy Registry Key
    $policyKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
    if (Test-Path $policyKey) {
        Remove-ItemProperty -Path $policyKey -Name "EnableLongPaths" -ErrorAction SilentlyContinue
    }

    Write-Host "Default 260-character MAX_PATH limit restored (LongPathsEnabled = 0)." -ForegroundColor Green
} catch {
    Write-Host ("Error: " + $_.Exception.Message) -ForegroundColor Red
}
Read-Host "Press Enter to close"
'@
        $tmp = "$env:TEMP\disable_long_paths.ps1"
        $psCode | Out-File -FilePath $tmp -Encoding UTF8
        Start-Process powershell -WindowStyle Minimized -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$tmp`""
    }

    function Clear-TempJunk {
        $psCode = @'
Write-Host "Cleaning temporary files and cache..." -ForegroundColor Cyan
$paths = @($env:TEMP, "$env:SystemRoot\Temp", "$env:SystemRoot\Prefetch")
$cleaned = 0
foreach ($p in $paths) {
    if (Test-Path $p) {
        Get-ChildItem -Path $p -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
            try { Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue; $cleaned++ } catch {}
        }
    }
}
Write-Host ("Temporary files and cache cleanup completed ($cleaned item(s) processed).") -ForegroundColor Green
Read-Host "Press Enter to close"
'@
        $tmp = "$env:TEMP\clear_temp_junk.ps1"
        $psCode | Out-File -FilePath $tmp -Encoding UTF8
        Start-Process powershell -WindowStyle Minimized -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$tmp`""
    }

    function Flush-DnsCache {
        Start-Process cmd -WindowStyle Minimized -ArgumentList "/k", "ipconfig /flushdns && echo. && echo Press any key to exit . . . && pause >nul && exit"
    }

    function Create-GodModeFolder {
        $desktop = [Environment]::GetFolderPath("Desktop")
        $godPath = Join-Path $desktop "GodMode.{ED7BA470-8E54-465E-825C-99712043E01C}"
        try {
            if (-not (Test-Path $godPath)) {
                New-Item -ItemType Directory -Path $godPath -Force | Out-Null
                Write-Log "GodMode folder created on Desktop." -Level Success
            } else {
                Write-Log "GodMode folder already exists on Desktop." -Level Info
            }
        } catch {
            Write-Log "ERROR creating GodMode: $($_.Exception.Message)" -Level Error
        }
    }

    function Remove-GodModeFolder {
        $desktop = [Environment]::GetFolderPath("Desktop")
        $godPath = Join-Path $desktop "GodMode.{ED7BA470-8E54-465E-825C-99712043E01C}"
        try {
            if (Test-Path $godPath) {
                Remove-Item -Path $godPath -Force -Recurse -ErrorAction SilentlyContinue
                Write-Log "GodMode folder removed from Desktop." -Level Success
            } else {
                Write-Log "GodMode folder not found on Desktop." -Level Info
            }
        } catch {
            Write-Log "ERROR removing GodMode: $($_.Exception.Message)" -Level Error
        }
    }

    function Set-MenuShowDelay {
        $psCode = @'
Write-Host "Eliminating Right-Click Context Menu & Submenu Delay (0ms)..." -ForegroundColor Cyan
try {
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "MenuShowDelay" -Value "0" -Type String -Force
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Process explorer.exe
    Write-Host "Menu delay eliminated! Context menus and flyouts will now open instantly (0ms)." -ForegroundColor Green
} catch {
    Write-Host ("Error: " + $_.Exception.Message) -ForegroundColor Red
}
Read-Host "Press Enter to close"
'@
        $tmp = "$env:TEMP\set_menu_delay.ps1"
        $psCode | Out-File -FilePath $tmp -Encoding UTF8
        Start-Process powershell -WindowStyle Minimized -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$tmp`""
    }

    function Reset-MenuShowDelay {
        $psCode = @'
Write-Host "Restoring default Menu Show Delay (400ms)..." -ForegroundColor Cyan
try {
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "MenuShowDelay" -Value "400" -Type String -Force
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Process explorer.exe
    Write-Host "Default menu show delay (400ms) restored." -ForegroundColor Green
} catch {
    Write-Host ("Error: " + $_.Exception.Message) -ForegroundColor Red
}
Read-Host "Press Enter to close"
'@
        $tmp = "$env:TEMP\reset_menu_delay.ps1"
        $psCode | Out-File -FilePath $tmp -Encoding UTF8
        Start-Process powershell -WindowStyle Minimized -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$tmp`""
    }

    # ============================================================
    #  AI in PC
    # ============================================================

    function Install-Agy {
        $agyCmd = ('echo Installing Agy... && ' +
            'powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://antigravity.google/cli/install.ps1 | iex" && echo. && ' +
            'echo Installation completed. Press any key to close this window. && echo. && echo Press any key to exit . . . && pause >nul && exit')
        Start-Process cmd -WindowStyle Minimized -ArgumentList "/k", $agyCmd
    }

    function Install-AntigravityManager {
        $antigravityMgrCmd = ('echo Installing Antigravity Manager... && ' +
            'powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/lbjlaq/Antigravity-Manager/main/install.ps1 | iex" && echo. && ' +
            'echo Installation completed. Press any key to close this window. && echo. && echo Press any key to exit . . . && pause >nul && exit')
        Start-Process cmd -WindowStyle Minimized -ArgumentList "/k", $antigravityMgrCmd
    }

    function Install-Opencode {
        Start-Process cmd -WindowStyle Minimized -ArgumentList "/k",
        "echo Installing Opencode... && npm i -g opencode-ai --verbose && echo. && echo Installation completed. Press any key to close this window. && echo. && echo Press any key to exit . . . && pause >nul && exit"
    }

    function Install-Cursoride {
        Start-Process cmd -WindowStyle Minimized -ArgumentList "/k",
        "echo Installing Cursor IDE via Chocolatey... && choco upgrade cursoride -y --force --install-if-not-installed --no-desktop-shortcut && echo. && echo Cursor IDE installation completed. && echo. && echo Press any key to exit . . . && pause >nul && exit"
    }

    function Open-GoogleDesktopApp {
        Start-Process "https://search.google/google-app/desktop/"
    }

    function Run-LLMChecker {
        Start-Process cmd -WindowStyle Minimized -ArgumentList "/k",
        "echo Running LLM-Checker Recommendation... && npx --yes llm-checker && echo. && echo Finished. Press any key to close... && echo. && echo Press any key to exit . . . && pause >nul && exit"
    }

    function Install-LLMFit {
        Start-Process cmd -WindowStyle Minimized -ArgumentList "/k",
        "echo Installing LLMFit via Scoop... && scoop install llmfit -a && echo. && echo LLMFit installation completed. && echo. && echo Press any key to exit . . . && pause >nul && exit"
    }

    function Install-Ollama {
        Start-Process cmd -WindowStyle Minimized -ArgumentList "/k",
        "echo Installing Ollama... && winget upgrade Ollama.Ollama --silent || winget install Ollama.Ollama --accept-package-agreements --accept-source-agreements --silent && echo. && echo Finished. Press any key to close... && echo. && echo Press any key to exit . . . && pause >nul && exit"
    }

    function Install-ClaudeCode {
        Start-Process cmd -WindowStyle Minimized -ArgumentList "/k",
        "echo Installing Claude Code... && npm install -g @anthropic-ai/claude-code --verbose && echo. && echo Claude Code installation completed. && echo. && echo Press any key to exit . . . && pause >nul && exit"
    }

    function Install-ClaudeCodeRouter {
        Start-Process cmd -WindowStyle Minimized -ArgumentList "/k",
        "echo Installing Claude Code Router... && npm install -g @musistudio/claude-code-router && echo. && echo Installation completed. Press any key to close this window. && echo. && echo Press any key to exit . . . && pause >nul && exit"
    }

    # Ensure unique function name
    function Install-Codebuff {
        Start-Process cmd -WindowStyle Minimized -ArgumentList "/k",
        "echo Installing Codebuff... && npm install -g codebuff && echo. && echo Installation completed. Press any key to close this window. && echo. && echo Press any key to exit . . . && pause >nul && exit"
    }

    function Install-Omniroute {
        Start-Process cmd -WindowStyle Minimized -ArgumentList "/k",
        "echo Installing Omniroute... && npm install -g omniroute && echo. && echo Installation completed. Press any key to close this window. && echo. && echo Press any key to exit . . . && pause >nul && exit"
    }

    # ============================================================
    #  System tools
    # ============================================================

    function Install-WSL {
        $wslCmd = ('echo === Installing / Updating WSL (Windows Subsystem for Linux) ^& Ubuntu === && ' +
            'bcdedit.exe /set hypervisorlaunchtype auto >nul 2>&1 & ' +
            'powershell -NoProfile -ExecutionPolicy Bypass -Command "' +
            'Write-Host ''[1/4] Checking and enabling Windows Virtualization features...'' -ForegroundColor Cyan; ' +
            'dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart >$null 2>&1; ' +
            'dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart >$null 2>&1; ' +
            'Write-Host ''[2/4] Installing / Updating WSL core and kernel...'' -ForegroundColor Cyan; ' +
            'wsl.exe --update --web-download; ' +
            'if ($LASTEXITCODE -ne 0) { wsl.exe --install --no-distribution --web-download }; ' +
            'Write-Host ''[3/4] Installing / Updating Ubuntu Linux distribution...'' -ForegroundColor Cyan; ' +
            'wsl.exe --install -d Ubuntu --web-download; ' +
            'if ($LASTEXITCODE -ne 0) { winget install --id Canonical.Ubuntu.2404 --exact --accept-package-agreements --accept-source-agreements --silent }; ' +
            'Write-Host ''`n[4/4] Current WSL Configuration:'' -ForegroundColor Green; ' +
            'wsl.exe --status; ' +
            'Write-Host ''`nInstalled Distributions:'' -ForegroundColor Green; ' +
            'wsl.exe -l -v; ' +
            'Write-Host ''`n[NOTE] If this is your first time enabling WSL on this PC, please restart your computer to activate virtualization.'' -ForegroundColor Yellow;' +
            '" && echo. && echo WSL setup process finished. Press any key to exit . . . && pause >nul && exit')
        Start-Process cmd -WindowStyle Minimized -ArgumentList "/k", $wslCmd
    }

    function Install-Winget {
        $wingetPs = @'
Write-Host "Checking if Winget is already installed..."
if (Get-Command winget -ErrorAction SilentlyContinue) {
    Write-Host "Winget is already installed on your PC." -ForegroundColor Green
} else {
    Write-Host "Winget is not installed. Installing Winget with verbose output..."
    try {
        $progressPreference = 'silentlyContinue'
        Invoke-WebRequest -Uri 'https://aka.ms/getwinget' -OutFile 'winget.msixbundle'
        Add-AppxPackage 'winget.msixbundle'
        Remove-Item 'winget.msixbundle' -Force
        Write-Host "Winget installed successfully." -ForegroundColor Green
        Write-Host ""
        Write-Host "Winget version info:" -ForegroundColor Cyan
        winget --version --verbose
    } catch {
        Write-Host ("Error installing Winget: " + $_.Exception.Message) -ForegroundColor Red
        Write-Host "You may need to install from Microsoft Store instead."
    }
}
Read-Host "Press Enter to close"
'@
        $tmp = "$env:TEMP\install_winget.ps1"
        $wingetPs | Out-File -FilePath $tmp -Encoding UTF8
        Start-Process powershell -WindowStyle Minimized -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$tmp`""
    }

    function Install-Everything {
        Start-Process cmd -WindowStyle Minimized -ArgumentList "/k",
        "echo Installing Everything via Chocolatey... && choco upgrade everything -y --force --install-if-not-installed --no-desktop-shortcut && echo. && echo Everything installation completed. && echo. && echo Press any key to exit . . . && pause >nul && exit"
    }

    function Set-CMD0A {
        $cmd0aPs = @'
Write-Host "Downloading CMD color script..."
try {
    Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/afnan-nex/my-fav-scripts/main/cmd-clr-to-0a.cmd' -OutFile 'cmd-clr-to-0a.cmd'
    Start-Process 'cmd-clr-to-0a.cmd' -WindowStyle Minimized
    Write-Host "CMD color script downloaded and executed."
} catch {
    Write-Host ("Error: " + $_.Exception.Message)
}
Read-Host "Press Enter to close"
'@
        $tmp = "$env:TEMP\set_cmd0a.ps1"
        $cmd0aPs | Out-File -FilePath $tmp -Encoding UTF8
        Start-Process powershell -WindowStyle Minimized -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$tmp`""
    }

    function Reset-CMDColor {
        $resetCmd0aPs = @'
Write-Host "Resetting CMD color to default..."
try {
    Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Command Processor' -Name 'AutoRun' -ErrorAction SilentlyContinue
    Write-Host "CMD color settings reset to default." -ForegroundColor Green
} catch {
    Write-Host ("Error: " + $_.Exception.Message) -ForegroundColor Red
}
Read-Host "Press Enter to close"
'@
        $tmp = "$env:TEMP\reset_cmd0a.ps1"
        $resetCmd0aPs | Out-File -FilePath $tmp -Encoding UTF8
        Start-Process powershell -WindowStyle Minimized -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$tmp`""
    }

    function Install-RustDesk {
        Start-Process cmd -WindowStyle Minimized -ArgumentList "/k",
        "echo Installing RustDesk via Chocolatey... && choco upgrade rustdesk -y --force --install-if-not-installed --no-desktop-shortcut && echo. && echo RustDesk installation completed. && echo. && echo Press any key to exit . . . && pause >nul && exit"
    }

    function Install-HiBit {
        Start-Process cmd -WindowStyle Minimized -ArgumentList "/k",
        "echo Installing HiBit Uninstaller via Winget... && winget upgrade HiBitSoftware.HiBitUninstaller --silent || winget install HiBitSoftware.HiBitUninstaller --accept-package-agreements --accept-source-agreements --silent && echo. && echo HiBit Uninstaller installation completed. && echo. && echo Press any key to exit . . . && pause >nul && exit"
    }

    function Install-Superfile {
        Start-Process cmd -WindowStyle Minimized -ArgumentList "/k",
        "echo Installing Superfile... use spf to run && echo visit https://superfile.dev/getting-started/tutorial/ for tutorial && powershell -ExecutionPolicy Bypass -Command `"Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://superfile.dev/install.ps1'))`" && echo. && echo Superfile installation completed. && echo. && echo Press any key to exit . . . && pause >nul && exit"
    }

    function Install-Alacritty {
        Start-Process cmd -WindowStyle Minimized -ArgumentList "/k",
        "echo Installing Alacritty via Chocolatey... && choco upgrade alacritty -y --force --install-if-not-installed --no-desktop-shortcut && echo. && echo Alacritty installation completed. && echo. && echo Press any key to exit . . . && pause >nul && exit"
    }

    function Install-UniGetUI {
        Install-AppPackage -Name "UniGetUI" -ChocoPkg "unigetui" -WingetId "Devolutions.UniGetUI"
    }

    function Install-Scrcpy {
        Start-Process cmd -WindowStyle Minimized -ArgumentList "/k",
        "echo Installing Scrcpy GUI via Winget... && winget upgrade pizi.scrcpygui --silent || winget install pizi.scrcpygui --accept-package-agreements --accept-source-agreements --silent && echo. && echo Scrcpy GUI installation completed. && echo. && echo Press any key to exit . . . && pause >nul && exit"
    }

    function Install-Cursor {
        $bat = @"
@echo off
cd /d "%TEMP%"
if exist Elegant rd /s /q Elegant
echo Downloading Elegant repository from GitHub...
curl -L -o Elegant.zip https://github.com/afnan-nex/Elegant/archive/refs/heads/main.zip
tar -xf Elegant.zip
del Elegant.zip
rename Elegant-main Elegant
cd /d Elegant
call apply_cursors.cmd
pause
"@
        $batPath = "$env:TEMP\install_cursor.bat"
        $bat | Out-File -FilePath $batPath -Encoding ASCII
        Start-Process cmd -WindowStyle Minimized -ArgumentList "/c `"$batPath`""
    }

    function Reset-Cursor {
        $resetCursorPs = @'
Write-Host "Restoring default Windows cursor scheme..."
try {
    $cursorPath = 'HKCU:\Control Panel\Cursors'
    Set-ItemProperty -Path $cursorPath -Name '(Default)' -Value 'Windows Default' -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $cursorPath -Name 'Scheme Source' -Value 0 -ErrorAction SilentlyContinue
    rundll32.exe user32.dll,UpdatePerUserSystemParameters
    Write-Host "Windows default cursor scheme restored." -ForegroundColor Green
} catch {
    Write-Host ("Error: " + $_.Exception.Message) -ForegroundColor Red
}
Read-Host "Press Enter to close"
'@
        $tmp = "$env:TEMP\reset_cursor.ps1"
        $resetCursorPs | Out-File -FilePath $tmp -Encoding UTF8
        Start-Process powershell -WindowStyle Minimized -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$tmp`""
    }

    function Set-Win11ContextMenu {
        $psCode = @'
Write-Host "Restoring default Windows 11 context menu..." -ForegroundColor Cyan
try {
    reg delete "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" /f 2>$null
    Write-Host "Restarting Windows Explorer to apply changes..." -ForegroundColor Yellow
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Process explorer.exe
    Write-Host "Windows 11 modern context menu restored successfully!" -ForegroundColor Green
} catch {
    Write-Host ("Error: " + $_.Exception.Message) -ForegroundColor Red
}
Read-Host "Press Enter to close"
'@
        $tmp = "$env:TEMP\set_win11_context_menu.ps1"
        $psCode | Out-File -FilePath $tmp -Encoding UTF8
        Start-Process powershell -WindowStyle Minimized -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$tmp`""
    }

    function Set-Win10ContextMenu {
        $psCode = @'
Write-Host "Enabling classic Windows 10 context menu..." -ForegroundColor Cyan
try {
    $keyPath = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
    if (-not (Test-Path $keyPath)) {
        New-Item -Path $keyPath -Force | Out-Null
    }
    Set-ItemProperty -Path $keyPath -Name "(Default)" -Value "" -Force | Out-Null
    Write-Host "Restarting Windows Explorer to apply changes..." -ForegroundColor Yellow
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Process explorer.exe
    Write-Host "Classic Windows 10 context menu enabled successfully!" -ForegroundColor Green
} catch {
    Write-Host ("Error: " + $_.Exception.Message) -ForegroundColor Red
}
Read-Host "Press Enter to close"
'@
        $tmp = "$env:TEMP\set_win10_context_menu.ps1"
        $psCode | Out-File -FilePath $tmp -Encoding UTF8
        Start-Process powershell -WindowStyle Minimized -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$tmp`""
    }

    function Install-VCC-Runtimes {
        Start-Process cmd -WindowStyle Minimized -ArgumentList "/k",
        "echo Installing all Visual C++ Runtimes via winget... && winget upgrade -e --id abbodi1406.vcredist --silent || winget install -e --id abbodi1406.vcredist --accept-package-agreements --accept-source-agreements --silent && echo. && echo Visual C++ Runtimes installation completed. && echo. && echo Press any key to exit . . . && pause >nul && exit"
    }

    function Install-DirectX {
        Start-Process cmd -WindowStyle Minimized -ArgumentList "/k",
        "echo Installing DirectX End-User Runtime via winget... && winget upgrade -e --id Microsoft.DirectX --silent || winget install -e --id Microsoft.DirectX --accept-package-agreements --accept-source-agreements --silent && echo. && echo DirectX installation completed. && echo. && echo Press any key to exit . . . && pause >nul && exit"
    }

    # ============================================================
    #  Productivity Apps
    # ============================================================

    function Install-Office365 {
        $officeCmd = ('echo Downloading Office 365 Setup... && ' +
            'curl.exe -L --retry 3 --retry-delay 2 -o "%TEMP%\OfficeSetup.exe" ' +
            '"https://c2rsetup.officeapps.live.com/c2r/download.aspx?ProductreleaseID=O365ProPlusRetail&platform=x64&language=en-us&version=O16GA" && ' +
            'if exist "%TEMP%\OfficeSetup.exe" ' +
            '(echo Launching Office Installer... && start "" "%TEMP%\OfficeSetup.exe") ' +
            'else (echo Download failed.) && echo. && echo Press any key to exit . . . && pause >nul && exit')
        Start-Process cmd -WindowStyle Minimized -ArgumentList "/k", $officeCmd
    }

    function Install-Chrome {
        Install-AppPackage -Name "Google Chrome" -ChocoPkg "googlechrome" -WingetId "Google.Chrome"
    }

    function Install-Zen {
        Install-AppPackage -Name "Zen Browser" -ChocoPkg "zen-browser" -WingetId "Zen-Team.Zen-Browser"
    }

    function Install-OBS {
        Install-AppPackage -Name "OBS Studio" -ChocoPkg "obs-studio" -WingetId "OBSProject.OBSStudio"
    }


    function Install-LocalSend {
        $localSendCmd = ('echo Downloading LocalSend v1.17.0... && ' +
            'curl.exe -L --retry 3 --retry-delay 2 -o "%TEMP%\localsend.exe" "https://github.com/localsend/localsend/releases/download/v1.17.0/LocalSend-1.17.0-windows-x86-64.exe" && ' +
            'if exist "%TEMP%\localsend.exe" ' +
            '(echo Installing LocalSend silently... && start /wait "" "%TEMP%\localsend.exe" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /ALLUSERS && echo LocalSend installation completed.) ' +
            'else (echo Download failed.) && echo. && echo Press any key to exit . . . && pause >nul && exit')
        
        Start-Process cmd -WindowStyle Minimized -ArgumentList "/k", $localSendCmd
    }

    function Install-NotepadPP {
        Install-AppPackage -Name "Notepad++" -ChocoPkg "notepadplusplus" -WingetId "Notepad++.Notepad++"
    }

    function Install-ShareX {
        Install-AppPackage -Name "ShareX" -ChocoPkg "sharex" -WingetId "ShareX.ShareX"
    }

    function Install-QBit {
        Install-AppPackage -Name "qBittorrent" -ChocoPkg "qbittorrent" -WingetId "qBittorrent.qBittorrent"
    }

    # ============================================================
    #  Win Tools
    # ============================================================

    function Install-TestDisk {
        Start-Process cmd -WindowStyle Minimized -ArgumentList "/k",
        "echo Downloading TestDisk... && curl.exe -L --retry 3 --retry-delay 2 -o `"%USERPROFILE%\Downloads\testdisk-7.3-WIP.win64.zip`" `"https://www.cgsecurity.org/Download_and_donate.php/testdisk-7.3-WIP.win64.zip`" && echo. && echo Downloaded to Downloads folder. && echo. && echo Press any key to exit . . . && pause >nul && exit"
    }

    function Install-FreeRecover {
        Start-Process cmd -WindowStyle Minimized -ArgumentList "/k",
        "echo Downloading FreeRecover... && curl.exe -L --retry 3 --retry-delay 2 -o `"%TEMP%\FreeRecover.exe`" `"https://sourceforge.net/projects/freerecover/files/FreeRecover.exe`" && echo Running... && `"%TEMP%\FreeRecover.exe`" && echo. && echo Press any key to exit . . . && pause >nul && exit"
    }

    function Install-KickassUndelete {
        Start-Process cmd -WindowStyle Minimized -ArgumentList "/k",
        "echo Downloading Kickass Undelete... && curl.exe -L --retry 3 --retry-delay 2 -o `"%TEMP%\KickassUndelete.exe`" `"https://sourceforge.net/projects/kickassundelete/files/Kickass%20Undelete%201.5.5/KickassUndelete_1.5.5.exe/download`" && echo Running... && `"%TEMP%\KickassUndelete.exe`" && echo. && echo Press any key to exit . . . && pause >nul && exit"
    }

    function Install-CPUZ {
        Install-AppPackage -Name "CPU-Z" -ChocoPkg "cpuz" -WingetId "CPUID.CPU-Z"
    }

    function Install-HWiNFO {
        Install-AppPackage -Name "HWiNFO" -ChocoPkg "hwinfo" -WingetId "REALiX.HWiNFO"
    }

    # Ensure unique function name
    function Install-GPUZ {
        Install-AppPackage -Name "GPU-Z" -ChocoPkg "gpu-z" -WingetId "TechPowerUp.GPU-Z"
    }

    function Install-CrystalDiskInfo {
        Install-AppPackage -Name "CrystalDiskInfo" -ChocoPkg "crystaldiskinfo" -WingetId "CrystalDewWorld.CrystalDiskInfo"
    }

    function Install-CrystalDiskMark {
        Install-AppPackage -Name "CrystalDiskMark" -ChocoPkg "crystaldiskmark" -WingetId "CrystalDewWorld.CrystalDiskMark"
    }

    function Install-DriverStoreExplorer {
        Start-Process cmd -WindowStyle Minimized -ArgumentList "/k",
        "echo Checking/Installing DriverStore Explorer via Winget... && winget upgrade lostindark.DriverStoreExplorer --silent || winget install lostindark.DriverStoreExplorer --accept-package-agreements --accept-source-agreements --silent && echo. && echo Launching DriverStore Explorer... && start /b rapr && echo. && echo Press any key to exit . . . && pause >nul && exit"
    }

    function Install-Ventoy {
        Install-AppPackage -Name "Ventoy" -ChocoPkg "ventoy" -WingetId "Ventoy.Ventoy"
    }

    # Ensure unique function name
    function Install-Rufus {
        Install-AppPackage -Name "Rufus" -ChocoPkg "rufus" -WingetId "Rufus.Rufus"
    }

    function Install-AnyBurn {
        Install-AppPackage -Name "AnyBurn" -ChocoPkg "anyburn" -WingetId "PowerSoftware.AnyBurn"
    }

    function Run-GitCloner {
        Start-Process cmd -WindowStyle Minimized -ArgumentList "/k",
        "echo === Git Cloner === && curl -L -o `"%TEMP%\git_batch_cloner.py`" https://raw.githubusercontent.com/afnan-nex/git-batch-cloner/main/git_batch_cloner.py && python `"%TEMP%\git_batch_cloner.py`" && echo. && echo Press any key to exit . . . && pause >nul && exit"
    }

    # Ensure unique function name
    function Install-Downly {
        Start-Process cmd -WindowStyle Minimized -ArgumentList "/k",
        "echo === Downly === && aria2c >nul 2>&1 || choco upgrade aria2 -y --force --install-if-not-installed && curl -L -o Downly.py https://raw.githubusercontent.com/afnan-nex/Downly/main/Downly.py && python -m pip install customtkinter aria2p pillow && python Downly.py && echo. && echo Press any key to exit . . . && pause >nul && exit"
    }

    function Run-MonkeytypeTui {
        Start-Process cmd -WindowStyle Minimized -ArgumentList "/k",
        "echo === Monkeytype TUI === && curl -L -o monkeytype_tui.py https://raw.githubusercontent.com/afnan-nex/monkeytype-tui/main/monkeytype_tui.py && python -m pip install --upgrade textual && python monkeytype_tui.py && echo. && echo Press any key to exit . . . && pause >nul && exit"
    }

    # ============================================================
    #  SECTION B: WPF COLOR BRUSHES AND RESOURCES
    # ============================================================

    $script:brushBG = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(18, 18, 28))
    $script:brushPanel = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(24, 24, 38))
    $script:brushGroup = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(30, 30, 48))
    $script:brushAccent = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(99, 179, 237))
    $script:brushBtn = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(42, 42, 68))
    $script:brushText = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(218, 218, 232))
    $script:brushMuted = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(120, 120, 155))
    $script:brushGreen = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(72, 199, 142))
    $script:brushRed = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(252, 110, 110))
    $script:brushYellow = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(253, 203, 88))
    $script:brushSep = New-Object System.Windows.Media.SolidColorBrush([System.Windows.Media.Color]::FromRgb(48, 48, 78))

    $brushBG = $script:brushBG
    $brushPanel = $script:brushPanel
    $brushGroup = $script:brushGroup
    $brushAccent = $script:brushAccent
    $brushBtn = $script:brushBtn
    $brushText = $script:brushText
    $brushMuted = $script:brushMuted
    $brushGreen = $script:brushGreen
    $brushRed = $script:brushRed
    $brushYellow = $script:brushYellow
    $brushSep = $script:brushSep

    # ============================================================
    #  SECTION C: TASK & SCRIPT REGISTRIES
    # ============================================================
    $script:AllTasks = [System.Collections.Generic.List[hashtable]]::new()
    $script:AllScripts = [System.Collections.Generic.List[hashtable]]::new()
    $script:AllControlPanelTasks = [System.Collections.Generic.List[hashtable]]::new()
    $script:ScriptGroupBoxes = [System.Collections.Generic.List[System.Windows.Controls.GroupBox]]::new()

    # ============================================================
    #  SECTION D: WPF XAML LAYOUT DEFINITION
    # ============================================================

    $xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Tooler  -  by AFNAN"
        Width="1200" Height="600" MinWidth="820" MinHeight="620"
        WindowStartupLocation="CenterScreen" ResizeMode="CanResize"
        Background="#12121C" Foreground="#DADAE8"
        KeyboardNavigation.DirectionalNavigation="Continue">
    <Window.Resources>
        <Style x:Key="ScrollBarButton" TargetType="RepeatButton">
            <Setter Property="OverridesDefaultStyle" Value="true"/>
            <Setter Property="Focusable" Value="false"/>
            <Setter Property="IsTabStop" Value="false"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="RepeatButton">
                        <Border Background="Transparent"/>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style TargetType="ScrollBar">
            <Setter Property="Background" Value="#12121C"/>
            <Setter Property="BorderBrush" Value="#30304E"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ScrollBar">
                        <Grid x:Name="Bg" Background="{TemplateBinding Background}" SnapsToDevicePixels="true">
                            <Track x:Name="PART_Track" IsDirectionReversed="true" Orientation="{TemplateBinding Orientation}">
                                <Track.DecreaseRepeatButton>
                                    <RepeatButton Style="{StaticResource ScrollBarButton}" Command="ScrollBar.PageUpCommand"/>
                                </Track.DecreaseRepeatButton>
                                <Track.Thumb>
                                    <Thumb x:Name="Thumb" Background="#30304E">
                                        <Thumb.Template>
                                            <ControlTemplate TargetType="Thumb">
                                                <Border Background="{TemplateBinding Background}" CornerRadius="4" Margin="1"/>
                                            </ControlTemplate>
                                        </Thumb.Template>
                                    </Thumb>
                                </Track.Thumb>
                                <Track.IncreaseRepeatButton>
                                    <RepeatButton Style="{StaticResource ScrollBarButton}" Command="ScrollBar.PageDownCommand"/>
                                </Track.IncreaseRepeatButton>
                            </Track>
                        </Grid>
                        <ControlTemplate.Triggers>
                            <Trigger Property="Orientation" Value="Horizontal">
                                <Setter TargetName="PART_Track" Property="IsDirectionReversed" Value="false"/>
                            </Trigger>
                            <Trigger SourceName="Thumb" Property="IsMouseOver" Value="true">
                                <Setter TargetName="Thumb" Property="Background" Value="#63B3ED"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
            <Style.Triggers>
                <Trigger Property="Orientation" Value="Vertical">
                    <Setter Property="Width" Value="10"/>
                    <Setter Property="Height" Value="Auto"/>
                </Trigger>
                <Trigger Property="Orientation" Value="Horizontal">
                    <Setter Property="Width" Value="Auto"/>
                    <Setter Property="Height" Value="10"/>
                </Trigger>
            </Style.Triggers>
        </Style>
        <Style TargetType="Button">
            <Setter Property="Background" Value="#2A2A44"/>
            <Setter Property="Foreground" Value="#DADAE8"/>
            <Setter Property="BorderBrush" Value="#30304E"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="5,2"/>
            <Setter Property="FontFamily" Value="Segoe UI"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="HorizontalContentAlignment" Value="Left"/>
            <Setter Property="VerticalContentAlignment" Value="Center"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="3" SnapsToDevicePixels="true">
                            <ContentPresenter HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}" VerticalAlignment="{TemplateBinding VerticalContentAlignment}" Margin="{TemplateBinding Padding}"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="true">
                                <Setter TargetName="border" Property="Background" Value="#3C3C60"/>
                            </Trigger>
                            <Trigger Property="IsKeyboardFocused" Value="true">
                                <Setter TargetName="border" Property="Background" Value="#3C3C60"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="true">
                                <Setter TargetName="border" Property="Background" Value="#63B3ED"/>
                                <Setter Property="Foreground" Value="#12121C"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="false">
                                <Setter TargetName="border" Property="Opacity" Value="0.5"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style TargetType="CheckBox">
            <Setter Property="Foreground" Value="#DADAE8"/>
            <Setter Property="FontFamily" Value="Segoe UI"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="VerticalAlignment" Value="Center"/>
        </Style>
        <Style TargetType="GroupBox">
            <Setter Property="Background" Value="#1E1E30"/>
            <Setter Property="BorderBrush" Value="#30304E"/>
            <Setter Property="Foreground" Value="#63B3ED"/>
            <Setter Property="FontFamily" Value="Segoe UI"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Margin" Value="0,0,0,14"/>
            <Setter Property="Padding" Value="8"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="GroupBox">
                        <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="1" CornerRadius="5">
                            <Grid>
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="Auto"/>
                                    <RowDefinition Height="*"/>
                                </Grid.RowDefinitions>
                                <Border Grid.Row="0" Background="#181826" CornerRadius="4,4,0,0" Padding="8,6">
                                    <ContentPresenter ContentSource="Header" SnapsToDevicePixels="{TemplateBinding SnapsToDevicePixels}"/>
                                </Border>
                                <ContentPresenter Grid.Row="1" Margin="{TemplateBinding Padding}" SnapsToDevicePixels="{TemplateBinding SnapsToDevicePixels}"/>
                            </Grid>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style TargetType="TextBox">
            <Setter Property="Background" Value="#181826"/>
            <Setter Property="Foreground" Value="#78789B"/>
            <Setter Property="BorderBrush" Value="#30304E"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="4,2"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="TextBox">
                        <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="3">
                            <ScrollViewer x:Name="PART_ContentHost"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Segmented Tab Navigation RadioButton Style -->
        <Style x:Key="NavTabStyle" TargetType="RadioButton">
            <Setter Property="Foreground" Value="#78789B"/>
            <Setter Property="FontFamily" Value="Segoe UI"/>
            <Setter Property="FontSize" Value="11"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="VerticalAlignment" Value="Stretch"/>
            <Setter Property="HorizontalAlignment" Value="Stretch"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="RadioButton">
                        <Border x:Name="TabBorder" Background="Transparent" CornerRadius="11" Padding="4,0" VerticalAlignment="Stretch" HorizontalAlignment="Stretch">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsChecked" Value="True">
                                <Setter TargetName="TabBorder" Property="Background" Value="#63B3ED"/>
                                <Setter Property="Foreground" Value="#12121C"/>
                                <Setter Property="FontWeight" Value="Bold"/>
                            </Trigger>
                            <MultiTrigger>
                                <MultiTrigger.Conditions>
                                    <Condition Property="IsChecked" Value="False"/>
                                    <Condition Property="IsMouseOver" Value="True"/>
                                </MultiTrigger.Conditions>
                                <Setter Property="Foreground" Value="#DADAE8"/>
                            </MultiTrigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

    </Window.Resources>
    
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="62"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="44"/>
        </Grid.RowDefinitions>
        
        <!-- Header Panel -->
        <Grid Grid.Row="0" Background="#181826">
            <StackPanel Orientation="Vertical" HorizontalAlignment="Left" VerticalAlignment="Center" Margin="14,0,0,0">
                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                    <TextBlock Text="Tooler" FontFamily="Segoe UI" FontSize="18" FontWeight="Bold" Foreground="#63B3ED" VerticalAlignment="Center"/>

                    <!-- Slider Segmented Switch (Apps / Dev / Tweaks) anchored right beside Tooler text -->
                    <Border Background="#12121C" BorderBrush="#30304E" BorderThickness="1" CornerRadius="14" Margin="14,0,0,0" Height="28" VerticalAlignment="Center" Padding="2">
                        <Grid Width="216">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>
                            <RadioButton Name="TabApps" Grid.Column="0" Content="Apps" IsChecked="True" GroupName="NavTabs" Style="{StaticResource NavTabStyle}"/>
                            <RadioButton Name="TabDev" Grid.Column="1" Content="Dev" GroupName="NavTabs" Style="{StaticResource NavTabStyle}"/>
                            <RadioButton Name="TabScripts" Grid.Column="2" Content="Tweaks" GroupName="NavTabs" Style="{StaticResource NavTabStyle}"/>
                        </Grid>
                    </Border>

                    <!-- System Specs & Health Overview HUD Pill -->
                    <Border Name="BorderSystemHUD" Background="#12121C" BorderBrush="#30304E" BorderThickness="1" CornerRadius="14" Margin="14,0,0,0" Height="28" VerticalAlignment="Center" Padding="12,0">
                        <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                            <TextBlock Text="RAM: " FontFamily="Segoe UI" FontSize="10" FontWeight="Bold" Foreground="#63B3ED" VerticalAlignment="Center"/>
                            <TextBlock Name="TxtHudRAM" Text="--" FontFamily="Segoe UI" FontSize="11" FontWeight="SemiBold" Foreground="#E2E8F0" VerticalAlignment="Center"/>
                        </StackPanel>
                    </Border>
                </StackPanel>
                
                <TextBlock Name="LblSubtitle" Text="Check items for batch run   |   Click a button for immediate single execution" FontFamily="Segoe UI" FontSize="11" Foreground="#78789B" Margin="0,3,0,0"/>
            </StackPanel>
            
            <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center" Margin="0,0,15,0">
                <CheckBox Name="ChkSelectAll" Content="Select All" Margin="0,0,15,0" VerticalAlignment="Center"/>
                <Button Name="BtnGithub" Content="GitHub" Width="80" Height="26" Margin="0,0,15,0" VerticalAlignment="Center" Cursor="Hand"/>
                <TextBox Name="TxtSearch" Text="Search..." Width="150" Height="26" VerticalAlignment="Center" Padding="4,2" FontFamily="Segoe UI" FontSize="12"/>
            </StackPanel>
        </Grid>
        
        <!-- Main Content Area -->
        <Grid Grid.Row="1">
            <!-- Apps View -->
            <ScrollViewer Name="AppsScrollViewer" HorizontalScrollBarVisibility="Auto" VerticalScrollBarVisibility="Auto" Background="#12121C" Visibility="Visible">
                <Grid Name="MainGrid">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="*"/>
                    </Grid.ColumnDefinitions>
                    <StackPanel Grid.Column="0" Name="Col0" Margin="14,12,7,12"/>
                    <StackPanel Grid.Column="1" Name="Col1" Margin="7,12,7,12"/>
                    <StackPanel Grid.Column="2" Name="Col2" Margin="7,12,7,12"/>
                    <StackPanel Grid.Column="3" Name="Col3" Margin="7,12,7,12"/>
                    <StackPanel Grid.Column="4" Name="Col4" Margin="7,12,14,12"/>
                </Grid>
            </ScrollViewer>

            <!-- Development View -->
            <ScrollViewer Name="DevScrollViewer" HorizontalScrollBarVisibility="Auto" VerticalScrollBarVisibility="Auto" Background="#12121C" Visibility="Collapsed">
                <Grid Name="DevGrid">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="*"/>
                    </Grid.ColumnDefinitions>
                    <StackPanel Grid.Column="0" Name="DevCol0" Margin="14,12,7,12"/>
                    <StackPanel Grid.Column="1" Name="DevCol1" Margin="7,12,7,12"/>
                    <StackPanel Grid.Column="2" Name="DevCol2" Margin="7,12,7,12"/>
                    <StackPanel Grid.Column="3" Name="DevCol3" Margin="7,12,7,12"/>
                    <StackPanel Grid.Column="4" Name="DevCol4" Margin="7,12,14,12"/>
                </Grid>
            </ScrollViewer>

            <!-- Tweaks View (Two-Section Layout: Left = System Tweaks, Right = Control Panel) -->
            <ScrollViewer Name="ScriptsScrollViewer" HorizontalScrollBarVisibility="Auto" VerticalScrollBarVisibility="Auto" Background="#12121C" Visibility="Collapsed">
                <Grid Margin="18,14,18,14">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*" MinWidth="440"/>
                        <ColumnDefinition Width="18"/>
                        <ColumnDefinition Width="340"/>
                    </Grid.ColumnDefinitions>
                    
                    <!-- Left Side: System & PowerShell Tweaks -->
                    <StackPanel Grid.Column="0" Name="ScriptsContainer">
                        <!-- Tweaks categories populated dynamically -->
                    </StackPanel>
                    
                    <!-- Right Side: Control Panel Shortcuts -->
                    <StackPanel Grid.Column="2" Name="TweaksRightContainer">
                        <!-- Control Panel section populated dynamically -->
                    </StackPanel>
                </Grid>
            </ScrollViewer>
        </Grid>
        
        <!-- Bottom Panel -->
        <Grid Grid.Row="2" Background="#181826">
            <Border BorderThickness="0,2,0,0" BorderBrush="#30304E" VerticalAlignment="Top"/>
            
            <DockPanel Margin="12,0,12,0" LastChildFill="False" VerticalAlignment="Center">
                <TextBlock Name="LblStatus" Text="Ready" Foreground="#78789B" VerticalAlignment="Center" FontFamily="Segoe UI" FontSize="12"/>
                
                <!-- Apps Bottom Controls -->
                <StackPanel Name="PanelAppsControls" Orientation="Horizontal" DockPanel.Dock="Right" VerticalAlignment="Center">
                    <!-- Package Manager Engine Switcher Pill -->
                    <Border Background="#12121C" BorderBrush="#30304E" BorderThickness="1" CornerRadius="14" Height="28" VerticalAlignment="Center" Padding="2" Margin="0,0,10,0" ToolTip="Select preferred backend package manager engine">
                        <Grid Width="144">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>
                            <RadioButton Name="ToggleChoco" Grid.Column="0" Content="Choco" IsChecked="True" GroupName="PkgEngine" Style="{StaticResource NavTabStyle}"/>
                            <RadioButton Name="ToggleWinget" Grid.Column="1" Content="Winget" GroupName="PkgEngine" Style="{StaticResource NavTabStyle}"/>
                        </Grid>
                    </Border>

                    <Button Name="BtnUpgradeAll" Content="choco update" Width="105" Height="28" Margin="0,0,8,0" Cursor="Hand" ToolTip="Update all installed packages using the selected package manager"/>
                    <Button Name="BtnRun" Content="Run selected" Width="105" Height="28" Cursor="Hand"/>
                </StackPanel>
            </DockPanel>
            
            <ProgressBar Name="ProgressBar" Height="4" VerticalAlignment="Bottom" Background="#1E1E30" BorderThickness="0" Foreground="#48C78E" Minimum="0" Value="0"/>
        </Grid>
    </Grid>
</Window>
"@

    Update-InitProgress -Percent 34 -Status "[4/12] Compiling XAML layout & responsive styling..."

    # Parse raw XAML directly via System.Xaml parser
    $script:window = [Windows.Markup.XamlReader]::Parse($xaml)

    Update-InitProgress -Percent 42 -Status "[5/12] Binding WPF visual elements & UI controls..."

    # Extract named controls in script scope
    $script:lblSubtitle = $script:window.FindName("LblSubtitle")
    $script:tabApps = $script:window.FindName("TabApps")
    $script:tabDev = $script:window.FindName("TabDev")
    $script:tabScripts = $script:window.FindName("TabScripts")
    $script:borderSystemHUD = $script:window.FindName("BorderSystemHUD")
    $script:txtHudRAM = $script:window.FindName("TxtHudRAM")
    $script:chkSelectAll = $script:window.FindName("ChkSelectAll")
    $script:btnGithub = $script:window.FindName("BtnGithub")
    $script:txtSearch = $script:window.FindName("TxtSearch")
    $script:appsScrollViewer = $script:window.FindName("AppsScrollViewer")
    $script:devScrollViewer = $script:window.FindName("DevScrollViewer")
    $script:scriptsScrollViewer = $script:window.FindName("ScriptsScrollViewer")
    $script:scriptsContainer = $script:window.FindName("ScriptsContainer")
    $script:tweaksRightContainer = $script:window.FindName("TweaksRightContainer")
    $script:col0 = $script:window.FindName("Col0")
    $script:col1 = $script:window.FindName("Col1")
    $script:col2 = $script:window.FindName("Col2")
    $script:col3 = $script:window.FindName("Col3")
    $script:col4 = $script:window.FindName("Col4")
    $script:devCol0 = $script:window.FindName("DevCol0")
    $script:devCol1 = $script:window.FindName("DevCol1")
    $script:devCol2 = $script:window.FindName("DevCol2")
    $script:devCol3 = $script:window.FindName("DevCol3")
    $script:devCol4 = $script:window.FindName("DevCol4")
    $script:LblStatus = $script:window.FindName("LblStatus")
    $script:panelAppsControls = $script:window.FindName("PanelAppsControls")
    $script:toggleChoco = $script:window.FindName("ToggleChoco")
    $script:toggleWinget = $script:window.FindName("ToggleWinget")
    $script:btnUpgradeAll = $script:window.FindName("BtnUpgradeAll")
    $script:BtnRun = $script:window.FindName("BtnRun")
    $script:ProgressBar = $script:window.FindName("ProgressBar")

    # Populate System Specs HUD immediately
    try {
        $specs = Get-SystemSpecsSummary
        if ($null -ne $script:txtHudRAM -and $null -ne $specs.RAMText) {
            $script:txtHudRAM.Text = $specs.RAMText
        }
    } catch {}

    # ============================================================
    #  SECTION E: HELPER FUNCTIONS FOR BUILDING GUI ROWS
    # ============================================================

    function Write-Log {
        param([string]$Message, [string]$Level = "Info")
        $color = switch ($Level) {
            "Running" { $brushYellow }
            "Success" { $brushGreen }
            "Error" { $brushRed }
            default { $brushText }
        }
        $ts = (Get-Date).ToString("HH:mm:ss")
        $line = "[$ts] $Message"
        $script:LblStatus.Dispatcher.Invoke([System.Action] {
            $script:LblStatus.Foreground = $color
            $script:LblStatus.Text = $line
        })
    }

    function New-TaskRow {
        param(
            [string]       $Name,
            [scriptblock]  $Func,
            $ParentStackPanel,
            [int]          $ColIndex,
            [string]       $Tab = "Apps"
        )

        $rowGrid = New-Object System.Windows.Controls.Grid
        $rowGrid.Margin = New-Object System.Windows.Thickness(0, 2, 0, 2)
        
        $col1Def = New-Object System.Windows.Controls.ColumnDefinition
        $col1Def.Width = New-Object System.Windows.GridLength(30)
        $col2Def = New-Object System.Windows.Controls.ColumnDefinition
        $col2Def.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
        
        $rowGrid.ColumnDefinitions.Add($col1Def)
        $rowGrid.ColumnDefinitions.Add($col2Def)

        # CheckBox
        $cb = New-Object System.Windows.Controls.CheckBox
        $cb.IsChecked = $false
        $cb.VerticalAlignment = "Center"
        $cb.HorizontalAlignment = "Left"
        $cb.Margin = New-Object System.Windows.Thickness(4, 0, 0, 0)
        $rowGrid.Children.Add($cb) | Out-Null
        [System.Windows.Controls.Grid]::SetColumn($cb, 0)

        # Button
        $btn = New-Object System.Windows.Controls.Button
        $btn.Content = $Name
        $btn.HorizontalContentAlignment = "Left"
        $btn.Padding = New-Object System.Windows.Thickness(10, 4, 10, 4)
        $btn.Height = 26
        $btn.Cursor = [System.Windows.Input.Cursors]::Hand
        $btn.Tag = $Func
        
        $rowGrid.Children.Add($btn) | Out-Null
        [System.Windows.Controls.Grid]::SetColumn($btn, 1)

        # Click Execution
        $btn.Add_Click({
            param($s, $e)
            $f = $s.Tag
            $taskName = $s.Content
            Refresh-Env
            Write-Log "Launching: $taskName ..." -Level Running
            try {
                & $f
                Refresh-Env
                Write-Log "$taskName - launched." -Level Success
            }
            catch {
                Write-Log "ERROR: $taskName - $($_.Exception.Message)" -Level Error
            }
            [void]$script:window.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Background, [System.Action] {
                $script:window.Activate() | Out-Null
                if ($null -ne $script:txtSearch) {
                    $script:txtSearch.Focus() | Out-Null
                    $script:txtSearch.SelectAll()
                }
            })
        })

        $ParentStackPanel.Children.Add($rowGrid) | Out-Null

        $entry = @{ 
            Name = $Name
            Function = $Func
            CheckBox = $cb
            Button = $btn
            RowGrid = $rowGrid
            ColIndex = $ColIndex
            Tab = $Tab
        }
        $script:AllTasks.Add($entry)
        return $entry
    }

    function New-CategoryGroup {
        param(
            [string]  $Title,
            [array]   $Items,
            $ParentStackPanel,
            [int]     $ColIndex,
            [string]  $Tab = "Apps"
        )
        
        $gb = New-Object System.Windows.Controls.GroupBox
        $gb.Header = $Title
        
        $inner = New-Object System.Windows.Controls.StackPanel
        $gb.Content = $inner
        
        foreach ($item in $Items) {
            New-TaskRow -Name $item.Name -Func $item.Func -ParentStackPanel $inner -ColIndex $ColIndex -Tab $Tab | Out-Null
        }
        
        $ParentStackPanel.Children.Add($gb) | Out-Null
        return $gb
    }

    # ============================================================
    #  SECTION E-2: HELPER FUNCTIONS FOR SCRIPTS SECTION
    # ============================================================

    function New-ScriptRow {
        param(
            [hashtable]    $ScriptDef,
            $ParentStackPanel
        )

        $cardBorder = New-Object System.Windows.Controls.Border
        $cardBorder.Background = $script:brushGroup
        $cardBorder.BorderBrush = $script:brushSep
        $cardBorder.BorderThickness = New-Object System.Windows.Thickness(1)
        $cardBorder.CornerRadius = New-Object System.Windows.CornerRadius(5)
        $cardBorder.Margin = New-Object System.Windows.Thickness(0, 0, 0, 5)
        $cardBorder.Padding = New-Object System.Windows.Thickness(12, 6, 12, 6)
        if (-not [string]::IsNullOrEmpty($ScriptDef.Description)) {
            $cardBorder.ToolTip = $ScriptDef.Description
        }

        $rowGrid = New-Object System.Windows.Controls.Grid
        
        $colInfo = New-Object System.Windows.Controls.ColumnDefinition
        $colInfo.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
        
        $colBtns = New-Object System.Windows.Controls.ColumnDefinition
        $colBtns.Width = New-Object System.Windows.GridLength(145)
        
        $rowGrid.ColumnDefinitions.Add($colInfo)
        $rowGrid.ColumnDefinitions.Add($colBtns)

        # Info container (Name only - Description shown on hover)
        $lblTitle = New-Object System.Windows.Controls.TextBlock
        $lblTitle.Text = $ScriptDef.Name
        $lblTitle.FontFamily = New-Object System.Windows.Media.FontFamily("Segoe UI")
        $lblTitle.FontSize = 12.5
        $lblTitle.FontWeight = [System.Windows.FontWeights]::SemiBold
        $lblTitle.Foreground = $script:brushText
        $lblTitle.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
        if (-not [string]::IsNullOrEmpty($ScriptDef.Description)) {
            $lblTitle.ToolTip = $ScriptDef.Description
        }
        $rowGrid.Children.Add($lblTitle) | Out-Null
        [System.Windows.Controls.Grid]::SetColumn($lblTitle, 0)

        # Action Buttons container (Revert + Run) - compact height
        $btnsPanel = New-Object System.Windows.Controls.StackPanel
        $btnsPanel.Orientation = [System.Windows.Controls.Orientation]::Horizontal
        $btnsPanel.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Right
        $btnsPanel.VerticalAlignment = [System.Windows.VerticalAlignment]::Center

        # Revert Button (compact height 22px)
        $btnRevert = New-Object System.Windows.Controls.Button
        $btnRevert.Content = "Revert"
        $btnRevert.Width = 64
        $btnRevert.Height = 22
        $btnRevert.Padding = New-Object System.Windows.Thickness(6, 1, 6, 1)
        $btnRevert.FontSize = 11
        $btnRevert.Margin = New-Object System.Windows.Thickness(0, 0, 6, 0)
        $btnRevert.HorizontalContentAlignment = [System.Windows.HorizontalAlignment]::Center
        $btnRevert.Cursor = [System.Windows.Input.Cursors]::Hand
        $btnRevert.Tag = $ScriptDef
        
        $btnRevert.Add_Click({
            param($s, $e)
            $def = $s.Tag
            $name = $def.Name
            Refresh-Env
            if ($null -ne $def.Off) {
                Write-Log "Reverting: $name ..." -Level Running
                try {
                    & $def.Off
                    Refresh-Env
                    Write-Log "$name - reverted." -Level Success
                } catch {
                    Write-Log "ERROR: $name - $($_.Exception.Message)" -Level Error
                }
            } else {
                Write-Log "Info: No revert action needed for $name." -Level Info
            }
            [void]$script:window.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Background, [System.Action] {
                $script:window.Activate() | Out-Null
                if ($null -ne $script:txtSearch) {
                    $script:txtSearch.Focus() | Out-Null
                    $script:txtSearch.SelectAll()
                }
            })
        })
        $btnsPanel.Children.Add($btnRevert) | Out-Null

        # Run Button (compact height 22px)
        $btnRun = New-Object System.Windows.Controls.Button
        $btnRun.Content = "Run"
        $btnRun.Width = 64
        $btnRun.Height = 22
        $btnRun.Padding = New-Object System.Windows.Thickness(6, 1, 6, 1)
        $btnRun.FontSize = 11
        $btnRun.HorizontalContentAlignment = [System.Windows.HorizontalAlignment]::Center
        $btnRun.Cursor = [System.Windows.Input.Cursors]::Hand
        $btnRun.Tag = $ScriptDef
        
        $btnRun.Add_Click({
            param($s, $e)
            $def = $s.Tag
            $name = $def.Name
            Refresh-Env
            Write-Log "Launching tweak: $name ..." -Level Running
            try {
                if ($null -ne $def.On) {
                    & $def.On
                    Refresh-Env
                    Write-Log "$name - executed." -Level Success
                }
            } catch {
                Write-Log "ERROR: $name - $($_.Exception.Message)" -Level Error
            }
            [void]$script:window.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Background, [System.Action] {
                $script:window.Activate() | Out-Null
                if ($null -ne $script:txtSearch) {
                    $script:txtSearch.Focus() | Out-Null
                    $script:txtSearch.SelectAll()
                }
            })
        })
        $btnsPanel.Children.Add($btnRun) | Out-Null

        $rowGrid.Children.Add($btnsPanel) | Out-Null
        [System.Windows.Controls.Grid]::SetColumn($btnsPanel, 1)

        $cardBorder.Child = $rowGrid
        $ParentStackPanel.Children.Add($cardBorder) | Out-Null

        $entry = @{
            Name        = $ScriptDef.Name
            Category    = $ScriptDef.Category
            Description = $ScriptDef.Description
            On          = $ScriptDef.On
            Off         = $ScriptDef.Off
            CardBorder  = $cardBorder
            RunBtn      = $btnRun
            RevertBtn   = $btnRevert
        }
        $script:AllScripts.Add($entry)
        return $entry
    }

    function New-SettingsRow {
        param(
            [string]       $Name,
            [scriptblock]  $Func,
            $ParentStackPanel
        )

        $btn = New-Object System.Windows.Controls.Button
        $btn.Content = $Name
        $btn.HorizontalContentAlignment = "Left"
        $btn.Padding = New-Object System.Windows.Thickness(12, 4, 12, 4)
        $btn.Height = 26
        $btn.Margin = New-Object System.Windows.Thickness(0, 0, 0, 4)
        $btn.Cursor = [System.Windows.Input.Cursors]::Hand
        $btn.Tag = $Func
        $btn.FontFamily = New-Object System.Windows.Media.FontFamily("Segoe UI")
        $btn.FontSize = 12

        $btn.Add_Click({
            param($s, $e)
            $f = $s.Tag
            $tName = $s.Content
            Refresh-Env
            Write-Log "Launching: $tName ..." -Level Running
            try {
                & $f
                Refresh-Env
                Write-Log "$tName - launched." -Level Success
            } catch {
                Write-Log "ERROR: $tName - $($_.Exception.Message)" -Level Error
            }
            [void]$script:window.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Background, [System.Action] {
                $script:window.Activate() | Out-Null
                if ($null -ne $script:txtSearch) {
                    $script:txtSearch.Focus() | Out-Null
                    $script:txtSearch.SelectAll()
                }
            })
        })

        $ParentStackPanel.Children.Add($btn) | Out-Null

        $entry = @{
            Name        = $Name
            Category    = "Settings"
            Function    = $Func
            CardBorder  = $btn
            Button      = $btn
        }
        $script:AllControlPanelTasks.Add($entry)
        return $entry
    }

    # ============================================================
    #  SECTION F: POPULATE APPS CATEGORIES
    # ============================================================

    function Add-Category {
        param([int]$ColIndex, [string]$Title, [array]$Items)
        $parentPanel = switch ($ColIndex) {
            0 { $script:col0 }
            1 { $script:col1 }
            2 { $script:col2 }
            3 { $script:col3 }
            4 { $script:col4 }
        }
        New-CategoryGroup -Title $Title -Items $Items -ParentStackPanel $parentPanel -ColIndex $ColIndex -Tab "Apps" | Out-Null
    }

    function Add-DevCategory {
        param([int]$ColIndex, [string]$Title, [array]$Items)
        $parentPanel = switch ($ColIndex) {
            0 { $script:devCol0 }
            1 { $script:devCol1 }
            2 { $script:devCol2 }
            3 { $script:devCol3 }
            4 { $script:devCol4 }
        }
        New-CategoryGroup -Title $Title -Items $Items -ParentStackPanel $parentPanel -ColIndex $ColIndex -Tab "Dev" | Out-Null
    }

    # Column 0
    # Column 0
    Update-InitProgress -Percent 50 -Status "[6/12] Building Apps: Essential & System tools..."
    Add-Category -ColIndex 0 -Title "About AFNAN" -Items @(
        @{ Name = "Open Portfolio"; Func = { Open-Portfolio } }
    )

    Add-Category -ColIndex 0 -Title "Essential" -Items @(
        @{ Name = "Chocolatey"; Func = { Install-Choco } },
        @{ Name = "Node.js LTS"; Func = { Install-NodeLTS } },
        @{ Name = "Scoop"; Func = { Install-Scoop } },
        @{ Name = "pnpm"; Func = { Install-Pnpm } },
        @{ Name = "Yarn"; Func = { Install-Yarn } },
        @{ Name = "Bun"; Func = { Install-Bun } },
        @{ Name = "Go"; Func = { Install-Go } },
        @{ Name = "Deno"; Func = { Install-Deno } }
    )

    # Column 1
    Add-Category -ColIndex 1 -Title "Recommended Tools" -Items @(
        @{ Name = "Git"; Func = { Install-Git } },
        @{ Name = "Python"; Func = { Install-Python } },
        @{ Name = ".NET Runtime"; Func = { Install-Dotnet } },
        @{ Name = "FFmpeg"; Func = { Install-FFmpeg } },
        @{ Name = "7-Zip"; Func = { Install-7Zip } },
        @{ Name = "PeaZip"; Func = { Install-PeaZip } },
        @{ Name = "WinDirStat"; Func = { Install-WinDirStat } },
        @{ Name = "yt-dlp"; Func = { Install-YTDLP } },
        @{ Name = "ngrok"; Func = { Install-Ngrok } },
        @{ Name = "localtunnel"; Func = { Install-Localtunnel } },
        @{ Name = "miniserve"; Func = { Install-Miniserve } },
        @{ Name = "Edge WebView2 Runtime"; Func = { Install-WebView2 } }
    )

    Add-Category -ColIndex 1 -Title "Other Apps" -Items @(
        @{ Name = "Fast Stone Image"; Func = { Install-FastStone } },
        @{ Name = "Vlc"; Func = { Install-VLC } },
        @{ Name = "MPC HC"; Func = { Install-MPC-HC } },
        @{ Name = "Only Office"; Func = { Install-OnlyOffice } },
        @{ Name = "Kdenlive"; Func = { Install-Kdenlive } },
        @{ Name = "HandBrake"; Func = { Install-HandBrake } },
        @{ Name = "IDM"; Func = { Install-IDM } },
        @{ Name = "Ghost Downloader"; Func = { Install-GhostDownloader } },
        @{ Name = "Virtual Box"; Func = { Install-VirtualBox } }
    )

    # Column 2
    Update-InitProgress -Percent 58 -Status "[7/12] Building Apps: Media, Scripts & Utilities..."
    Add-Category -ColIndex 2 -Title "Run Scripts" -Items @(
        @{ Name = "Chris Titus Tool"; Func = { Run-Titus } },
        @{ Name = "Mass Grave"; Func = { Run-MassGrave } },
        @{ Name = "Win11 Debloat"; Func = { Run-Win11Debloat } },
        @{ Name = "WinScript"; Func = { Run-WinScript } },
        @{ Name = "Coporton"; Func = { Run-Coporton } },
        @{ Name = "IDM Fixer"; Func = { Run-IDM } },
        @{ Name = "Sparkle"; Func = { Run-Sparkle } },
        @{ Name = "GHGrab (GitHub Grabber)"; Func = { Run-GHGrab } },
        @{ Name = "Tooler Setup"; Func = { Run-Setup } },
        @{ Name = "VPN"; Func = { Run-VPN } },
        @{ Name = "Tor Link"; Func = { Run-TorLink } },
        @{ Name = "Tork"; Func = { Install-Tork } },
        @{ Name = "YTDLP Frontend"; Func = { Run-YTDLPFrontend } },
        @{ Name = "Yoinks"; Func = { Run-Yoinks } }
    )

    Add-Category -ColIndex 2 -Title "AI in PC" -Items @(
        @{ Name = "Google Desktop App"; Func = { Open-GoogleDesktopApp } },
        @{ Name = "LLM-Checker"; Func = { Run-LLMChecker } },
        @{ Name = "LLMFit"; Func = { Install-LLMFit } },
        @{ Name = "Ollama"; Func = { Install-Ollama } }
    )

    # Column 3
    Add-Category -ColIndex 3 -Title "System Tools" -Items @(
        @{ Name = "WSL (Ubuntu)"; Func = { Install-WSL } },
        @{ Name = "Winget"; Func = { Install-Winget } },
        @{ Name = "Everything Search"; Func = { Install-Everything } },
        @{ Name = "RustDesk"; Func = { Install-RustDesk } },
        @{ Name = "HiBit Uninstaller"; Func = { Install-HiBit } },
        @{ Name = "Superfile"; Func = { Install-Superfile } },
        @{ Name = "Alacritty"; Func = { Install-Alacritty } },
        @{ Name = "UniGetUI"; Func = { Install-UniGetUI } },
        @{ Name = "Scrcpy GUI"; Func = { Install-Scrcpy } },
        @{ Name = "VC++ Runtimes"; Func = { Install-VCC-Runtimes } },
        @{ Name = "DirectX Runtime"; Func = { Install-DirectX } }
    )

    Add-Category -ColIndex 3 -Title "Productivity Apps" -Items @(
        @{ Name = "Office 365"; Func = { Install-Office365 } },
        @{ Name = "Chrome"; Func = { Install-Chrome } },
        @{ Name = "Zen Browser"; Func = { Install-Zen } },
        @{ Name = "OBS Studio"; Func = { Install-OBS } },
        @{ Name = "LocalSend"; Func = { Install-LocalSend } },
        @{ Name = "Notepad++"; Func = { Install-NotepadPP } },
        @{ Name = "ShareX"; Func = { Install-ShareX } },
        @{ Name = "qBittorrent"; Func = { Install-QBit } }
    )

    # Column 4
    Add-Category -ColIndex 4 -Title "Win Tools" -Items @(
        @{ Name = "TestDisk"; Func = { Install-TestDisk } },
        @{ Name = "FreeRecover"; Func = { Install-FreeRecover } },
        @{ Name = "Kickass Undelete"; Func = { Install-KickassUndelete } },
        @{ Name = "CPU-Z"; Func = { Install-CPUZ } },
        @{ Name = "HWiNFO"; Func = { Install-HWiNFO } },
        @{ Name = "GPU-Z"; Func = { Install-GPUZ } },
        @{ Name = "CrystalDiskInfo"; Func = { Install-CrystalDiskInfo } },
        @{ Name = "CrystalDiskMark"; Func = { Install-CrystalDiskMark } },
        @{ Name = "DriverStore Explorer"; Func = { Install-DriverStoreExplorer } },
        @{ Name = "Ventoy"; Func = { Install-Ventoy } },
        @{ Name = "Rufus"; Func = { Install-Rufus } },
        @{ Name = "AnyBurn"; Func = { Install-AnyBurn } },
        @{ Name = "Git Cloner"; Func = { Run-GitCloner } },
        @{ Name = "Downly"; Func = { Install-Downly } },
        @{ Name = "Monkeytype tui"; Func = { Run-MonkeytypeTui } }
    )

    # ============================================================
    #  SECTION F-2: POPULATE DEVELOPMENT CATEGORIES
    # ============================================================

    Update-InitProgress -Percent 66 -Status "[8/12] Building Dev: IDEs, CLI Agents & Automation..."

    # Column 0: IDE
    Add-DevCategory -ColIndex 0 -Title "IDE" -Items @(
        @{ Name = "AntiGravity IDE"; Func = { Install-AntiGravity-ide } },
        @{ Name = "VS Code"; Func = { Install-VSCode } },
        @{ Name = "Zed Editor"; Func = { Install-Zed } },
        @{ Name = "Cursor IDE"; Func = { Install-Cursoride } },
        @{ Name = "Android Studio"; Func = { Install-AndroidStudio } }
    )

    # Column 1: CLI Agents
    Add-DevCategory -ColIndex 1 -Title "CLI Agents" -Items @(
        @{ Name = "Agy"; Func = { Install-Agy } },
        @{ Name = "Antigravity Manager"; Func = { Install-AntigravityManager } },
        @{ Name = "Opencode"; Func = { Install-Opencode } },
        @{ Name = "Claude Code"; Func = { Install-ClaudeCode } },
        @{ Name = "Claude Code Router"; Func = { Install-ClaudeCodeRouter } },
        @{ Name = "Codebuff"; Func = { Install-Codebuff } },
        @{ Name = "Omniroute"; Func = { Install-Omniroute } }
    )

    # Column 2: Automation
    Add-DevCategory -ColIndex 2 -Title "Automation" -Items @(
        @{ Name = "n8n Workflow Automation"; Func = { Install-N8N } },
        @{ Name = "Google Workspace CLI (GWS)"; Func = { Install-GWS } },
        @{ Name = "Hermes GUI"; Func = { Install-HermesGUI } },
        @{ Name = "Hermes CLI"; Func = { Install-HermesCLI } },
        @{ Name = "OpenClaw"; Func = { Install-OpenClaw } }
    )

    Update-InitProgress -Percent 75 -Status "[9/12] Building Dev: Languages, TUI & Other Dev tools..."

    # Column 3: Languages
    Add-DevCategory -ColIndex 3 -Title "Languages" -Items @(
        @{ Name = "MinGW (C/C++)"; Func = { Install-MinGW } },
        @{ Name = "Rust"; Func = { Install-Rust } },
        @{ Name = "Java"; Func = { Install-Java } },
        @{ Name = "Eclipse Temurin JDK (Hotspot)"; Func = { Install-TemurinJDK } }
    )

    # Column 4: TUI & Other Dev
    Add-DevCategory -ColIndex 4 -Title "TUI" -Items @(
        @{ Name = "gh cli"; Func = { Install-GhCli } },
        @{ Name = "lazy git"; Func = { Install-LazyGit } },
        @{ Name = "lazy docker"; Func = { Install-LazyDocker } }
    )

    Add-DevCategory -ColIndex 4 -Title "Other Dev" -Items @(
        @{ Name = "Flutter"; Func = { Install-Flutter } },
        @{ Name = "Android SDK Binary"; Func = { Install-AndroidSDK } },
        @{ Name = "Android NDK"; Func = { Install-AndroidNDK } }
    )

    # ============================================================
    #  SECTION F-3: POPULATE SCRIPTS SECTION (On/Off Architecture)
    # ============================================================
    $script:ScriptDefinitions = @(
        @{
            Name        = "Context Menu Style"
            Category    = "System Tweaks"
            Description = "Run: Modern Windows 11 context menu  |  Revert: Classic Windows 10 context menu"
            On          = { Set-Win11ContextMenu }
            Off         = { Set-Win10ContextMenu }
        },
        @{
            Name        = "Ultimate Performance"
            Category    = "System Tweaks"
            Description = "Run: Unlock & activate Ultimate Performance power plan  |  Revert: Restore Balanced plan"
            On          = { Set-UltimatePerformance }
            Off         = { Reset-UltimatePerformance }
        },
        @{
            Name        = "Show Ext & Hidden Files"
            Category    = "System Tweaks"
            Description = "Run: Show known file extensions and hidden files in Explorer  |  Revert: Restore defaults"
            On          = { Set-ShowExtensionsAndHidden }
            Off         = { Reset-ShowExtensionsAndHidden }
        },
        @{
            Name        = "Enable Long Paths"
            Category    = "System Tweaks"
            Description = "Run: Remove Windows 260-character MAX_PATH file path limit  |  Revert: Restore default 260-char limit"
            On          = { Enable-LongPaths }
            Off         = { Disable-LongPaths }
        },
        @{
            Name        = "Disable Start Bing Search"
            Category    = "System Tweaks"
            Description = "Run: Disable Bing/web search in Windows Start Menu  |  Revert: Enable Bing search"
            On          = { Disable-StartBingSearch }
            Off         = { Enable-StartBingSearch }
        },
        @{
            Name        = "Instant Menu Delay"
            Category    = "System Tweaks"
            Description = "Run: Remove right-click & flyout menu delay (0ms)  |  Revert: Restore Windows default (400ms)"
            On          = { Set-MenuShowDelay }
            Off         = { Reset-MenuShowDelay }
        },
        @{
            Name        = "Dark / Light Theme"
            Category    = "System Tweaks"
            Description = "Run: Apply Windows Dark Theme  |  Revert: Apply Windows Light Theme"
            On          = { Set-DarkTheme }
            Off         = { Set-LightTheme }
        },
        @{
            Name        = "God Mode Folder"
            Category    = "System Tweaks"
            Description = "Run: Create GodMode master control folder on Desktop  |  Revert: Remove GodMode folder"
            On          = { Create-GodModeFolder }
            Off         = { Remove-GodModeFolder }
        },
        @{
            Name        = "CMD Color 0a"
            Category    = "System Tweaks"
            Description = "Run: Set Command Prompt color scheme to Matrix green (0a)  |  Revert: Reset default color"
            On          = { Set-CMD0A }
            Off         = { Reset-CMDColor }
        },
        @{
            Name        = "Cursor / Elegant Theme"
            Category    = "System Tweaks"
            Description = "Run: Download and apply custom Elegant cursor scheme  |  Revert: Restore default cursor"
            On          = { Install-Cursor }
            Off         = { Reset-Cursor }
        },
        @{
            Name        = "Clean Temp & Cache"
            Category    = "Maintenance"
            Description = "Run: Clean temporary files, Windows cache, and prefetch junk"
            On          = { Clear-TempJunk }
            Off         = $null
        },
        @{
            Name        = "Flush DNS Cache"
            Category    = "Maintenance"
            Description = "Run: Flush and reset Windows DNS resolver cache (ipconfig /flushdns)"
            On          = { Flush-DnsCache }
            Off         = $null
        },
        @{
            Name        = "See Execution Policy"
            Category    = "PowerShell Tweaks"
            Description = "Inspect current PowerShell execution policy across all scopes"
            On          = { See-Policy }
            Off         = $null
        },
        @{
            Name        = "Unrestrict Policy"
            Category    = "PowerShell Tweaks"
            Description = "Run: Set PowerShell policy to Unrestricted  |  Revert: Set policy to Restricted"
            On          = { Unrestrict-Policy }
            Off         = { Restrict-Policy }
        }
    )

    function Build-ScriptsSection {
        $categories = $script:ScriptDefinitions | Group-Object -Property Category
        foreach ($cat in $categories) {
            $gb = New-Object System.Windows.Controls.GroupBox
            $gb.Header = $cat.Name
            $gb.Margin = New-Object System.Windows.Thickness(0, 0, 0, 14)
            
            $inner = New-Object System.Windows.Controls.StackPanel
            $gb.Content = $inner
            
            foreach ($scriptDef in $cat.Group) {
                New-ScriptRow -ScriptDef $scriptDef -ParentStackPanel $inner | Out-Null
            }
            
            $script:scriptsContainer.Children.Add($gb) | Out-Null
            $script:ScriptGroupBoxes.Add($gb)
        }
    }

    function Build-SettingsSection {
        $gb = New-Object System.Windows.Controls.GroupBox
        $gb.Header = "Settings"
        $gb.Margin = New-Object System.Windows.Thickness(0, 0, 0, 14)
        
        $inner = New-Object System.Windows.Controls.StackPanel
        $gb.Content = $inner
        
        $settingsItems = @(
            @{ Name = "Sync Time (Auto Fix)";     Func = { Sync-SystemTime } },
            @{ Name = "Date & Time Settings";     Func = { Open-DateTimeSettings } },
            @{ Name = "Environment Variables";    Func = { Open-EnvironmentVariables } },
            @{ Name = "Network Connections";      Func = { Open-NetworkConnections } },
            @{ Name = "Sound Control Panel";      Func = { Open-SoundControlPanel } },
            @{ Name = "Windows Services";         Func = { Open-Services } },
            @{ Name = "Installed Programs";       Func = { Open-ProgramsAndFeatures } },
            @{ Name = "Windows Security";         Func = { Open-WindowsSecurity } },
            @{ Name = "Classic Control Panel";    Func = { Open-ControlPanel } },
            @{ Name = "Devices and Printers";     Func = { Open-DevicesAndPrinters } },
            @{ Name = "Mouse Properties";         Func = { Open-MouseProperties } },
            @{ Name = "Task Manager";             Func = { Open-TaskManager } },
            @{ Name = "Device Manager";           Func = { Open-DeviceManager } },
            @{ Name = "Disk Management";          Func = { Open-DiskManagement } },
            @{ Name = "System Properties";        Func = { Open-SystemProperties } },
            @{ Name = "System Config (MSConfig)"; Func = { Open-MSConfig } },
            @{ Name = "Power Options";            Func = { Open-PowerOptions } }
        )

        foreach ($item in $settingsItems) {
            New-SettingsRow -Name $item.Name -Func $item.Func -ParentStackPanel $inner | Out-Null
        }

        $script:tweaksRightContainer.Children.Add($gb) | Out-Null
        $script:ScriptGroupBoxes.Add($gb)
    }

    Update-InitProgress -Percent 83 -Status "[10/12] Building System Tweaks & Maintenance cards..."
    Build-ScriptsSection

    Update-InitProgress -Percent 91 -Status "[11/12] Building Windows Settings & Control Panel..."
    Build-SettingsSection

    # ============================================================
    #  SECTION G: RUN SELECTED APPS (non-blocking via Runspace)
    # ============================================================

    $script:BtnRun.Add_Click({
        # Gather checked items
        $selected = @($script:AllTasks | Where-Object { $_.CheckBox.IsChecked })

        if (-not $selected -or $selected.Count -eq 0) {
            [System.Windows.MessageBox]::Show(
                "No items are checked.`nPlease check at least one item before clicking Run Selected.",
                "Nothing Selected",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Information
            ) | Out-Null
            return
        }

        $script:BtnRun.IsEnabled = $false
        $script:BtnRun.Content = "Running..."
        $script:ProgressBar.Value = 0
        $script:ProgressBar.Maximum = $selected.Count

        Write-Log ("=== Batch run started: {0} item(s) ===" -f $selected.Count) -Level Info

        # Share references into runspace
        $rsData = @{
            SelectedTasks = $selected
            ProgressBar   = $script:ProgressBar
            StatusLabel   = $script:LblStatus
            RunButton     = $script:BtnRun
            CLR_TEXT      = $brushText
            CLR_YELLOW    = $brushYellow
            CLR_GREEN     = $brushGreen
            CLR_RED       = $brushRed
        }

        $rs = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
        $rs.ApartmentState = "STA"
        $rs.ThreadOptions = "ReuseThread"
        $rs.Open()
        foreach ($k in $rsData.Keys) { $rs.SessionStateProxy.SetVariable($k, $rsData[$k]) }

        $ps = [System.Management.Automation.PowerShell]::Create()
        $ps.Runspace = $rs

        [void]$ps.AddScript({
            function Ui-Log {
                param([string]$Msg, $Clr)
                $ts = (Get-Date).ToString("HH:mm:ss")
                $StatusLabel.Dispatcher.Invoke([System.Action] {
                    $StatusLabel.Foreground = $Clr
                    $StatusLabel.Text = "[$ts] $Msg"
                })
            }

            function Refresh-RunspaceEnv {
                try {
                    $m = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine)
                    $u = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::User)
                    $comb = "$m;$u"
                    $cp = @(
                        "$env:ProgramData\chocolatey\bin",
                        "$env:USERPROFILE\scoop\shims",
                        "$env:APPDATA\npm",
                        "$env:ProgramFiles\nodejs",
                        "$env:LOCALAPPDATA\Programs\Python\Python313",
                        "$env:LOCALAPPDATA\Programs\Python\Python313\Scripts",
                        "$env:LOCALAPPDATA\Programs\Python\Python312",
                        "$env:LOCALAPPDATA\Programs\Python\Python312\Scripts",
                        "$env:LOCALAPPDATA\Programs\Python\Python311",
                        "$env:LOCALAPPDATA\Programs\Python\Python311\Scripts",
                        "$env:ProgramFiles\Git\cmd",
                        "$env:USERPROFILE\go\bin",
                        "$env:USERPROFILE\.cargo\bin",
                        "$env:LOCALAPPDATA\Microsoft\WindowsApps"
                    )
                    foreach ($p in $cp) {
                        if ((Test-Path $p) -and ($comb -notlike "*$p*")) {
                            $comb = "$p;$comb"
                        }
                    }
                    $env:Path = $comb
                    [System.Environment]::SetEnvironmentVariable("Path", $comb, [System.EnvironmentVariableTarget]::Process)
                } catch {}
            }

            $total = $SelectedTasks.Count
            $ok = 0
            $fail = 0

            for ($i = 0; $i -lt $total; $i++) {
                $task = $SelectedTasks[$i]
                $idx = $i
                $tName = $task.Name
                $StatusLabel.Dispatcher.Invoke([System.Action] {
                    $StatusLabel.Text = "Task $($idx+1) of $total : $tName"
                })

                Refresh-RunspaceEnv
                Ui-Log -Msg "Running: $($task.Name) ..." -Clr $CLR_YELLOW

                if ($null -eq $task -or $null -eq $task.Function) {
                    Ui-Log -Msg "FAILED:  $($task.Name) | Invalid action object." -Clr $CLR_RED
                    $fail++
                    continue
                }
                if ($task.Function -isnot [scriptblock] -and $task.Function -isnot [System.Management.Automation.ScriptBlock]) {
                    Ui-Log -Msg "FAILED:  $($task.Name) | Action is not executable." -Clr $CLR_RED
                    $fail++
                    continue
                }
                if ($task.Name -match "(?i)Portfolio") {
                    Ui-Log -Msg "Skipped: $($task.Name) (Not an installer)" -Clr $CLR_YELLOW
                    continue
                }

                try {
                    & $task.Function
                    Refresh-RunspaceEnv
                    Ui-Log -Msg "Done:    $($task.Name)" -Clr $CLR_GREEN
                    $ok++
                }
                catch {
                    Ui-Log -Msg "FAILED:  $($task.Name) | $($_.Exception.Message)" -Clr $CLR_RED
                    $fail++
                }

                $pVal = $i + 1
                $ProgressBar.Dispatcher.Invoke([System.Action] {
                    $ProgressBar.Value = [Math]::Min($pVal, $ProgressBar.Maximum)
                })

                Start-Sleep -Milliseconds 250
            }

            $sumMsg = "=== Completed: $ok Successful  |  $fail Failed ==="
            $sumClr = if ($fail -gt 0) { $CLR_RED } else { $CLR_GREEN }
            Ui-Log -Msg $sumMsg -Clr $sumClr

            $RunButton.Dispatcher.Invoke([System.Action] {
                $RunButton.IsEnabled = $true
                $RunButton.Content = "Run selected"
            })
            $StatusLabel.Dispatcher.Invoke([System.Action] {
                $StatusLabel.Text = "Done   OK: $ok   Failed: $fail"
            })

            $RunButton.Dispatcher.Invoke([System.Action] {
                $icon = if ($fail -gt 0) {
                    [System.Windows.MessageBoxImage]::Warning
                }
                else {
                    [System.Windows.MessageBoxImage]::Information
                }
                [System.Windows.MessageBox]::Show(
                    "Batch run complete.`n`nSuccessful : $ok`nFailed     : $fail",
                    "Run Summary",
                    [System.Windows.MessageBoxButton]::OK,
                    $icon
                ) | Out-Null
            })
        })

        [void]$ps.BeginInvoke()
    })

    # ============================================================
    #  SECTION H: EVENT WIREUPS
    # ============================================================

    # Navigation Slidebar Tabs Switching
    $script:clearSearchForTabSwitch = {
        if ($null -ne $script:txtSearch -and $script:txtSearch.Text -ne "" -and $script:txtSearch.Text -ne "Search...") {
            $script:txtSearch.Text = ""
        }
    }
    $script:tabApps.Add_PreviewMouseDown($script:clearSearchForTabSwitch)
    $script:tabDev.Add_PreviewMouseDown($script:clearSearchForTabSwitch)
    $script:tabScripts.Add_PreviewMouseDown($script:clearSearchForTabSwitch)

    $script:tabApps.Add_Checked({
        if (-not $script:InAutoSwitch -and $null -ne $script:txtSearch -and $script:txtSearch.Text -ne "" -and $script:txtSearch.Text -ne "Search...") {
            $script:txtSearch.Text = ""
        }
        $script:appsScrollViewer.Visibility = [System.Windows.Visibility]::Visible
        $script:devScrollViewer.Visibility = [System.Windows.Visibility]::Collapsed
        $script:scriptsScrollViewer.Visibility = [System.Windows.Visibility]::Collapsed
        $script:chkSelectAll.Visibility = [System.Windows.Visibility]::Visible
        $script:panelAppsControls.Visibility = [System.Windows.Visibility]::Visible
        if ($null -ne $script:lblSubtitle) {
            $script:lblSubtitle.Text = "Check items for batch run   |   Click a button for immediate single execution"
        }
        Update-SearchFilter
        [void]$script:txtSearch.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Background, [System.Action] {
            if ($null -ne $script:txtSearch) {
                $script:txtSearch.Focus() | Out-Null
                $script:txtSearch.SelectAll()
            }
        })
    })

    $script:tabDev.Add_Checked({
        if (-not $script:InAutoSwitch -and $null -ne $script:txtSearch -and $script:txtSearch.Text -ne "" -and $script:txtSearch.Text -ne "Search...") {
            $script:txtSearch.Text = ""
        }
        $script:appsScrollViewer.Visibility = [System.Windows.Visibility]::Collapsed
        $script:devScrollViewer.Visibility = [System.Windows.Visibility]::Visible
        $script:scriptsScrollViewer.Visibility = [System.Windows.Visibility]::Collapsed
        $script:chkSelectAll.Visibility = [System.Windows.Visibility]::Visible
        $script:panelAppsControls.Visibility = [System.Windows.Visibility]::Visible
        if ($null -ne $script:lblSubtitle) {
            $script:lblSubtitle.Text = "Check items for batch run   |   Click a button for immediate single execution"
        }
        Update-SearchFilter
        [void]$script:txtSearch.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Background, [System.Action] {
            if ($null -ne $script:txtSearch) {
                $script:txtSearch.Focus() | Out-Null
                $script:txtSearch.SelectAll()
            }
        })
    })

    $script:tabScripts.Add_Checked({
        if (-not $script:InAutoSwitch -and $null -ne $script:txtSearch -and $script:txtSearch.Text -ne "" -and $script:txtSearch.Text -ne "Search...") {
            $script:txtSearch.Text = ""
        }
        $script:appsScrollViewer.Visibility = [System.Windows.Visibility]::Collapsed
        $script:devScrollViewer.Visibility = [System.Windows.Visibility]::Collapsed
        $script:scriptsScrollViewer.Visibility = [System.Windows.Visibility]::Visible
        $script:chkSelectAll.Visibility = [System.Windows.Visibility]::Collapsed
        $script:panelAppsControls.Visibility = [System.Windows.Visibility]::Collapsed
        if ($null -ne $script:lblSubtitle) {
            $script:lblSubtitle.Text = "Click Run to apply tweaks, Revert to restore defaults, or open Settings tools"
        }
        Update-SearchFilter
        [void]$script:txtSearch.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Background, [System.Action] {
            if ($null -ne $script:txtSearch) {
                $script:txtSearch.Focus() | Out-Null
                $script:txtSearch.SelectAll()
            }
        })
    })

    # Select All / Unselect All
    $script:chkSelectAll.Add_Checked({
        $activeTab = if ($script:tabDev.IsChecked) { "Dev" } else { "Apps" }
        foreach ($t in $script:AllTasks) {
            if ($t.Tab -eq $activeTab) {
                $t.CheckBox.IsChecked = $true
            }
        }
    })
    $script:chkSelectAll.Add_Unchecked({
        $activeTab = if ($script:tabDev.IsChecked) { "Dev" } else { "Apps" }
        foreach ($t in $script:AllTasks) {
            if ($t.Tab -eq $activeTab) {
                $t.CheckBox.IsChecked = $false
            }
        }
    })

    # GitHub Button
    $script:btnGithub.Add_Click({ Open-Github })


    # Package Manager Engine Toggle
    $script:toggleChoco.Add_Checked({
        $script:PreferredPkgEngine = "Choco"
        if ($null -ne $script:btnUpgradeAll) {
            $script:btnUpgradeAll.Content = "choco update"
        }
        Write-Log "Package Manager Engine set to: Chocolatey (Default)" -Level Info
    })
    $script:toggleWinget.Add_Checked({
        $script:PreferredPkgEngine = "Winget"
        if ($null -ne $script:btnUpgradeAll) {
            $script:btnUpgradeAll.Content = "winget update"
        }
        Write-Log "Package Manager Engine set to: Winget (Windows Package Manager)" -Level Info
    })

    # Bottom Panel Update Button (adapts to selected package manager)
    $script:btnUpgradeAll.Add_Click({
        if ($script:PreferredPkgEngine -eq "Winget") {
            Write-Log "Running Winget package updates..." -Level Running
            Start-Process winget -WindowStyle Minimized -ArgumentList "upgrade", "--all", "--silent", "--accept-source-agreements", "--accept-package-agreements"
        } else {
            Write-Log "Running Chocolatey package updates..." -Level Running
            Start-Process cmd -WindowStyle Minimized -ArgumentList "/k", "choco upgrade all -y --no-desktop-shortcut && echo. && echo Press any key to exit . . . && pause >nul && exit"
        }
    })

    # Search & Filter Engine across ALL tabs
    function Update-SearchFilter {
        if ($script:SkipSearchUpdate) { return }
        $query = $script:txtSearch.Text.Trim()
        $isQueryEmpty = ($query -eq "") -or ($query -eq "Search...")

        # 1. Filter Apps & Dev tasks
        foreach ($t in $script:AllTasks) {
            $innerPanel = $t.RowGrid.Parent
            $gb = $innerPanel.Parent
            
            if ($isQueryEmpty) {
                $match = $true
            } else {
                $match = ($t.Name -match "(?i)" + [regex]::Escape($query)) -or ($gb.Header -match "(?i)" + [regex]::Escape($query))
                if (-not $match -and $null -ne $t.Function) {
                    $funcText = $t.Function.ToString()
                    $match = $funcText -match "(?i)" + [regex]::Escape($query)
                }
            }
            
            if ($match) {
                $t.RowGrid.Visibility = [System.Windows.Visibility]::Visible
            } else {
                $t.RowGrid.Visibility = [System.Windows.Visibility]::Collapsed
            }
        }
        
        # Hide Apps and Dev groupboxes with no visible tasks
        $gbs = @()
        foreach ($t in $script:AllTasks) {
            $innerPanel = $t.RowGrid.Parent
            $gb = $innerPanel.Parent
            if ($gbs -notcontains $gb) {
                $gbs += $gb
            }
        }
        
        foreach ($gb in $gbs) {
            $innerPanel = $gb.Content
            $anyVisible = $false
            foreach ($child in $innerPanel.Children) {
                if ($child.Visibility -eq [System.Windows.Visibility]::Visible) {
                    $anyVisible = $true
                    break
                }
            }
            if ($anyVisible) {
                $gb.Visibility = [System.Windows.Visibility]::Visible
            } else {
                $gb.Visibility = [System.Windows.Visibility]::Collapsed
            }
        }

        # 2. Filter Tweaks
        foreach ($s in $script:AllScripts) {
            if ($isQueryEmpty) {
                $sMatch = $true
            } else {
                $sMatch = ($s.Name -match "(?i)" + [regex]::Escape($query)) -or 
                          ($s.Category -match "(?i)" + [regex]::Escape($query)) -or 
                          ($s.Description -match "(?i)" + [regex]::Escape($query))
                if (-not $sMatch -and $null -ne $s.On) {
                    $sMatch = $s.On.ToString() -match "(?i)" + [regex]::Escape($query)
                }
                if (-not $sMatch -and $null -ne $s.Off) {
                    $sMatch = $s.Off.ToString() -match "(?i)" + [regex]::Escape($query)
                }
            }
            $s.CardBorder.Visibility = if ($sMatch) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
        }

        # 3. Filter Control Panel Tasks in Tweaks View
        foreach ($cp in $script:AllControlPanelTasks) {
            if ($isQueryEmpty) {
                $cpMatch = $true
            } else {
                $cpMatch = ($cp.Name -match "(?i)" + [regex]::Escape($query)) -or 
                           ($cp.Category -match "(?i)" + [regex]::Escape($query))
                if (-not $cpMatch -and $null -ne $cp.Function) {
                    $cpMatch = $cp.Function.ToString() -match "(?i)" + [regex]::Escape($query)
                }
            }
            $cp.CardBorder.Visibility = if ($cpMatch) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
        }

        # Hide tweaks groupboxes if no children visible
        if ($null -ne $script:ScriptGroupBoxes) {
            foreach ($sgb in $script:ScriptGroupBoxes) {
                $inner = $sgb.Content
                $anyVis = $false
                foreach ($child in $inner.Children) {
                    if ($child.Visibility -eq [System.Windows.Visibility]::Visible) {
                        $anyVis = $true
                        break
                    }
                }
                $sgb.Visibility = if ($anyVis) { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
            }
        }

        # 4. Auto-switch to the tab that contains matches if the current tab has 0 matches
        if (-not $isQueryEmpty -and -not $script:InAutoSwitch) {
            $appsCount = @($script:AllTasks | Where-Object { $_.Tab -eq "Apps" -and $_.RowGrid.Visibility -eq [System.Windows.Visibility]::Visible }).Count
            $devCount = @($script:AllTasks | Where-Object { $_.Tab -eq "Dev" -and $_.RowGrid.Visibility -eq [System.Windows.Visibility]::Visible }).Count
            $tweaksCount = @($script:AllScripts | Where-Object { $_.CardBorder.Visibility -eq [System.Windows.Visibility]::Visible }).Count + 
                           @($script:AllControlPanelTasks | Where-Object { $_.CardBorder.Visibility -eq [System.Windows.Visibility]::Visible }).Count

            $script:InAutoSwitch = $true
            try {
                if ($script:tabApps.IsChecked -and $appsCount -eq 0) {
                    if ($devCount -gt 0) {
                        $script:tabDev.IsChecked = $true
                    } elseif ($tweaksCount -gt 0) {
                        $script:tabScripts.IsChecked = $true
                    }
                }
                elseif ($script:tabDev.IsChecked -and $devCount -eq 0) {
                    if ($appsCount -gt 0) {
                        $script:tabApps.IsChecked = $true
                    } elseif ($tweaksCount -gt 0) {
                        $script:tabScripts.IsChecked = $true
                    }
                }
                elseif ($script:tabScripts.IsChecked -and $tweaksCount -eq 0) {
                    if ($appsCount -gt 0) {
                        $script:tabApps.IsChecked = $true
                    } elseif ($devCount -gt 0) {
                        $script:tabDev.IsChecked = $true
                    }
                }
            } finally {
                $script:InAutoSwitch = $false
            }
        }
    }

    $script:txtSearch.Add_GotFocus({
        if ($script:txtSearch.Text -eq "Search...") {
            $script:SkipSearchUpdate = $true
            $script:txtSearch.Text = ""
            $script:txtSearch.Foreground = [System.Windows.Media.Brushes]::White
            $script:SkipSearchUpdate = $false
        }
    })

    $script:txtSearch.Add_LostFocus({
        if ([string]::IsNullOrWhiteSpace($script:txtSearch.Text)) {
            $script:SkipSearchUpdate = $true
            $script:txtSearch.Text = "Search..."
            $script:txtSearch.Foreground = $brushMuted
            $script:SkipSearchUpdate = $false
        }
    })

    $script:txtSearch.Add_TextChanged({
        Update-SearchFilter
    })

    $script:txtSearch.Add_KeyDown({
        param($s, $e)
        if ($e.Key -eq [System.Windows.Input.Key]::Enter) {
            $e.Handled = $true
            
            $visibleApps = @($script:AllTasks | Where-Object { $_.Tab -eq "Apps" -and $_.RowGrid.Visibility -eq [System.Windows.Visibility]::Visible })
            $visibleDev = @($script:AllTasks | Where-Object { $_.Tab -eq "Dev" -and $_.RowGrid.Visibility -eq [System.Windows.Visibility]::Visible })
            $visibleScripts = @($script:AllScripts | Where-Object { $_.CardBorder.Visibility -eq [System.Windows.Visibility]::Visible })
            $visibleCP = @($script:AllControlPanelTasks | Where-Object { $_.CardBorder.Visibility -eq [System.Windows.Visibility]::Visible })
            
            $totalMatches = $visibleApps.Count + $visibleDev.Count + $visibleScripts.Count + $visibleCP.Count
            
            if ($totalMatches -eq 1) {
                if ($visibleApps.Count -eq 1) {
                    $task = $visibleApps[0]
                    $name = $task.Name
                    $f = $task.Function
                    Write-Log "Launching: $name ..." -Level Running
                    try { & $f; Write-Log "$name - launched." -Level Success } catch { Write-Log "ERROR: $name - $($_.Exception.Message)" -Level Error }
                }
                elseif ($visibleDev.Count -eq 1) {
                    $task = $visibleDev[0]
                    $name = $task.Name
                    $f = $task.Function
                    Write-Log "Launching: $name ..." -Level Running
                    try { & $f; Write-Log "$name - launched." -Level Success } catch { Write-Log "ERROR: $name - $($_.Exception.Message)" -Level Error }
                }
                elseif ($visibleScripts.Count -eq 1) {
                    $sItem = $visibleScripts[0]
                    $name = $sItem.Name
                    Write-Log "Launching tweak: $name ..." -Level Running
                    try { if ($null -ne $sItem.On) { & $sItem.On }; Write-Log "$name - executed." -Level Success } catch { Write-Log "ERROR: $name - $($_.Exception.Message)" -Level Error }
                }
                elseif ($visibleCP.Count -eq 1) {
                    $cpItem = $visibleCP[0]
                    $name = $cpItem.Name
                    Write-Log "Launching: $name ..." -Level Running
                    try { & $cpItem.Function; Write-Log "$name - launched." -Level Success } catch { Write-Log "ERROR: $name - $($_.Exception.Message)" -Level Error }
                }
            }
            elseif ($totalMatches -gt 1) {
                $currentTabMatches = @()
                if ($script:tabApps.IsChecked) { $currentTabMatches = $visibleApps }
                elseif ($script:tabDev.IsChecked) { $currentTabMatches = $visibleDev }
                elseif ($script:tabScripts.IsChecked) { $currentTabMatches = $visibleScripts + $visibleCP }
                
                if ($currentTabMatches.Count -eq 1) {
                    $item = $currentTabMatches[0]
                    $name = $item.Name
                    Write-Log "Launching: $name ..." -Level Running
                    try {
                        if ($null -ne $item.Function) { & $item.Function }
                        elseif ($null -ne $item.On) { & $item.On }
                        Write-Log "$name - launched." -Level Success
                    } catch {
                        Write-Log "ERROR: $name - $($_.Exception.Message)" -Level Error
                    }
                }
            }

            [void]$script:window.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Background, [System.Action] {
                $script:window.Activate() | Out-Null
                if ($null -ne $script:txtSearch) {
                    $script:txtSearch.Focus() | Out-Null
                    $script:txtSearch.SelectAll()
                }
            })
        }
    })

    $script:window.Add_PreviewKeyDown({
        param($s, $e)
        
        $focused = [System.Windows.Input.Keyboard]::FocusedElement
        
        # Escape key clears search and refocuses search box
        if ($e.Key -eq [System.Windows.Input.Key]::Escape) {
            $e.Handled = $true
            $script:txtSearch.Text = ""
            $script:txtSearch.Focus() | Out-Null
        }
        # Enter key executes all selected and unselects in Apps / Dev view
        elseif ($e.Key -eq [System.Windows.Input.Key]::Enter) {
            if ($focused -ne $script:txtSearch) {
                if ($script:tabApps.IsChecked -or $script:tabDev.IsChecked) {
                    $e.Handled = $true
                    $script:BtnRun.RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Button]::ClickEvent)))
                    $activeTab = if ($script:tabDev.IsChecked) { "Dev" } else { "Apps" }
                    foreach ($t in $script:AllTasks) {
                        if ($t.Tab -eq $activeTab) {
                            $t.CheckBox.IsChecked = $false
                        }
                    }
                    $script:chkSelectAll.IsChecked = $false
                }
            }
        }
        # Space key toggles selection on the focused button
        elseif ($e.Key -eq [System.Windows.Input.Key]::Space) {
            if ($focused -is [System.Windows.Controls.Button]) {
                $currentTask = $script:AllTasks | Where-Object { $_.Button -eq $focused }
                if ($null -ne $currentTask) {
                    $e.Handled = $true
                    $currentTask.CheckBox.IsChecked = -not $currentTask.CheckBox.IsChecked
                }
            }
        }
        # Down Arrow from search box focuses first visible task or tweak button
        elseif ($e.Key -eq [System.Windows.Input.Key]::Down -and $focused -eq $script:txtSearch) {
            if ($script:tabApps.IsChecked) {
                $firstTask = $script:AllTasks | Where-Object { $_.Tab -eq "Apps" -and $_.RowGrid.Visibility -eq [System.Windows.Visibility]::Visible } | Select-Object -First 1
                if ($null -ne $firstTask -and $null -ne $firstTask.Button) {
                    $e.Handled = $true
                    $firstTask.Button.Focus() | Out-Null
                }
            }
            elseif ($script:tabDev.IsChecked) {
                $firstTask = $script:AllTasks | Where-Object { $_.Tab -eq "Dev" -and $_.RowGrid.Visibility -eq [System.Windows.Visibility]::Visible } | Select-Object -First 1
                if ($null -ne $firstTask -and $null -ne $firstTask.Button) {
                    $e.Handled = $true
                    $firstTask.Button.Focus() | Out-Null
                }
            } else {
                $firstScript = $script:AllScripts | Where-Object { $_.CardBorder.Visibility -eq [System.Windows.Visibility]::Visible } | Select-Object -First 1
                if ($null -ne $firstScript -and $null -ne $firstScript.RunBtn) {
                    $e.Handled = $true
                    $firstScript.RunBtn.Focus() | Out-Null
                } else {
                    $firstCP = $script:AllControlPanelTasks | Where-Object { $_.CardBorder.Visibility -eq [System.Windows.Visibility]::Visible } | Select-Object -First 1
                    if ($null -ne $firstCP -and $null -ne $firstCP.Button) {
                        $e.Handled = $true
                        $firstCP.Button.Focus() | Out-Null
                    }
                }
            }
        }
        # Arrow key navigation between task buttons / tweak buttons / control panel buttons
        elseif ($focused -is [System.Windows.Controls.Button]) {
            # Check if focused button belongs to Apps or Dev tasks
            $currentTask = $script:AllTasks | Where-Object { $_.Button -eq $focused }
            if ($null -ne $currentTask) {
                $activeTab = $currentTask.Tab
                $visibleTasks = @($script:AllTasks | Where-Object { $_.Tab -eq $activeTab -and $_.RowGrid.Visibility -eq [System.Windows.Visibility]::Visible })
                
                if ($e.Key -eq [System.Windows.Input.Key]::Down -or $e.Key -eq [System.Windows.Input.Key]::Up) {
                    $sameColTasks = @($visibleTasks | Where-Object { $_.ColIndex -eq $currentTask.ColIndex })
                    if ($sameColTasks.Count -gt 0) {
                        $currIdx = $sameColTasks.IndexOf($currentTask)
                        
                        if ($e.Key -eq [System.Windows.Input.Key]::Down) {
                            $nextIdx = ($currIdx + 1) % $sameColTasks.Count
                            $sameColTasks[$nextIdx].Button.Focus() | Out-Null
                            $e.Handled = $true
                        }
                        elseif ($e.Key -eq [System.Windows.Input.Key]::Up) {
                            if ($currIdx -eq 0) {
                                $script:txtSearch.Focus() | Out-Null
                                $e.Handled = $true
                            } else {
                                $nextIdx = ($currIdx - 1 + $sameColTasks.Count) % $sameColTasks.Count
                                $sameColTasks[$nextIdx].Button.Focus() | Out-Null
                                $e.Handled = $true
                            }
                        }
                    }
                }
                elseif ($e.Key -eq [System.Windows.Input.Key]::Right -or $e.Key -eq [System.Windows.Input.Key]::Left) {
                    $dir = if ($e.Key -eq [System.Windows.Input.Key]::Right) { 1 } else { -1 }
                    $targetCol = $currentTask.ColIndex
                    
                    for ($step = 1; $step -lt 5; $step++) {
                        $targetCol = ($targetCol + $dir + 5) % 5
                        $targetColTasks = @($visibleTasks | Where-Object { $_.ColIndex -eq $targetCol })
                        if ($targetColTasks.Count -gt 0) {
                            $targetTask = $targetColTasks[0]
                            try {
                                $currentPoint = $currentTask.Button.TransformToVisual($script:window).Transform((New-Object System.Windows.Point(0, 0)))
                                $currentY = $currentPoint.Y
                                $closestTask = $null
                                $minDiff = [double]::MaxValue
                                foreach ($t in $targetColTasks) {
                                    $tPoint = $t.Button.TransformToVisual($script:window).Transform((New-Object System.Windows.Point(0, 0)))
                                    $diff = [System.Math]::Abs($tPoint.Y - $currentY)
                                    if ($diff -lt $minDiff) {
                                        $minDiff = $diff
                                        $closestTask = $t
                                    }
                                }
                                if ($null -ne $closestTask) {
                                    $targetTask = $closestTask
                                }
                            } catch {}
                            
                            $targetTask.Button.Focus() | Out-Null
                            $e.Handled = $true
                            break
                        }
                    }
                }
            } else {
                # Check if focused button belongs to Tweaks section (RunBtn or RevertBtn)
                $currentScript = $script:AllScripts | Where-Object { $_.RunBtn -eq $focused -or $_.RevertBtn -eq $focused }
                if ($null -ne $currentScript) {
                    $visibleScripts = @($script:AllScripts | Where-Object { $_.CardBorder.Visibility -eq [System.Windows.Visibility]::Visible })
                    $sIdx = $visibleScripts.IndexOf($currentScript)
                    
                    if ($e.Key -eq [System.Windows.Input.Key]::Left) {
                        $e.Handled = $true
                        if ($focused -eq $currentScript.RunBtn) {
                            $currentScript.RevertBtn.Focus() | Out-Null
                        }
                    }
                    elseif ($e.Key -eq [System.Windows.Input.Key]::Right) {
                        $e.Handled = $true
                        if ($focused -eq $currentScript.RevertBtn) {
                            $currentScript.RunBtn.Focus() | Out-Null
                        } else {
                            # Move across to the Control Panel list on the right
                            $visibleCP = @($script:AllControlPanelTasks | Where-Object { $_.CardBorder.Visibility -eq [System.Windows.Visibility]::Visible })
                            if ($visibleCP.Count -gt 0) {
                                $cpTarget = if ($sIdx -lt $visibleCP.Count) { $visibleCP[$sIdx] } else { $visibleCP[0] }
                                $cpTarget.Button.Focus() | Out-Null
                            }
                        }
                    }
                    elseif ($e.Key -eq [System.Windows.Input.Key]::Down) {
                        if ($visibleScripts.Count -gt 0) {
                            $e.Handled = $true
                            $nextSIdx = ($sIdx + 1) % $visibleScripts.Count
                            $visibleScripts[$nextSIdx].RunBtn.Focus() | Out-Null
                        }
                    }
                    elseif ($e.Key -eq [System.Windows.Input.Key]::Up) {
                        $e.Handled = $true
                        if ($sIdx -eq 0) {
                            $script:txtSearch.Focus() | Out-Null
                        } else {
                            $prevSIdx = ($sIdx - 1 + $visibleScripts.Count) % $visibleScripts.Count
                            $visibleScripts[$prevSIdx].RunBtn.Focus() | Out-Null
                        }
                    }
                } else {
                    # Check if focused button belongs to Control Panel section
                    $currentCP = $script:AllControlPanelTasks | Where-Object { $_.Button -eq $focused }
                    if ($null -ne $currentCP) {
                        $visibleCP = @($script:AllControlPanelTasks | Where-Object { $_.CardBorder.Visibility -eq [System.Windows.Visibility]::Visible })
                        $cpIdx = $visibleCP.IndexOf($currentCP)
                        
                        if ($e.Key -eq [System.Windows.Input.Key]::Left) {
                            # Move back across to Tweaks list on the left
                            $visibleScripts = @($script:AllScripts | Where-Object { $_.CardBorder.Visibility -eq [System.Windows.Visibility]::Visible })
                            if ($visibleScripts.Count -gt 0) {
                                $e.Handled = $true
                                $sTarget = if ($cpIdx -lt $visibleScripts.Count) { $visibleScripts[$cpIdx] } else { $visibleScripts[0] }
                                $sTarget.RunBtn.Focus() | Out-Null
                            }
                        }
                        elseif ($e.Key -eq [System.Windows.Input.Key]::Down) {
                            if ($visibleCP.Count -gt 0) {
                                $e.Handled = $true
                                $nextCPIdx = ($cpIdx + 1) % $visibleCP.Count
                                $visibleCP[$nextCPIdx].Button.Focus() | Out-Null
                            }
                        }
                        elseif ($e.Key -eq [System.Windows.Input.Key]::Up) {
                            $e.Handled = $true
                            if ($cpIdx -eq 0) {
                                $script:txtSearch.Focus() | Out-Null
                            } else {
                                $prevCPIdx = ($cpIdx - 1 + $visibleCP.Count) % $visibleCP.Count
                                $visibleCP[$prevCPIdx].Button.Focus() | Out-Null
                            }
                        }
                    }
                }
            }
        }
        # If user starts typing printable characters while not focused on search box, redirect to search box
        elseif ($focused -ne $script:txtSearch -and -not [System.Windows.Input.Keyboard]::Modifiers) {
            if (($e.Key -ge [System.Windows.Input.Key]::A -and $e.Key -le [System.Windows.Input.Key]::Z) -or
                ($e.Key -ge [System.Windows.Input.Key]::D0 -and $e.Key -le [System.Windows.Input.Key]::D9) -or
                ($e.Key -ge [System.Windows.Input.Key]::NumPad0 -and $e.Key -le [System.Windows.Input.Key]::NumPad9) -or
                $e.Key -eq [System.Windows.Input.Key]::Back) {
                $script:txtSearch.Focus() | Out-Null
                $script:txtSearch.SelectAll()
            }
        }
    })

    # Auto-refocus and select search box when window becomes active
    $script:window.Add_Activated({
        [void]$script:txtSearch.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Input, [System.Action] {
            if ($null -ne $script:txtSearch) {
                $script:txtSearch.Focus() | Out-Null
                $script:txtSearch.SelectAll()
            }
        })
    })

    # ============================================================
    #  SECTION I: STARTUP MESSAGE AND LAUNCH
    # ============================================================

    $script:window.add_SourceInitialized({
        $script:txtSearch.Focus()
        Write-Log "Tooler GUI ready - running as Administrator." -Level Success
        Write-Log "Tip: Check boxes next to items and press [Run Selected] for batch install." -Level Info
        Write-Log "Tip: Click any tool button to launch it immediately without queuing." -Level Info

        # Populate System Specs HUD
        try {
            $specs = Get-SystemSpecsSummary
            if ($null -ne $script:txtHudRAM -and $null -ne $specs.RAMText) {
                $script:txtHudRAM.Text = $specs.RAMText
            }
        } catch {}

        try {
            $darkMode = 1
            $osVersion = [Environment]::OSVersion.Version
            if ($osVersion.Major -ge 10) {
                $helper = New-Object System.Windows.Interop.WindowInteropHelper($script:window)
                $hwnd = $helper.Handle
                try { [Native.DWM]::DwmSetWindowAttribute($hwnd, 20, [ref]$darkMode, 4) }
                catch { try { [Native.DWM]::DWMSetWindowAttribute($hwnd, 19, [ref]$darkMode, 4) } catch {} }
            }
        } catch {}
    })

    Update-InitProgress -Percent 96 -Status "[12/12] Preparing window icon, theme & launching GUI..."

    # Load window Icon dynamically
    $iconPath = "$env:TEMP\Tooler.ico"
    try {
        if (-not (Test-Path $iconPath)) {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -Uri "https://raw.githubusercontent.com/afnan-nex/tooler/main/cpp-binary/Tooler.ico" -OutFile $iconPath -UseBasicParsing -TimeoutSec 3 -ErrorAction SilentlyContinue
        }
        if (Test-Path $iconPath) {
            $script:window.Icon = New-Object System.Windows.Media.Imaging.BitmapImage(New-Object System.Uri($iconPath))
        }
    }
    catch {}

    Update-InitProgress -Percent 100 -Status "[12/12] Ready! Launching application..."
    Start-Sleep -Milliseconds 150
    Write-Progress -Activity "Tooler - Starting Up" -Completed
    Write-Host "`n`n  [OK] Initialization complete. Launching GUI...`n" -ForegroundColor Green
    Start-Sleep -Milliseconds 150

    # Hide the calling PowerShell CLI console window on completion
    try {
        $consoleHWnd = [Console.Window]::GetConsoleWindow()
        if ($consoleHWnd -ne [IntPtr]::Zero) {
            [Console.Window]::ShowWindow($consoleHWnd, 0) | Out-Null
        }
    } catch {
        "Console suppression error: $_" | Out-File -FilePath $logPath -Append
    }

    $script:window.ShowDialog() | Out-Null
    exit

} catch {
    $err = $_.Exception.ToString()
    $err | Out-File -FilePath $logPath -Append
    try {
        [System.Windows.MessageBox]::Show("CRITICAL EXCEPTION IN TOOLER:`n`n$err", "Tooler Error")
    } catch {
        # Fallback to Windows Forms if WPF MessageBox fails
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show("CRITICAL EXCEPTION IN TOOLER:`n`n$err", "Tooler Error")
    }
    exit 1
}
