# Fixed Node.js LTS installation action. Loaded by the loopback helper only.
$script:nodeSetup = $null

function Find-Winget {
    $command = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    return $null
}

function Start-NodeInstallerProcess([string]$Executable, [string]$OutFile, [string]$ErrorFile) {
    $arguments = @('install','--id','OpenJS.NodeJS.LTS','--exact','--source','winget','--accept-package-agreements','--accept-source-agreements','--silent','--disable-interactivity','--force')
    return Start-Process -FilePath $Executable -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $OutFile -RedirectStandardError $ErrorFile
}

function Get-NodeSetupStatus {
    if (-not $script:nodeSetup) { return @{status='idle'} }
    $job = $script:nodeSetup
    if ($job.status -eq 'running') {
        if (-not $job.process.HasExited -and ([DateTime]::UtcNow - $job.startedAt).TotalMinutes -gt 15) {
            try { $job.process.Kill($true); [void]$job.process.WaitForExit(3000) } catch {}
            $job.status='failed'; $job.code='NODE_SETUP_TIMEOUT'; $job.message='Node.js 安装超过 15 分钟，已停止安装进程。请查看日志后重试。'
        } elseif ($job.process.HasExited) {
            $exitCode = $job.process.ExitCode
            $job.exitCode = $exitCode
            if ($exitCode -in @(0,3010)) {
                Refresh-NodePath
                try {
                    $node = Check 'node' 'C:\OpenClawMeeting'
                    $npm = Check 'npm' 'C:\OpenClawMeeting'
                    if ($node.status -ne 'pass' -or $npm.status -ne 'pass') { throw 'Node/npm verification failed' }
                    $job.status='succeeded'; $job.code='NODE_SETUP_OK'; $job.message="Node.js $($node.detail) 与 npm $($npm.detail) 已验证，可继续部署。"
                } catch {
                    $job.status='failed'; $job.code='NODE_SETUP_VERIFY_FAILED'; $job.message='安装器已结束，但 Node.js 版本或 npm 仍未通过验证。请检查 PATH，必要时重启电脑后重试。'
                }
            } else {
                $job.status='failed'; $job.code='NODE_SETUP_FAILED'; $job.message="winget 安装未成功（退出码 $exitCode）。请检查网络和权限；若曾出现系统授权窗口，请允许安装。"
            }
        }
        if ($job.status -ne 'running' -and $job.mutex) {
            $job.mutex.ReleaseMutex(); $job.mutex.Dispose(); $job.mutex=$null
        }
    }
    $log = @()
    foreach ($path in @($job.outFile,$job.errorFile)) {
        if (Test-Path -LiteralPath $path) { $log += Get-Content -LiteralPath $path -Tail 35 -ErrorAction SilentlyContinue }
    }
    return @{status=$job.status;code=$job.code;message=$job.message;jobId=$job.id;exitCode=$job.exitCode;log=($log -join "`n");progress=$(if($job.status -eq 'running'){35}else{100})}
}

function Start-NodeSetup {
    $current = Get-NodeSetupStatus
    if ($current.status -eq 'running') { return $current }
    if ((Get-DeploymentStatus).status -eq 'running') { throw 'NODE_SETUP_DEPLOY_BUSY' }
    try {
        $node = Check 'node' 'C:\OpenClawMeeting'
        $npm = Check 'npm' 'C:\OpenClawMeeting'
        if ($node.status -eq 'pass' -and $npm.status -eq 'pass') {
            return @{status='succeeded';code='NODE_SETUP_OK';message='Node.js 与 npm 已符合要求，无需安装。';progress=100;log=''}
        }
    } catch {}
    $winget = Find-Winget
    if (-not $winget) { throw 'NODE_WINGET_MISSING' }
    $mutex = [Threading.Mutex]::new($false, 'Local\OpenClawDeploymentKit.NodeSetup')
    $acquired = $false
    try {
        try { $acquired = $mutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $acquired=$true }
        if (-not $acquired) { throw 'NODE_SETUP_BUSY' }
        $id = [Guid]::NewGuid().ToString('N')
        $jobRoot = Join-Path $script:runtimeRoot ('node-setup\' + $id)
        New-Item -ItemType Directory -Path $jobRoot -Force | Out-Null
        $outFile = Join-Path $jobRoot 'winget.log'
        $errorFile = Join-Path $jobRoot 'winget-error.log'
        $process = Start-NodeInstallerProcess $winget $outFile $errorFile
        $script:nodeSetup = @{id=$id;status='running';code='NODE_SETUP_RUNNING';message='检测到 Node.js/npm 缺失、过旧或无法运行，正在通过 winget 安装 Node.js LTS。若系统弹出授权窗口，请允许安装。';process=$process;startedAt=[DateTime]::UtcNow;outFile=$outFile;errorFile=$errorFile;mutex=$mutex;exitCode=$null}
    } catch {
        if ($acquired) { $mutex.ReleaseMutex() }
        $mutex.Dispose()
        throw
    }
    return Get-NodeSetupStatus
}
