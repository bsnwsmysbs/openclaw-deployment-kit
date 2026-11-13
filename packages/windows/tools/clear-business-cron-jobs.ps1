#requires -Version 7.0

param(
    [string]$InstallDir = "D:\OpenClawMeeting",
    [int]$Port = 18789,
    [string]$Token = "123456",
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

if ($PSVersionTable.PSEdition -ne "Core" -or $PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "[ERROR] This script requires PowerShell 7 pwsh.exe." -ForegroundColor Red
    exit 1
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PackageRoot = Split-Path -Parent $ScriptDir
$jobsPath = Join-Path $PackageRoot "preload\cron-jobs.json"
$localCmd = Join-Path $InstallDir "openclaw-local.cmd"
$gatewayUrl = "ws://127.0.0.1:$Port"
$defaultPreloadedNames = @(
    "政策源每日监测",
    "政策周报生成",
    "会议督办周报",
    "合同风险月度抽检",
    "人力绩效部门级月报",
    "战略执行月度汇总",
    "员工行为合规月度提示",
    "管理优化量化月报"
)

if (-not (Test-Path -LiteralPath $localCmd)) {
    throw "openclaw-local.cmd not found: $localCmd"
}
$preloadedNames = $defaultPreloadedNames
if (Test-Path -LiteralPath $jobsPath) {
    $preloadedJobs = @(Get-Content -LiteralPath $jobsPath -Raw -Encoding UTF8 | ConvertFrom-Json)
    $templateNames = @($preloadedJobs | ForEach-Object { [string]$_.name } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($templateNames.Count -gt 0) {
        $preloadedNames = $templateNames
    }
}
if ($preloadedNames.Count -eq 0) {
    Write-Host "[OK] No preloaded business cron job names found." -ForegroundColor Green
    exit 0
}

Write-Host "[INFO] Listing cron jobs from Gateway..." -ForegroundColor DarkCyan
$raw = & $localCmd cron list --all --json --token $Token --url $gatewayUrl --timeout 30000 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "Could not list cron jobs: $raw"
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
    Write-Host "[OK] No preloaded business cron jobs found." -ForegroundColor Green
    exit 0
}

foreach ($job in $matched) {
    $jobId = if ($job.PSObject.Properties.Name -contains "id") { [string]$job.id } elseif ($job.PSObject.Properties.Name -contains "jobId") { [string]$job.jobId } else { "" }
    if ([string]::IsNullOrWhiteSpace($jobId)) {
        Write-Host "[WARN] Skipping cron job without id: $($job.name)" -ForegroundColor Yellow
        continue
    }

    if ($WhatIf) {
        Write-Host "[WHATIF] Would remove preloaded business cron job: $($job.name) ($jobId)" -ForegroundColor Yellow
        continue
    }

    $removeOutput = & $localCmd cron rm $jobId --token $Token --url $gatewayUrl --timeout 30000 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] Removed preloaded business cron job: $($job.name)" -ForegroundColor Green
    } else {
        Write-Host "[WARN] Failed to remove cron job $($job.name): $removeOutput" -ForegroundColor Yellow
    }
}

Write-Host "[DONE] Business cron cleanup completed." -ForegroundColor Cyan
