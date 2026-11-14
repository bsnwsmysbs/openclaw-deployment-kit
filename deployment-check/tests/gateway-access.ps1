# Browser launching is isolated: this test never opens the user's browser.
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '..\gateway-access.ps1')
function Get-GatewayAccess($Body) { return @{url='http://127.0.0.1:18789/#token=fixture-only'} }
function Check($Id,$Directory) { return @{status='pass'} }
$script:openedGatewayUrl=$null
function Start-GatewayBrowser([string]$Url) { $script:openedGatewayUrl=$Url }
$opened=Open-GatewayAccess @{installDir='C:\Fixture'}
if($opened.status -ne 'opened' -or $script:openedGatewayUrl -ne 'http://127.0.0.1:18789/#token=fixture-only'){throw 'Gateway browser launch contract failed'}
Write-Host 'PASS: Ready Gateway opens browser with authenticated loopback URL'
if(($opened | ConvertTo-Json) -match 'fixture-only'){throw 'Browser response leaked token'}
Write-Host 'PASS: Browser launch response contains no token'
function Start-GatewayBrowser([string]$Url) { throw 'Fake browser launcher failure' }
$code='';try { Open-GatewayAccess @{installDir='C:\Fixture'} | Out-Null }catch{$code=$_.Exception.Message}
if($code -ne 'GATEWAY_ACCESS_OPEN_FAILED'){throw 'Browser launch failure not reported'}
Write-Host 'PASS: Browser launch failure returns actionable error'
