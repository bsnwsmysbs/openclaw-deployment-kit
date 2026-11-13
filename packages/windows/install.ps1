#requires -Version 7.0

param(
    [string]$InstallDir = "D:\OpenClawMeeting",
    [int]$Port = 18789,
    [string]$Token = "",
    [string]$DeepSeekApiKey = "",
    [string]$OpenClawVersion = "2026.6.1",
    [string]$NodeVersion = "24.16.0",
    [string]$NpmRegistry = "https://registry.npmmirror.com",
    [switch]$SkipBusinessSkills
)

$ErrorActionPreference = "Stop"

if ($PSVersionTable.PSEdition -ne "Core" -or $PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "[ERROR] This installer requires PowerShell 7 pwsh.exe." -ForegroundColor Red
    Write-Host "[ERROR] Windows PowerShell 5.1 powershell.exe is not supported." -ForegroundColor Red
    Write-Host "[INFO]  Please run from CMD with: install.cmd" -ForegroundColor Yellow
    Write-Host "[INFO]  Or run directly with: pwsh -NoProfile -ExecutionPolicy Bypass -File .\install.ps1" -ForegroundColor Yellow
    exit 1
}

$Script:PwshExe = (Get-Command pwsh.exe -ErrorAction SilentlyContinue).Source
if ([string]::IsNullOrWhiteSpace($Script:PwshExe)) {
    $candidatePwsh = Join-Path $PSHOME "pwsh.exe"
    if (Test-Path -LiteralPath $candidatePwsh) {
        $Script:PwshExe = $candidatePwsh
    }
}
if ([string]::IsNullOrWhiteSpace($Script:PwshExe) -or -not (Test-Path -LiteralPath $Script:PwshExe)) {
    throw "PowerShell 7 pwsh.exe was used to start this process but its executable path could not be resolved."
}

$PackageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

function Read-Value {
    param([string]$Prompt, [string]$Default)
    $text = Read-Host "$Prompt [$Default]"
    if ([string]::IsNullOrWhiteSpace($text)) { return $Default }
    return $text
}

function Read-YesNo {
    param([string]$Prompt, [bool]$Default = $true)
    $defaultText = if ($Default) { "Y" } else { "N" }
    $text = Read-Host "$Prompt [$defaultText]"
    if ([string]::IsNullOrWhiteSpace($text)) { return $Default }
    return ($text.Trim().ToLowerInvariant() -in @("y", "yes", "是", "1", "true"))
}

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
        [string]$NpmCmd,
        [switch]$RequireNpmInternals
    )

    if (-not (Test-Path -LiteralPath $NodeExe)) { return $false }
    if (-not (Test-Path -LiteralPath $NpmCmd)) { return $false }

    $checkInternals = [bool]$RequireNpmInternals
    try {
        $nodeDirFull = [System.IO.Path]::GetFullPath($NodeDir).TrimEnd('\')
        $npmCmdFull = [System.IO.Path]::GetFullPath($NpmCmd)
        if ($npmCmdFull.StartsWith($nodeDirFull, [System.StringComparison]::OrdinalIgnoreCase)) {
            $checkInternals = $true
        }
    } catch {
        $checkInternals = [bool]$RequireNpmInternals
    }

    if ($checkInternals) {
        $npmCli = Join-Path $NodeDir "node_modules\npm\bin\npm-cli.js"
        $npmPrefix = Join-Path $NodeDir "node_modules\npm\bin\npm-prefix.js"
        if (-not (Test-Path -LiteralPath $npmCli)) { return $false }
        if (-not (Test-Path -LiteralPath $npmPrefix)) { return $false }
    }

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

    $nodeCommand = Get-Command node.exe -ErrorAction SilentlyContinue
    $npmCommand = Get-Command npm.cmd -ErrorAction SilentlyContinue
    if (-not $nodeCommand -or -not $npmCommand) {
        Write-Host "[ERROR] System Node.js/npm.cmd not found." -ForegroundColor Red
        Write-Host "[INFO]  Install system Node.js from CMD or PowerShell:" -ForegroundColor Yellow
        Write-Host "        winget install OpenJS.NodeJS --accept-package-agreements --accept-source-agreements" -ForegroundColor Yellow
        Write-Host "[INFO]  After installation, close and reopen CMD, then run install.cmd again." -ForegroundColor Yellow
        return $null
    }

    $nodeExe = $nodeCommand.Source
    $npmCmd = $npmCommand.Source
    $nodeDir = Split-Path -Parent $nodeExe
    if (-not (Test-NpmRuntime -NodeDir $nodeDir -NodeExe $nodeExe -NpmCmd $npmCmd)) {
        Write-Host "[ERROR] Existing system Node.js/npm is incomplete or cannot run cleanly." -ForegroundColor Red
        Write-Host "[INFO]  Repair/reinstall system Node.js with:" -ForegroundColor Yellow
        Write-Host "        winget install OpenJS.NodeJS --accept-package-agreements --accept-source-agreements" -ForegroundColor Yellow
        Write-Host "[INFO]  After installation, close and reopen CMD, then run install.cmd again." -ForegroundColor Yellow
        return $null
    }

    try {
        $actualNodeVersion = (& $nodeExe -v 2>$null).Trim()
        $npmVersion = (& $npmCmd -v 2>$null).Trim()
    } catch {
        Write-Host "[ERROR] Existing system Node.js/npm could not run cleanly." -ForegroundColor Red
        Write-Host "[INFO]  Repair/reinstall system Node.js with:" -ForegroundColor Yellow
        Write-Host "        winget install OpenJS.NodeJS --accept-package-agreements --accept-source-agreements" -ForegroundColor Yellow
        Write-Host "[INFO]  After installation, close and reopen CMD, then run install.cmd again." -ForegroundColor Yellow
        return $null
    }

    if (-not (Test-VersionAtLeast -Actual $actualNodeVersion -Required $NodeVersion)) {
        Write-Host "[ERROR] Existing system Node.js is $actualNodeVersion; required >= v$NodeVersion." -ForegroundColor Red
        Write-Host "[INFO]  Upgrade system Node.js with:" -ForegroundColor Yellow
        Write-Host "        winget upgrade OpenJS.NodeJS --accept-package-agreements --accept-source-agreements" -ForegroundColor Yellow
        Write-Host "[INFO]  If upgrade is unavailable, install with:" -ForegroundColor Yellow
        Write-Host "        winget install OpenJS.NodeJS --accept-package-agreements --accept-source-agreements" -ForegroundColor Yellow
        Write-Host "[INFO]  After installation, close and reopen CMD, then run install.cmd again." -ForegroundColor Yellow
        return $null
    }

    Write-Host "[OK] Using existing system Node.js $actualNodeVersion with npm $npmVersion" -ForegroundColor Green
    return @{ NodeDir = $nodeDir; NodeExe = $nodeExe; NpmCmd = $npmCmd; Source = "system" }
}

function Ensure-SystemNodeRuntime {
    param([string]$NodeVersion)
    $systemNode = Get-CompatibleSystemNodeRuntime -NodeVersion $NodeVersion
    if ($systemNode) {
        return $systemNode
    }
    throw "System Node.js/npm is required. Install Node.js v$NodeVersion or newer globally, then rerun install.cmd. Private Node.js runtime download is disabled for this package."
}

function Install-OpenClawRuntime {
    param(
        [string]$InstallDir,
        [hashtable]$Node,
        [string]$OpenClawVersion,
        [string]$NpmRegistry
    )
    $appDir = Join-Path $InstallDir "app"
    $openclawPrefix = Join-Path $appDir "openclaw"
    New-Item -ItemType Directory -Force -Path $appDir | Out-Null

    if (Test-Path -LiteralPath $openclawPrefix) {
        $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $backupRoot = Join-Path $InstallDir "backup"
        New-Item -ItemType Directory -Force -Path $backupRoot | Out-Null
        $backupPath = Join-Path $backupRoot "openclaw-runtime-$stamp"
        Move-Item -LiteralPath $openclawPrefix -Destination $backupPath
        Write-Host "[OK] Existing OpenClaw runtime moved to: $backupPath" -ForegroundColor Green
    }

    New-Item -ItemType Directory -Force -Path $openclawPrefix | Out-Null
    $env:PATH = "$($Node.NodeDir);$env:PATH"
    & $Node.NpmCmd install -g --prefix $openclawPrefix "openclaw@$OpenClawVersion" --registry $NpmRegistry | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "npm install openclaw@$OpenClawVersion failed with exit code $LASTEXITCODE" }

    $cmd = Join-Path $openclawPrefix "openclaw.cmd"
    if (-not (Test-Path -LiteralPath $cmd)) { throw "OpenClaw command was not installed: $cmd" }
    return $openclawPrefix
}

function Install-PreloadedSkills {
    param([string]$InstallDir, [string]$PackageRoot)
    $skillsRoot = Join-Path $PackageRoot "preload\skills"
    if (-not (Test-Path -LiteralPath $skillsRoot)) {
        Write-Host "[SKIP] No preloaded skills found." -ForegroundColor DarkGray
        return
    }
    $skillDirs = Get-ChildItem -LiteralPath $skillsRoot -Directory -ErrorAction SilentlyContinue
    foreach ($skill in $skillDirs) {
        $skillFile = Join-Path $skill.FullName "SKILL.md"
        if (-not (Test-Path -LiteralPath $skillFile)) {
            Write-Host "[WARN] Skipping invalid skill folder: $($skill.FullName)" -ForegroundColor Yellow
            continue
        }
        # Workspace skills are discovered by OpenClaw without a separate CLI installer.
        $targetRoot = Join-Path $InstallDir 'workspace\skills'
        New-Item -ItemType Directory -Force -Path $targetRoot | Out-Null
        Copy-Item -LiteralPath $skill.FullName -Destination $targetRoot -Recurse -Force
        Write-Host "[OK] Skill installed: $($skill.Name)" -ForegroundColor Green
    }
}

function Install-PreloadedCronJobs {
    param([string]$InstallDir, [string]$PackageRoot, [int]$Port, [string]$Token)
    $jobsPath = Join-Path $PackageRoot "preload\cron-jobs.json"
    if (-not (Test-Path -LiteralPath $jobsPath)) {
        Write-Host "[SKIP] No preloaded automation jobs found." -ForegroundColor DarkGray
        return
    }
    $jobs = @(Get-Content -LiteralPath $jobsPath -Raw -Encoding UTF8 | ConvertFrom-Json)
    if (-not $jobs) {
        Write-Host "[SKIP] Automation job template is empty." -ForegroundColor DarkGray
        return
    }
    $gatewayUrl = "ws://127.0.0.1:$Port"
    foreach ($job in $jobs) {
        $session = if ($job.session) { [string]$job.session } else { "isolated" }
        $args = @("cron", "add", "--name", $job.name, "--description", $job.description, "--message", $job.message, "--session", $session, "--token", $Token, "--url", $gatewayUrl, "--json")
        if ($job.disabled -eq $true) { $args += "--disabled" }
        if ($job.cron) { $args += @("--cron", $job.cron) }
        if ($job.every) { $args += @("--every", $job.every) }
        if ($job.tz) { $args += @("--tz", $job.tz) }
        try {
            & (Join-Path $InstallDir "openclaw-local.cmd") @args | Out-Host
            Write-Host "[OK] Automation job installed: $($job.name)" -ForegroundColor Green
        } catch {
            Write-Host "[WARN] Failed to install automation job $($job.name): $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}

function Clear-PreloadedCronJobs {
    param([string]$InstallDir, [string]$PackageRoot, [int]$Port, [string]$Token)

    $jobsPath = Join-Path $PackageRoot "preload\cron-jobs.json"
    if (-not (Test-Path -LiteralPath $jobsPath)) {
        Write-Host "[SKIP] No preloaded automation job names to clean." -ForegroundColor DarkGray
        return
    }

    try {
        $preloadedJobs = @(Get-Content -LiteralPath $jobsPath -Raw -Encoding UTF8 | ConvertFrom-Json)
        $preloadedNames = @($preloadedJobs | ForEach-Object { [string]$_.name } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        if ($preloadedNames.Count -eq 0) {
            Write-Host "[SKIP] Preloaded automation job template contains no names." -ForegroundColor DarkGray
            return
        }

        $gatewayUrl = "ws://127.0.0.1:$Port"
        $localCmd = Join-Path $InstallDir "openclaw-local.cmd"
        $raw = & $localCmd cron list --all --json --token $Token --url $gatewayUrl --timeout 30000 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[WARN] Could not list existing automation jobs for cleanup: $raw" -ForegroundColor Yellow
            return
        }

        $parsed = $raw | Out-String | ConvertFrom-Json
        $existingJobs = @()
        if ($parsed -is [array]) {
            $existingJobs = @($parsed)
        } elseif ($parsed.PSObject.Properties.Name -contains "jobs") {
            $existingJobs = @($parsed.jobs)
        } else {
            $existingJobs = @($parsed)
        }

        $matched = @($existingJobs | Where-Object { $preloadedNames -contains [string]$_.name })
        if ($matched.Count -eq 0) {
            Write-Host "[OK] No preloaded business automation jobs found." -ForegroundColor Green
            return
        }

        foreach ($job in $matched) {
            $jobId = if ($job.PSObject.Properties.Name -contains "id") { [string]$job.id } elseif ($job.PSObject.Properties.Name -contains "jobId") { [string]$job.jobId } else { "" }
            if ([string]::IsNullOrWhiteSpace($jobId)) {
                Write-Host "[WARN] Skipping automation job without id: $($job.name)" -ForegroundColor Yellow
                continue
            }
            $removeOutput = & $localCmd cron rm $jobId --token $Token --url $gatewayUrl --timeout 30000 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "[OK] Removed preloaded automation job: $($job.name)" -ForegroundColor Green
            } else {
                Write-Host "[WARN] Failed to remove automation job $($job.name): $removeOutput" -ForegroundColor Yellow
            }
        }
    } catch {
        Write-Host "[WARN] Preloaded automation cleanup failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

function Install-PreloadedWorkspace {
    param([string]$InstallDir, [string]$PackageRoot, [bool]$IncludeBusinessSkills)

    $sourceDir = if ($IncludeBusinessSkills) {
        Join-Path $PackageRoot "preload\workspace"
    } else {
        Join-Path $PackageRoot "preload\workspace-basic"
    }
    if (-not (Test-Path -LiteralPath $sourceDir)) {
        Write-Host "[SKIP] No preloaded workspace files found." -ForegroundColor DarkGray
        return
    }

    $workspaceDir = Join-Path $InstallDir "workspace"
    $casesDir = Join-Path $workspaceDir "cases"
    $outputDir = Join-Path $InstallDir "output"
    New-Item -ItemType Directory -Force -Path $workspaceDir | Out-Null
    New-Item -ItemType Directory -Force -Path $casesDir | Out-Null
    New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

    if ($IncludeBusinessSkills) {
        $scenarios = @(
            "meeting-supervision-closure",
            "contract-risk-review",
            "policy-briefing",
            "hr-performance-analysis",
            "strategy-execution-review",
            "employee-behavior-analysis",
            "management-optimization-quantification"
        )
        foreach ($scenario in $scenarios) {
            New-Item -ItemType Directory -Force -Path (Join-Path $casesDir $scenario) | Out-Null
            New-Item -ItemType Directory -Force -Path (Join-Path $outputDir $scenario) | Out-Null
        }
    }
    New-Item -ItemType Directory -Force -Path (Join-Path $casesDir "综合资料源") | Out-Null

    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupDir = Join-Path $InstallDir "backup\workspace-$stamp"

    foreach ($file in Get-ChildItem -LiteralPath $sourceDir -File) {
        $target = Join-Path $workspaceDir $file.Name
        if (Test-Path -LiteralPath $target) {
            New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
            Copy-Item -LiteralPath $target -Destination (Join-Path $backupDir $file.Name) -Force
        }
        Copy-Item -LiteralPath $file.FullName -Destination $target -Force
        Write-Host "[OK] Workspace file installed: $($file.Name)" -ForegroundColor Green
    }

    if (Test-Path -LiteralPath $backupDir) {
        Write-Host "[OK] Previous workspace files backed up to: $backupDir" -ForegroundColor Green
    }
    Write-Host "[OK] Workspace case/output folders prepared." -ForegroundColor Green
}

function Initialize-DesktopWorkbench {
    param([bool]$IncludeBusinessSkills)

    $desktop = [Environment]::GetFolderPath("Desktop")
    if ([string]::IsNullOrWhiteSpace($desktop)) {
        Write-Host "[WARN] Desktop path was not found. Skipping Chinese desktop workbench creation." -ForegroundColor Yellow
        return
    }

    $workbenchRoot = Join-Path $desktop "龙虾工作台"
    $folders = if ($IncludeBusinessSkills) {
        @(
            "01-输入资料\综合资料源",
            "01-输入资料\合同资料",
            "01-输入资料\会议督办",
            "01-输入资料\政策简报",
            "01-输入资料\人力绩效",
            "01-输入资料\战略执行",
            "01-输入资料\员工行为",
            "01-输入资料\管理优化",
            "02-输出成果\会议督办",
            "02-输出成果\合同审查",
            "02-输出成果\政策简报",
            "02-输出成果\人力绩效",
            "02-输出成果\战略执行",
            "02-输出成果\员工行为",
            "02-输出成果\管理优化",
            "03-人工复核",
            "04-历史归档"
        )
    } else {
        @(
            "01-输入资料\综合资料源",
            "02-输出成果\通用成果",
            "03-人工复核",
            "04-历史归档"
        )
    }

    foreach ($folder in $folders) {
        New-Item -ItemType Directory -Force -Path (Join-Path $workbenchRoot $folder) | Out-Null
    }

    $guidePath = Join-Path $workbenchRoot "使用说明.txt"
    $guide = if ($IncludeBusinessSkills) {
@"
龙虾工作台使用说明

1. 合同资料放到：01-输入资料\合同资料
2. 其他资料优先放到：01-输入资料\综合资料源
3. 如需分类，也可以放到会议督办、政策简报、人力绩效、战略执行、员工行为、管理优化等目录。
4. 生成结果默认放到：02-输出成果
5. 输出文件优先使用 WPS 可直接打开的 docx、xlsx、pptx 或 txt。
"@
    } else {
@"
龙虾工作台使用说明

当前为基础版，不预置 7 个业务 Skill。

1. 通用资料放到：01-输入资料\综合资料源
2. 生成结果默认放到：02-输出成果\通用成果
3. 可用于文件问答、文档总结、材料起草、表格整理、操作说明等基础任务。
4. 输出文件优先使用 WPS 可直接打开的 docx、xlsx、pptx 或 txt。
5. 如需会议督办、合同风险审查、政策简报、人力绩效、战略执行、员工行为、管理优化等能力，请使用业务增强版或后续补装业务 Skill。
"@
    }
    Set-Content -LiteralPath $guidePath -Value $guide -Encoding UTF8

    Write-Host "[OK] Desktop workbench prepared: $workbenchRoot" -ForegroundColor Green
}

function Install-ToolPackage {
    param([string]$InstallDir, [string]$PackageRoot)

    $sourceDir = Join-Path $PackageRoot "tools"
    if (-not (Test-Path -LiteralPath $sourceDir)) {
        Write-Host "[SKIP] No tool package found." -ForegroundColor DarkGray
        return
    }

    $toolsDir = Join-Path $InstallDir "tools"
    New-Item -ItemType Directory -Force -Path $toolsDir | Out-Null

    foreach ($file in Get-ChildItem -LiteralPath $sourceDir -File) {
        Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $toolsDir $file.Name) -Force
        Write-Host "[OK] Tool installed: $($file.Name)" -ForegroundColor Green
    }
}

function Write-AutoStartScripts {
    param([string]$InstallDir)

    $enableScript = @"
#requires -Version 7.0

`$ErrorActionPreference = "Stop"
`$InstallDir = "$InstallDir"
`$StartupDir = [Environment]::GetFolderPath("Startup")
if ([string]::IsNullOrWhiteSpace(`$StartupDir)) { throw "Cannot resolve current user Startup folder." }
`$StartGateway = Join-Path `$InstallDir "start-gateway.cmd"
`$LogPath = Join-Path `$InstallDir "logs\gateway-autostart.log"
if (-not (Test-Path -LiteralPath `$StartGateway)) { throw "Missing start-gateway.cmd: `$StartGateway" }
if (-not (Test-Path -LiteralPath (Split-Path -Parent `$LogPath))) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent `$LogPath) | Out-Null
}
`$StartupFile = Join-Path `$StartupDir "OpenClawMeeting-Gateway.vbs"
`$Command = "cmd.exe /c call ""`$StartGateway"" >> ""`$LogPath"" 2>&1"
`$VbsCommand = `$Command.Replace("""", """""")
`$Content = "Set shell = CreateObject(""WScript.Shell"")`r`nshell.Run ""`$VbsCommand"", 0, False`r`n"
Set-Content -LiteralPath `$StartupFile -Value `$Content -Encoding ASCII
Write-Host "[OK] Current user logon auto-start enabled: `$StartupFile" -ForegroundColor Green
"@
    Set-Content -LiteralPath (Join-Path $InstallDir "enable-autostart.ps1") -Value $enableScript -Encoding UTF8

    $disableScript = @"
#requires -Version 7.0

`$ErrorActionPreference = "Stop"
`$StartupDir = [Environment]::GetFolderPath("Startup")
`$StartupFile = Join-Path `$StartupDir "OpenClawMeeting-Gateway.vbs"
if (Test-Path -LiteralPath `$StartupFile) {
    Remove-Item -LiteralPath `$StartupFile -Force
    Write-Host "[OK] Current user logon auto-start disabled: `$StartupFile" -ForegroundColor Green
} else {
    Write-Host "[OK] Auto-start entry is not present." -ForegroundColor Green
}
"@
    Set-Content -LiteralPath (Join-Path $InstallDir "disable-autostart.ps1") -Value $disableScript -Encoding UTF8
}

Write-Host ""
Write-Host "OpenClawMeeting lite installer" -ForegroundColor Cyan
Write-Host "OpenClaw version: $OpenClawVersion" -ForegroundColor Cyan
Write-Host ""

if (-not $PSBoundParameters.ContainsKey("InstallDir")) {
    $InstallDir = Read-Value -Prompt "Install directory" -Default $InstallDir
}
if ($InstallDir -match '[^\x00-\x7F]' -or $InstallDir -match '\s') {
    throw "Install directory must use an ASCII path without spaces. Recommended: D:\OpenClawMeeting"
}
if (-not $PSBoundParameters.ContainsKey("Port")) {
    $Port = [int](Read-Value -Prompt "Gateway port" -Default ([string]$Port))
}
if (-not $PSBoundParameters.ContainsKey("DeepSeekApiKey")) {
    $DeepSeekApiKey = Read-Host "DeepSeek API key (optional, press Enter to configure later)"
}
$InstallBusinessSkills = -not $SkipBusinessSkills
if (-not $PSBoundParameters.ContainsKey("SkipBusinessSkills")) {
    $InstallBusinessSkills = Read-YesNo -Prompt "Install 7 business skills and business SOUL? Enter N for basic-only mode" -Default $true
}
if ($InstallBusinessSkills) {
    Write-Host "[INFO] Delivery mode: business skills enabled." -ForegroundColor DarkCyan
} else {
    Write-Host "[INFO] Delivery mode: basic only. Business skills, business SOUL, and business cron templates will be skipped." -ForegroundColor DarkCyan
}

if ([string]::IsNullOrWhiteSpace($Token)) { $Token = [Guid]::NewGuid().ToString('N') + [Guid]::NewGuid().ToString('N') }
if ($Token -notmatch '^[A-Za-z0-9_-]{16,128}$') { throw 'Token must contain 16-128 letters, digits, underscores or hyphens.' }
if ($DeepSeekApiKey -and $DeepSeekApiKey -notmatch '^sk-[A-Za-z0-9_-]{8,256}$') { throw 'DeepSeek API key format is invalid.' }
$AccessHost = "127.0.0.1"
$ConfigDir = Join-Path $InstallDir "config"
$WorkspaceDir = Join-Path $InstallDir "workspace"
$OutputDir = Join-Path $InstallDir "output"
$LogsDir = Join-Path $InstallDir "logs"
$BackupDir = Join-Path $InstallDir "backup"
$ToolsDir = Join-Path $InstallDir "tools"

foreach ($dir in @($InstallDir, $ConfigDir, $WorkspaceDir, $OutputDir, $LogsDir, $BackupDir, $ToolsDir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
}

Write-Host "[1/10] Ensuring Node runtime..." -ForegroundColor Yellow
$node = Ensure-SystemNodeRuntime -NodeVersion $NodeVersion

Write-Host "[2/10] Installing OpenClaw runtime from npm..." -ForegroundColor Yellow
$openclawPrefix = Install-OpenClawRuntime -InstallDir $InstallDir -Node $node -OpenClawVersion $OpenClawVersion -NpmRegistry $NpmRegistry

Write-Host "[3/10] Writing OpenClaw config..." -ForegroundColor Yellow
$config = Get-Content -Raw -Encoding UTF8 (Join-Path $PackageRoot "templates\openclaw.json.template")
$jsonInstallDir = $InstallDir.Replace("\", "\\")
$config = $config.Replace("CHANGE_ME", $Token).Replace("18789", [string]$Port).Replace("INSTALL_DIR_PLACEHOLDER", $jsonInstallDir)
Set-Content -Path (Join-Path $ConfigDir "openclaw.json") -Value $config -Encoding UTF8

Write-Host "[4/10] Writing local scripts..." -ForegroundColor Yellow
$deepseekEnvLine = ""
if (-not [string]::IsNullOrWhiteSpace($DeepSeekApiKey)) {
    $deepseekEnvLine = "set `"DEEPSEEK_API_KEY=$DeepSeekApiKey`"`r`n"
}
$openclawLocal = @"
@echo off
set "OPENCLAW_ROOT=$InstallDir"
set "OPENCLAW_STATE_DIR=$InstallDir\state"
set "OPENCLAW_CONFIG_PATH=$InstallDir\config\openclaw.json"
set "OPENCLAW_WORKSPACE=$InstallDir\workspace"
set "OPENCLAW_NODE_DIR=$($node.NodeDir)"
set "OPENCLAW_NO_AUTO_UPDATE=1"
set "PATH=$($node.NodeDir);%PATH%"
$deepseekEnvLine
set "OPENCLAW_DISABLE_TALK=1"
if not exist "$InstallDir\logs\tmp" mkdir "$InstallDir\logs\tmp"
set "TEMP=$InstallDir\logs\tmp"
set "TMP=$InstallDir\logs\tmp"
"$openclawPrefix\openclaw.cmd" %*
"@
Set-Content -Path (Join-Path $InstallDir "openclaw-local.cmd") -Value $openclawLocal -Encoding ASCII

$startGateway = @"
@echo off
cd /d "$InstallDir"
call "$InstallDir\openclaw-local.cmd" gateway run
"@
Set-Content -Path (Join-Path $InstallDir "start-gateway.cmd") -Value $startGateway -Encoding ASCII

$stopGateway = @"
@echo off
cd /d "$InstallDir"
call "$InstallDir\openclaw-local.cmd" gateway stop
"@
Set-Content -Path (Join-Path $InstallDir "stop-gateway.cmd") -Value $stopGateway -Encoding ASCII

$verify = @"
#requires -Version 7.0

`$ErrorActionPreference = "Stop"
`$InstallDir = "$InstallDir"
`$Port = $Port
Write-Host "Checking OpenClawMeeting installation..." -ForegroundColor Cyan
foreach (`$path in @("$openclawPrefix\openclaw.cmd", "$($node.NodeExe)", "$InstallDir\config\openclaw.json", "$InstallDir\openclaw-local.cmd")) {
    if (-not (Test-Path -LiteralPath `$path)) { throw "Missing: `$path" }
    Write-Host "[OK] `$path"
}
& (Join-Path `$InstallDir "openclaw-local.cmd") --version
`$conn = Get-NetTCPConnection -LocalPort `$Port -State Listen -ErrorAction SilentlyContinue
if (`$conn) {
    Write-Host "[OK] Gateway listening on port `$Port" -ForegroundColor Green
} else {
    Write-Host "[WARN] Gateway is not listening yet. Start it with start-gateway.cmd" -ForegroundColor Yellow
}
Write-Host "Open browser on this computer: http://$AccessHost`:$Port/" -ForegroundColor Cyan
"@
Set-Content -Path (Join-Path $InstallDir "verify.ps1") -Value $verify -Encoding UTF8

Write-AutoStartScripts -InstallDir $InstallDir
& $Script:PwshExe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $InstallDir "enable-autostart.ps1")

Write-Host "[5/10] Installing fixed tool package..." -ForegroundColor Yellow
Install-ToolPackage -InstallDir $InstallDir -PackageRoot $PackageRoot

Write-Host "[6/10] Installing preloaded workspace soul..." -ForegroundColor Yellow
Install-PreloadedWorkspace -InstallDir $InstallDir -PackageRoot $PackageRoot -IncludeBusinessSkills $InstallBusinessSkills

Write-Host "[6.5/10] Preparing desktop workbench..." -ForegroundColor Yellow
Initialize-DesktopWorkbench -IncludeBusinessSkills $InstallBusinessSkills

if ($InstallBusinessSkills) {
    Write-Host "[7/10] Installing preloaded skills..." -ForegroundColor Yellow
    Install-PreloadedSkills -InstallDir $InstallDir -PackageRoot $PackageRoot
} else {
    Write-Host "[7/10] Skipping preloaded business skills..." -ForegroundColor Yellow
}

Write-Host "[8/10] Checking OpenClaw runtime..." -ForegroundColor Yellow
& (Join-Path $InstallDir "openclaw-local.cmd") --version
if ($LASTEXITCODE -ne 0) { throw 'OpenClaw runtime verification failed.' }

Write-Host "[9/10] Starting gateway..." -ForegroundColor Yellow
try { & (Join-Path $InstallDir "stop-gateway.cmd") | Out-Null } catch { }
Start-Process -FilePath (Join-Path $InstallDir "start-gateway.cmd") -WindowStyle Hidden
Start-Sleep -Seconds 3
& $Script:PwshExe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $InstallDir "verify.ps1")

if ($InstallBusinessSkills) {
    Write-Host "[10/10] Installing disabled automation templates..." -ForegroundColor Yellow
    Install-PreloadedCronJobs -InstallDir $InstallDir -PackageRoot $PackageRoot -Port $Port -Token $Token
} else {
    Write-Host "[10/10] Cleaning preloaded business automation templates..." -ForegroundColor Yellow
    Clear-PreloadedCronJobs -InstallDir $InstallDir -PackageRoot $PackageRoot -Port $Port -Token $Token
}

Write-Host ""
Write-Host "Installation complete." -ForegroundColor Green
Write-Host "URL: http://$AccessHost`:$Port/" -ForegroundColor Cyan
Write-Host "Gateway token is stored in config\openclaw.json (gateway.auth.token)." -ForegroundColor Cyan
Write-Host ""
