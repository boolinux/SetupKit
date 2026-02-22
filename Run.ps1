# ==============================
# AutoSetupPC vPro - Full Deployment Edition
# ==============================

$global:ErrorOccurred = $false

function Info($m){ Write-Host "[*] $m" -ForegroundColor Cyan }
function OK($m){ Write-Host "[✓] $m" -ForegroundColor Green }
function ERR($m){
    Write-Host "[X] $m" -ForegroundColor Red
    $global:ErrorOccurred = $true
}

# CHECK ADMIN
if (-not ([Security.Principal.WindowsPrincipal] `
[Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {

    ERR "Vui lòng chạy PowerShell bằng quyền Administrator!"
    return
}

# EXECUTION POLICY
try{
    if ((Get-ExecutionPolicy -Scope CurrentUser) -ne "RemoteSigned") {
        Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    }
}catch{ ERR "Không thể set ExecutionPolicy." }

# DESKTOP ICONS
try{
    $reg="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel"
    if(-not (Test-Path $reg)){ New-Item -Path $reg -Force | Out-Null }

    $icons=@(
        "{20D04FE0-3AEA-1069-A2D8-08002B30309D}",
        "{59031a47-3f72-44a7-89c5-5595fe6b30ee}",
        "{5399E694-6CE5-4D6C-8FCE-1D8870FDCBA0}",
        "{F02C1A0D-BE21-4350-88B0-7367FC96EF3C}",
        "{645FF040-5081-101B-9F08-00AA002F954E}"
    )

    foreach($icon in $icons){
        New-ItemProperty -Path $reg -Name $icon -Value 0 -PropertyType DWord -Force | Out-Null
    }

    OK "Desktop tối ưu xong."
}catch{ ERR "Lỗi Desktop." }

# TASKBAR SEARCH
try{
    Set-ItemProperty `
    -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" `
    -Name "SearchboxTaskbarMode" `
    -Value 2 -Force
}catch{ ERR "Lỗi Search." }

# DISABLE WIDGET
try{
    Set-ItemProperty `
    -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
    -Name "TaskbarDa" `
    -Value 0 -Force
}catch{ ERR "Lỗi Widgets." }

# REFRESH EXPLORER
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Process explorer

# SOFTWARE LIST
if(-not (Get-Command winget -ErrorAction SilentlyContinue)){
    ERR "Winget chưa có trên máy."
}
else{
    $apps=@(
        @{Name="Google Chrome";Id="Google.Chrome"},
        @{Name="7-Zip";Id="7zip.7zip"},
        @{Name="WinRAR";Id="RARLab.WinRAR"},
        @{Name="AnyDesk";Id="AnyDeskSoftwareGmbH.AnyDesk"},
        @{Name="UltraViewer";Id="UltraViewer.UltraViewer"},
        @{Name="UniKey";Id="Unikey.Unikey"}
    )

    foreach($app in $apps){
        try{
            if(winget list --id $app.Id | Select-String $app.Id){
                Info "$($app.Name) đã cài. Bỏ qua."
            }
            else{
                Info "Đang cài $($app.Name)..."
                winget install --id $app.Id -e --silent `
                --accept-package-agreements `
                --accept-source-agreements | Out-Null
                OK "$($app.Name) cài xong."
            }
        }catch{
            ERR "Không cài được $($app.Name)"
        }
    }
}

# FINISH
Write-Host ""
if(-not $global:ErrorOccurred){
    Write-Host "HOÀN TẤT - Restart sau 3 giây..." -ForegroundColor Green
    Start-Sleep 3
    Restart-Computer -Force
}
else{
    Write-Host "Có lỗi xảy ra. Không restart." -ForegroundColor Red
}
