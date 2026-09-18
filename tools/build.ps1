# BUILD COMPLETO DO GNOSIS — um comando: export -> ícone/versão -> instalador.
# Uso (PowerShell, de qualquer pasta):
#   powershell -ExecutionPolicy Bypass -File tools\build.ps1 [-Version 1.0.0]
# Saídas: builds\GNOSIS.exe + GNOSIS.pck · installer\Output\GNOSIS-Setup-<v>.exe
param([string]$Version = "1.0.0")

$ErrorActionPreference = "Stop"
$proj = Split-Path $PSScriptRoot -Parent
$godot = "C:\Users\jmtat\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64_console.exe"
$rcedit = Join-Path $proj "tools\bin\rcedit-x64.exe"
$iscc = "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
if (-not (Test-Path $iscc)) { $iscc = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" }

Write-Host "[1/3] Exportando builds\GNOSIS.exe (release)..."
& $godot --headless --path $proj --export-release "Windows Desktop" "builds/GNOSIS.exe" 2>$null | Out-Null
if (-not (Test-Path "$proj\builds\GNOSIS.pck")) { throw "Export falhou (GNOSIS.pck ausente). Rode de novo — o OneDrive as vezes segura o arquivo." }

Write-Host "[2/3] Aplicando ícone + versão ($Version) no exe..."
if (Test-Path $rcedit) {
	& $rcedit "$proj\builds\GNOSIS.exe" --set-icon "$proj\assets\icon_gnosis.ico" `
		--set-version-string "ProductName" "GNOSIS" `
		--set-version-string "FileDescription" "GNOSIS - beat-em-up 2.5D gnostico" `
		--set-file-version "$Version.0" --set-product-version $Version
} else { Write-Warning "rcedit ausente ($rcedit) — exe fica sem ícone próprio." }

Write-Host "[3/3] Compilando o instalador..."
if (Test-Path $iscc) {
	& $iscc "/DAppVersion=$Version" "$proj\installer\gnosis.iss" | Select-Object -Last 3
} else { Write-Warning "Inno Setup ausente — instale com: winget install -e --id JRSoftware.InnoSetup" }

Write-Host "PRONTO:" -ForegroundColor Green
Get-ChildItem "$proj\builds\GNOSIS.exe", "$proj\builds\GNOSIS.pck", "$proj\installer\Output\GNOSIS-Setup-$Version.exe" -ErrorAction SilentlyContinue |
	Select-Object FullName, @{n="MB";e={[math]::Round($_.Length/1MB,1)}}
