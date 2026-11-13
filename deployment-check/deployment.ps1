# Local ZIP validation and deployment orchestration; loaded by server.ps1.
Add-Type -AssemblyName System.IO.Compression
$script:packageSource = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\packages\windows'))
$script:runtimeRoot = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'OpenClawDeploymentKit'
$script:uploads = @{}
$script:deployment = $null

function Assert-InstallTarget([string]$Directory) {
    # The delivery script embeds this path in CMD and PowerShell scripts. Restrict it to safe literal characters.
    if ($Directory -notmatch '^[A-Za-z]:\\[A-Za-z0-9_-]+(?:\\[A-Za-z0-9_-]+)*$') { throw 'DEPLOY_PATH_INVALID' }
    $target = [IO.Path]::GetFullPath($Directory).TrimEnd('\')
    $drive = [IO.Path]::GetPathRoot($target)
    if (-not (Test-Path -LiteralPath $drive -PathType Container)) { throw 'DEPLOY_DRIVE_MISSING' }
    $protected = @($env:WINDIR, $env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:ProgramData, $env:USERPROFILE, (Join-Path $drive 'Users'), (Join-Path $drive 'Windows'), (Split-Path $PSScriptRoot -Parent))
    foreach ($entry in $protected) {
        if (-not $entry) { continue }
        $protectedPath = [IO.Path]::GetFullPath($entry).TrimEnd('\')
        if ($target.Equals($protectedPath, [StringComparison]::OrdinalIgnoreCase) -or $target.StartsWith($protectedPath + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'DEPLOY_PATH_PROTECTED' }
    }
    # Refuse symlinks/junctions at any existing ancestor.
    $ancestor = $target
    while ($ancestor -and $ancestor.Length -gt 3) {
        if (Test-Path -LiteralPath $ancestor) {
            $item = Get-Item -LiteralPath $ancestor -Force
            if (-not $item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'DEPLOY_PATH_PROTECTED' }
        }
        $ancestor = Split-Path $ancestor -Parent
    }
    if (Test-Path -LiteralPath $target) {
        if (@(Get-ChildItem -LiteralPath $target -Force).Count) { throw 'DEPLOY_TARGET_NOT_EMPTY' }
    }
    return $target
}

function Get-ZipPackage([string]$ZipPath, [string]$ExtractionRoot = '') {
    $hash = (Get-FileHash -LiteralPath $ZipPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $legacyCatalog = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'config\trusted-packages.json') -Raw | ConvertFrom-Json
    $legacy = @($legacyCatalog.legacyPackages | Where-Object sha256 -eq $hash)
    $archive = [IO.Compression.ZipFile]::OpenRead($ZipPath)
    try {
        if ($archive.Entries.Count -gt 1000) { throw 'ZIP_TOO_LARGE' }
        $names = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        $files = @{}
        $expandedSize = 0L
        foreach ($entry in $archive.Entries) {
            $name = $entry.FullName.Replace('\','/')
            if (-not $name -or $name.StartsWith('/') -or $name -match '[:\x00-\x1F<>"|?*]' -or @($name.Split('/') | Where-Object { $_ -in @('.', '..') -or $_ -match '[. ]$' -or $_ -match '^(?i:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)' }).Count) { throw 'ZIP_UNSAFE_PATH' }
            if (-not $names.Add($name.TrimEnd('/'))) { throw 'ZIP_DUPLICATE_ENTRY' }
            $unixType = ($entry.ExternalAttributes -shr 16) -band 0xF000
            if ($unixType -eq 0xA000) { throw 'ZIP_UNSAFE_PATH' }
            $expandedSize += $entry.Length
            if ($expandedSize -gt 64MB -or $entry.Length -gt 16MB) { throw 'ZIP_TOO_LARGE' }
            if (-not $name.EndsWith('/')) { $files[$name] = $entry }
        }
        $manifestNames = @($files.Keys | Where-Object { $_ -eq 'manifest.json' -or $_ -match '^[^/]+/manifest\.json$' })
        if ($manifestNames.Count -ne 1) { throw 'ZIP_PACKAGE_INVALID' }
        $prefix = $manifestNames[0].Substring(0, $manifestNames[0].Length - 'manifest.json'.Length)
        foreach ($name in $files.Keys) { if (-not $name.StartsWith($prefix, [StringComparison]::Ordinal)) { throw 'ZIP_PACKAGE_INVALID' } }
        foreach ($required in @('install.ps1','install.cmd','manifest.json','templates/openclaw.json.template','preload/workspace/AGENTS.md')) {
            if (-not $files.ContainsKey($prefix + $required)) { throw 'ZIP_PACKAGE_INVALID' }
        }
        $manifestReader = [IO.StreamReader]::new($files[$prefix + 'manifest.json'].Open())
        try { $manifest = $manifestReader.ReadToEnd() | ConvertFrom-Json } finally { $manifestReader.Dispose() }
        if ($manifest.name -ne 'OpenClawMeeting-Setup-Lite' -or $manifest.openclawVersion -ne '2026.6.1') { throw 'ZIP_PACKAGE_INVALID' }
        if (-not $legacy.Count) {
            # A ZIP from this repository must match every source file, including scripts and preload assets.
            $sourceFiles = @(Get-ChildItem -LiteralPath $script:packageSource -Recurse -File)
            if ($sourceFiles.Count -ne $files.Count) { throw 'ZIP_UNTRUSTED' }
            foreach ($source in $sourceFiles) {
                $relative = [IO.Path]::GetRelativePath($script:packageSource, $source.FullName).Replace('\','/')
                if (-not $files.ContainsKey($prefix + $relative)) { throw 'ZIP_UNTRUSTED' }
                $stream = $files[$prefix + $relative].Open()
                $sha = [Security.Cryptography.SHA256]::Create()
                try { $entryHash = [Convert]::ToHexString($sha.ComputeHash($stream)) } finally { $stream.Dispose(); $sha.Dispose() }
                if ($entryHash -ne (Get-FileHash -LiteralPath $source.FullName -Algorithm SHA256).Hash) { throw 'ZIP_UNTRUSTED' }
            }
        }
        if ($ExtractionRoot) {
            New-Item -ItemType Directory -Path $ExtractionRoot -Force | Out-Null
            $destinationPrefix = [IO.Path]::GetFullPath($ExtractionRoot).TrimEnd('\') + '\'
            foreach ($name in $files.Keys) {
                $relative = $name.Substring($prefix.Length).Replace('/','\')
                $destination = [IO.Path]::GetFullPath((Join-Path $ExtractionRoot $relative))
                if (-not $destination.StartsWith($destinationPrefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'ZIP_UNSAFE_PATH' }
                New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force | Out-Null
                [IO.Compression.ZipFileExtensions]::ExtractToFile($files[$name], $destination, $false)
            }
        }
        return @{ name = [string]$manifest.name; version = [string]$manifest.version; openclawVersion = [string]$manifest.openclawVersion; sha256 = $hash; fileCount = $files.Count; legacy = [bool]$legacy.Count }
    } finally { $archive.Dispose() }
}

function Save-Package([byte[]]$Bytes) {
    if ($Bytes.Length -gt 16MB -or $Bytes.Length -lt 22) { throw 'ZIP_TOO_LARGE' }
    $id = [Guid]::NewGuid().ToString('N')
    $folder = Join-Path $script:runtimeRoot ('uploads\' + $id)
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
    $zipPath = Join-Path $folder 'package.zip'
    [IO.File]::WriteAllBytes($zipPath, $Bytes)
    try {
        $package = Get-ZipPackage $zipPath
        $script:uploads[$id] = @{ path = $zipPath; package = $package }
        return @{ packageId = $id; package = $package }
    } catch {
        # Only this upload's generated file is removed.
        Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue
        throw
    }
}

function Get-DeploymentStatus {
    if (-not $script:deployment) { return @{ status = 'idle' } }
    $job = $script:deployment
    $state = $null
    if (Test-Path -LiteralPath $job.statePath) {
        try { $state = Get-Content -LiteralPath $job.statePath -Raw | ConvertFrom-Json -AsHashtable } catch {}
    }
    if (-not $state) { $state = @{ status='running'; stage='starting'; progress=5; message='正在启动安装进程。' } }
    if ($state.status -eq 'running' -and $job.process.HasExited) {
        $state = @{status='failed';stage='installer';progress=100;message='安装进程提前退出，请查看安装日志。';code='DEPLOY_PROCESS_EXITED'}
    }
    if ($state.status -eq 'running' -and ([DateTime]::UtcNow - $job.startedAt).TotalMinutes -gt 30) {
        try { $job.process.Kill($true) } catch {}
        $state = @{status='failed';stage='installer';progress=100;message='安装超过 30 分钟，已停止本次安装进程。请检查网络后重新部署到新目录。';code='DEPLOY_TIMEOUT'}
        $state | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $job.statePath -Encoding utf8
    }
    $state.jobId = $job.id
    $state.installDir = $job.installDir
    $state.log = ''
    if (Test-Path -LiteralPath $job.logPath) {
        $text = (Get-Content -LiteralPath $job.logPath -Tail 65 -ErrorAction SilentlyContinue) -join "`n"
        $text = $text -replace 'sk-[A-Za-z0-9_-]{8,}', '[REDACTED]' -replace '(?im)(Token:\s*)\S+', '$1[REDACTED]'
        $state.log = $text
        if ($state.status -eq 'running' -and $state.stage -eq 'installer') {
            $steps = [regex]::Matches($text, '\[(\d+)(?:\.\d+)?/10\]')
            if ($steps.Count) { $state.progress = [math]::Min(85, 10 + [int]$steps[$steps.Count-1].Groups[1].Value * 7) }
        }
    }
    return $state
}

function Start-Deployment($Body) {
    $current = Get-DeploymentStatus
    if ($current.status -eq 'running') { throw 'DEPLOY_BUSY' }
    if (-not $script:uploads.ContainsKey([string]$Body.packageId)) { throw 'PACKAGE_NOT_FOUND' }
    $target = Assert-InstallTarget ([string]$Body.installDir)
    $key = [string]$Body.apiKey
    if ($key -and $key -notmatch '^sk-[A-Za-z0-9_-]{8,256}$') { throw 'MODEL_KEY_FORMAT' }
    $gatewayPort = 0
    if (-not [int]::TryParse([string]$Body.port, [ref]$gatewayPort) -or $gatewayPort -lt 1024 -or $gatewayPort -gt 65535 -or $gatewayPort -eq $Port) { throw 'DEPLOY_PORT_INVALID' }
    if (Get-NetTCPConnection -LocalPort $gatewayPort -State Listen -ErrorAction SilentlyContinue) { throw 'DEPLOY_PORT_BUSY' }
    $nodeResult = Check 'node' $target
    if ($nodeResult.status -ne 'pass') { throw $nodeResult.code }
    $npmResult = Check 'npm' $target
    if ($npmResult.status -ne 'pass') { throw $npmResult.code }
    $id = [Guid]::NewGuid().ToString('N')
    $jobRoot = Join-Path $script:runtimeRoot ('jobs\' + $id)
    New-Item -ItemType Directory -Path $jobRoot -Force | Out-Null
    $extracted = Join-Path $jobRoot 'package'
    $package = Get-ZipPackage $script:uploads[[string]$Body.packageId].path $extracted
    $request = @{ installDir=$target; port=$gatewayPort; includeBusiness=($Body.includeBusiness -ne $false); packageRoot=$extracted }
    $requestPath = Join-Path $jobRoot 'request.json'
    $request | ConvertTo-Json | Set-Content -LiteralPath $requestPath -Encoding utf8
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = Join-Path $PSHOME 'pwsh.exe'
    foreach ($arg in @('-NoLogo','-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',(Join-Path $PSScriptRoot 'deploy-worker.ps1'),'-JobRoot',$jobRoot)) { $info.ArgumentList.Add($arg) }
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    # Credentials are inherited privately, not passed in command-line arguments or job JSON/logs.
    $info.Environment['OPENCLAW_DEPLOY_KEY'] = $key
    $node = Find-Node
    $info.Environment['PATH'] = (Split-Path $node -Parent) + ';' + $env:PATH
    $process = [Diagnostics.Process]::Start($info)
    $script:deployment = @{id=$id;process=$process;installDir=$target;statePath=(Join-Path $jobRoot 'status.json');logPath=(Join-Path $jobRoot 'install.log');startedAt=[DateTime]::UtcNow}
    return (Get-DeploymentStatus)
}
