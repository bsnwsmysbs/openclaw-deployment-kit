#requires -Version 7.0
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$fixtureBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
$fixtureRoot = Join-Path $fixtureBase ('openclaw-check-test-' + [Guid]::NewGuid().ToString('N'))
$worker = $null
$assertions = 0
function Assert-Check([bool]$Condition, [string]$Name) {
    if (-not $Condition) { throw "FAILED: $Name" }
    $script:assertions++
    Write-Host "PASS: $Name"
}
try {
    New-Item -ItemType Directory -Path (Join-Path $fixtureRoot 'config') -Force | Out-Null
    # Reserve a free loopback port for an isolated test instance.
    $reservation = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
    $reservation.Start()
    $testPort = $reservation.LocalEndpoint.Port
    $reservation.Stop()
    $url = "http://127.0.0.1:$testPort"
    $worker = Start-Process -FilePath (Join-Path $PSHOME 'pwsh.exe') -ArgumentList @('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File', ('"' + (Join-Path $projectRoot 'server.ps1') + '"'),'-Port', $testPort,'-NoBrowser') -WindowStyle Hidden -PassThru
    $page = $null
    for ($attempt = 0; $attempt -lt 30; $attempt++) {
        try { $page = Invoke-WebRequest "$url/" -TimeoutSec 2; break } catch { Start-Sleep -Milliseconds 100 }
    }
    Assert-Check ($null -ne $page) 'Local helper starts without Node dependency'
    $token = [regex]::Match($page.Content, 'name="check-session" content="([a-f0-9]+)"').Groups[1].Value
    Assert-Check ($token.Length -eq 64) 'Page receives per-run API session'
    Assert-Check (($page.Headers['Content-Security-Policy'] -join '') -match "frame-ancestors 'none'") 'Page refuses framing'
    foreach ($asset in @('app.js','node-setup.js','model-key.js','style.css')) {
        $assetResponse = Invoke-WebRequest "$url/$asset" -TimeoutSec 3
        Assert-Check ($assetResponse.StatusCode -eq 200) "Static asset: $asset"
    }
    $body = @{ id='config'; installDir=$fixtureRoot } | ConvertTo-Json -Compress
    $denied = Invoke-WebRequest "$url/api/check" -Method Post -Body $body -ContentType 'application/json' -SkipHttpErrorCheck
    Assert-Check ($denied.StatusCode -eq 403) 'API rejects missing session token'
    $denied = Invoke-WebRequest "$url/api/check" -Method Post -Body $body -ContentType 'application/json' -Headers @{'X-Check-Token'=$token; Origin='https://example.com'} -SkipHttpErrorCheck
    Assert-Check ($denied.StatusCode -eq 403) 'API rejects foreign Origin'
    foreach ($protectedRoute in @('/api/node/setup','/api/node/status','/api/model/key')) {
        $denied=Invoke-WebRequest ($url+$protectedRoute) -Method Post -Body '{}' -ContentType 'application/json' -SkipHttpErrorCheck
        Assert-Check ($denied.StatusCode -eq 403) "Installation/key route requires session: $protectedRoute"
    }
    $denied = Invoke-WebRequest "$url/server.ps1" -SkipHttpErrorCheck
    Assert-Check ($denied.StatusCode -eq 404) 'Server source is not public'
    function Invoke-Check([string]$Id, [string]$Directory = $fixtureRoot) {
        return Invoke-RestMethod "$url/api/check" -Method Post -Headers @{'X-Check-Token'=$token} -ContentType 'application/json' -Body (@{id=$Id;installDir=$Directory} | ConvertTo-Json -Compress) -TimeoutSec 20
    }
    $result = Invoke-Check 'installation'
    Assert-Check ($result.status -eq 'fail' -and $result.code -eq 'INSTALLATION_MISSING') 'Blank computer reports missing installation'
    $result = Invoke-Check 'config'
    Assert-Check ($result.status -eq 'fail' -and $result.code -eq 'CONFIG_MISSING') 'Missing configuration is a failure'
    Set-Content -LiteralPath (Join-Path $fixtureRoot 'config\openclaw.json') -Value '{ broken JSON' -Encoding UTF8
    $result = Invoke-Check 'config'
    Assert-Check ($result.code -eq 'CONFIG_INVALID') 'Malformed configuration is distinct from missing configuration'
    $config = @{gateway=@{bind='loopback';port=18789;auth=@{token='test-token-do-not-expose'}};agents=@{defaults=@{model=@{primary='custom/example'}}}}
    $config | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $fixtureRoot 'config\openclaw.json') -Encoding UTF8
    $result = Invoke-Check 'config'
    Assert-Check ($result.status -eq 'pass') 'Valid local configuration passes'
    Assert-Check (($result | ConvertTo-Json -Depth 8) -notmatch 'test-token-do-not-expose') 'Gateway token is never returned'
    $result = Invoke-Check 'model-config'
    Assert-Check ($result.status -eq 'warn' -and $result.code -eq 'MODEL_CUSTOM_PROVIDER') 'Unsupported model provider remains unconfirmed'
    $result = Invoke-Check 'config' '\\example\share'
    Assert-Check ($result.code -eq 'INVALID_PATH') 'Network paths are rejected'
    $result = Invoke-Check 'config' 'D:\anything:stream'
    Assert-Check ($result.code -eq 'INVALID_PATH') 'Alternate stream paths are rejected'
    $result = Invoke-Check 'not-a-check'
    Assert-Check ($result.code -eq 'UNKNOWN_CHECK') 'Unknown operations cannot execute'
    Write-Host "All $assertions assertions passed."
} finally {
    if ($worker -and -not $worker.HasExited) { Stop-Process -Id $worker.Id -Force }
    $resolvedFixture = [IO.Path]::GetFullPath($fixtureRoot)
    if ($resolvedFixture.StartsWith($fixtureBase + '\', [StringComparison]::OrdinalIgnoreCase) -and [IO.Path]::GetFileName($resolvedFixture).StartsWith('openclaw-check-test-')) {
        if (Test-Path -LiteralPath $resolvedFixture) { Remove-Item -LiteralPath $resolvedFixture -Recurse -Force }
    }
}
