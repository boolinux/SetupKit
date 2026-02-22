# ============================================
# AUTO SETUP TOOL - STABLE TECH EDITION
# ============================================

$ErrorOccurred = $false

function Write-Status($msg, $color="White") {
    Write-Host $msg -ForegroundColor $color
}

# ==============================
# CHECK ADMIN (DOUBLE SAFETY)
# ==============================
if (-not ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {

    Start-Process powershell "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# ==============================
# ASK DISK SPLIT FIRST
# ==============================
$response = Read-Host "Bạn có muốn chia ổ cứng không? (Y/N)"
$DoSplit = $response -match "^[Yy]$"

# ==============================
# CHECK WINGET
# ==============================
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Status "Winget chưa tồn tại. Vui lòng cài Microsoft App Installer trước." "Red"
    $ErrorOccurred = $true
}

# ==============================
# INSTALL FUNCTION
# ==============================
function Install-App($name, $id) {

    Write-Status "Đang kiểm tra $name..." "Cyan"

    $installed = winget list --id $id -e 2>$null

    if ($installed) {
        Write-Status "$name đã tồn tại." "Yellow"
        return
    }

    Write-Status "Đang cài $name..." "Cyan"

    winget install --id $id -e --silent `
    --accept-source-agreements `
    --accept-package-agreements

    if ($LASTEXITCODE -eq 0) {
        Write-Status "Đã cài xong $name." "Green"
    } else {
        Write-Status "Lỗi cài $name." "Red"
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
Write-Status "Tạo shortcut Office..." "Cyan"

$desktop = [Environment]::GetFolderPath("Desktop")
$officePaths = @(
"C:\Program Files\Microsoft Office\root\Office16\WINWORD.EXE",
"C:\Program Files\Microsoft Office\root\Office16\EXCEL.EXE",
"C:\Program Files\Microsoft Office\root\Office16\POWERPNT.EXE"
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

# ==============================
# SHOW SYSTEM ICONS
# ==============================
try {
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel"

    $icons = @(
    "{20D04FE0-3AEA-1069-A2D8-08002B30309D}", # This PC
    "{59031a47-3f72-44a7-89c5-5595fe6b30ee}", # User
    "{645FF040-5081-101B-9F08-00AA002F954E}", # Recycle
    "{F02C1A0D-BE21-4350-88B0-7367FC96EF3C}", # Network
    "{5399E694-6CE5-4D6C-8FCE-1D8870FDCBA0}"  # Control Panel
    )

    foreach ($i in $icons) {
        Set-ItemProperty -Path $regPath -Name $i -Value 0 -Force
    }

    Write-Status "Đã bật icon hệ thống." "Green"

} catch {
    Write-Status "Lỗi bật icon hệ thống." "Red"
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

        Write-Status "Đã tối ưu Taskbar Windows 11." "Green"

    } catch {
        Write-Status "Lỗi chỉnh Taskbar." "Red"
        $ErrorOccurred = $true
    }
}

# ==============================
# DISK SPLIT SAFE MODE
# ==============================
if ($DoSplit) {

    try {
        if (Get-Partition -DriveLetter D -ErrorAction SilentlyContinue) {
            Write-Status "Ổ D đã tồn tại. Bỏ qua chia ổ." "Yellow"
        }
        else {

            $volume = Get-Volume -DriveLetter C
            $freeGB = [math]::Round($volume.SizeRemaining/1GB)

            if ($freeGB -lt 60) {
                Write-Status "Dung lượng trống quá thấp để chia ổ." "Red"
            }
            else {

                if ($freeGB -gt 400) { $newSize = 200GB }
                elseif ($freeGB -gt 200) { $newSize = 100GB }
                elseif ($freeGB -gt 100) { $newSize = 50GB }
                else { throw "Không đủ dung lượng." }

                Write-Status "Đang chia ổ..." "Cyan"

                Resize-Partition -DriveLetter C `
                -Size ($volume.Size - $newSize)

                $disk = (Get-Partition -DriveLetter C).DiskNumber

                New-Partition -DiskNumber $disk `
                -UseMaximumSize -DriveLetter D | `
                Format-Volume -FileSystem NTFS `
                -NewFileSystemLabel "DATA" -Confirm:$false

                Write-Status "Chia ổ thành công." "Green"
            }
        }
    }
    catch {
        Write-Status "Lỗi khi chia ổ: $_" "Red"
        $ErrorOccurred = $true
    }
}

# ==============================
# REFRESH EXPLORER
# ==============================
Stop-Process -Name explorer -Force
Start-Process explorer

# ==============================
# RESTART IF CLEAN
# ==============================
if (-not $ErrorOccurred) {
    Write-Status "Hoàn tất! Restart sau 3 giây..." "Green"
    Start-Sleep 3
    Restart-Computer -Force
}
else {
    Write-Status "Hoàn tất nhưng có lỗi. Không restart." "Yellow"
}