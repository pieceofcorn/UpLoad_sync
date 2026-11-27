[CmdletBinding()]
param(
    [string]$DesktopDirectory = [Environment]::GetFolderPath('DesktopDirectory')
)

$ErrorActionPreference = 'Stop'

try {
    $scriptPath = Join-Path $PSScriptRoot 'Sync.ps1'
    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) { throw '找不到 Sync.ps1，请保留完整项目目录。' }
    if (-not $DesktopDirectory -or -not (Test-Path -LiteralPath $DesktopDirectory -PathType Container)) {
        throw '找不到桌面目录。请检查 Windows 桌面位置，或使用 -DesktopDirectory 指定目录。'
    }

    $linkPath = Join-Path $DesktopDirectory '同步到 GitHub.lnk'
    $description = "GitHub Manual Sync | $PSScriptRoot"
    $shell = New-Object -ComObject WScript.Shell
    if (Test-Path -LiteralPath $linkPath) {
        if ((Get-Item -LiteralPath $linkPath -Force).Attributes -band ([IO.FileAttributes]::Directory -bor [IO.FileAttributes]::ReparsePoint)) {
            throw "同名路径已存在：$linkPath。"
        }
        $existing = $shell.CreateShortcut($linkPath)
        if ($existing.Description -cne $description -or $existing.Arguments -notlike "*`"$([WildcardPattern]::Escape($scriptPath))`"*") {
            throw "已存在同名快捷方式：$linkPath。请先处理该快捷方式。"
        }
        Write-Host "快捷方式已安装：$linkPath"
        return
    }

    $powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $shortcut = $shell.CreateShortcut($linkPath)
    $shortcut.TargetPath = $powershell
    $shortcut.Arguments = "-NoLogo -NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -PauseOnExit"
    $shortcut.WorkingDirectory = $PSScriptRoot
    $shortcut.Description = $description
    $shortcut.Save()
    Write-Host "已创建快捷方式：$linkPath"
} catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
