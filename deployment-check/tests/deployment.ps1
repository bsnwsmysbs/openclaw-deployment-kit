#requires -Version 7.0
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$sandbox = Join-Path ([IO.Path]::GetPathRoot($repo)) ('OpenClawKitTest-' + [Guid]::NewGuid().ToString('N'))
$helper = $null
$gateway = $null
$count = 0
$runtimeItems = [Collections.Generic.List[string]]::new()
function Assert-Test([bool]$Value, [string]$Name) {
    if (-not $Value) { throw "FAILED: $Name" }
    $script:count++
    Write-Host "PASS: $Name"
}
function Free-Port {
    $socket = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,0)
    $socket.Start(); $portNumber=$socket.LocalEndpoint.Port; $socket.Stop()
    return $portNumber
}
try {
    # Copy the application and supply a minimal, explicitly disposable source package.
    $testRepo = Join-Path $sandbox 'repo'
    New-Item -ItemType Directory -Path $testRepo -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $repo 'deployment-check') -Destination $testRepo -Recurse
    $packageRoot = Join-Path $testRepo 'packages\windows'
    foreach ($folder in @('templates','preload\workspace')) { New-Item -ItemType Directory -Path (Join-Path $packageRoot $folder) -Force | Out-Null }
    @{name='OpenClawMeeting-Setup-Lite';version='test';openclawVersion='2026.6.1'} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $packageRoot 'manifest.json') -Encoding utf8
    '{}' | Set-Content -LiteralPath (Join-Path $packageRoot 'templates\openclaw.json.template')
    'fixture' | Set-Content -LiteralPath (Join-Path $packageRoot 'preload\workspace\AGENTS.md')
    '@echo off' | Set-Content -LiteralPath (Join-Path $packageRoot 'install.cmd')
    @'
param([string]$InstallDir,[int]$Port,[string]$DeepSeekApiKey,[switch]$SkipBusinessSkills)
if (-not $PSBoundParameters.ContainsKey('SkipBusinessSkills') -or -not $PSBoundParameters.ContainsKey('DeepSeekApiKey')) { throw 'Parameters were not explicitly bound' }
Start-Sleep -Seconds 2
if ($InstallDir.EndsWith('failure')) { throw 'Intentional test failure' }
foreach ($folder in @('config','app\openclaw\node_modules\openclaw')) { New-Item -ItemType Directory -Path (Join-Path $InstallDir $folder) -Force | Out-Null }
"@echo off" | Set-Content -LiteralPath (Join-Path $InstallDir 'openclaw-local.cmd')
'{}' | Set-Content -LiteralPath (Join-Path $InstallDir 'config\openclaw.json')
'{}' | Set-Content -LiteralPath (Join-Path $InstallDir 'app\openclaw\node_modules\openclaw\package.json')
Write-Output ('test secret: ' + $DeepSeekApiKey)
Write-Output '[10/10] Test fixture completed'
'@ | Set-Content -LiteralPath (Join-Path $packageRoot 'install.ps1') -Encoding utf8
    $zip = Join-Path $sandbox 'package.zip'
    [IO.Compression.ZipFile]::CreateFromDirectory($packageRoot,$zip,[IO.Compression.CompressionLevel]::Optimal,$true)
    $helperPort = Free-Port
    $gatewayPort = Free-Port
    $url = "http://127.0.0.1:$helperPort"
    # Windows Known Folders may ignore LOCALAPPDATA; track generated IDs for exact cleanup.
    $info=[Diagnostics.ProcessStartInfo]::new()
    $info.FileName=Join-Path $PSHOME 'pwsh.exe'
    $info.UseShellExecute=$false; $info.CreateNoWindow=$true
    $info.Environment['LOCALAPPDATA']=Join-Path $sandbox 'local'
    foreach($arg in @('-NoLogo','-NoProfile','-File',(Join-Path $testRepo 'deployment-check\server.ps1'),'-Port', $helperPort,'-NoBrowser')) { $info.ArgumentList.Add([string]$arg) }
    $helper=[Diagnostics.Process]::Start($info)
    $page=$null
    for($i=0;$i -lt 40;$i++){try{$page=Invoke-WebRequest "$url/" -TimeoutSec 2;break}catch{Start-Sleep -Milliseconds 100}}
    Assert-Test ($null -ne $page) 'Isolated helper starts'
    $token=[regex]::Match($page.Content,'name="check-session" content="([a-f0-9]+)"').Groups[1].Value
    function Api([string]$Path, $Body) {
        return Invoke-RestMethod ($url+$Path) -Method Post -Headers @{'X-Check-Token'=$token} -ContentType 'application/json' -Body ($Body | ConvertTo-Json -Compress) -TimeoutSec 25
    }
    function Upload([string]$Path) {
        return Invoke-RestMethod "$url/api/packages" -Method Post -Headers @{'X-Check-Token'=$token} -ContentType 'application/zip' -InFile $Path -TimeoutSec 25
    }
    function Error-Code([string]$Path,$Body) {
        $response=Invoke-WebRequest ($url+$Path) -Method Post -Headers @{'X-Check-Token'=$token} -ContentType 'application/json' -Body ($Body | ConvertTo-Json -Compress) -SkipHttpErrorCheck
        return ($response.Content | ConvertFrom-Json).error
    }
    $missingManifest = Join-Path $packageRoot 'manifest.json'
    Move-Item -LiteralPath $missingManifest -Destination ($missingManifest + '.held')
    try {
        Assert-Test ((Error-Code '/api/packages/bundled' @{}) -eq 'PACKAGE_SOURCE_MISSING') 'Incomplete repository reports bundled package missing'
    } finally { Move-Item -LiteralPath ($missingManifest + '.held') -Destination $missingManifest }
    $bundled = Api '/api/packages/bundled' @{}
    $runtimeItems.Add(('uploads\' + $bundled.packageId))
    Assert-Test ($bundled.source -eq 'bundled' -and $bundled.package.version -eq 'test' -and $bundled.package.fileCount -eq 5) 'Repository Lite package is ready without any upload'
    $again = Api '/api/packages/bundled' @{}
    Assert-Test ($again.packageId -eq $bundled.packageId) 'Repeated page load reuses verified bundled snapshot'
    $upload = Upload $zip
    $runtimeItems.Add(('uploads\' + $upload.packageId))
    Assert-Test ($upload.package.fileCount -eq 5 -and $upload.package.version -eq 'test') 'Binary ZIP upload and per-file trust verification'
    # Mutated installer must not run even with a valid manifest.
    'throw "unexpected"' | Add-Content -LiteralPath (Join-Path $packageRoot 'install.ps1')
    $untrusted=Invoke-WebRequest "$url/api/packages" -Method Post -Headers @{'X-Check-Token'=$token} -ContentType 'application/zip' -InFile $zip -SkipHttpErrorCheck
    Assert-Test (($untrusted.Content | ConvertFrom-Json).error -eq 'ZIP_UNTRUSTED') 'Changed source rejects old unregistered ZIP'
    Assert-Test ((Error-Code '/api/packages/bundled' @{}) -eq 'ZIP_UNTRUSTED') 'Changed repository source invalidates bundled snapshot'
    # Restore exact fixture source by extracting the already generated archive to another folder then copying one file.
    $restore=Join-Path $sandbox 'restore'
    [IO.Compression.ZipFile]::ExtractToDirectory($zip,$restore)
    Copy-Item -LiteralPath (Join-Path $restore 'windows\install.ps1') -Destination (Join-Path $packageRoot 'install.ps1') -Force
    $unsafe=Join-Path $sandbox 'unsafe.zip'
    $archive=[IO.Compression.ZipFile]::Open($unsafe,[IO.Compression.ZipArchiveMode]::Create)
    try { $entry=$archive.CreateEntry('../escape.ps1');$writer=[IO.StreamWriter]::new($entry.Open());$writer.Write('noop');$writer.Dispose() } finally { $archive.Dispose() }
    $bad=Invoke-WebRequest "$url/api/packages" -Method Post -Headers @{'X-Check-Token'=$token} -ContentType 'application/zip' -InFile $unsafe -SkipHttpErrorCheck
    Assert-Test (($bad.Content | ConvertFrom-Json).error -eq 'ZIP_UNSAFE_PATH') 'ZIP traversal is rejected before extraction'
    $target=Join-Path $sandbox 'success'
    $body=@{packageId=$bundled.packageId;installDir=$target;port=$gatewayPort;apiKey='sk-TEST_SECRET_NOT_REAL_12345';includeBusiness=$true}
    Assert-Test ((Error-Code '/api/deploy' (@{packageId=$upload.packageId;installDir=$env:WINDIR;port=$gatewayPort})) -eq 'DEPLOY_PATH_PROTECTED') 'System directory cannot be an installation target'
    Assert-Test ((Error-Code '/api/deploy' (@{packageId=$upload.packageId;installDir=$sandbox;port=$gatewayPort})) -eq 'DEPLOY_TARGET_NOT_EMPTY') 'Existing nonempty target is protected'
    $started=Api '/api/deploy' $body
    $runtimeItems.Add(('jobs\' + $started.jobId))
    Assert-Test ($started.status -eq 'running') 'Bundled source extracts and launches a separate installation worker'
    Assert-Test ((Test-Path -LiteralPath (Join-Path $sandbox 'local\OpenClawDeploymentKit\jobs')) -or (Test-Path -LiteralPath (Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'OpenClawDeploymentKit\jobs'))) 'Job directory exists'
    Assert-Test ((Error-Code '/api/deploy' $body) -eq 'DEPLOY_BUSY') 'Concurrent deployment is rejected'
    # Worker is already running. Now provide a harmless loopback OpenClaw-like page.
    $gatewayScript=Join-Path $sandbox 'gateway.ps1'
    @'
param([int]$Port)
$l=[Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,$Port);$l.Start()
try { while($true){$c=$l.AcceptTcpClient();try{$s=$c.GetStream();$r=[IO.StreamReader]::new($s);while($r.ReadLine()){};$b=[Text.Encoding]::ASCII.GetBytes('OpenClaw test fixture');$h=[Text.Encoding]::ASCII.GetBytes("HTTP/1.1 200 OK`r`nContent-Type: text/html; charset=utf-8`r`nContent-Length: $($b.Length)`r`nConnection: close`r`n`r`n");$s.Write($h);$s.Write($b)}finally{$c.Close()}} }finally{$l.Stop()}
'@ | Set-Content -LiteralPath $gatewayScript -Encoding utf8
    $gateway=Start-Process (Join-Path $PSHOME 'pwsh.exe') -ArgumentList @('-NoProfile','-File', $gatewayScript,'-Port',$gatewayPort) -WindowStyle Hidden -PassThru
    $state=$null
    for($i=0;$i -lt 150;$i++){ $state=Api '/api/deploy/status' @{};if($state.status -ne 'running'){break};Start-Sleep -Milliseconds 300 }
    if ($state.status -ne 'succeeded') { Write-Host ($state | ConvertTo-Json -Compress) }
    Assert-Test ($state.status -eq 'succeeded') 'Worker verifies installation artifacts and Gateway before success'
    Assert-Test ($state.log -notmatch 'TEST_SECRET_NOT_REAL' -and $state.log -match '\[REDACTED\]') 'API Key is redacted from deployment log'
    $configPath=Join-Path $target 'config\openclaw.json'
    $testConfig=@{gateway=@{bind='loopback';port=$gatewayPort;auth=@{token='fixture-only'}};agents=@{defaults=@{model=@{primary='deepseek/deepseek-chat'}}};models=@{providers=@{deepseek=@{baseUrl='https://api.deepseek.com'}}}}
    $testConfig | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $configPath
    $access=Api '/api/gateway/access' @{installDir=$target}
    Assert-Test ($access.token -eq 'fixture-only' -and $access.url -eq "http://127.0.0.1:$gatewayPort/#token=fixture-only") 'Dedicated gateway access reads actual token and configured port'
    Assert-Test (($access | ConvertTo-Json -Depth 5) -notmatch 'providers|apiKey|deepseek') 'Gateway access returns no model credentials or full configuration'
    $foreign=Invoke-WebRequest "$url/api/gateway/access" -Method Post -Headers @{'X-Check-Token'=$token;Origin='https://example.com'} -ContentType 'application/json' -Body (@{installDir=$target}|ConvertTo-Json) -SkipHttpErrorCheck
    Assert-Test ($foreign.StatusCode -eq 403) 'Gateway credentials reject foreign Origin even with session token'
    $response=Invoke-WebRequest "$url/api/gateway/access" -Method Post -Headers @{'X-Check-Token'=$token} -ContentType 'application/json' -Body (@{installDir=$target}|ConvertTo-Json)
    Assert-Test (($response.Headers['Cache-Control'] -join '') -eq 'no-store') 'Gateway credential response cannot be cached'
    Assert-Test ((Error-Code '/api/gateway/access' @{installDir=$env:WINDIR}) -eq 'GATEWAY_ACCESS_PATH_INVALID') 'Gateway access refuses protected directories'
    $testConfig.gateway.bind='lan'
    $testConfig | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $configPath
    Assert-Test ((Error-Code '/api/gateway/access' @{installDir=$target}) -eq 'GATEWAY_ACCESS_CONFIG_INVALID') 'Gateway access refuses non-loopback configuration'
    $testConfig.gateway.bind='loopback';$testConfig.gateway.port=Free-Port
    $testConfig.gateway.auth.token='fixture&value/#?'
    $testConfig | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $configPath
    $access=Api '/api/gateway/access' @{installDir=$target}
    Assert-Test ($access.url.EndsWith('#token=fixture%26value%2F%23%3F')) 'Gateway token is encoded inside URL fragment'
    Assert-Test ((Error-Code '/api/gateway/open' @{installDir=$target}) -eq 'GATEWAY_ACCESS_OFFLINE') 'Offline Gateway never launches browser or claims success'
    $testConfig.gateway.auth.token=''
    $testConfig | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $configPath
    Assert-Test ((Error-Code '/api/gateway/access' @{installDir=$target}) -eq 'GATEWAY_ACCESS_TOKEN_MISSING') 'Missing token is reported without generating or changing it'
    $testConfig.gateway.port=$gatewayPort;$testConfig.gateway.auth.token='fixture-only'
    $testConfig | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $configPath
    $keyBody=@{installDir=$target;apiKey='sk-FAKE_KEY_FOR_TEST_12345'}
    $saved=Api '/api/model/key' $keyBody
    $wrapperPath=Join-Path $target 'openclaw-local.cmd'
    Assert-Test ($saved.status -eq 'saved' -and (Get-Content -LiteralPath $wrapperPath -Raw) -match 'sk-FAKE_KEY_FOR_TEST_12345') 'Post-install key is saved to existing startup configuration'
    Assert-Test (($saved | ConvertTo-Json -Depth 5) -notmatch 'sk-FAKE_KEY' -and $saved.restartRequired) 'Key response contains no credential and requires gateway restart'
    $keyBody.apiKey='sk-FAKE_REPLACEMENT_KEY_12345'
    Api '/api/model/key' $keyBody | Out-Null
    $wrapperContent=Get-Content -LiteralPath $wrapperPath -Raw
    Assert-Test (([regex]::Matches($wrapperContent,'DEEPSEEK_API_KEY=')).Count -eq 1 -and $wrapperContent -notmatch 'sk-FAKE_KEY_FOR_TEST') 'Replacing a key removes old assignments'
    Assert-Test (@(Get-ChildItem -LiteralPath (Join-Path $target 'backup') -Filter '*.bak').Count -eq 2) 'Every key change preserves prior startup file'
    Assert-Test ((Error-Code '/api/model/key' @{installDir=$target;apiKey="sk-malicious`r`nwhoami"}) -eq 'MODEL_KEY_FORMAT') 'Key rejects shell injection and newlines'
    Assert-Test ((Error-Code '/api/model/key' @{installDir=$env:WINDIR;apiKey=$keyBody.apiKey}) -eq 'MODEL_KEY_PATH_INVALID') 'Key updates refuse system directories'
    Assert-Test ((Error-Code '/api/model/key' @{installDir=(Join-Path $sandbox 'not-installed');apiKey=$keyBody.apiKey}) -eq 'MODEL_KEY_INSTALLATION_MISSING') 'Key cannot be saved before an installation exists'
    $testConfig.models.providers.deepseek.baseUrl='https://example.com'
    $testConfig | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $configPath
    Assert-Test ((Error-Code '/api/model/key' $keyBody) -eq 'MODEL_KEY_PROVIDER_UNSUPPORTED') 'Key updates cannot target a custom provider'
    $failure=Api '/api/deploy' @{packageId=$upload.packageId;installDir=(Join-Path $sandbox 'failure');port=(Free-Port);apiKey='';includeBusiness=$false}
    $runtimeItems.Add(('jobs\' + $failure.jobId))
    for($i=0;$i -lt 80;$i++){ $state=Api '/api/deploy/status' @{};if($state.status -ne 'running'){break};Start-Sleep -Milliseconds 150 }
    Assert-Test ($state.status -eq 'failed' -and $state.code -eq 'DEPLOY_INSTALL_FAILED') 'Installer failure becomes red failed state'
    Assert-Test ($state.log -match 'Intentional test failure') 'Terminating installation error is visible in deployment log'
    Write-Host "All $count deployment assertions passed."
} finally {
    foreach($process in @($helper,$gateway)){ if($process -and -not $process.HasExited){Stop-Process -Id $process.Id -Force} }
    foreach ($runtimeBase in @((Join-Path $sandbox 'local\OpenClawDeploymentKit'), (Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'OpenClawDeploymentKit'))) {
        foreach ($relative in $runtimeItems) {
            $generated = [IO.Path]::GetFullPath((Join-Path $runtimeBase $relative))
            if ($relative -match '^(jobs|uploads)\\[a-f0-9]{32}$' -and $generated.StartsWith([IO.Path]::GetFullPath($runtimeBase).TrimEnd('\')+'\', [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $generated)) {
                Remove-Item -LiteralPath $generated -Recurse -Force
            }
        }
    }
    $resolved=[IO.Path]::GetFullPath($sandbox)
    if ([IO.Path]::GetDirectoryName($resolved).TrimEnd('\') -eq [IO.Path]::GetPathRoot($repo).TrimEnd('\') -and [IO.Path]::GetFileName($resolved).StartsWith('OpenClawKitTest-')) {
        if(Test-Path -LiteralPath $resolved){Remove-Item -LiteralPath $resolved -Recurse -Force}
    }
}
