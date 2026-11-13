function Save-ModelKey($Body) {
    if ((Get-DeploymentStatus).status -eq 'running' -or (Get-NodeSetupStatus).status -eq 'running') { throw 'MODEL_KEY_BUSY' }
    $key = [string]$Body.apiKey
    if ($key -notmatch '^sk-[A-Za-z0-9_-]{8,256}$') { throw 'MODEL_KEY_FORMAT' }
    # Reuse the deployment path protections, permitting an existing nonempty installation.
    try { [void](Assert-InstallTarget ([string]$Body.installDir)) }
    catch { if ($_.Exception.Message -ne 'DEPLOY_TARGET_NOT_EMPTY') { throw 'MODEL_KEY_PATH_INVALID' } }
    $target = [IO.Path]::GetFullPath([string]$Body.installDir).TrimEnd('\')
    $wrapper = Join-Path $target 'openclaw-local.cmd'
    $configuration = Join-Path $target 'config\openclaw.json'
    foreach ($relative in @('openclaw-local.cmd','config','config\openclaw.json','backup')) {
        $path = Join-Path $target $relative
        if ((Test-Path -LiteralPath $path) -and ((Get-Item -LiteralPath $path -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'MODEL_KEY_PATH_INVALID' }
    }
    if (-not (Test-Path -LiteralPath $wrapper -PathType Leaf) -or -not (Test-Path -LiteralPath $configuration -PathType Leaf)) { throw 'MODEL_KEY_INSTALLATION_MISSING' }
    try { $config = Get-Content -LiteralPath $configuration -Raw | ConvertFrom-Json }
    catch { throw 'MODEL_KEY_CONFIG_INVALID' }
    if ([string]$config.agents.defaults.model.primary -notlike 'deepseek/*' -or [string]$config.models.providers.deepseek.baseUrl -notin @('https://api.deepseek.com','https://api.deepseek.com/','https://api.deepseek.com/v1','https://api.deepseek.com/v1/')) { throw 'MODEL_KEY_PROVIDER_UNSUPPORTED' }
    if ($config.models.providers.deepseek.apiKey -and $config.models.providers.deepseek.apiKey -ne '${DEEPSEEK_API_KEY}') { throw 'MODEL_KEY_CONFIG_OVERRIDE' }
    $content = [IO.File]::ReadAllText($wrapper)
    $pattern = '(?im)^[ \t]*@?set[ \t]+(?:"DEEPSEEK_API_KEY=[^\r\n]*"|DEEPSEEK_API_KEY=[^\r\n]*)[ \t]*\r?\n?'
    $content = [regex]::Replace($content, $pattern, '')
    $content = [regex]::Replace($content, '(?im)^@echo off[ \t]*\r?\n?', '')
    $updated = "@echo off`r`nset `"DEEPSEEK_API_KEY=$key`"`r`n" + $content
    $backupRoot = Join-Path $target 'backup'
    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
    $id = [Guid]::NewGuid().ToString('N')
    $backupFile = Join-Path $backupRoot ('openclaw-local.cmd.before-web-key-' + $id + '.bak')
    Copy-Item -LiteralPath $wrapper -Destination $backupFile
    $temporary = $wrapper + '.' + $id + '.tmp'
    try {
        [IO.File]::WriteAllText($temporary, $updated, [Text.UTF8Encoding]::new($false))
        Move-Item -LiteralPath $temporary -Destination $wrapper -Force
    } finally { if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force } }
    return @{status='saved';restartRequired=$true;message='SK 密钥已保存，旧启动文件已备份。若网关正在运行，请先运行 stop-gateway.cmd，再运行 start-gateway.cmd，使新密钥生效。'}
}
