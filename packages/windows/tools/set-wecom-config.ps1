#requires -Version 7.0

param(
    [string]$InstallDir = "D:\OpenClawMeeting",
    [string]$BotId = "",
    [string]$Secret = "",
    [switch]$RestartGateway,
    [switch]$CheckOnly
)

$ErrorActionPreference = "Stop"
$Script:FailCount = 0
$Script:WarnCount = 0

function Write-Check {
    param(
        [ValidateSet("OK", "WARN", "FAIL", "INFO")]
        [string]$Level,
        [string]$Message
    )

    switch ($Level) {
        "OK" {
            Write-Host "[OK] $Message" -ForegroundColor Green
        }
        "WARN" {
            $Script:WarnCount++
            Write-Host "[WARN] $Message" -ForegroundColor Yellow
        }
        "FAIL" {
            $Script:FailCount++
            Write-Host "[FAIL] $Message" -ForegroundColor Red
        }
        default {
            Write-Host "[INFO] $Message" -ForegroundColor DarkCyan
        }
    }
}

function Set-JsonProperty {
    param(
        [object]$Object,
        [string]$Name,
        [object]$Value
    )

    if ($Object.PSObject.Properties.Name -contains $Name) {
        $Object.$Name = $Value
    } else {
        $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
    }
}

function Ensure-JsonObject {
    param(
        [object]$Parent,
        [string]$Name
    )

    if (($Parent.PSObject.Properties.Name -notcontains $Name) -or ($null -eq $Parent.$Name)) {
        Set-JsonProperty -Object $Parent -Name $Name -Value ([pscustomobject]@{})
    }
    return $Parent.$Name
}

function Backup-File {
    param(
        [string]$Path,
        [string]$Label,
        [string]$BackupDir
    )

    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupPath = Join-Path $BackupDir "$Label-$stamp.bak"
    Copy-Item -LiteralPath $Path -Destination $backupPath -Force
    return $backupPath
}

function Get-LauncherNodeDir {
    param([string]$LocalCmd)

    if (-not (Test-Path -LiteralPath $LocalCmd)) { return "" }
    $content = Get-Content -Raw -LiteralPath $LocalCmd
    $match = [regex]::Match($content, '(?m)^set\s+"OPENCLAW_NODE_DIR=([^"]+)"')
    if ($match.Success) { return $match.Groups[1].Value.Trim() }
    return ""
}

function Test-CommandRun {
    param(
        [string]$FilePath,
        [string[]]$Arguments = @()
    )

    try {
        $output = & $FilePath @Arguments 2>&1
        return @{
            Ok = ($LASTEXITCODE -eq 0)
            Output = (($output | Out-String).Trim())
        }
    } catch {
        return @{
            Ok = $false
            Output = $_.Exception.Message
        }
    }
}

function Test-WeComEnvironment {
    param([string]$InstallDir)

    $configPath = Join-Path $InstallDir "config\openclaw.json"
    $localCmd = Join-Path $InstallDir "openclaw-local.cmd"
    $startCmd = Join-Path $InstallDir "start-gateway.cmd"
    $stopCmd = Join-Path $InstallDir "stop-gateway.cmd"
    $openclawCmd = Join-Path $InstallDir "app\openclaw\openclaw.cmd"
    $catalogPath = Join-Path $InstallDir "app\openclaw\node_modules\openclaw\dist\channel-catalog.json"

    Write-Host "Checking WeCom/OpenClaw environment..." -ForegroundColor Cyan

    if ($PSVersionTable.PSEdition -eq "Core" -and $PSVersionTable.PSVersion.Major -ge 7) {
        Write-Check OK "PowerShell 7 detected: $($PSVersionTable.PSVersion)"
    } else {
        Write-Check FAIL "This script requires PowerShell 7 pwsh.exe."
    }

    if (Test-Path -LiteralPath $InstallDir) {
        Write-Check OK "Install directory exists: $InstallDir"
    } else {
        Write-Check FAIL "Install directory not found: $InstallDir"
    }

    $cfg = $null
    if (Test-Path -LiteralPath $configPath) {
        try {
            $cfg = Get-Content -Raw -Encoding UTF8 -LiteralPath $configPath | ConvertFrom-Json
            Write-Check OK "Config JSON is readable: $configPath"
        } catch {
            Write-Check FAIL "Config JSON is invalid: $($_.Exception.Message)"
        }
    } else {
        Write-Check FAIL "Config file not found: $configPath"
    }

    if (Test-Path -LiteralPath $localCmd) {
        Write-Check OK "Launcher exists: $localCmd"
        $cmdContent = Get-Content -Raw -LiteralPath $localCmd
        if ($cmdContent -match '(?m)^set\s+"OPENCLAW_SKIP_CHANNELS=1"') {
            Write-Check WARN "Launcher contains OPENCLAW_SKIP_CHANNELS=1. WeCom channel startup will be skipped until this is removed."
        } else {
            Write-Check OK "Launcher does not skip channels."
        }
        if ($cmdContent -match '(?m)^set\s+"OPENCLAW_SKIP_PROVIDERS=1"') {
            Write-Check WARN "Launcher contains OPENCLAW_SKIP_PROVIDERS=1. Channel/provider startup may be skipped."
        }
    } else {
        Write-Check FAIL "Launcher not found: $localCmd"
    }

    foreach ($scriptPath in @($startCmd, $stopCmd)) {
        if (Test-Path -LiteralPath $scriptPath) {
            Write-Check OK "Gateway script exists: $scriptPath"
        } else {
            Write-Check WARN "Gateway script not found: $scriptPath"
        }
    }

    $nodeDir = Get-LauncherNodeDir -LocalCmd $localCmd
    if ([string]::IsNullOrWhiteSpace($nodeDir)) {
        Write-Check WARN "OPENCLAW_NODE_DIR is not set in openclaw-local.cmd."
    } else {
        $nodeExe = Join-Path $nodeDir "node.exe"
        $npmCmd = Join-Path $nodeDir "npm.cmd"
        if (Test-Path -LiteralPath $nodeExe) {
            $nodeRun = Test-CommandRun -FilePath $nodeExe -Arguments @("-v")
            if ($nodeRun.Ok) {
                Write-Check OK "Node.js is runnable: $($nodeRun.Output)"
            } else {
                Write-Check FAIL "Node.js cannot run from OPENCLAW_NODE_DIR: $($nodeRun.Output)"
            }
        } else {
            Write-Check FAIL "node.exe not found under OPENCLAW_NODE_DIR: $nodeDir"
        }

        if (Test-Path -LiteralPath $npmCmd) {
            $npmRun = Test-CommandRun -FilePath $npmCmd -Arguments @("-v")
            if ($npmRun.Ok) {
                Write-Check OK "npm is runnable: $($npmRun.Output)"
            } else {
                Write-Check FAIL "npm cannot run from OPENCLAW_NODE_DIR: $($npmRun.Output)"
            }
        } else {
            Write-Check FAIL "npm.cmd not found under OPENCLAW_NODE_DIR: $nodeDir"
        }
    }

    if (Test-Path -LiteralPath $openclawCmd) {
        Write-Check OK "OpenClaw command exists: $openclawCmd"
    } else {
        Write-Check FAIL "OpenClaw command not found: $openclawCmd"
    }

    if (Test-Path -LiteralPath $localCmd) {
        $versionRun = Test-CommandRun -FilePath $localCmd -Arguments @("--version")
        if ($versionRun.Ok) {
            Write-Check OK "openclaw-local.cmd can run: $($versionRun.Output -replace '\r?\n', ' ')"
        } else {
            Write-Check FAIL "openclaw-local.cmd cannot run: $($versionRun.Output)"
        }
    }

    if (Test-Path -LiteralPath $catalogPath) {
        try {
            $catalogText = Get-Content -Raw -Encoding UTF8 -LiteralPath $catalogPath
            if ($catalogText -match '"wecom_mcp"' -and $catalogText -match '"wecom-openclaw-plugin"') {
                Write-Check OK "OpenClaw catalog knows WeCom plugin and wecom_mcp."
            } else {
                Write-Check FAIL "OpenClaw catalog does not expose wecom_mcp. OpenClaw version/plugin catalog may be incompatible."
            }
        } catch {
            Write-Check FAIL "Cannot read channel catalog: $($_.Exception.Message)"
        }
    } else {
        Write-Check WARN "Channel catalog not found: $catalogPath"
    }

    if ($cfg) {
        $alsoAllow = @()
        if ($cfg.PSObject.Properties.Name -contains "tools" -and $cfg.tools -and $cfg.tools.PSObject.Properties.Name -contains "alsoAllow") {
            $alsoAllow = @($cfg.tools.alsoAllow)
        }
        if ($alsoAllow -contains "wecom_mcp") {
            Write-Check OK "tools.alsoAllow already includes wecom_mcp."
        } else {
            Write-Check WARN "tools.alsoAllow does not include wecom_mcp. The configure mode will add it."
        }

        $pluginEnabled = $false
        if ($cfg.PSObject.Properties.Name -contains "plugins" -and $cfg.plugins.entries -and $cfg.plugins.entries.PSObject.Properties.Name -contains "wecom-openclaw-plugin") {
            $pluginEnabled = [bool]$cfg.plugins.entries."wecom-openclaw-plugin".enabled
        }
        if ($pluginEnabled) {
            Write-Check OK "wecom-openclaw-plugin is enabled in config."
        } else {
            Write-Check WARN "wecom-openclaw-plugin is not enabled in config. The configure mode will enable it."
        }

        if ($cfg.PSObject.Properties.Name -contains "channels" -and $cfg.channels.PSObject.Properties.Name -contains "wecom") {
            $wecom = $cfg.channels.wecom
            if ($wecom.enabled -eq $true -and $wecom.connectionMode -eq "websocket" -and -not [string]::IsNullOrWhiteSpace([string]$wecom.botId) -and -not [string]::IsNullOrWhiteSpace([string]$wecom.secret)) {
                Write-Check OK "channels.wecom is configured for websocket mode."
            } else {
                Write-Check WARN "channels.wecom exists but is incomplete. The configure mode will rewrite required fields."
            }
        } else {
            Write-Check WARN "channels.wecom is not configured yet. The configure mode will create it."
        }
    }

    if (Test-Path -LiteralPath $localCmd) {
        $validateRun = Test-CommandRun -FilePath $localCmd -Arguments @("config", "validate")
        if ($validateRun.Ok) {
            Write-Check OK "openclaw config validate passed."
        } else {
            Write-Check FAIL "openclaw config validate failed: $($validateRun.Output)"
        }
    }

    Write-Host ""
    if ($Script:FailCount -gt 0) {
        Write-Host "[RESULT] Not ready. Failures: $Script:FailCount, warnings: $Script:WarnCount" -ForegroundColor Red
    } elseif ($Script:WarnCount -gt 0) {
        Write-Host "[RESULT] Basically supported, but configuration repair is needed. Warnings: $Script:WarnCount" -ForegroundColor Yellow
    } else {
        Write-Host "[RESULT] Environment is ready for WeCom configuration." -ForegroundColor Green
    }

    return @{
        ConfigPath = $configPath
        LocalCmd = $localCmd
        BackupDir = (Join-Path $InstallDir "backup")
        FailCount = $Script:FailCount
        WarnCount = $Script:WarnCount
    }
}

if ($PSVersionTable.PSEdition -ne "Core" -or $PSVersionTable.PSVersion.Major -lt 7) {
    Write-Check FAIL "This script requires PowerShell 7 pwsh.exe."
    exit 1
}

$envReport = Test-WeComEnvironment -InstallDir $InstallDir
if ($CheckOnly) {
    if ($Script:FailCount -gt 0) { exit 2 }
    exit 0
}
if ($Script:FailCount -gt 0) {
    throw "Environment check failed. Fix the failed items above, then rerun this script."
}

if ([string]::IsNullOrWhiteSpace($BotId)) {
    $BotId = Read-Host "WeCom Bot ID"
}
if ([string]::IsNullOrWhiteSpace($Secret)) {
    $Secret = Read-Host "WeCom Secret"
}
if ([string]::IsNullOrWhiteSpace($BotId) -or [string]::IsNullOrWhiteSpace($Secret)) {
    throw "BotId and Secret are required."
}

$configPath = $envReport.ConfigPath
$localCmd = $envReport.LocalCmd
$backupDir = $envReport.BackupDir

$configBackup = Backup-File -Path $configPath -Label "openclaw.json.before-wecom-config" -BackupDir $backupDir
$cmdBackup = Backup-File -Path $localCmd -Label "openclaw-local.cmd.before-wecom-config" -BackupDir $backupDir

$cfg = Get-Content -Raw -Encoding UTF8 -LiteralPath $configPath | ConvertFrom-Json

$tools = Ensure-JsonObject -Parent $cfg -Name "tools"
if (($tools.PSObject.Properties.Name -notcontains "profile") -or [string]::IsNullOrWhiteSpace([string]$tools.profile)) {
    Set-JsonProperty -Object $tools -Name "profile" -Value "coding"
}

$alsoAllow = @()
if ($tools.PSObject.Properties.Name -contains "alsoAllow" -and $null -ne $tools.alsoAllow) {
    $alsoAllow = @($tools.alsoAllow)
}
if ($alsoAllow -notcontains "wecom_mcp") {
    $alsoAllow += "wecom_mcp"
}
Set-JsonProperty -Object $tools -Name "alsoAllow" -Value $alsoAllow

$plugins = Ensure-JsonObject -Parent $cfg -Name "plugins"
$entries = Ensure-JsonObject -Parent $plugins -Name "entries"
$wecomPlugin = Ensure-JsonObject -Parent $entries -Name "wecom-openclaw-plugin"
Set-JsonProperty -Object $wecomPlugin -Name "enabled" -Value $true

$channels = Ensure-JsonObject -Parent $cfg -Name "channels"
$wecom = Ensure-JsonObject -Parent $channels -Name "wecom"
Set-JsonProperty -Object $wecom -Name "enabled" -Value $true
Set-JsonProperty -Object $wecom -Name "name" -Value "企业微信"
Set-JsonProperty -Object $wecom -Name "connectionMode" -Value "websocket"
Set-JsonProperty -Object $wecom -Name "botId" -Value $BotId
Set-JsonProperty -Object $wecom -Name "secret" -Value $Secret
Set-JsonProperty -Object $wecom -Name "dmPolicy" -Value "open"
Set-JsonProperty -Object $wecom -Name "allowFrom" -Value @("*")
Set-JsonProperty -Object $wecom -Name "groupPolicy" -Value "open"
Set-JsonProperty -Object $wecom -Name "sendThinkingMessage" -Value $true

$cfg | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $configPath -Encoding UTF8

$cmdContent = Get-Content -Raw -LiteralPath $localCmd
$cmdContent = $cmdContent -replace '(?m)^set\s+"OPENCLAW_SKIP_CHANNELS=1"\r?\n?', ''
$cmdContent = $cmdContent -replace '(?m)^set\s+"OPENCLAW_SKIP_PROVIDERS=1"\r?\n?', ''
Set-Content -LiteralPath $localCmd -Value $cmdContent -Encoding ASCII

Write-Host "[OK] WeCom channel config written." -ForegroundColor Green
Write-Host "[OK] tools.alsoAllow includes wecom_mcp." -ForegroundColor Green
Write-Host "[OK] OPENCLAW_SKIP_CHANNELS / OPENCLAW_SKIP_PROVIDERS removed from openclaw-local.cmd if present." -ForegroundColor Green
Write-Host "[INFO] Config backup: $configBackup" -ForegroundColor DarkCyan
Write-Host "[INFO] Launcher backup: $cmdBackup" -ForegroundColor DarkCyan

& (Join-Path $InstallDir "openclaw-local.cmd") config validate
if ($LASTEXITCODE -ne 0) {
    throw "openclaw config validate failed."
}

if ($RestartGateway) {
    $stop = Join-Path $InstallDir "stop-gateway.cmd"
    $start = Join-Path $InstallDir "start-gateway.cmd"
    if (Test-Path -LiteralPath $stop) {
        try { & $stop | Out-Null } catch { Write-Host "[WARN] stop-gateway failed: $($_.Exception.Message)" -ForegroundColor Yellow }
    }
    if (-not (Test-Path -LiteralPath $start)) {
        throw "start-gateway.cmd not found: $start"
    }
    Start-Process -FilePath $start -WindowStyle Hidden
    Start-Sleep -Seconds 3
    Write-Host "[OK] Gateway restart triggered." -ForegroundColor Green
}

Write-Host "[DONE] WeCom config is ready. Test with: openclaw channels capabilities --channel wecom" -ForegroundColor Cyan
