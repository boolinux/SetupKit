@echo off
setlocal EnableDelayedExpansion

set "psFile=%~dp0AutoSetup.ps1"

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Elevating...
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
        "Start-Process PowerShell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File ""!psFile!""' -Verb RunAs"
    exit /b
)

powershell -NoProfile -ExecutionPolicy Bypass -File "!psFile!"
exit /b
