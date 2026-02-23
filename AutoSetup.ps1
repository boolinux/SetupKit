# ==========================================================
# TitanDeploy Pro v1.2.0
# Enterprise Deployment Edition
# ----------------------------------------------------------
# Author      : Nam Hoai (NamDH29)
# Role        : System Deployment Technician
# Build       : 2026.02 Stable
# Environment : Windows 10 / Windows 11
# ==========================================================


# ==============================
# FORCE UTF-8 MODE
# ==============================
chcp 65001 | Out-Null
[Console]::InputEncoding  = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8


# ==============================
# PRE-FLIGHT CHECK
# ==============================

# 1️⃣ CHECK ADMIN
if (-not ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {

    Start-Process powershell "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# 2️⃣ CHECK EXECUTION POLICY (SAFE FIX)
if ((Get-ExecutionPolicy -Scope CurrentUser) -eq "Restricted") {
    Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
}

# 3️⃣ CHECK / INSTALL WINGET
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {

    Write-Host "Winget not found. Installing..." -ForegroundColor Yellow

    try {
        $tempPath = "$env:TEMP\AppInstaller.msixbundle"
        Invoke-WebRequest -Uri "https://aka.ms/getwinget" -OutFile $tempPath
        Add-AppxPackage -Path $tempPath
        Start-Sleep 5

        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
            throw "Winget install failed."
        }

        Write-Host "Winget installed successfully." -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to install Winget. Script stopped." -ForegroundColor Red
        exit
    }
}


# ==============================
# INITIALIZE UI
# ==============================

Clear-Host
$Host.UI.RawUI.WindowTitle = "TitanDeploy Pro v1.2.0 - Enterprise Deployment Edition"

Write-Host ""
Write-Host "████████╗██╗████████╗ █████╗ ███╗   ██╗" -ForegroundColor DarkCyan
Write-Host "╚══██╔══╝██║╚══██╔══╝██╔══██╗████╗  ██║" -ForegroundColor DarkCyan
Write-Host "   ██║   ██║   ██║   ███████║██╔██╗ ██║" -ForegroundColor Cyan
Write-Host "   ██║   ██║   ██║   ██╔══██║██║╚██╗██║" -ForegroundColor Cyan
Write-Host "   ██║   ██║   ██║   ██║  ██║██║ ╚████║" -ForegroundColor Yellow
Write-Host "   ╚═╝   ╚═╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═══╝" -ForegroundColor Yellow
Write-Host ""
Write-Host "        TitanDeploy Pro v1.2.0" -ForegroundColor Green
Write-Host "  Enterprise Windows Deployment Suite" -ForegroundColor Gray
Write-Host "----------------------------------------------------------" -ForegroundColor DarkGray
Write-Host "  Developed by Nam Hoai (NamDH29) | Build 2026.02 Stable" -ForegroundColor DarkYellow
Write-Host "----------------------------------------------------------" -ForegroundColor DarkGray
Write-Host ""

$ErrorOccurred = $false

function Write-Status($msg, $color="White") {
    Write-Host $msg -ForegroundColor $color
}

# ==============================
# ASK DISK SPLIT
# ==============================
$response = Read-Host "Do you want to split the disk? (Y/N)"
$DoSplit = $response -match "^[Yy]$"


# ==============================
# INSTALL FUNCTION
# ==============================
function Install-App($name, $id) {

    Write-Status "Checking $name..." "Cyan"

    $installed = winget list --id $id -e 2>$null

    if ($installed) {
        Write-Status "$name is already installed." "Yellow"
        return
    }

    Write-Status "Installing $name..." "Cyan"

    winget install --id $id -e --silent `
        --accept-source-agreements `
        --accept-package-agreements `
        --scope machine

    if ($LASTEXITCODE -eq 0) {
        Write-Status "$name installed successfully." "Green"
    } else {
        Write-Status "Failed to install $name." "Red"
        $global:ErrorOccurred = $true
    }
}


# ==============================
# WINDOWS UPDATE FUNCTION (FINAL)
# ==============================
function Invoke-WindowsUpdate {

    Write-Status "Running final Windows Update..." "Cyan"

    try {
        Install-PackageProvider -Name NuGet -Force -Confirm:$false | Out-Null
        Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted

        if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
            Install-Module PSWindowsUpdate -Force -Confirm:$false -Scope AllUsers
        }

        Import-Module PSWindowsUpdate

        Get-WindowsUpdate `
            -MicrosoftUpdate `
            -AcceptAll `
            -Install `
            -IgnoreReboot

        Write-Status "Windows Update completed." "Green"
    }
    catch {
        Write-Status "Windows Update failed." "Red"
        $global:ErrorOccurred = $true
    }
}


# ==============================
# INSTALL SOFTWARE
# ==============================
Install-App "Google Chrome" "Google.Chrome"
Install-App "UniKey" "Unikey.Unikey"
Install-App "WinRAR" "RARLab.WinRAR"
Install-App "7zip" "7zip.7zip"
Install-App "VLC" "VideoLAN.VLC"
Install-App "UltraViewer" "DucFabulous.UltraViewer"
Install-App "AnyDesk" "AnyDeskSoftwareGmbH.AnyDesk"


# ==============================
# CREATE OFFICE SHORTCUTS
# ==============================
Write-Status "Creating Office shortcuts..." "Cyan"

$desktop = [Environment]::GetFolderPath("Desktop")
$officeBases = @(
"C:\Program Files\Microsoft Office\root\Office16",
"C:\Program Files (x86)\Microsoft Office\root\Office16"
)

foreach ($base in $officeBases) {
    $officePaths = @(
        "$base\WINWORD.EXE",
        "$base\EXCEL.EXE",
        "$base\POWERPNT.EXE"
    )

    foreach ($path in $officePaths) {
        if (Test-Path $path) {
            $shell = New-Object -ComObject WScript.Shell
            $shortcut = $shell.CreateShortcut("$desktop\" + `
            [System.IO.Path]::GetFileNameWithoutExtension($path) + ".lnk")
            $shortcut.TargetPath = $path
            $shortcut.Save()
        }
    }
}


# ==============================
# SHOW SYSTEM ICONS
# ==============================
try {
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel"

    $icons = @(
    "{20D04FE0-3AEA-1069-A2D8-08002B30309D}",
    "{59031a47-3f72-44a7-89c5-5595fe6b30ee}",
    "{645FF040-5081-101B-9F08-00AA002F954E}",
    "{F02C1A0D-BE21-4350-88B0-7367FC96EF3C}",
    "{5399E694-6CE5-4D6C-8FCE-1D8870FDCBA0}"
    )

    foreach ($i in $icons) {
        Set-ItemProperty -Path $regPath -Name $i -Value 0 -Force
    }

    Write-Status "System icons enabled." "Green"
}
catch {
    Write-Status "Failed to enable system icons." "Red"
    $ErrorOccurred = $true
}


# ==============================
# WINDOWS 11 TWEAK
# ==============================
$winVer = (Get-CimInstance Win32_OperatingSystem).Caption

if ($winVer -like "*Windows 11*") {
    try {
        reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
        /v TaskbarDa /t REG_DWORD /d 0 /f | Out-Null

        reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" `
        /v SearchboxTaskbarMode /t REG_DWORD /d 1 /f | Out-Null

        Write-Status "Windows 11 taskbar optimized." "Green"
    }
    catch {
        Write-Status "Taskbar configuration failed." "Red"
        $ErrorOccurred = $true
    }
}


# ==============================
# DISK SPLIT
# ==============================
if ($DoSplit) {
    try {
        if (Get-Partition -DriveLetter D -ErrorAction SilentlyContinue) {
            Write-Status "Drive D already exists. Skipping partition split." "Yellow"
        }
        else {
            $volume = Get-Volume -DriveLetter C
            $freeGB = [math]::Round($volume.SizeRemaining/1GB)

            if ($freeGB -lt 60) {
                Write-Status "Insufficient free space to split the disk." "Red"
            }
            else {
                if ($freeGB -gt 400) { $newSize = 200GB }
                elseif ($freeGB -gt 200) { $newSize = 100GB }
                elseif ($freeGB -gt 100) { $newSize = 50GB }
                else { throw "Not enough space." }

                Write-Status "Splitting disk..." "Cyan"

                Resize-Partition -DriveLetter C -Size ($volume.Size - $newSize)

                $disk = (Get-Partition -DriveLetter C).DiskNumber

                New-Partition -DiskNumber $disk `
                    -UseMaximumSize -DriveLetter D | `
                    Format-Volume -FileSystem NTFS `
                    -NewFileSystemLabel "DATA" -Confirm:$false

                Write-Status "Disk split completed successfully." "Green"
            }
        }
    }
    catch {
        Write-Status "Error while splitting disk: $_" "Red"
        $ErrorOccurred = $true
    }
}


# ==============================
# REFRESH EXPLORER
# ==============================
Stop-Process -Name explorer -ErrorAction SilentlyContinue
Start-Process explorer


# ==============================
# FINAL WINDOWS UPDATE
# ==============================
Invoke-WindowsUpdate


# ==============================
# RESTART IF CLEAN
# ==============================
if (-not $ErrorOccurred) {
    Write-Status "Deployment completed successfully! Restarting in 5 seconds..." "Green"
    Start-Sleep 5
    Restart-Computer -Force
}
else {
    Write-Status "Deployment completed with errors. Restart canceled." "Yellow"
}