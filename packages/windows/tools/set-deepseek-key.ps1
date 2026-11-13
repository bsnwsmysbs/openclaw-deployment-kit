#requires -Version 7.0

param(
    [string]$InstallDir = "D:\OpenClawMeeting",
    [string]$ApiKey = "",
    [switch]$RestartGateway
)

$ErrorActionPreference = "Stop"

if ($PSVersionTable.PSEdition -ne "Core" -or $PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "[ERROR] This tool requires PowerShell 7 pwsh.exe." -ForegroundColor Red
    Write-Host "[ERROR] Windows PowerShell 5.1 powershell.exe is not supported." -ForegroundColor Red
    Write-Host "[INFO]  Run with: pwsh -NoProfile -ExecutionPolicy Bypass -File .\tools\set-deepseek-key.ps1" -ForegroundColor Yellow
    exit 1
}

function ConvertTo-PlainText {
    param([System.Security.SecureString]$SecureText)
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureText)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

function Escape-CmdValue {
    param([string]$Value)
    return ($Value -replace '"', '\"')
}

if ([string]::IsNullOrWhiteSpace($ApiKey)) {
    $secure = Read-Host "DeepSeek API key" -AsSecureString
    $ApiKey = ConvertTo-PlainText -SecureText $secure
}

if ([string]::IsNullOrWhiteSpace($ApiKey)) {
    throw "DeepSeek API key cannot be empty."
}

if ($ApiKey -match '[\r\n]') {
    throw "DeepSeek API key must be a single line."
}

$localCmd = Join-Path $InstallDir "openclaw-local.cmd"
if (-not (Test-Path -LiteralPath $localCmd)) {
    throw "openclaw-local.cmd not found: $localCmd"
}

$backupDir = Join-Path $InstallDir "backup"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupPath = Join-Path $backupDir "openclaw-local.cmd.before-deepseek-key-$stamp.bak"
Copy-Item -LiteralPath $localCmd -Destination $backupPath -Force

$content = Get-Content -LiteralPath $localCmd -Raw -Encoding Default
$escapedKey = Escape-CmdValue -Value $ApiKey
$keyLine = "set `"DEEPSEEK_API_KEY=$escapedKey`""

if ($content -match '(?m)^set\s+"DEEPSEEK_API_KEY=.*"$') {
    $content = [regex]::Replace($content, '(?m)^set\s+"DEEPSEEK_API_KEY=.*"$', $keyLine)
} else {
    $pathPattern = '(?m)^set\s+"PATH=.*"$'
    if ($content -match $pathPattern) {
        $content = [regex]::Replace($content, $pathPattern, "`$0`r`n$keyLine", 1)
    } else {
        $content = "$keyLine`r`n$content"
    }
}

Set-Content -LiteralPath $localCmd -Value $content -Encoding ASCII

Write-Host "[OK] DeepSeek API key updated in: $localCmd" -ForegroundColor Green
Write-Host "[OK] Backup created: $backupPath" -ForegroundColor Green

if ($RestartGateway) {
    $stop = Join-Path $InstallDir "stop-gateway.cmd"
    $start = Join-Path $InstallDir "start-gateway.cmd"
    if (Test-Path -LiteralPath $stop) {
        Write-Host "[INFO] Stopping gateway..." -ForegroundColor Yellow
        try { & $stop | Out-Null } catch { Write-Host "[WARN] stop-gateway failed: $($_.Exception.Message)" -ForegroundColor Yellow }
    }
    if (Test-Path -LiteralPath $start) {
        Write-Host "[INFO] Starting gateway hidden..." -ForegroundColor Yellow
        Start-Process -FilePath $start -WindowStyle Hidden
        Write-Host "[OK] Gateway restart command sent." -ForegroundColor Green
    } else {
        Write-Host "[WARN] start-gateway.cmd not found: $start" -ForegroundColor Yellow
    }
} else {
    Write-Host "[INFO] Restart the gateway for the new key to take effect." -ForegroundColor Yellow
}
