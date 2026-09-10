# Tooler C# Edition (cs-binary)

This directory contains the standalone C# executable and source code for **`tooler.exe`**.

## Files
- **`tooler.exe`**: Standalone C# application. Acts as both the installer on first launch and the fast, offline launcher for the Tooler WPF GUI.
- **`ToolerLauncher.cs`**: C# source code.
- **`Tooler.ico`**: Embedded application icon.

## Features
- **Offline First**: Runs the local GUI script directly without re-downloading from GitHub on every launch.
- **Safe**: Native .NET executable that avoids heuristic detection patterns.
- **Auto-Setup**: Sets up `%LocalAppData%\Tooler`, configures user `PATH`, and creates Desktop & Start Menu shortcuts on first run.

## Build from Source
Compile directly with the Windows built-in C# compiler:
```cmd
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /target:exe /win32icon:Tooler.ico /out:tooler.exe ToolerLauncher.cs
```
