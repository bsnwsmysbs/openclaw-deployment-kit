# Local gateway access, separate from ordinary diagnostic results and reports.
function Get-GatewayAccess($Body) {
    try { [void](Assert-InstallTarget ([string]$Body.installDir)) }
    catch { if ($_.Exception.Message -ne 'DEPLOY_TARGET_NOT_EMPTY') { throw 'GATEWAY_ACCESS_PATH_INVALID' } }
    $target = [IO.Path]::GetFullPath([string]$Body.installDir).TrimEnd('\')
    foreach ($relative in @('config','config\openclaw.json')) {
        $path = Join-Path $target $relative
        if ((Test-Path -LiteralPath $path) -and ((Get-Item -LiteralPath $path -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'GATEWAY_ACCESS_PATH_INVALID' }
    }
    if (-not (Test-Path -LiteralPath (Join-Path $target 'openclaw-local.cmd') -PathType Leaf)) { throw 'GATEWAY_ACCESS_INSTALLATION_MISSING' }
    try { $config = Read-Config $target } catch { throw 'GATEWAY_ACCESS_CONFIG_INVALID' }
    $gatewayPort = 0
    if ($config.gateway.bind -ne 'loopback' -or -not [int]::TryParse([string]$config.gateway.port,[ref]$gatewayPort) -or $gatewayPort -lt 1 -or $gatewayPort -gt 65535 -or $gatewayPort -eq $Port) { throw 'GATEWAY_ACCESS_CONFIG_INVALID' }
    $token = [string]$config.gateway.auth.token
    if (($config.gateway.auth.mode -and $config.gateway.auth.mode -ne 'token') -or [string]::IsNullOrWhiteSpace($token) -or $token.Length -gt 512 -or $token -match '[\x00-\x20\x7f]' -or $token.StartsWith('$')) { throw 'GATEWAY_ACCESS_TOKEN_MISSING' }
    $baseUrl = 'http://127.0.0.1:' + $gatewayPort + '/'
    return @{token=$token;baseUrl=$baseUrl;url=($baseUrl + '#token=' + [Uri]::EscapeDataString($token))}
}

function Start-GatewayBrowser([string]$Url) {
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = $Url
    $info.UseShellExecute = $true
    [void][Diagnostics.Process]::Start($info)
}

function Open-GatewayAccess($Body) {
    $access = Get-GatewayAccess $Body
    try { $gateway = Check 'gateway' ([string]$Body.installDir) } catch { throw 'GATEWAY_ACCESS_OFFLINE' }
    if ($gateway.status -ne 'pass') { throw 'GATEWAY_ACCESS_OFFLINE' }
    try { Start-GatewayBrowser $access.url } catch { throw 'GATEWAY_ACCESS_OPEN_FAILED' }
    return @{status='opened';message='已在系统默认浏览器打开 OpenClaw，并自动携带网关 Token。'}
}
