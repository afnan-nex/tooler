@echo off
echo Compiling Tooler CLI Binary...
if exist resource.rc (
    windres resource.rc -O coff -o resource.res
    g++ -O3 -std=c++17 tooler.cpp resource.res -o tooler.exe -static
) else (
    g++ -O3 -std=c++17 tooler.cpp -o tooler.exe -static
)
if %errorlevel% equ 0 (
    echo [OK] Successfully built tooler.exe
) else (
    echo [ERROR] Build failed!
)
