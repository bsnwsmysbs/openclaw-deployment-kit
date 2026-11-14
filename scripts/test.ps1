#requires -Version 7.0
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$scripts = @(Get-ChildItem -LiteralPath $repo -Recurse -Filter '*.ps1' -File | Where-Object FullName -notmatch '\\(dist|node_modules|\.git)\\')
foreach ($file in $scripts) {
    $parseErrors=$null; $tokens=$null
    [void][Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$parseErrors)
    if ($parseErrors.Count) { throw "PowerShell parse errors: $($file.FullName): $($parseErrors.Message -join '; ')" }
}
Write-Host "PowerShell syntax: $($scripts.Count) files passed."
if (Get-Command node.exe -ErrorAction SilentlyContinue) {
    foreach ($file in Get-ChildItem -LiteralPath (Join-Path $repo 'deployment-check\public') -Filter '*.js') {
        & node.exe --check $file.FullName
        if ($LASTEXITCODE -ne 0) { throw "JavaScript parse failed: $($file.Name)" }
    }
} else { Write-Host 'Node is absent; JS syntax check skipped. PowerShell tests still run.' }
& (Join-Path $repo 'deployment-check\tests\smoke.ps1')
& (Join-Path $repo 'deployment-check\tests\deployment.ps1')
& (Join-Path $repo 'deployment-check\tests\node-setup.ps1')
& (Join-Path $repo 'deployment-check\tests\gateway-access.ps1')
Write-Host 'All project checks passed.'
