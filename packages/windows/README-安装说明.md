# OpenClawMeeting Lite 安装说明

本包为轻量版交付包，不内置 Node.js 和完整 OpenClaw `node_modules`。

本包安装脚本只支持 PowerShell 7 `pwsh.exe`。Windows 自带 PowerShell 5.1 `powershell.exe` 不再支持，避免现场因旧版 PowerShell 解析脚本导致安装失败。

安装时会检查本机系统 Node.js：

- 本包只使用系统 Node.js / npm，不再下载或使用 `D:\OpenClawMeeting\runtime` 下的私有 Node.js。
- 系统必须已有 `node.exe` 和 `npm.cmd`，且 Node.js 版本不低于 `24.16.0`，并且 `npm -v` 可正常执行。
- 若系统 Node.js / npm 不可用，安装会直接停止，请先安装系统 Node.js 后再运行安装包。
- `openclaw@2026.6.1`

安装脚本固定安装 `openclaw@2026.6.1`，不会跟随 npm `latest` 漂移。

安装时会询问是否安装 7 个业务能力：

- 直接回车：安装业务增强版，预置 7 个业务 Skill、业务 SOUL、业务资料目录和禁用状态的业务定时任务模板。
- 输入 `N`：安装基础版，不安装 7 个业务 Skill，不使用 7 功能 SOUL，只保留通用文件问答、文档总结、材料起草、表格整理和操作说明，并尝试清理本包预置的业务定时任务。

命令行静默选择基础版：

```cmd
install.cmd -SkipBusinessSkills
```

## 使用方式

双击运行：

```cmd
install.cmd
```

`install.cmd` 会自动查找 PowerShell 7。若提示找不到 `pwsh.exe`，请先安装 PowerShell 7，常见路径为：

```text
C:\Program Files\PowerShell\7\pwsh.exe
```

默认安装到：

```text
D:\OpenClawMeeting
```

默认本机访问地址：

```text
http://127.0.0.1:18789/
```

0.3.0 起每次新装自动生成随机 Gateway token，保存在安装目录 `config/openclaw.json` 的 `gateway.auth.token`。打开控制台时使用这个值完成认证。

通过仓库 H5 检查台安装时，上传由 `scripts/build-package.ps1` 生成的 ZIP，点击“解压并一键部署”即可。网页仅接受新的空目录，先确保系统 Node.js / npm 可用；Key 可以留空后续配置。

## 安装系统 Node.js

本包只使用系统 Node.js / npm。若安装器提示没有 `node.exe` 或 `npm.cmd`，先在 CMD 或 PowerShell 中执行：

```cmd
winget install OpenJS.NodeJS --accept-package-agreements --accept-source-agreements
```

如果机器已有旧版 Node.js，需要升级：

```cmd
winget upgrade OpenJS.NodeJS --accept-package-agreements --accept-source-agreements
```

安装或升级完成后，关闭当前 CMD / PowerShell 窗口，重新打开，再验证：

```cmd
node -v
npm -v
```

确认 Node.js 版本不低于 `v24.16.0` 后，再运行：

```cmd
install.cmd
```

## 注意事项

- 安装前必须先安装系统 Node.js，安装时只需要能访问 npm 镜像源。
- 默认 npm 镜像源为 `https://registry.npmmirror.com`。
- 本包只配置本机访问，不配置局域网访问，不开放防火墙。
- 安装完成后会为当前 Windows 用户创建登录自启动项，用户登录后自动启动本机 Gateway；不会注册 Windows 服务。
- 如需关闭登录自启动，运行 `D:\OpenClawMeeting\disable-autostart.ps1`；如需重新开启，运行 `D:\OpenClawMeeting\enable-autostart.ps1`。
- 本包关闭自动更新和启动查新提示：配置 `update.auto.enabled=false`、`update.checkOnStart=false`，启动环境写入 `OPENCLAW_NO_AUTO_UPDATE=1`。
- 本包会按安装模式预置对应的 `SOUL.md`、`AGENTS.md`、`WORKSPACE_GUIDE.md` 和 `资料源索引.md` 到 `D:\OpenClawMeeting\workspace`；若已有同名文件，会先备份到 `D:\OpenClawMeeting\backup\workspace-时间戳`。
- 本包会在当前用户桌面创建 `龙虾工作台` 中文目录，供甲方日常放资料和取成果。
- 用户资料默认放到 `桌面\龙虾工作台\01-输入资料`，生成成果默认放到 `桌面\龙虾工作台\02-输出成果`。
- 合同资料放到 `桌面\龙虾工作台\01-输入资料\合同资料`；其他资料优先放到 `桌面\龙虾工作台\01-输入资料\综合资料源`。
- 输出成果优先使用 WPS 可直接打开的 `.docx`、`.xlsx`、`.pptx` 或 `.txt`，默认不向用户交付 `.md` 文件。
- 本包会安装固定 DOCX 导出工具：`D:\OpenClawMeeting\tools\export-docx.ps1`，用于把固定交付稿导出为基础 Word 文档，不依赖 Microsoft Word 或 Office。
- 本包会安装 DeepSeek Key 修改工具：`D:\OpenClawMeeting\tools\set-deepseek-key.ps1`，用于现场更换 `DEEPSEEK_API_KEY`，会自动备份 `openclaw-local.cmd`。
- 本包会安装企业微信配置工具：`D:\OpenClawMeeting\tools\set-wecom-config.ps1`，用于现场写入企微 Bot ID / Secret、放行 `wecom_mcp`，并清理会导致通道不启动的 `OPENCLAW_SKIP_CHANNELS`。
- 本包会安装 Node/npm 路径修复工具：`D:\OpenClawMeeting\tools\repair-node-npm-runtime.ps1`，用于把 `openclaw-local.cmd` 修正为使用系统 Node.js / npm。
- 本包会安装业务定时任务清理工具：`D:\OpenClawMeeting\tools\clear-business-cron-jobs.ps1`，用于删除本包预置的业务定时任务，不删除用户自建任务。
- 用户在聊天窗口询问 `功能列表`、`帮助`、`list`、`怎么用` 时，业务增强版会展示 7 个可用功能；基础版只展示通用文件问答、文档总结、材料起草、表格整理和操作说明。
- 本包预置 DeepSeek 静态模型目录：`deepseek-v4-flash`、`deepseek-v4-pro`、`deepseek-chat`、`deepseek-reasoner`。
- 已安装机器可直接运行 `tools\mount-workspace.ps1` 将交付版 soul 挂载到现有安装目录；加 `-Basic` 可切换为基础版 SOUL。
- 本包不包含会议视频、音频、转写文件、OCR 帧、运行日志和历史状态。
- 7 个业务能力默认会在安装过程中预置；如选择基础版，则不会安装这些业务 Skill，也不会写入 7 功能 SOUL。
- 如需在已安装机器上单独清理业务定时任务，先预览：`pwsh -NoProfile -ExecutionPolicy Bypass -File "D:\OpenClawMeeting\tools\clear-business-cron-jobs.ps1" -WhatIf`；确认后去掉 `-WhatIf` 执行。

## 桌面工作台目录

安装完成后，桌面会出现：

业务增强版：

```text
龙虾工作台
  01-输入资料
    综合资料源
    合同资料
    会议督办
    政策简报
    人力绩效
    战略执行
    员工行为
    管理优化
  02-输出成果
    会议督办
    合同审查
    政策简报
    人力绩效
    战略执行
    员工行为
    管理优化
  03-人工复核
  04-历史归档
```

基础版：

```text
龙虾工作台
  01-输入资料
    综合资料源
  02-输出成果
    通用成果
  03-人工复核
  04-历史归档
```

用户日常只需要使用桌面的 `龙虾工作台`，不需要进入 `D:\OpenClawMeeting` 内部运行目录。

## 修改 DeepSeek API Key

交互输入新 Key：

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "D:\OpenClawMeeting\tools\set-deepseek-key.ps1"
```

修改后自动重启 Gateway：

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "D:\OpenClawMeeting\tools\set-deepseek-key.ps1" -RestartGateway
```

## Node/npm 异常修复

如果历史安装曾经指向私有 Node.js，或 `openclaw-local.cmd` 里仍然写着 `D:\OpenClawMeeting\runtime\node-v24.16.0-win-x64`，直接运行修复脚本：

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "D:\OpenClawMeeting\tools\repair-node-npm-runtime.ps1"
```

修复脚本只会使用系统 Node.js / npm，不会下载私有 Node.js。

修复完成后，建议用以下命令验证：

```cmd
D:\OpenClawMeeting\openclaw-local.cmd --version
```

Windows 现场不要使用 `openclaw gateway restart` 作为重启方式。请使用：

```cmd
D:\OpenClawMeeting\stop-gateway.cmd
D:\OpenClawMeeting\start-gateway.cmd
```

## 企业微信配置

企业微信智能机器人使用 WebSocket 长连接模式时，先在企业微信后台拿到 `Bot ID` 和 `Secret`，再在本机执行：

先检查当前机器是否支持企微接入：

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "D:\OpenClawMeeting\tools\set-wecom-config.ps1" -CheckOnly
```

如果检查结果没有 `[FAIL]`，再写入配置：

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "D:\OpenClawMeeting\tools\set-wecom-config.ps1" -RestartGateway
```

脚本会提示输入：

```text
WeCom Bot ID
WeCom Secret
```

该脚本会自动完成：

- 写入 `channels.wecom`。
- 写入 `tools.alsoAllow=["wecom_mcp"]`，避免 `wecom_mcp 不在白名单中`。
- 清理 `openclaw-local.cmd` 中的 `OPENCLAW_SKIP_CHANNELS=1` 和 `OPENCLAW_SKIP_PROVIDERS=1`，避免 Gateway 启动时跳过企微通道。

验证命令：

```cmd
D:\OpenClawMeeting\openclaw-local.cmd channels list --all
D:\OpenClawMeeting\openclaw-local.cmd channels capabilities --channel wecom
```
