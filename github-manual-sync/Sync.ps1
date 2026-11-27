[CmdletBinding()]
param(
    [string]$ConfigPath,
    [switch]$PauseOnExit
)

$ErrorActionPreference = 'Stop'
if (-not $ConfigPath) { $ConfigPath = Join-Path $PSScriptRoot 'config.json' }

# Windows PowerShell cannot pass literal double quotes or empty arguments to
# native commands reliably. Quote arguments once for the Windows process API.
function ConvertTo-ProcessArgument([string]$Value) {
    if ($Value.Length -gt 0 -and $Value -notmatch '[\s"]') { return $Value }
    $escaped = [regex]::Replace($Value, '(\\*)"', '$1$1\"')
    $escaped = [regex]::Replace($escaped, '(\\+)$', '$1$1')
    return '"' + $escaped + '"'
}

function Invoke-Git {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [int[]]$AllowedExitCodes = @(0),
        [string]$InputText,
        [string]$Advice = '请查看 Git 的错误信息。'
    )

    $start = [System.Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $gitPath
    $start.WorkingDirectory = $repositoryPath
    $start.Arguments = ($Arguments | ForEach-Object { ConvertTo-ProcessArgument $_ }) -join ' '
    $start.UseShellExecute = $false
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.RedirectStandardInput = $true
    $encoding = [System.Text.UTF8Encoding]::new($false)
    $start.StandardOutputEncoding = $encoding
    $start.StandardErrorEncoding = $encoding
    $start.EnvironmentVariables['GIT_TERMINAL_PROMPT'] = '0'
    $start.EnvironmentVariables['GCM_INTERACTIVE'] = 'never'
    $start.EnvironmentVariables['GIT_NO_REPLACE_OBJECTS'] = '1'
    $start.EnvironmentVariables['GIT_NO_LAZY_FETCH'] = '1'
    $start.EnvironmentVariables['GIT_OPTIONAL_LOCKS'] = '0'
    foreach ($name in @('GIT_DIR', 'GIT_WORK_TREE', 'GIT_INDEX_FILE', 'GIT_COMMON_DIR', 'GIT_NAMESPACE', 'GIT_LITERAL_PATHSPECS', 'GIT_GLOB_PATHSPECS', 'GIT_NOGLOB_PATHSPECS', 'GIT_ICASE_PATHSPECS')) {
        $start.EnvironmentVariables.Remove($name)
    }
    if ($sshCommand) {
        $start.EnvironmentVariables['GIT_SSH_COMMAND'] = $sshCommand
    }

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $start
    try {
        [void]$process.Start()
        $outputTask = $process.StandardOutput.ReadToEndAsync()
        $errorTask = $process.StandardError.ReadToEndAsync()
        try {
            if ($PSBoundParameters.ContainsKey('InputText')) {
                $bytes = $encoding.GetBytes($InputText)
                $process.StandardInput.BaseStream.Write($bytes, 0, $bytes.Length)
            }
        } catch [System.IO.IOException] {
            # Git may exit before reading stdin. Its exit status explains why.
        } finally {
            $process.StandardInput.Close()
        }
        $process.WaitForExit()
        $result = [pscustomobject]@{
            ExitCode = $process.ExitCode
            Output = $outputTask.GetAwaiter().GetResult()
            Error = $errorTask.GetAwaiter().GetResult()
        }
    } finally {
        $process.Dispose()
    }

    if ($result.ExitCode -notin $AllowedExitCodes) {
        $details = ($result.Error.Trim(), $result.Output.Trim() | Where-Object { $_ }) -join "`n"
        $commandIndex = 0
        while ($Arguments[$commandIndex] -eq '-c') { $commandIndex += 2 }
        throw "git $($Arguments[$commandIndex]) 失败（退出码 $($result.ExitCode)）。`n$details`n$Advice"
    }
    return $result
}

function Format-PathForDisplay([string]$Path) {
    return [regex]::Replace($Path, '[\x00-\x1f\x7f\u202a-\u202e\u2066-\u2069]', {
        param($match)
        '\u{0:X4}' -f [int][char]$match.Value
    })
}

function Get-Head {
    return (Invoke-Git -Arguments @('rev-parse', '--verify', '--quiet', 'HEAD') -AllowedExitCodes @(0, 1)).Output.Trim()
}

function Assert-RepositoryReady {
    $branchResult = Invoke-Git -Arguments @('symbolic-ref', '--quiet', 'HEAD') -AllowedExitCodes @(0, 1)
    $currentRef = $branchResult.Output.Trim()
    if ($currentRef -cne $targetRef) {
        $currentBranch = $currentRef -creplace '^refs/heads/', ''
        if (-not $currentBranch) { $currentBranch = '分离的 HEAD' }
        throw "当前分支为 $currentBranch，配置要求 $branch。请手动切换到目标分支后重试。"
    }

    foreach ($marker in @('MERGE_HEAD', 'CHERRY_PICK_HEAD', 'REVERT_HEAD', 'rebase-merge', 'rebase-apply', 'sequencer', 'BISECT_START')) {
        $path = (Invoke-Git -Arguments @('rev-parse', '--git-path', $marker)).Output.TrimEnd("`r", "`n")
        if (-not [IO.Path]::IsPathRooted($path)) { $path = Join-Path $repositoryPath $path }
        if (Test-Path -LiteralPath $path) {
            throw "仓库中存在进行中的 Git 操作（$marker）。请先完成或取消该操作。"
        }
    }
}

function Test-ExcludedPath([string]$Path) {
    foreach ($rule in $ignorePatterns) {
        if ($rule.IsMatch($Path)) { return $true }
    }
    return $false
}

function Assert-RemoteUrlUnchanged {
    $rewrites = Invoke-Git -Arguments @('config', '--null', '--get-regexp', '^url\..*\.(insteadof|pushinsteadof)$') -AllowedExitCodes @(0, 1)
    foreach ($record in $rewrites.Output.Split([char[]]@(0), [StringSplitOptions]::RemoveEmptyEntries)) {
        $separator = $record.IndexOf("`n")
        if ($separator -ge 0 -and $url.StartsWith($record.Substring($separator + 1), [StringComparison]::Ordinal)) {
            throw 'Git 的 URL 重写规则命中了同步地址。请检查 insteadOf 和 pushInsteadOf 配置。'
        }
    }
}

function Get-StagedPaths {
    $result = Invoke-Git -Arguments @('diff', '--cached', '--no-renames', '--name-only', '--ignore-submodules=none', '-z', '--')
    return $result.Output.Split([char[]]@(0), [StringSplitOptions]::RemoveEmptyEntries)
}

function Get-WorktreeChanges {
    $result = Invoke-Git -Arguments @('status', '--porcelain=v1', '-z', '--no-renames', '--untracked-files=all', '--ignore-submodules=dirty')
    $changes = [System.Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
    foreach ($entry in $result.Output.Split([char[]]@(0), [StringSplitOptions]::RemoveEmptyEntries)) {
        $state = $entry.Substring(0, 2)
        $path = $entry.Substring(3)
        if ($state -match 'U|^AA$|^DD$') {
            throw "存在未解决的冲突：$(Format-PathForDisplay $path)。请解决冲突后重试。"
        }
        if ($changes.ContainsKey($path)) {
            # A staged deletion followed by recreation appears twice.
            $changes[$path].Kind = '修改'
        } else {
            $kind = switch -Regex ($state) {
                'D$|^D' { '删除'; break }
                '^A|A$|^\?\?$' { '新增'; break }
                default { '修改' }
            }
            # With --untracked-files=all, a trailing slash denotes an embedded repo.
            $excluded = $path.EndsWith('/') -or (Test-ExcludedPath $path)
            $changes.Add($path, [pscustomobject]@{ Path = $path; Kind = $kind; Excluded = $excluded })
        }
    }
    return $changes.Values | Sort-Object -Property Path -CaseSensitive
}

function Assert-TrackableIndex {
    $excluded = @(Get-StagedPaths | Where-Object { Test-ExcludedPath $_ })
    if ($excluded.Count -gt 0) {
        $paths = ($excluded | ForEach-Object { Format-PathForDisplay $_ }) -join "`n"
        throw "暂存区包含排除规则命中的路径。请先用 git restore --staged -- <路径> 取消暂存，首次提交前可用 git rm --cached -- <路径>。`n$paths"
    }
}

function Get-PendingCommits([string]$Head, [string]$RemoteHead) {
    if (-not $Head) { return }
    $arguments = @('rev-list', $Head)
    if ($RemoteHead) { $arguments += "^$RemoteHead" }
    $result = Invoke-Git -Arguments $arguments
    return $result.Output.Split([char[]]@(10), [StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object { $_.Trim() }
}

function Assert-PublishableHistory([string[]]$Commits) {
    if ($Commits.Count -eq 0) { return }
    $result = Invoke-Git -Arguments @('diff-tree', '--stdin', '--root', '-m', '-r', '--no-commit-id', '--no-renames', '--ignore-submodules=none', '--name-only', '--diff-filter=ACMTUXB', '-z') -InputText (($Commits -join "`n") + "`n")
    $excluded = @($result.Output.Split([char[]]@(0), [StringSplitOptions]::RemoveEmptyEntries) | Where-Object { Test-ExcludedPath $_ } | Sort-Object -Unique)
    if ($excluded.Count -gt 0) {
        $paths = ($excluded | ForEach-Object { Format-PathForDisplay $_ }) -join "`n"
        throw "待上传历史中包含排除规则命中的文件。请先检查并清理有关本地提交。仅在新提交中删除文件，较早提交仍会包含它。`n$paths"
    }
}

$exitCode = 0
$mutex = $null
$mutexAcquired = $false
$noChanges = $false

try {
    Write-Host "`nGitHub 手动同步工具`n"
    $git = Get-Command git.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $git) { throw '找不到 Git。请安装 Git for Windows，并确保 git.exe 在 PATH 中。' }
    $gitPath = $git.Source
    $configFile = Get-Item -LiteralPath $ConfigPath -ErrorAction SilentlyContinue
    if (-not $configFile -or $configFile.PSIsContainer) {
        throw "找不到配置文件 $ConfigPath。请将 config.example.json 复制为 config.json 并填写仓库信息。"
    }
    $config = Get-Content -LiteralPath $configFile.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
    $repositories = @($config.repositories | Where-Object { $null -ne $_ })
    if ($repositories.Count -eq 0) { throw '配置文件中的 repositories 为空，请先填写仓库。' }

    $repository = $repositories[0]
    if ($repositories.Count -gt 1) {
        for ($i = 0; $i -lt $repositories.Count; $i++) {
            Write-Host ('[{0}] {1} ({2})' -f ($i + 1), $repositories[$i].name, $repositories[$i].path)
        }
        $choice = Read-Host '输入仓库编号，或按 Enter 退出'
        if (-not $choice) { return }
        $number = 0
        if (-not [int]::TryParse($choice, [ref]$number) -or $number -lt 1 -or $number -gt $repositories.Count) {
            throw '仓库编号无效，请重新运行并选择列表中的编号。'
        }
        $repository = $repositories[$number - 1]
    }

    foreach ($property in @('path', 'branch', 'commitMessageFormat')) {
        if ($repository.$property -isnot [string] -or [string]::IsNullOrWhiteSpace($repository.$property)) {
            throw "仓库配置中的 $property 必须是非空字符串。"
        }
    }
    $configuredPath = $repository.path
    if ($configuredPath -notmatch '^(?:[A-Za-z]:[\\/]|\\\\)') {
        $configuredPath = Join-Path $configFile.DirectoryName $configuredPath
    }
    $directory = Get-Item -LiteralPath $configuredPath -ErrorAction SilentlyContinue
    if (-not $directory -or -not $directory.PSIsContainer -or $directory.PSProvider.Name -ne 'FileSystem') {
        throw "仓库目录不存在：$configuredPath。请检查配置中的 path。"
    }
    $repositoryPath = $directory.FullName
    $branch = $repository.branch
    $targetRef = "refs/heads/$branch"
    $url = $repository.remoteUrl
    if ($url -isnot [string] -or [string]::IsNullOrWhiteSpace($url)) {
        throw "请在 $($configFile.FullName) 的 remoteUrl 中填写 GitHub 仓库地址。"
    }
    if ($url -notmatch '^(?:git@github\.com:|ssh://git@github\.com/|ssh://git@ssh\.github\.com:443/|https://github\.com/)[A-Za-z0-9][A-Za-z0-9-]*/[A-Za-z0-9_.-]+\z') {
        throw 'remoteUrl 必须是 GitHub 仓库的 SSH 或 HTTPS 地址，且不能包含密码、Token 或查询字符串。'
    }
    if (-not $repository.commitMessageFormat.Contains('{timestamp}') -or $repository.commitMessageFormat -match '[\x00-\x1f]') {
        throw 'commitMessageFormat 必须是包含 {timestamp} 的单行文本。'
    }

    $defaultRules = @(
        '.env', '.env.*', '*.env', '.ssh', '.aws', '.gnupg', '.netrc', '_netrc', '.git-credentials',
        '.npmrc', '.pypirc', 'id_rsa*', 'id_dsa*', 'id_ecdsa*', 'id_ed25519*', '*.pem', '*.key',
        '*.ppk', '*.p12', '*.pfx', '*.kdbx', '.kube', 'credentials*.json', 'secrets*.json',
        'service-account*.json', 'passwords.*', 'password.txt', 'tokens.*', 'secrets', 'credentials',
        '.envrc', '.codex', '.agents', '.azure', 'auth.json'
    )
    if ($null -ne $repository.ignoreRules -and $repository.ignoreRules -isnot [array]) {
        throw 'ignoreRules 必须是字符串数组。'
    }
    $ignorePatterns = @(foreach ($rule in ($defaultRules + @($repository.ignoreRules | Where-Object { $null -ne $_ }))) {
        if ($rule -isnot [string] -or [string]::IsNullOrWhiteSpace($rule) -or $rule -match '[\\\x00-\x1f]|^/|/$') {
            throw 'ignoreRules 中的规则须为非空字符串，路径用 /，首尾无需斜杠。'
        }
        if ($rule.Contains('/')) {
            $pattern = '^' + [regex]::Escape($rule).Replace('\*', '.*').Replace('\?', '[^/]') + '$'
        } else {
            $pattern = '(?:^|/)' + [regex]::Escape($rule).Replace('\*', '[^/]*').Replace('\?', '[^/]') + '(?:/|$)'
        }
        [regex]::new($pattern, [Text.RegularExpressions.RegexOptions]'IgnoreCase, CultureInvariant')
    })

    $sshCommand = $null
    $top = (Invoke-Git -Arguments @('rev-parse', '--show-toplevel') -Advice '请确认 path 指向已初始化的 Git 工作区。').Output.TrimEnd("`r", "`n")
    if ([IO.Path]::GetFullPath($top).TrimEnd('\', '/') -ine [IO.Path]::GetFullPath($repositoryPath).TrimEnd('\', '/')) {
        throw "path 必须指向仓库根目录。Git 识别的根目录为 $top。"
    }
    [void](Invoke-Git -Arguments @('check-ref-format', $targetRef) -Advice '请检查配置中的分支名称。')
    $lockPath = (Invoke-Git -Arguments @('rev-parse', '--absolute-git-dir')).Output.TrimEnd("`r", "`n")
    $sha256 = [Security.Cryptography.SHA256]::Create()
    try {
        $hash = [BitConverter]::ToString($sha256.ComputeHash([Text.Encoding]::UTF8.GetBytes($lockPath.ToUpperInvariant()))).Replace('-', '')
    } finally { $sha256.Dispose() }
    $mutex = [Threading.Mutex]::new($false, "Local\GitHubManualSync_$hash")
    try { $mutexAcquired = $mutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $mutexAcquired = $true }
    if (-not $mutexAcquired) { throw '该工作区已有同步窗口正在运行。请等待它结束后重试。' }

    Assert-RepositoryReady
    $head = Get-Head
    if ($url.StartsWith('git@', [StringComparison]::OrdinalIgnoreCase) -or $url.StartsWith('ssh://', [StringComparison]::OrdinalIgnoreCase)) {
        $configuredSsh = (Invoke-Git -Arguments @('config', '--get', 'core.sshCommand') -AllowedExitCodes @(0, 1)).Output.Trim()
        if (-not $env:GIT_SSH_COMMAND -and -not $env:GIT_SSH -and -not $configuredSsh) {
            $sshCommand = 'ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=yes -o UpdateHostKeys=no'
        }
    }

    $name = $repository.name
    if ([string]::IsNullOrWhiteSpace($name)) { $name = $directory.Name }
    Write-Host "仓库：$name`n目录：$repositoryPath`n远程：$url`n分支：$branch`n"
    Write-Host '正在检查 GitHub 连接和远程分支…'

    Assert-RemoteUrlUnchanged
    $remoteArguments = @('-c', 'http.followRedirects=false')
    $remoteResult = Invoke-Git -Arguments ($remoteArguments + @('ls-remote', '--exit-code', '--refs', '--heads', $url, $targetRef)) -AllowedExitCodes @(0, 2) -Advice '请检查 GitHub 地址、网络及 SSH 密钥或 HTTPS 凭据。若提示主机密钥未知，请先通过 GitHub 官方说明核对并建立信任。'
    $remoteHead = ''
    if ($remoteResult.ExitCode -eq 0) {
        $remoteLine = $remoteResult.Output.TrimEnd("`r", "`n")
        $remoteFields = $remoteLine.Split("`t")
        if ($remoteFields.Count -ne 2 -or $remoteFields[0] -notmatch '^[0-9a-f]{40}(?:[0-9a-f]{24})?$' -or $remoteFields[1] -cne $targetRef) {
            throw 'GitHub 返回了无法识别的分支信息。请检查配置后重试。'
        }
        $remoteHead = $remoteFields[0]
        $available = $false
        if ($head) {
            $available = (Invoke-Git -Arguments @('cat-file', '-e', "$remoteHead`^{commit}") -AllowedExitCodes @(0, 1, 128)).ExitCode -eq 0
        }
        if (-not $available -or (Invoke-Git -Arguments @('merge-base', '--is-ancestor', $remoteHead, $head) -AllowedExitCodes @(0, 1)).ExitCode -ne 0) {
            throw "GitHub 上的 $branch 含有本地当前分支未纳入的提交。请先手动获取并整合远程历史，再运行同步。"
        }
    } elseif ((Invoke-Git -Arguments @('rev-parse', '--is-shallow-repository')).Output.Trim() -eq 'true') {
        throw '本地仓库为浅克隆，无法审核新建远程分支所需的完整历史。请先手动补齐历史。'
    }

    Assert-TrackableIndex
    $changes = @(Get-WorktreeChanges)
    $included = @($changes | Where-Object { -not $_.Excluded })
    $excludedCount = $changes.Count - $included.Count
    $pending = @(Get-PendingCommits $head $remoteHead)
    Assert-PublishableHistory $pending
    foreach ($kind in @('新增', '修改', '删除')) {
        $items = @($included | Where-Object { $_.Kind -eq $kind })
        Write-Host ('{0}文件：{1}' -f $kind, $items.Count)
        foreach ($item in $items) { Write-Host ('  ' + (Format-PathForDisplay $item.Path)) }
    }
    if ($excludedCount -gt 0) { Write-Host "排除规则已跳过 $excludedCount 个变更路径。" }
    Write-Host "已有待上传提交：$($pending.Count)"
    if ($included.Count -eq 0 -and $pending.Count -eq 0) {
        Write-Host '无需同步。'
        $noChanges = $true
        return
    }

    $prompt = if ($included.Count -gt 0) { '输入 Y 确认提交并上传，其他输入取消' } else { '输入 Y 上传待同步提交，其他输入取消' }
    if ((Read-Host $prompt) -ine 'Y') {
        Write-Host '已取消。'
        return
    }
    Assert-RepositoryReady
    if ((Get-Head) -cne $head) { throw '确认期间分支提交发生变化。请重新运行并检查变更列表。' }
    Assert-TrackableIndex
    $current = @(Get-WorktreeChanges | Where-Object { -not $_.Excluded })
    $approved = [System.Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal)
    foreach ($item in $included) { $approved.Add($item.Path, $item.Kind) }
    if ($current.Count -ne $included.Count) { throw '确认期间变更列表发生变化。请重新运行并确认。' }
    foreach ($item in $current) {
        if (-not $approved.ContainsKey($item.Path) -or $approved[$item.Path] -ne $item.Kind) {
            throw '确认期间变更列表发生变化。请重新运行并确认。'
        }
    }

    if ($included.Count -gt 0) {
        $pathspecs = ($included | ForEach-Object { ':(top,literal)' + $_.Path }) -join [char]0
        [void](Invoke-Git -Arguments @('add', '-A', '--pathspec-from-file=-', '--pathspec-file-nul') -InputText ($pathspecs + [char]0) -Advice '请检查文件访问权限和 .gitignore，然后重试。')
        $staged = @(Get-StagedPaths)
        foreach ($path in $staged) {
            if ((Test-ExcludedPath $path) -or -not $approved.ContainsKey($path)) {
                throw "暂存区出现未获确认的路径：$(Format-PathForDisplay $path)。请用 git status 检查暂存区后重试。"
            }
        }
        if ($staged.Count -gt 0) {
            Assert-RepositoryReady
            if ((Get-Head) -cne $head) { throw '暂存期间分支提交发生变化。请检查仓库状态后重试。' }
            $tree = (Invoke-Git -Arguments @('write-tree')).Output.Trim()
            $previousHead = $head
            $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz'
            $message = $repository.commitMessageFormat.Replace('{timestamp}', $timestamp)
            $commit = Invoke-Git -Arguments @('commit', '-m', $message) -Advice '请检查 Git 的 user.name、user.email、签名或提交钩子设置。文件可能仍在暂存区。'
            Write-Host $commit.Output.TrimEnd()
            if ($commit.Error.Trim()) { Write-Host $commit.Error.TrimEnd() }
            $head = Get-Head
            $actualTree = (Invoke-Git -Arguments @('rev-parse', "$head`^{tree}")).Output.Trim()
            $parents = (Invoke-Git -Arguments @('show', '-s', '--format=%P', $head)).Output.Trim()
            if ($actualTree -cne $tree -or $parents -cne $previousHead) {
                throw '提交内容与确认后暂存的内容不同。本地提交已保留，请检查提交及 Git 钩子后重试。'
            }
        }
    }
    $pending = @(Get-PendingCommits $head $remoteHead)
    if ($pending.Count -eq 0) {
        Write-Host '没有可提交或上传的变更。'
        $noChanges = $true
        return
    }
    Assert-PublishableHistory $pending
    Assert-RemoteUrlUnchanged
    Write-Host '正在上传到 GitHub…'
    $pushArguments = $remoteArguments + @('push', '--porcelain', '--no-follow-tags', '--recurse-submodules=no', $url, "${head}:$targetRef")
    $push = Invoke-Git -Arguments $pushArguments -Advice '本地提交已保留。网络或认证恢复后可重新运行；如远程分支已更新，请手动整合远程提交后重试。'
    if ($push.Output.Trim()) { Write-Host $push.Output.TrimEnd() }
    if ($push.Error.Trim()) { Write-Host $push.Error.TrimEnd() }
    Write-Host '同步成功。' -ForegroundColor Green
} catch {
    $exitCode = 1
    Write-Host $_.Exception.Message -ForegroundColor Red
} finally {
    if ($mutexAcquired) { $mutex.ReleaseMutex() }
    if ($mutex) { $mutex.Dispose() }
    if ($PauseOnExit) {
        if ($noChanges) { Start-Sleep -Seconds 3 }
        else { [void](Read-Host '按 Enter 关闭窗口') }
    }
}

exit $exitCode
