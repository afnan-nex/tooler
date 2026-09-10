#include <windows.h>
#include <iostream>
#include <string>
#include <cstdlib>

#define TOOLER_VERSION "2.1"

int main(int argc, char* argv[]) {
    // Handle command line flags
    if (argc > 1) {
        std::string arg = argv[1];
        if (arg == "--version" || arg == "-v" || arg == "/v") {
            std::cout << "Tooler version " << TOOLER_VERSION << "\n";
            return 0;
        }

        if (arg == "--help" || arg == "-h" || arg == "/?" || arg == "-help") {
            std::cout << "====================================================\n";
            std::cout << "  Tooler v" << TOOLER_VERSION << " - Modern Windows Utility & Tool Installer\n";
            std::cout << "  by AFNAN (https://github.com/afnan-nex/tooler)    \n";
            std::cout << "====================================================\n\n";
            std::cout << "Usage:\n";
            std::cout << "  tooler           Download and launch Tooler GUI\n";
            std::cout << "  tooler --beta    Download and launch Tooler Beta GUI\n";
            std::cout << "  tooler --version Show version number\n";
            std::cout << "  tooler --help    Show this help message\n\n";
            return 0;
        }

        if (arg == "--beta" || arg == "-b" || arg == "-beta") {
            const char* betaCmd = "curl -L -o \"%TEMP%\\tooler-beta.ps1\" https://raw.githubusercontent.com/afnan-nex/tooler/main/tooler-beta.ps1 && powershell -NoProfile -ExecutionPolicy Bypass -File \"%TEMP%\\tooler-beta.ps1\"";
            return system(betaCmd);
        }
    }

    // Default command
    const char* defaultCmd = "curl -L -o \"%TEMP%\\tooler.ps1\" https://raw.githubusercontent.com/afnan-nex/tooler/main/tooler.ps1 && powershell -NoProfile -ExecutionPolicy Bypass -File \"%TEMP%\\tooler.ps1\"";
    return system(defaultCmd);
}
