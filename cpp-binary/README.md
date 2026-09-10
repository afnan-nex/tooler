# Tooler CLI Binary & Setup

This directory contains the Inno Setup installer and C++ CLI binary for Tooler.

## Files
- **`tooler-setup.exe`**: Inno Setup installer executable.
- **`tooler.exe`**: C++ CLI wrapper.
- **`tooler.cpp`**: C++ source code.
- **`Tooler.ico`**: Application icon.
- **`build.bat`**: Build script for C++ binary.

## Quick Installation
Run `tooler-setup.exe` or run the PowerShell one-liner:
```powershell
irm https://raw.githubusercontent.com/afnan-nex/tooler/main/install.ps1 | iex
```

## CLI Usage
Once installed, open any terminal or the `Win + R` Run dialog and type `tooler`:

```cmd
tooler           Launch local Tooler GUI (fast & offline)
tooler --update  Download and update the local script from GitHub
tooler --beta    Launch Tooler in Beta mode
tooler --version Show version number
tooler --help    Show this help message
```

## Building from Source

### Using G++ / MinGW:
```cmd
build.bat
```
