#requires -Version 7.0

param(
    [string]$InstallDir = "D:\OpenClawMeeting"
)

$ErrorActionPreference = "Stop"
if ($PSVersionTable.PSEdition -ne "Core" -or $PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "[ERROR] This script requires PowerShell 7 pwsh.exe." -ForegroundColor Red
    Write-Host "[ERROR] Windows PowerShell 5.1 powershell.exe is not supported." -ForegroundColor Red
    Write-Host "[INFO]  Run with: pwsh -NoProfile -ExecutionPolicy Bypass -File .\uninstall.ps1" -ForegroundColor Yellow
    exit 1
}
$pwshExe = (Get-Command pwsh.exe -ErrorAction SilentlyContinue).Source
if ([string]::IsNullOrWhiteSpace($pwshExe)) {
    $candidatePwsh = Join-Path $PSHOME "pwsh.exe"
    if (Test-Path -LiteralPath $candidatePwsh) { $pwshExe = $candidatePwsh }
}
if ([string]::IsNullOrWhiteSpace($pwshExe) -or -not (Test-Path -LiteralPath $pwshExe)) {
    throw "PowerShell 7 pwsh.exe was used to start this process but its executable path could not be resolved."
}
Write-Host "This script only stops OpenClaw local gateway. It does not delete files." -ForegroundColor Yellow
$disableAutoStart = Join-Path $InstallDir "disable-autostart.ps1"
if (Test-Path -LiteralPath $disableAutoStart) {
    & $pwshExe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $disableAutoStart
}
$stop = Join-Path $InstallDir "stop-gateway.cmd"
if (Test-Path -LiteralPath $stop) {
    & $stop
} else {
    Write-Host "stop-gateway.cmd not found: $stop" -ForegroundColor Yellow
}
