using System;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Reflection;
using System.Runtime.InteropServices;

namespace Tooler
{
    class Program
    {
        const string TOOLER_VERSION = "v2.3.1";
        const string SCRIPT_NAME = "tooler.ps1";
        const string ICON_NAME = "Tooler.ico";
        const string GITHUB_RAW_BASE = "https://raw.githubusercontent.com/afnan-nex/tooler/main";

        [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
        private static extern IntPtr SendMessageTimeout(
            IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam,
            uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);

        static int Main(string[] args)
        {
            // Fast CLI flags (no setup needed)
            if (args.Length > 0)
            {
                string arg = args[0].ToLowerInvariant();
                if (arg == "--version" || arg == "-v" || arg == "/v")
                {
                    Console.WriteLine("Tooler version " + TOOLER_VERSION);
                    return 0;
                }

                if (arg == "--help" || arg == "-h" || arg == "/?" || arg == "-help")
                {
                    Console.WriteLine("====================================================");
                    Console.WriteLine("  Tooler " + TOOLER_VERSION + " - Modern Windows Utility & Tool Installer");
                    Console.WriteLine("  by AFNAN (https://github.com/afnan-nex/tooler)");
                    Console.WriteLine("====================================================\n");
                    Console.WriteLine("Usage:");
                    Console.WriteLine("  tooler           Launch local Tooler GUI (fast & offline)");
                    Console.WriteLine("  tooler --update  Download and update local script from GitHub");
                    Console.WriteLine("  tooler --beta    Launch Tooler in Beta mode");
                    Console.WriteLine("  tooler --setup   Re-run environment and shortcut setup");
                    Console.WriteLine("  tooler --version Show version number");
                    Console.WriteLine("  tooler --help    Show this help message\n");
                    return 0;
                }
            }

            string currentExePath = Process.GetCurrentProcess().MainModule.FileName;
            string localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
            string installDir = Path.Combine(localAppData, "Tooler");
            string installedExe = Path.Combine(installDir, "tooler.exe");
            string installedScript = Path.Combine(installDir, SCRIPT_NAME);

            bool isExplicitSetup = args.Length > 0 && (args[0] == "--setup" || args[0] == "-s");
            bool isAlreadyInstalled = File.Exists(installedScript) && File.Exists(installedExe);

            // First run on a clean machine OR explicit setup flag
            if (isExplicitSetup || !isAlreadyInstalled)
            {
                return RunSetup(currentExePath, installDir, args);
            }

            // Normal launch for installed app
            return RunLauncher(currentExePath, installDir, args);
        }

        // ============================================================
        //  SETUP / INSTALLER ROUTINE
        // ============================================================
        static int RunSetup(string currentExePath, string installDir, string[] args)
        {
            Console.ForegroundColor = ConsoleColor.Cyan;
            Console.WriteLine("====================================================");
            Console.WriteLine("  Tooler " + TOOLER_VERSION + " Setup - Modern Windows Utility Installer");
            Console.WriteLine("  by AFNAN (https://github.com/afnan-nex/tooler)");
            Console.WriteLine("====================================================\n");
            Console.ResetColor();

            try
            {
                if (!Directory.Exists(installDir))
                {
                    Directory.CreateDirectory(installDir);
                }

                string targetExe = Path.Combine(installDir, "tooler.exe");
                string targetScript = Path.Combine(installDir, SCRIPT_NAME);
                string targetIcon = Path.Combine(installDir, ICON_NAME);

                // 1. Copy or download tooler.ps1
                Console.Write("[1/4] Setting up Tooler GUI script... ");
                string localScriptSource = FindLocalFile(SCRIPT_NAME);
                if (!string.IsNullOrEmpty(localScriptSource) && File.Exists(localScriptSource))
                {
                    File.Copy(localScriptSource, targetScript, true);
                    Console.ForegroundColor = ConsoleColor.Green;
                    Console.WriteLine("Done (local copy)");
                    Console.ResetColor();
                }
                else
                {
                    DownloadFromGitHub(GITHUB_RAW_BASE + "/" + SCRIPT_NAME, targetScript);
                    Console.ForegroundColor = ConsoleColor.Green;
                    Console.WriteLine("Done (downloaded)");
                    Console.ResetColor();
                }

                // 2. Copy or download Tooler.ico
                Console.Write("[2/4] Setting up application icon... ");
                string localIconSource = FindLocalFile(ICON_NAME);
                if (!string.IsNullOrEmpty(localIconSource) && File.Exists(localIconSource))
                {
                    File.Copy(localIconSource, targetIcon, true);
                    Console.ForegroundColor = ConsoleColor.Green;
                    Console.WriteLine("Done (local copy)");
                    Console.ResetColor();
                }
                else
                {
                    DownloadFromGitHub(GITHUB_RAW_BASE + "/cs-binary/" + ICON_NAME, targetIcon);
                    Console.ForegroundColor = ConsoleColor.Green;
                    Console.WriteLine("Done (downloaded)");
                    Console.ResetColor();
                }

                // 3. Install tooler.exe binary
                Console.Write("[3/4] Installing Tooler executable... ");
                if (!string.Equals(currentExePath, targetExe, StringComparison.OrdinalIgnoreCase))
                {
                    File.Copy(currentExePath, targetExe, true);
                }

                // Also copy to WindowsApps folder (pre-configured in standard Windows PATH)
                try
                {
                    string winAppsDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Microsoft", "WindowsApps");
                    if (Directory.Exists(winAppsDir))
                    {
                        File.Copy(currentExePath, Path.Combine(winAppsDir, "tooler.exe"), true);
                    }
                }
                catch {}

                Console.ForegroundColor = ConsoleColor.Green;
                Console.WriteLine("Done");
                Console.ResetColor();

                // 4. Update PATH environment variable & Shortcuts
                Console.Write("[4/4] Configuring PATH & Shortcuts... ");
                string userPath = Environment.GetEnvironmentVariable("Path", EnvironmentVariableTarget.User) ?? "";
                if (userPath.IndexOf(installDir, StringComparison.OrdinalIgnoreCase) < 0)
                {
                    string newPath = userPath.TrimEnd(';') + ";" + installDir;
                    Environment.SetEnvironmentVariable("Path", newPath, EnvironmentVariableTarget.User);
                }
                NotifyEnvironmentChange();

                // Desktop shortcut
                string desktop = Environment.GetFolderPath(Environment.SpecialFolder.Desktop);
                CreateShortcut(Path.Combine(desktop, "Tooler.lnk"), targetExe, targetIcon, installDir, "Tooler " + TOOLER_VERSION + " by AFNAN");

                // Start Menu shortcut
                string programs = Environment.GetFolderPath(Environment.SpecialFolder.Programs);
                CreateShortcut(Path.Combine(programs, "Tooler.lnk"), targetExe, targetIcon, installDir, "Tooler " + TOOLER_VERSION + " by AFNAN");

                Console.ForegroundColor = ConsoleColor.Green;
                Console.WriteLine("Done");
                Console.ResetColor();

                Console.ForegroundColor = ConsoleColor.Green;
                Console.WriteLine("\n>>> SUCCESS: Tooler has been successfully installed!");
                Console.ResetColor();
                Console.WriteLine("  - Install Path: " + installDir);
                Console.WriteLine("  - Command:      Type 'tooler' in any terminal or Win+R");
                Console.WriteLine("  - Shortcuts:    Added to Desktop and Start Menu\n");

                Console.ForegroundColor = ConsoleColor.Cyan;
                Console.WriteLine(">>> Launching Tooler GUI now...\n");
                Console.ResetColor();

                LaunchScript(targetScript, false);
                return 0;
            }
            catch (Exception ex)
            {
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine("\n[ERROR] Setup failed: " + ex.Message);
                Console.ResetColor();
                return 1;
            }
        }

        // ============================================================
        //  LAUNCHER ROUTINE
        // ============================================================
        static int RunLauncher(string currentExePath, string installDir, string[] args)
        {
            string appDir = Path.GetDirectoryName(currentExePath);
            string localScript = Path.Combine(appDir, SCRIPT_NAME);

            if (!File.Exists(localScript))
            {
                string installedScript = Path.Combine(installDir, SCRIPT_NAME);
                if (File.Exists(installedScript))
                {
                    localScript = installedScript;
                }
                else
                {
                    string repoScript = FindLocalFile(SCRIPT_NAME);
                    if (!string.IsNullOrEmpty(repoScript) && File.Exists(repoScript))
                    {
                        localScript = repoScript;
                    }
                }
            }

            bool update = false;
            bool beta = false;

            if (args.Length > 0)
            {
                string arg = args[0].ToLowerInvariant();
                if (arg == "--update" || arg == "-u")
                {
                    update = true;
                }
                else if (arg == "--beta" || arg == "-b")
                {
                    beta = true;
                }
            }

            if (update || !File.Exists(localScript))
            {
                Console.ForegroundColor = ConsoleColor.Cyan;
                Console.WriteLine(">>> Downloading latest Tooler script from GitHub...");
                Console.ResetColor();

                try
                {
                    DownloadFromGitHub(GITHUB_RAW_BASE + "/" + SCRIPT_NAME, localScript);
                    Console.ForegroundColor = ConsoleColor.Green;
                    Console.WriteLine(">>> Updated local script: " + localScript);
                    Console.ResetColor();
                    if (update) return 0;
                }
                catch (Exception ex)
                {
                    Console.ForegroundColor = ConsoleColor.Yellow;
                    Console.WriteLine("Warning: Could not connect to GitHub: " + ex.Message);
                    Console.ResetColor();

                    if (!File.Exists(localScript))
                    {
                        Console.ForegroundColor = ConsoleColor.Red;
                        Console.WriteLine("Error: Local script not found and unable to download.");
                        Console.ResetColor();
                        return 1;
                    }
                }
            }

            return LaunchScript(localScript, beta);
        }

        // ============================================================
        //  HELPERS
        // ============================================================
        static void NotifyEnvironmentChange()
        {
            try
            {
                UIntPtr result;
                SendMessageTimeout((IntPtr)0xffff, 0x001A, UIntPtr.Zero, "Environment", 2, 1000, out result);
            }
            catch {}
        }

        static void DownloadFromGitHub(string url, string destination)
        {
            ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12;
            string dir = Path.GetDirectoryName(destination);
            if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
            {
                Directory.CreateDirectory(dir);
            }
            using (WebClient client = new WebClient())
            {
                client.DownloadFile(url + "?v=" + DateTime.UtcNow.Ticks, destination);
            }
        }

        static string FindLocalFile(string filename)
        {
            string exeDir = AppDomain.CurrentDomain.BaseDirectory.TrimEnd('\\');
            string[] searchPaths = new string[]
            {
                Path.Combine(exeDir, filename),
                Path.Combine(exeDir, "..", filename),
                Path.Combine(exeDir, "..", "cpp-binary", filename),
                Path.Combine(exeDir, "..", "cs-binary", filename),
                Path.Combine(@"C:\Users\ABDULLAH\tooler", filename),
                Path.Combine(@"C:\Users\ABDULLAH\tooler\cpp-binary", filename),
                Path.Combine(@"C:\Users\ABDULLAH\tooler\cs-binary", filename)
            };

            foreach (string p in searchPaths)
            {
                if (File.Exists(p)) return Path.GetFullPath(p);
            }
            return null;
        }

        static void CreateShortcut(string shortcutPath, string targetPath, string iconLocation, string workingDir, string description)
        {
            try
            {
                Type shellType = Type.GetTypeFromProgID("WScript.Shell");
                if (shellType == null) return;
                object shell = Activator.CreateInstance(shellType);
                object shortcut = shellType.InvokeMember("CreateShortcut", BindingFlags.InvokeMethod, null, shell, new object[] { shortcutPath });
                Type scType = shortcut.GetType();
                scType.InvokeMember("TargetPath", BindingFlags.SetProperty, null, shortcut, new object[] { targetPath });
                if (!string.IsNullOrEmpty(iconLocation) && File.Exists(iconLocation))
                {
                    scType.InvokeMember("IconLocation", BindingFlags.SetProperty, null, shortcut, new object[] { iconLocation + ",0" });
                }
                if (!string.IsNullOrEmpty(workingDir))
                {
                    scType.InvokeMember("WorkingDirectory", BindingFlags.SetProperty, null, shortcut, new object[] { workingDir });
                }
                if (!string.IsNullOrEmpty(description))
                {
                    scType.InvokeMember("Description", BindingFlags.SetProperty, null, shortcut, new object[] { description });
                }
                scType.InvokeMember("Save", BindingFlags.InvokeMethod, null, shortcut, null);
            }
            catch {}
        }

        static int LaunchScript(string scriptPath, bool beta)
        {
            try
            {
                string scriptArgs = "-NoProfile -ExecutionPolicy Bypass -STA -File \"" + scriptPath + "\"";
                if (beta) scriptArgs += " -Beta";

                ProcessStartInfo psi = new ProcessStartInfo
                {
                    FileName = "powershell.exe",
                    Arguments = scriptArgs,
                    UseShellExecute = true
                };

                Process.Start(psi);
                return 0;
            }
            catch (Exception ex)
            {
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine("Error launching Tooler: " + ex.Message);
                Console.ResetColor();
                return 1;
            }
        }
    }
}
