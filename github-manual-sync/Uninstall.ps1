[CmdletBinding()]
param(
    [string]$DesktopDirectory = [Environment]::GetFolderPath('DesktopDirectory')
)

$ErrorActionPreference = 'Stop'

try {
    if (-not $DesktopDirectory -or -not (Test-Path -LiteralPath $DesktopDirectory -PathType Container)) {
        throw '找不到桌面目录。请检查 Windows 桌面位置，或使用 -DesktopDirectory 指定目录。'
    }
    $linkPath = Join-Path $DesktopDirectory '同步到 GitHub.lnk'
    $link = Get-Item -LiteralPath $linkPath -Force -ErrorAction SilentlyContinue
    if (-not $link) {
        Write-Host "未找到已安装的快捷方式：$linkPath"
        return
    }
    if ($link.Attributes -band ([IO.FileAttributes]::Directory -bor [IO.FileAttributes]::ReparsePoint)) {
        throw "同名路径已存在：$linkPath。"
    }

    $scriptPath = Join-Path $PSScriptRoot 'Sync.ps1'
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($linkPath)
    if ($shortcut.Description -cne "GitHub Manual Sync | $PSScriptRoot" -or $shortcut.Arguments -notlike "*`"$([WildcardPattern]::Escape($scriptPath))`"*") {
        throw "同名快捷方式来自其他安装：$linkPath。"
    }
    Remove-Item -LiteralPath $link.FullName -ErrorAction Stop
    Write-Host "已卸载快捷方式：$linkPath"
} catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
