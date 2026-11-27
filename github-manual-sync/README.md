# Windows GitHub 手动同步工具

双击桌面上的「同步到 GitHub」即可检查指定仓库。工具列出新增、修改、删除的文件和待上传提交数，输入 `Y` 后暂存列出的文件、创建带时间戳的提交，并上传到配置的分支。一次运行对应一次同步。工具在前台运行，关闭窗口即结束。

## 初始化

1. 确认 `git --version` 可用，使用 Git for Windows 和 Windows PowerShell 5.1 或 PowerShell 7。
2. 创建 GitHub 仓库。首次上传已有本地项目时，可创建空仓库。如果 GitHub 目标分支已有提交，先克隆该仓库，或在本地手动整合双方历史。
3. 在本工具目录复制配置模板，再编辑 `config.json`。已有配置时直接编辑原文件。

   ```powershell
   Copy-Item .\config.example.json .\config.json
   notepad .\config.json
   ```

4. `path` 填本地 Git 仓库根目录。对于尚未纳入 Git 的文件夹，在其根目录运行 `git init -b main`，其中 `main` 应与配置分支一致。既有仓库使用当前分支或手动切换到配置分支。首次提交前如有需要，在仓库根目录设置提交身份。

   ```powershell
   git config user.name "你的名字"
   git config user.email "你的提交邮箱"
   ```

5. 建立 GitHub 认证。SSH 地址使用 `git@github.com:OWNER/REPO.git`。先配置 SSH 密钥，再运行 `ssh -T git@github.com`。首次连接时核对主机指纹。GitHub 确认认证成功的 SSH 测试会显示账号名，退出码为 `1`。 [配置 SSH](https://docs.github.com/en/authentication/connecting-to-github-with-ssh) · [测试 SSH](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/testing-your-ssh-connection) · [核对主机指纹](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints)

   只授权给目标仓库时，可将专用 SSH 公钥添加到该仓库的 Deploy Keys，并开启写权限。私钥留在本机。如果使用非默认密钥路径，可在本地仓库的 Git 配置中用 `core.sshCommand` 指定身份文件。 [管理 Deploy Keys](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/managing-deploy-keys)

   HTTPS 地址使用 `https://github.com/OWNER/REPO.git`。提前用 Git Credential Manager 登录，例如运行 `git credential-manager github login`，也可以用 `gh auth login` 并选择为 Git 配置 HTTPS 凭据。 [GitHub HTTPS 认证说明](https://docs.github.com/en/get-started/git-basics/caching-your-github-credentials-in-git)

## 安装、运行与卸载

在项目目录运行以下命令创建当前用户的桌面快捷方式。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1
```

双击「同步到 GitHub」。多仓库配置会先显示选择菜单。确认或取消后可按 Enter 关闭窗口。没有变更或待上传提交时，窗口短暂显示结果后自动关闭。

也可在终端运行，或指定另一份配置。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Sync.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Sync.ps1 -ConfigPath 'E:\配置\github-sync.json'
```

卸载脚本删除由当前项目目录创建的快捷方式。移动项目目录前，先从原目录卸载快捷方式。命令中的 `-ExecutionPolicy Bypass` 只作用于本次 PowerShell 进程。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Uninstall.ps1
```

## 配置字段

| 字段 | 用法 |
| --- | --- |
| `name` | 显示名称，可省略 |
| `path` | 本地仓库根目录。支持绝对路径和以配置文件所在目录为基准的相对路径。JSON 中可用 `/` 或 `\\` |
| `remoteUrl` | GitHub 仓库的 SSH 或 HTTPS 地址。可以使用 `ssh://git@ssh.github.com:443/OWNER/REPO.git` |
| `branch` | 要上传的分支。运行时本地必须位于此分支 |
| `commitMessageFormat` | 含 `{timestamp}` 的单行模板。时间戳使用本机时间和时区，例如 `2026-11-24 14:30:00 +08:00` |
| `ignoreRules` | 额外排除规则数组，可省略。向 `repositories` 添加对象即可配置其他仓库 |

Git 按仓库的 `.gitignore` 处理未跟踪路径。工具另有敏感文件排除规则，覆盖 `.env`、`.ssh`、常见密钥、凭据文件和目录。规则忽略大小写。没有 `/` 的规则匹配任一文件名或目录名，例如 `*.local.json`。包含 `/` 的规则从仓库根目录匹配，例如 `drafts/*` 覆盖草稿目录及其子目录中的文件。`*` 匹配任意长度，`?` 匹配一个非 `/` 字符。

排除规则同时检查暂存区和待上传提交历史。暂存区命中时，根据提示手动取消暂存。若历史命中，须清理含该文件的本地提交，之后才能上传。路径规则无法识别普通文件正文中的密码或 Token，请在确认前检查变更内容。

## 同步失败时

- **认证或网络异常**。先用终端验证 SSH 连接或 HTTPS 登录。推送阶段失败时，已创建的提交保留在本地。再次启动，即使工作区干净也会列出待上传提交。
- **远程已有其他提交**。工具用 `git ls-remote` 查询远程分支，发现本地无法验证远程提交已纳入当前分支时会停止。请手动检查和整合远程历史。正常上传使用 Git 的快进保护。
- **仓库正在合并或变基**。先在 Git 中完成当前操作，再尝试同步。
- **上传被 GitHub 拒绝**。终端会保留 Git 的拒绝原因。分支保护要求走 Pull Request 时，应按仓库规则处理。
