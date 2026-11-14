#requires -Version 7.0
$ErrorActionPreference = 'Stop'
$repository = Split-Path $PSScriptRoot -Parent
$launcher = Join-Path $repository '启动部署检查台.cmd'
if (-not (Test-Path -LiteralPath $launcher -PathType Leaf)) { throw 'Please extract the complete repository ZIP first.' }
$desktop = [Environment]::GetFolderPath('Desktop')
if (-not $desktop -or -not (Test-Path -LiteralPath $desktop -PathType Container)) { throw 'Windows desktop folder was not found.' }
$shortcutPath = Join-Path $desktop 'OpenClaw 部署检查台.lnk'
$shell = New-Object -ComObject WScript.Shell
try {
    $shortcut = $shell.CreateShortcut($shortcutPath)
    if ((Test-Path -LiteralPath $shortcutPath) -and $shortcut.TargetPath -and -not $shortcut.TargetPath.Equals($launcher, [StringComparison]::OrdinalIgnoreCase)) {
        $backup = $shortcutPath + '.' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.bak'
        Copy-Item -LiteralPath $shortcutPath -Destination $backup -ErrorAction Stop
    }
    $shortcut.TargetPath = $launcher
    $shortcut.WorkingDirectory = $repository
    $shortcut.Description = 'OpenClaw 安装、自检与维护入口'
    $shortcut.IconLocation = (Join-Path $env:SystemRoot 'System32\shell32.dll') + ',14'
    $shortcut.WindowStyle = 1
    $shortcut.Save()
    Write-Host "桌面快捷方式已创建：$shortcutPath"
    Write-Host '请保留解压后的完整文件夹；移动文件夹后，重新运行“创建桌面快捷方式.cmd”。'
} finally {
    if ($shortcut) { [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($shortcut) }
    [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($shell)
}
