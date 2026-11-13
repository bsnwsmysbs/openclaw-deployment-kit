#requires -Version 7.0

param(
    [string]$InstallDir = "D:\OpenClawMeeting",
    [switch]$Basic
)

$ErrorActionPreference = "Stop"
if ($PSVersionTable.PSEdition -ne "Core" -or $PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "[ERROR] This tool requires PowerShell 7 pwsh.exe." -ForegroundColor Red
    Write-Host "[ERROR] Windows PowerShell 5.1 powershell.exe is not supported." -ForegroundColor Red
    Write-Host "[INFO]  Run with: pwsh -NoProfile -ExecutionPolicy Bypass -File .\tools\mount-workspace.ps1" -ForegroundColor Yellow
    exit 1
}
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PackageRoot = Split-Path -Parent $ScriptDir
$SourceDir = if ($Basic) {
    Join-Path $PackageRoot "preload\workspace-basic"
} else {
    Join-Path $PackageRoot "preload\workspace"
}
$WorkspaceDir = Join-Path $InstallDir "workspace"
$CasesDir = Join-Path $WorkspaceDir "cases"
$OutputDir = Join-Path $InstallDir "output"
$ToolsDir = Join-Path $InstallDir "tools"

if (-not (Test-Path -LiteralPath $SourceDir)) {
    throw "Preloaded workspace folder not found: $SourceDir"
}

New-Item -ItemType Directory -Force -Path $WorkspaceDir | Out-Null
New-Item -ItemType Directory -Force -Path $CasesDir | Out-Null
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
New-Item -ItemType Directory -Force -Path $ToolsDir | Out-Null

if (-not $Basic) {
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
        New-Item -ItemType Directory -Force -Path (Join-Path $CasesDir $scenario) | Out-Null
        New-Item -ItemType Directory -Force -Path (Join-Path $OutputDir $scenario) | Out-Null
    }
} else {
    New-Item -ItemType Directory -Force -Path (Join-Path $OutputDir "通用成果") | Out-Null
}
New-Item -ItemType Directory -Force -Path (Join-Path $CasesDir "综合资料源") | Out-Null

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupDir = Join-Path $InstallDir "backup\workspace-$stamp"
$copied = @()

foreach ($file in Get-ChildItem -LiteralPath $SourceDir -File) {
    $target = Join-Path $WorkspaceDir $file.Name
    if (Test-Path -LiteralPath $target) {
        New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
        Copy-Item -LiteralPath $target -Destination (Join-Path $backupDir $file.Name) -Force
    }
    Copy-Item -LiteralPath $file.FullName -Destination $target -Force
    $copied += $file.Name
}

if ($Basic) {
    Write-Host "[OK] Basic workspace soul mounted to: $WorkspaceDir" -ForegroundColor Green
} else {
    Write-Host "[OK] Business workspace soul mounted to: $WorkspaceDir" -ForegroundColor Green
}
if (Test-Path -LiteralPath $backupDir) {
    Write-Host "[OK] Previous workspace files backed up to: $backupDir" -ForegroundColor Green
}
Write-Host "[OK] Workspace case/output folders prepared." -ForegroundColor Green
Write-Host ("[OK] Files: " + ($copied -join ", ")) -ForegroundColor Green

$toolFiles = @("export-docx.ps1", "README-DOCX工具.md", "mount-workspace.ps1")
$toolCopied = @()
foreach ($toolFile in $toolFiles) {
    $sourceTool = Join-Path $ScriptDir $toolFile
    if (Test-Path -LiteralPath $sourceTool) {
        Copy-Item -LiteralPath $sourceTool -Destination (Join-Path $ToolsDir $toolFile) -Force
        $toolCopied += $toolFile
    }
}
if ($toolCopied.Count -gt 0) {
    Write-Host ("[OK] Tools mounted to: $ToolsDir -> " + ($toolCopied -join ", ")) -ForegroundColor Green
}
