#requires -Version 7.0
param([string]$OutputDirectory = (Join-Path $PSScriptRoot '..\dist'))
$ErrorActionPreference = 'Stop'
$source = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\packages\windows'))
$manifest = Get-Content -LiteralPath (Join-Path $source 'manifest.json') -Raw | ConvertFrom-Json
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$destination = [IO.Path]::GetFullPath((Join-Path $OutputDirectory ("OpenClawMeeting-Windows-$($manifest.version).zip")))
if (Test-Path -LiteralPath $destination) { throw "Output already exists: $destination. Choose another OutputDirectory or move the previous artifact first." }
[IO.Compression.ZipFile]::CreateFromDirectory($source, $destination, [IO.Compression.CompressionLevel]::Optimal, $true)
$hash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant()
"$hash  $([IO.Path]::GetFileName($destination))" | Set-Content -LiteralPath ($destination + '.sha256') -Encoding utf8
Write-Host "Package: $destination"
Write-Host "SHA256: $hash"
