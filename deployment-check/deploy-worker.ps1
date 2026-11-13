#requires -Version 7.0
param([Parameter(Mandatory)][string]$JobRoot)
$ErrorActionPreference = 'Stop'
$stateFile = Join-Path $JobRoot 'status.json'
$logFile = Join-Path $JobRoot 'install.log'
$key = $env:OPENCLAW_DEPLOY_KEY
$env:OPENCLAW_DEPLOY_KEY = $null
function Write-State([string]$Status,[string]$Stage,[int]$Progress,[string]$Message,[string]$Code='') {
    $state = @{status=$Status;stage=$Stage;progress=$Progress;message=$Message;code=$Code;updatedAt=[DateTimeOffset]::Now.ToString('o')}
    $temp = $stateFile + '.tmp'
    $state | ConvertTo-Json | Set-Content -LiteralPath $temp -Encoding utf8
    Move-Item -LiteralPath $temp -Destination $stateFile -Force
}
try {
    $request = Get-Content -LiteralPath (Join-Path $JobRoot 'request.json') -Raw | ConvertFrom-Json
    $target = [string]$request.installDir
    # Check again in the worker, immediately before invoking the installer.
    . (Join-Path $PSScriptRoot 'deployment.ps1')
    [void](Assert-InstallTarget $target)
    Write-State 'running' 'installer' 10 'ZIP 已解压校验，正在下载依赖并安装 OpenClaw。'
    $parameters = @{InstallDir=$target;Port=[int]$request.port;DeepSeekApiKey=$key;SkipBusinessSkills=(-not $request.includeBusiness)}
    & (Join-Path $request.packageRoot 'install.ps1') @parameters *>&1 | ForEach-Object {
        $line = $_ | Out-String
        if ($key) { $line = $line.Replace($key,'[REDACTED]') }
        $line = $line -replace 'sk-[A-Za-z0-9_-]{8,}', '[REDACTED]' -replace '(?im)(Token:\s*)\S+', '$1[REDACTED]'
        $line | Add-Content -LiteralPath $logFile -Encoding utf8
    }
    Write-State 'running' 'gateway' 90 '安装脚本已结束，正在等待网关页面响应。'
    foreach ($required in @('openclaw-local.cmd','config\openclaw.json','app\openclaw\node_modules\openclaw\package.json')) {
        if (-not (Test-Path -LiteralPath (Join-Path $target $required) -PathType Leaf)) { throw 'DEPLOY_ARTIFACTS_MISSING' }
    }
    $ready = $false
    for ($attempt=0; $attempt -lt 25; $attempt++) {
        try {
            $response = Invoke-WebRequest ("http://127.0.0.1:$($request.port)/") -TimeoutSec 2 -MaximumRedirection 0
            if ($response.StatusCode -eq 200 -and $response.Content -match '(?i)openclaw') { $ready=$true; break }
        } catch {}
        Start-Sleep -Seconds 1
    }
    if (-not $ready) { throw 'DEPLOY_GATEWAY_NOT_READY' }
    Write-State 'succeeded' 'complete' 100 '程序已安装，网关页面可以访问。请运行全面自检，并完成实际对话和文件导出验收。'
} catch {
    $code = [string]$_.Exception.Message
    $detail = ($_ | Out-String)
    if ($key) { $detail = $detail.Replace($key, '[REDACTED]') }
    $detail = $detail -replace 'sk-[A-Za-z0-9_-]{8,}', '[REDACTED]' -replace '(?im)(Token:\s*)\S+', '$1[REDACTED]'
    $detail | Add-Content -LiteralPath $logFile -Encoding utf8
    if ($code -notmatch '^DEPLOY_[A-Z_]+$') { $code = 'DEPLOY_INSTALL_FAILED' }
    Write-State 'failed' 'installer' 100 '部署未完成。请查看下方日志，处理失败项后重试；已写入的目录会保留，避免丢失排错信息。' $code
} finally { $key = $null }
