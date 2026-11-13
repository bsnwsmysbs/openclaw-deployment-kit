#requires -Version 7.0

param(
    [string]$InstallDir = "D:\OpenClawMeeting",
    [string]$NodeVersion = "24.16.0"
)

$ErrorActionPreference = "Stop"

function Test-VersionAtLeast {
    param(
        [string]$Actual,
        [string]$Required
    )

    try {
        $actualVersion = [version]($Actual.Trim().TrimStart("v"))
        $requiredVersion = [version]($Required.Trim().TrimStart("v"))
        return ($actualVersion -ge $requiredVersion)
    } catch {
        return $false
    }
}

function Test-NpmRuntime {
    param(
        [string]$NodeDir,
        [string]$NodeExe,
        [string]$NpmCmd
    )

    if (-not (Test-Path -LiteralPath $NodeExe)) { return $false }
    if (-not (Test-Path -LiteralPath $NpmCmd)) { return $false }

    try {
        $nodeVersionText = (& $NodeExe -v 2>$null).Trim()
        $npmVersionText = (& $NpmCmd -v 2>$null).Trim()
        return ((-not [string]::IsNullOrWhiteSpace($nodeVersionText)) -and (-not [string]::IsNullOrWhiteSpace($npmVersionText)))
    } catch {
        return $false
    }
}

function Get-CompatibleSystemNodeRuntime {
    param([string]$NodeVersion)

    $candidateDirs = New-Object System.Collections.Generic.List[string]
    foreach ($dir in @("C:\Program Files\nodejs", "C:\Program Files (x86)\nodejs")) {
        if (Test-Path -LiteralPath $dir) { $candidateDirs.Add($dir) }
    }

    foreach ($cmdName in @("node.exe", "npm.cmd")) {
        $cmd = Get-Command $cmdName -ErrorAction SilentlyContinue
        if ($cmd -and $cmd.Source) {
            $candidateDirs.Add((Split-Path -Parent $cmd.Source))
        }
    }

    foreach ($nodeDir in ($candidateDirs | Select-Object -Unique)) {
        $nodeExe = Join-Path $nodeDir "node.exe"
        $npmCmd = Join-Path $nodeDir "npm.cmd"
        if (-not (Test-NpmRuntime -NodeDir $nodeDir -NodeExe $nodeExe -NpmCmd $npmCmd)) { continue }

        $actualNodeVersion = (& $nodeExe -v 2>$null).Trim()
        if (-not (Test-VersionAtLeast -Actual $actualNodeVersion -Required $NodeVersion)) { continue }

        $npmVersion = (& $npmCmd -v 2>$null).Trim()
        Write-Host "[OK] Found system Node.js $actualNodeVersion with npm $npmVersion`: $nodeDir" -ForegroundColor Green
        return @{ NodeDir = $nodeDir; NodeExe = $nodeExe; NpmCmd = $npmCmd; Source = "system" }
    }

    return $null
}

function Update-OpenClawLocalNodeDir {
    param(
        [string]$InstallDir,
        [string]$NodeDir
    )

    $localCmd = Join-Path $InstallDir "openclaw-local.cmd"
    if (-not (Test-Path -LiteralPath $localCmd)) {
        throw "openclaw-local.cmd not found: $localCmd"
    }

    $backupDir = Join-Path $InstallDir "backup"
    New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupPath = Join-Path $backupDir "openclaw-local.cmd.before-system-node-repair-$stamp.bak"
    Copy-Item -LiteralPath $localCmd -Destination $backupPath -Force

    $content = Get-Content -LiteralPath $localCmd -Raw
    $content = $content -replace '(?m)^set "OPENCLAW_NODE_DIR=.*"$', "set `"OPENCLAW_NODE_DIR=$NodeDir`""
    $content = $content -replace '(?m)^set "PATH=.*;%PATH%"$', "set `"PATH=$NodeDir;%PATH%`""

    if ($content -notmatch '(?m)^set "OPENCLAW_NODE_DIR=') {
        $content = $content -replace '(?m)^set "OPENCLAW_WORKSPACE=.*"$', "`$0`r`nset `"OPENCLAW_NODE_DIR=$NodeDir`""
    }
    if ($content -notmatch '(?m)^set "PATH=.*;%PATH%"$') {
        $content = $content -replace '(?m)^set "OPENCLAW_NO_AUTO_UPDATE=.*"$', "`$0`r`nset `"PATH=$NodeDir;%PATH%`""
    }

    Set-Content -LiteralPath $localCmd -Value $content -Encoding ASCII
    Write-Host "[OK] Updated openclaw-local.cmd to system Node.js. Backup: $backupPath" -ForegroundColor Green
}

Write-Host "Repairing OpenClaw Node.js/npm runtime path to system Node.js..." -ForegroundColor Cyan

if (-not (Test-Path -LiteralPath $InstallDir)) {
    throw "Install directory not found: $InstallDir"
}

$node = Get-CompatibleSystemNodeRuntime -NodeVersion $NodeVersion
if (-not $node) {
    throw "No compatible system Node.js/npm found. Install Node.js v$NodeVersion or newer globally, then rerun this script."
}

Update-OpenClawLocalNodeDir -InstallDir $InstallDir -NodeDir $node.NodeDir

$env:PATH = "$($node.NodeDir);$env:PATH"
& $node.NodeExe -v
& $node.NpmCmd -v

$localCmd = Join-Path $InstallDir "openclaw-local.cmd"
& $localCmd --version
if ($LASTEXITCODE -ne 0) {
    throw "openclaw-local.cmd verification failed."
}

Write-Host "[OK] System Node.js/npm runtime repair completed." -ForegroundColor Green
