#requires -Version 7.0
$ErrorActionPreference='Stop'
$sandbox=Join-Path ([IO.Path]::GetTempPath()) ('openclaw-node-test-'+[Guid]::NewGuid().ToString('N'))
$script:runtimeRoot=$sandbox
$script:runtimeReady=$false
$script:wingetAvailable=$true
$script:deployRunning=$false
$script:installCount=0
$script:fixtureExit=0
$count=0
function Assert-Node([bool]$Condition,[string]$Name){if(-not $Condition){throw "FAILED: $Name"};$script:count++;Write-Host "PASS: $Name"}
. (Join-Path $PSScriptRoot '..\node-setup.ps1')
function Check([string]$Id,[string]$Directory){if($script:runtimeReady){return @{status='pass';detail='24.16.0'}};return @{status='fail';code='NODE_MISSING'}}
function Refresh-NodePath {}
function Get-DeploymentStatus {return @{status=$(if($script:deployRunning){'running'}else{'idle'})}}
function Find-Winget {if($script:wingetAvailable){return 'fake-winget'}}
function Start-NodeInstallerProcess([string]$Executable,[string]$OutFile,[string]$ErrorFile){
    $script:installCount++
    return Start-Process (Join-Path $PSHOME 'pwsh.exe') -ArgumentList @('-NoProfile','-File',(Join-Path $sandbox 'fixture.ps1'),'-ExitCode',$script:fixtureExit) -WindowStyle Hidden -PassThru -RedirectStandardOutput $OutFile -RedirectStandardError $ErrorFile
}
function Wait-NodeFixture {
    for($attempt=0;$attempt -lt 60;$attempt++){$state=Get-NodeSetupStatus;if($state.status -ne 'running'){return $state};Start-Sleep -Milliseconds 100}
    throw 'Fixture timed out'
}
try {
    New-Item -ItemType Directory -Path $sandbox | Out-Null
    'param([int]$ExitCode); Write-Output "Installing test fixture"; Start-Sleep -Milliseconds 400; exit $ExitCode' | Set-Content (Join-Path $sandbox 'fixture.ps1')
    $script:runtimeReady=$true
    Assert-Node ((Start-NodeSetup).status -eq 'succeeded' -and $script:installCount -eq 0) 'Healthy Node/npm skips system installer'
    $script:runtimeReady=$false;$script:wingetAvailable=$false
    $code='';try{Start-NodeSetup | Out-Null}catch{$code=$_.Exception.Message}
    Assert-Node ($code -eq 'NODE_WINGET_MISSING' -and $script:installCount -eq 0) 'Missing winget produces actionable failure'
    $script:wingetAvailable=$true;$script:deployRunning=$true
    $code='';try{Start-NodeSetup | Out-Null}catch{$code=$_.Exception.Message}
    Assert-Node ($code -eq 'NODE_SETUP_DEPLOY_BUSY') 'Node installation cannot change a running deployment'
    $script:deployRunning=$false
    $started=Start-NodeSetup
    Assert-Node ($started.status -eq 'running') 'Missing runtime starts asynchronous installer'
    $again=Start-NodeSetup
    Assert-Node ($again.jobId -eq $started.jobId -and $script:installCount -eq 1) 'Concurrent requests reuse one installer'
    $script:runtimeReady=$true
    $finished=Wait-NodeFixture
    if($finished.status -ne 'succeeded'){Write-Host ($finished | ConvertTo-Json -Compress)}
    Assert-Node ($finished.status -eq 'succeeded' -and $finished.log -match 'test fixture') 'Successful installer rechecks Node/npm and returns logs'
    $script:runtimeReady=$false
    Start-NodeSetup | Out-Null
    $finished=Wait-NodeFixture
    Assert-Node ($finished.code -eq 'NODE_SETUP_VERIFY_FAILED') 'Installer exit zero cannot bypass runtime verification'
    $script:fixtureExit=25
    Start-NodeSetup | Out-Null
    $finished=Wait-NodeFixture
    Assert-Node ($finished.status -eq 'failed' -and $finished.exitCode -eq 25) 'Installer error becomes failed state with exit code'
    $script:fixtureExit=0
    Start-NodeSetup | Out-Null
    $script:nodeSetup.startedAt=[DateTime]::UtcNow.AddMinutes(-16)
    $finished=Get-NodeSetupStatus
    Assert-Node ($finished.code -eq 'NODE_SETUP_TIMEOUT') 'Stalled installer is stopped and marked failed'
    Write-Host "All $count Node setup assertions passed."
} finally {
    if($script:nodeSetup){
        if(-not $script:nodeSetup.process.HasExited){$script:nodeSetup.process.Kill($true);[void]$script:nodeSetup.process.WaitForExit(3000)}
        if($script:nodeSetup.mutex){$script:nodeSetup.mutex.ReleaseMutex();$script:nodeSetup.mutex.Dispose()}
    }
    $resolved=[IO.Path]::GetFullPath($sandbox)
    if($resolved.StartsWith([IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase) -and [IO.Path]::GetFileName($resolved).StartsWith('openclaw-node-test-')){if(Test-Path -LiteralPath $resolved){Remove-Item -LiteralPath $resolved -Recurse -Force}}
}
