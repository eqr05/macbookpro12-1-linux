#Requires -RunAsAdministrator
# Ejecutar tras reiniciar:  powershell -ExecutionPolicy Bypass -File .\compilar.ps1
# Instala/arranca Debian en WSL2, valida las opciones de live-build y compila la ISO.
$ErrorActionPreference = 'Stop'

$projectWin = Split-Path -Parent $MyInvocation.MyCommand.Path
$isoOutWin  = Join-Path $projectWin 'iso'
$logWin     = Join-Path $projectWin 'build-wsl.log'
New-Item -ItemType Directory -Force -Path $isoOutWin | Out-Null

function ConvertTo-WslPath([string]$p) {
	$drive = $p.Substring(0, 1).ToLower()
	$rest  = $p.Substring(2).Replace('\', '/')
	"/mnt/$drive$rest"
}

$projectWsl = ConvertTo-WslPath $projectWin
$isoOutWsl  = ConvertTo-WslPath $isoOutWin

Write-Host '== Comprobando WSL2 =='
$list = (& wsl.exe -l -q 2>&1 | Out-String)
if ($list -match 'Uso:|Usage:') {
	Write-Host 'WSL2 no está activo. Reinicia el equipo y vuelve a ejecutar este script.' -ForegroundColor Yellow
	exit 1
}

$distros = ($list -split "`r?`n") |
	ForEach-Object { ($_ -replace "`0", '').Trim() } |
	Where-Object { $_ }

if ($distros -notcontains 'Debian') {
	Write-Host '== Instalando Debian en WSL2 =='
	& wsl.exe --install -d Debian --no-launch
	if ($LASTEXITCODE -ne 0) {
		Write-Host 'No se pudo instalar Debian automáticamente. Ejecuta: wsl --install -d Debian' -ForegroundColor Red
		exit 1
	}
}

& wsl.exe --set-default-version 2 2>&1 | Out-Null
& wsl.exe --set-version Debian 2 2>&1 | Out-Null
& wsl.exe --update 2>&1 | Out-Null

Write-Host '== Ejecutando validación y compilación dentro de Debian =='
Write-Host "Registro completo: $logWin"
Write-Host "Si Debian pide crear un usuario en el primer arranque, usa 'macbook'."
Write-Host ''

& wsl.exe -d Debian -u root --exec bash "$projectWsl/scripts/preparar-y-compilar.sh" $projectWsl $isoOutWsl 2>&1 |
	Tee-Object -FilePath $logWin

if ($LASTEXITCODE -ne 0) {
	Write-Host "La compilación falló (código $LASTEXITCODE). Revisa build-wsl.log." -ForegroundColor Red
	exit $LASTEXITCODE
}

Write-Host "ISO generada en: $isoOutWin" -ForegroundColor Green
