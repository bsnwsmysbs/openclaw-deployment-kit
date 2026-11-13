#requires -Version 7.0
# PowerShell 7 is the prerequisite. Node.js and admin rights are not required.
param([ValidateRange(1024,65535)][int]$Port = 18890, [switch]$NoBrowser)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$sessionToken = [Guid]::NewGuid().ToString('N') + [Guid]::NewGuid().ToString('N')
$utf8 = New-Object System.Text.UTF8Encoding($false)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Result($Status, $Code, $Detail = '', $Data = $null) {
    return @{ status = $Status; code = $Code; detail = $Detail; data = $Data; checkedAt = [DateTimeOffset]::Now.ToString('o') }
}
function Run-Version([string]$Executable, [string]$Arguments, [hashtable]$EnvironmentOverrides = @{}, [int]$TimeoutMs = 7000) {
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = $Executable
    $info.Arguments = $Arguments
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    foreach ($name in $EnvironmentOverrides.Keys) { $info.EnvironmentVariables[$name] = [string]$EnvironmentOverrides[$name] }
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $info
    try {
        [void]$process.Start()
        $out = $process.StandardOutput.ReadToEndAsync()
        $err = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit($TimeoutMs)) { try { $process.Kill($true) } catch {}; throw 'COMMAND_TIMEOUT' }
        if ($process.ExitCode -ne 0) { throw 'COMMAND_FAILED' }
        return $out.GetAwaiter().GetResult().Trim()
    } finally { $process.Dispose() }
}
function Http-Probe([string]$Url, [string]$ApiKey = '') {
    # Only fixed public endpoints and the loopback gateway are called by this helper.
    $request = [Net.HttpWebRequest]::Create($Url)
    $request.Timeout = 8000
    $request.ReadWriteTimeout = 8000
    $request.AllowAutoRedirect = $false
    $request.Method = 'GET'
    $request.UserAgent = 'OpenClaw-Deployment-Check/1.0'
    if ($ApiKey) { $request.Headers.Add('Authorization', 'Bearer ' + $ApiKey) }
    $response = $null
    try {
        $response = $request.GetResponse()
    } catch [Net.WebException] {
        if ($_.Exception.Response) { $response = $_.Exception.Response } else { throw 'NETWORK_UNREACHABLE' }
    }
    try {
        $reader = New-Object IO.StreamReader($response.GetResponseStream())
        try { $body = $reader.ReadToEnd() } finally { $reader.Dispose() }
        return @{ status = [int]$response.StatusCode; body = $body }
    } finally { if ($response) { $response.Close() } }
}
function Read-Config([string]$InstallDir) {
    $path = Join-Path $InstallDir 'config\openclaw.json'
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw 'CONFIG_MISSING' }
    try { return (Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json) } catch { throw 'CONFIG_INVALID' }
}
function Find-Node {
    $cmd = Get-Command node.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $candidate = Join-Path $env:ProgramFiles 'nodejs\node.exe'
    if (Test-Path -LiteralPath $candidate) { return $candidate }
    return $null
}
function Check([string]$Id, [string]$InstallDir) {
    switch ($Id) {
        'system' {
            if (-not [Environment]::Is64BitOperatingSystem) { return (Result 'fail' 'SYSTEM_X64_REQUIRED') }
            if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { return (Result 'warn' 'SYSTEM_ARM_UNTESTED' ([Environment]::OSVersion.VersionString)) }
            return (Result 'pass' 'SYSTEM_OK' ([Environment]::OSVersion.VersionString))
        }
        'disk' {
            try {
                $drive = New-Object IO.DriveInfo([IO.Path]::GetPathRoot($InstallDir))
                if (-not $drive.IsReady) { return (Result 'fail' 'DRIVE_MISSING') }
                $free = [math]::Round($drive.AvailableFreeSpace / 1GB, 1)
            } catch { return (Result 'fail' 'DRIVE_MISSING') }
            if ($free -lt 8) { return (Result 'fail' 'DISK_LOW' "$free GB") }
            if ($free -lt 20) { return (Result 'warn' 'DISK_RECOMMENDED' "$free GB") }
            return (Result 'pass' 'DISK_OK' "$free GB")
        }
        'powershell' {
            $exe = Get-Command pwsh.exe -ErrorAction SilentlyContinue
            $path = Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe'
            if ($exe) { $path = $exe.Source }
            if (-not (Test-Path -LiteralPath $path)) { return (Result 'fail' 'PWSH_MISSING') }
            $version = Run-Version $path '-NoLogo -NoProfile -Command "$PSVersionTable.PSVersion.ToString()"'
            if ([version]$version -lt [version]'7.0') { return (Result 'fail' 'PWSH_OLD' $version) }
            return (Result 'pass' 'PWSH_OK' $version)
        }
        'node' {
            $node = Find-Node
            if (-not $node) { return (Result 'fail' 'NODE_MISSING') }
            $version = Run-Version $node '--version'
            if ([version]$version.TrimStart('v') -lt [version]'24.16.0') { return (Result 'fail' 'NODE_OLD' $version) }
            return (Result 'pass' 'NODE_OK' $version)
        }
        'npm' {
            $node = Find-Node
            if (-not $node) { return (Result 'fail' 'NODE_MISSING') }
            $npm = Join-Path (Split-Path $node -Parent) 'node_modules\npm\bin\npm-cli.js'
            if (-not (Test-Path -LiteralPath $npm)) { return (Result 'fail' 'NPM_MISSING') }
            $version = Run-Version $node ('"' + $npm + '" --version')
            return (Result 'pass' 'NPM_OK' $version)
        }
        'npm-network' {
            $probe = Http-Probe 'https://registry.npmmirror.com/openclaw/2026.6.1'
            if ($probe.status -ne 200) { return (Result 'fail' 'NPM_NETWORK_FAILED' ('HTTP ' + $probe.status)) }
            $package = $probe.body | ConvertFrom-Json
            if ($package.version -ne '2026.6.1') { return (Result 'fail' 'NPM_PACKAGE_INVALID') }
            return (Result 'pass' 'NPM_NETWORK_OK' 'openclaw@2026.6.1')
        }
        'model-network' {
            $probe = Http-Probe 'https://api.deepseek.com/models'
            if ($probe.status -in @(200, 401, 403)) { return (Result 'pass' 'MODEL_NETWORK_OK' ('HTTP ' + $probe.status)) }
            return (Result 'fail' 'MODEL_NETWORK_FAILED' ('HTTP ' + $probe.status))
        }
        'installation' {
            $required = @('openclaw-local.cmd', 'start-gateway.cmd', 'config\openclaw.json', 'app\openclaw\node_modules\openclaw\package.json')
            $missing = @($required | Where-Object { -not (Test-Path -LiteralPath (Join-Path $InstallDir $_) -PathType Leaf) })
            if ($missing.Count) { return (Result 'fail' 'INSTALLATION_MISSING' ($missing -join ', ')) }
            $pkg = Get-Content -LiteralPath (Join-Path $InstallDir 'app\openclaw\node_modules\openclaw\package.json') -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($pkg.version -ne '2026.6.1') { return (Result 'warn' 'INSTALLATION_VERSION' ([string]$pkg.version)) }
            return (Result 'pass' 'INSTALLATION_OK' ([string]$pkg.version))
        }
        'config' {
            $config = Read-Config $InstallDir
            $gatewayPort = 0
            if (-not [int]::TryParse([string]$config.gateway.port, [ref]$gatewayPort) -or $gatewayPort -lt 1 -or $gatewayPort -gt 65535) { return (Result 'fail' 'CONFIG_PORT_INVALID') }
            if ($config.gateway.bind -ne 'loopback') { return (Result 'warn' 'CONFIG_BIND' ([string]$config.gateway.bind)) }
            if ([string]::IsNullOrWhiteSpace([string]$config.gateway.auth.token)) { return (Result 'fail' 'CONFIG_TOKEN_MISSING') }
            return (Result 'pass' 'CONFIG_OK' ('127.0.0.1:' + $gatewayPort))
        }
        'gateway' {
            $config = Read-Config $InstallDir
            $gatewayPort = [int]$config.gateway.port
            if ($gatewayPort -lt 1 -or $gatewayPort -gt 65535) { return (Result 'fail' 'CONFIG_PORT_INVALID') }
            try { $probe = Http-Probe ('http://127.0.0.1:' + $gatewayPort + '/') } catch { return (Result 'fail' 'GATEWAY_OFFLINE') }
            if ($probe.status -ne 200 -or $probe.body -notmatch '(?i)openclaw') { return (Result 'fail' 'GATEWAY_WRONG_SERVICE' ('HTTP ' + $probe.status)) }
            return (Result 'pass' 'GATEWAY_OK' ('http://127.0.0.1:' + $gatewayPort + '/') @{ url = ('http://127.0.0.1:' + $gatewayPort + '/') })
        }
        'model-config' {
            $config = Read-Config $InstallDir
            $primary = [string]$config.agents.defaults.model.primary
            if (-not $primary.StartsWith('deepseek/')) { return (Result 'warn' 'MODEL_CUSTOM_PROVIDER' $primary) }
            $provider = $config.models.providers.deepseek
            if ([string]$provider.baseUrl -notin @('https://api.deepseek.com', 'https://api.deepseek.com/', 'https://api.deepseek.com/v1', 'https://api.deepseek.com/v1/')) { return (Result 'warn' 'MODEL_CUSTOM_PROVIDER' $primary) }
            $key = ''
            $wrapper = Join-Path $InstallDir 'openclaw-local.cmd'
            if (Test-Path -LiteralPath $wrapper) {
                $wrapperText = Get-Content -LiteralPath $wrapper -Raw
                $match = [regex]::Match($wrapperText, '(?im)^\s*set\s+"DEEPSEEK_API_KEY=([^"\r\n]+)"\s*$')
                if ($match.Success) { $key = $match.Groups[1].Value }
            }
            if (-not $key -and $env:DEEPSEEK_API_KEY) { $key = $env:DEEPSEEK_API_KEY }
            if (-not $key -and $provider.apiKey -is [string] -and $provider.apiKey -notmatch '^\$') { $key = $provider.apiKey }
            if (-not $key) { return (Result 'fail' 'MODEL_KEY_MISSING') }
            $probe = Http-Probe 'https://api.deepseek.com/models' $key
            if ($probe.status -eq 401 -or $probe.status -eq 403) { return (Result 'fail' 'MODEL_KEY_REJECTED' ('HTTP ' + $probe.status)) }
            if ($probe.status -ne 200) { return (Result 'fail' 'MODEL_API_FAILED' ('HTTP ' + $probe.status)) }
            $catalog = $probe.body | ConvertFrom-Json
            $model = $primary.Substring(9)
            $available = @($catalog.data | ForEach-Object { [string]$_.id })
            if ($model -notin $available) { return (Result 'fail' 'MODEL_UNAVAILABLE' $primary @{ availableModels = $available }) }
            return (Result 'pass' 'MODEL_CONFIG_OK' $primary)
        }
        'skills' {
            $config = Read-Config $InstallDir
            $workspace = [string]$config.agents.defaults.workspace
            if (-not $workspace) { $workspace = Join-Path $InstallDir 'workspace' }
            $locations = @((Join-Path $workspace 'skills'), (Join-Path $InstallDir 'state\skills'), (Join-Path $env:USERPROFILE '.openclaw\skills'), (Join-Path $env:USERPROFILE '.agents\skills'))
            if ($config.skills.load.extraDirs) { $locations += @($config.skills.load.extraDirs) }
            $expected = @('meeting-supervision-closure','contract-risk-review','policy-briefing','hr-performance-analysis','strategy-execution-review','employee-behavior-analysis','management-optimization-quantification')
            $missing = @()
            foreach ($skill in $expected) {
                $found = $false
                foreach ($location in $locations) { if (Test-Path -LiteralPath (Join-Path $location ($skill + '\SKILL.md')) -PathType Leaf) { $found = $true; break } }
                if (-not $found) { $missing += $skill }
            }
            if ($missing.Count) { return (Result 'fail' 'SKILLS_MISSING' ($missing -join ', ')) }
            $entry = Join-Path $InstallDir 'app\openclaw\node_modules\openclaw\openclaw.mjs'
            $node = Find-Node
            if ($node -and (Test-Path -LiteralPath $entry)) {
                try {
                    $cliEnv = @{
                        OPENCLAW_CONFIG_PATH = (Join-Path $InstallDir 'config\openclaw.json')
                        OPENCLAW_STATE_DIR = (Join-Path $InstallDir 'state')
                        OPENCLAW_WORKSPACE = $workspace
                        OPENCLAW_NO_AUTO_UPDATE = '1'
                        OPENCLAW_SKIP_CHANNELS = '1'
                    }
                    $json = Run-Version $node ('"' + $entry + '" skills list --json') $cliEnv 15000
                    $catalog = $json | ConvertFrom-Json
                    if (-not $catalog.PSObject.Properties['skills']) { throw 'SKILL_CATALOG_UNAVAILABLE' }
                    $notReady = @()
                    foreach ($skill in $expected) {
                        $loaded = @($catalog.skills | Where-Object { $_.name -eq $skill -and $_.eligible -eq $true -and -not $_.disabled -and -not $_.blockedByAllowlist -and -not $_.blockedByAgentFilter })
                        if (-not $loaded.Count) { $notReady += $skill }
                    }
                    if ($notReady.Count) { return (Result 'fail' 'SKILLS_NOT_READY' ($notReady -join ', ')) }
                    return (Result 'pass' 'SKILLS_READY' '7 / 7')
                } catch {
                    if ($_.Exception.Message -eq 'COMMAND_TIMEOUT') { return (Result 'fail' 'COMMAND_TIMEOUT') }
                    return (Result 'warn' 'SKILLS_PRESENT' '7 / 7')
                }
            }
            return (Result 'warn' 'SKILLS_PRESENT' '7 / 7')
        }
        'workspace' {
            $required = @('AGENTS.md','SOUL.md','WORKSPACE_GUIDE.md')
            $missing = @($required | Where-Object { -not (Test-Path -LiteralPath (Join-Path $InstallDir ('workspace\' + $_)) -PathType Leaf) })
            if ($missing.Count) { return (Result 'fail' 'WORKSPACE_MISSING' ($missing -join ', ')) }
            return (Result 'pass' 'WORKSPACE_OK')
        }
        'workbench' {
            $desktop = [Environment]::GetFolderPath('Desktop')
            $workbenchName = -join ([char[]]@(0x9F99,0x867E,0x5DE5,0x4F5C,0x53F0))
            $workbench = Join-Path $desktop $workbenchName
            $inputName = '01-' + (-join ([char[]]@(0x8F93,0x5165,0x8D44,0x6599)))
            $outputName = '02-' + (-join ([char[]]@(0x8F93,0x51FA,0x6210,0x679C)))
            if (-not (Test-Path -LiteralPath (Join-Path $workbench $inputName) -PathType Container) -or -not (Test-Path -LiteralPath (Join-Path $workbench $outputName) -PathType Container)) { return (Result 'fail' 'WORKBENCH_MISSING' $workbench) }
            return (Result 'pass' 'WORKBENCH_OK' $workbench)
        }
        'docx' {
            if (-not (Test-Path -LiteralPath (Join-Path $InstallDir 'tools\export-docx.ps1') -PathType Leaf)) { return (Result 'fail' 'DOCX_MISSING') }
            return (Result 'pass' 'DOCX_PRESENT')
        }
        'autostart' {
            $startup = [Environment]::GetFolderPath('Startup')
            $entry = Join-Path $startup 'OpenClawMeeting-Gateway.vbs'
            if (Test-Path -LiteralPath $entry) {
                $content = Get-Content -LiteralPath $entry -Raw
                if ($content.IndexOf($InstallDir, [StringComparison]::OrdinalIgnoreCase) -ge 0) { return (Result 'pass' 'AUTOSTART_OK') }
                return (Result 'fail' 'AUTOSTART_WRONG_PATH')
            }
            return (Result 'warn' 'AUTOSTART_UNCONFIRMED')
        }
        default { return (Result 'fail' 'UNKNOWN_CHECK') }
    }
}
. (Join-Path $PSScriptRoot 'deployment.ps1')

function Read-HttpRequest($Stream) {
    # Parse headers without buffered text reads, so binary ZIP bodies remain byte-exact.
    $header = [IO.MemoryStream]::new()
    try {
        $tail = 0
        while ($true) {
            $byte = $Stream.ReadByte()
            if ($byte -lt 0) { throw 'INCOMPLETE_REQUEST' }
            $header.WriteByte([byte]$byte)
            if ($header.Length -gt 16384) { throw 'REQUEST_TOO_LARGE' }
            $tail = (($tail -shl 8) -bor $byte) -band 0xFFFFFFFFL
            if ($tail -eq 0x0D0A0D0A) { break }
        }
        $lines = [Text.Encoding]::ASCII.GetString($header.ToArray()).Split("`r`n")
    } finally { $header.Dispose() }
    $parts = $lines[0].Split(' ')
    if ($parts.Count -ne 3) { throw 'INVALID_REQUEST' }
    $headers = @{}
    foreach ($line in $lines[1..($lines.Count-1)]) {
        if (-not $line) { continue }
        $colon = $line.IndexOf(':')
        if ($colon -lt 1) { throw 'INVALID_REQUEST' }
        $name = $line.Substring(0,$colon).ToLowerInvariant()
        if ($headers.ContainsKey($name)) { throw 'INVALID_REQUEST' }
        $headers[$name] = $line.Substring($colon+1).Trim()
    }
    $path = $parts[1].Split('?')[0]
    $length = 0
    if ($headers.ContainsKey('content-length')) {
        if (-not [int]::TryParse([string]$headers['content-length'], [ref]$length) -or $length -lt 0) { throw 'INVALID_REQUEST' }
    }
    $limit = 8192
    if ($path -eq '/api/packages') { $limit = 16MB }
    if ($length -gt $limit) { throw 'REQUEST_TOO_LARGE' }
    $payload = [byte[]]::new($length)
    $offset = 0
    while ($offset -lt $length) {
        $read = $Stream.Read($payload, $offset, $length-$offset)
        if ($read -le 0) { throw 'INCOMPLETE_REQUEST' }
        $offset += $read
    }
    if ($headers['host'] -notin @("127.0.0.1:$Port", "localhost:$Port") -or $headers['transfer-encoding']) { throw 'FORBIDDEN_REQUEST' }
    if ($parts[0] -eq 'POST') {
        if ($headers['x-check-token'] -ne $sessionToken -or ($headers['origin'] -and $headers['origin'] -notin @("http://127.0.0.1:$Port", "http://localhost:$Port"))) { throw 'FORBIDDEN_REQUEST' }
    }
    return @{method=$parts[0];path=$path;headers=$headers;payload=$payload}
}

function Send-Response($Stream, [int]$Status, [string]$Type, [byte[]]$Body) {
    $label = @{ 200='OK'; 400='Bad Request'; 403='Forbidden'; 404='Not Found'; 405='Method Not Allowed'; 413='Payload Too Large'; 500='Internal Server Error' }[$Status]
    $header = "HTTP/1.1 $Status $label`r`nContent-Type: $Type`r`nContent-Length: $($Body.Length)`r`nConnection: close`r`nCache-Control: no-store`r`nX-Content-Type-Options: nosniff`r`nReferrer-Policy: no-referrer`r`nContent-Security-Policy: default-src 'self'; script-src 'self'; style-src 'self'; connect-src 'self'; img-src 'self' data:; frame-ancestors 'none'; base-uri 'none'`r`n`r`n"
    $bytes = [Text.Encoding]::ASCII.GetBytes($header)
    $Stream.Write($bytes, 0, $bytes.Length)
    $Stream.Write($Body, 0, $Body.Length)
}

$listener = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback, $Port)
try { $listener.Start() } catch { Write-Host "Cannot bind 127.0.0.1:$Port. Another check desk may already be running."; exit 1 }
$url = "http://127.0.0.1:$Port/"
Write-Host "OpenClaw deployment check: $url"
Write-Host 'Local diagnostics and ZIP deployment. Close this window to stop the web helper.'
if (-not $NoBrowser) { Start-Process $url }
try {
    while ($true) {
        $client = $listener.AcceptTcpClient()
        try {
            $stream = $client.GetStream()
            $stream.ReadTimeout = 5000
            $stream.WriteTimeout = 5000
            $http = Read-HttpRequest $stream
            $path = $http.path
            if ($path -eq '/api/check' -and $http.method -eq 'POST') {
                try {
                    $body = $utf8.GetString($http.payload) | ConvertFrom-Json
                    $dir = [string]$body.installDir
                    if ($dir -notmatch '^[A-Za-z]:\\[\x20-\x7E]+$' -or $dir -match '[<>"|?*]' -or $dir.Substring(2).Contains(':')) { throw 'INVALID_PATH' }
                    $dir = [IO.Path]::GetFullPath($dir).TrimEnd('\')
                    $result = Check ([string]$body.id) $dir
                } catch {
                    $message = [string]$_.Exception.Message
                    $known = @('CONFIG_MISSING','CONFIG_INVALID','COMMAND_TIMEOUT','COMMAND_FAILED','NETWORK_UNREACHABLE','INVALID_PATH')
                    $code = 'CHECK_ERROR'
                    if ($message -in $known) { $code = $message }
                    $result = Result 'fail' $code
                }
                $json = $result | ConvertTo-Json -Depth 6 -Compress
                Send-Response $stream 200 'application/json; charset=utf-8' ($utf8.GetBytes($json))
            } elseif ($http.method -eq 'POST' -and $path -in @('/api/packages','/api/deploy','/api/deploy/status')) {
                try {
                    if ($path -eq '/api/packages') {
                        $result = Save-Package $http.payload
                    } elseif ($path -eq '/api/deploy') {
                        $body = $utf8.GetString($http.payload) | ConvertFrom-Json
                        $result = Start-Deployment $body
                    } else { $result = Get-DeploymentStatus }
                    Send-Response $stream 200 'application/json; charset=utf-8' ($utf8.GetBytes(($result | ConvertTo-Json -Depth 8 -Compress)))
                } catch {
                    $code = [string]$_.Exception.Message
                    if ($code -notmatch '^(ZIP_|DEPLOY_|PACKAGE_|NODE_|NPM_|MODEL_KEY_FORMAT)[A-Z_]*$') { $code = 'DEPLOY_REQUEST_FAILED' }
                    Send-Response $stream 400 'application/json; charset=utf-8' ($utf8.GetBytes((@{error=$code} | ConvertTo-Json -Compress)))
                }
            } elseif ($http.method -eq 'GET' -and $path -in @('/', '/index.html', '/powershell7.html', '/app.js', '/deploy.js', '/style.css')) {
                if ($path -in @('/', '/index.html')) {
                    $html = [IO.File]::ReadAllText((Join-Path $root 'public\index.html'), $utf8).Replace('__CHECK_SESSION__', $sessionToken)
                    Send-Response $stream 200 'text/html; charset=utf-8' ($utf8.GetBytes($html))
                } else {
                    $type = 'text/css; charset=utf-8'
                    if ($path -eq '/powershell7.html') { $type = 'text/html; charset=utf-8' }
                    if ($path -in @('/app.js','/deploy.js')) { $type = 'text/javascript; charset=utf-8' }
                    Send-Response $stream 200 $type ([IO.File]::ReadAllBytes((Join-Path $root ('public' + $path.Replace('/','\')))))
                }
            } else { Send-Response $stream 404 'text/plain; charset=utf-8' ($utf8.GetBytes('Not found')) }
        } catch {
            # Do not print request bodies, configuration, or credentials to console/logs.
            $status = 400
            if ($_.Exception.Message -eq 'FORBIDDEN_REQUEST') { $status=403 }
            if ($_.Exception.Message -eq 'REQUEST_TOO_LARGE') { $status=413 }
            try { Send-Response $stream $status 'text/plain; charset=utf-8' ($utf8.GetBytes('Request failed')) } catch {}
        } finally { $client.Close() }
    }
} finally { $listener.Stop() }
