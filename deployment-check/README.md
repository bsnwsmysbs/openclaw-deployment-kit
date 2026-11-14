# OpenClaw Windows 部署检查台

面向 Windows 七大场景交付版的本地 H5 自检页面。前提是已安装 PowerShell 7；检查台不依赖 Node.js、npm、Python、数据库或管理员权限。

## 启动

双击 `start.cmd`，会启动本地检测程序并打开浏览器：

```text
http://127.0.0.1:18890/
```

也可以在 PowerShell 7 中启动：

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\server.ps1
```

端口冲突时用 `-Port 18891`。关闭启动窗口即可停止检测程序。请完整复制本目录，不能只复制 HTML；直接双击 HTML 无法执行本机检查。

## 操作

1. 填写实际安装目录，默认为 `D:\OpenClawMeeting`。
2. 点击“开始全面自检”，每项显示等待、运行、通过、失败或待确认。
3. 失败项自动标红并展开原因和处理方法。其他检查继续执行。
4. Node.js/npm 缺失、过旧或无法执行时，会自动通过 winget 安装 Node.js LTS；若弹出系统授权窗口，请允许安装。页面展示进度与日志，实际验证通过后才继续。没有 winget 时需按提示手动安装。其他失败项按处理方法修复后，点击单项“重试”。
5. 完成实际对话、资料导出、重启验收后，勾选对应人工验收项。
6. 导出 TXT 检查报告，用于部署交接。

## 安装后补填 SK 密钥

确认上方是已有安装目录，在“补填／修改 SK 密钥”输入 DeepSeek `sk-…` 并点击“保存并检查密钥”。保存会备份并更新 `openclaw-local.cmd`，不更改网关令牌；不回显密钥，输入框在提交结束后清空。仅支持官方 DeepSeek 配置；若配置文件直接指定了其他 apiKey，会提示先处理配置，避免新密钥被覆盖。

模型目录检查通过仍需重启正在运行的网关：先运行安装目录 `stop-gateway.cmd`，再运行 `start-gateway.cmd`，随后实际对话确认。页面不自动重启现有网关。

## 轻量版一键部署

完整仓库包含最新 Windows Lite 0.3.0 的 `packages/windows/` 安装源码。网页自动选中它，填写可选 Key 和端口，点击“安装仓库自带轻量版”。无需另外下载、打包或上传 ZIP。页面显示安装进度与脱敏日志，失败标红，成功后自动全面自检。

若需使用单独的 ZIP，可展开“其他方式：上传轻量版 ZIP”。[Releases](https://github.com/bsnwsmysbs/openclaw-deployment-kit/releases/tag/v0.3.0) 提供轻量版 ZIP 与 SHA256，或运行根目录 `scripts/build-package.ps1` 生成相同源码包。

安装需要系统 Node >= 24.16.0 与 npm，只接受新的空目录。默认预置七大场景、桌面工作台和当前用户登录自启；业务定时任务禁用。ZIP 需逐文件匹配当前仓库源码，或匹配已登记旧版包的精确 SHA256。不要只分发本目录而遗漏安装源码。

## 检查范围与边界

- 系统架构、安装盘空间、PowerShell 7、Node >= 24.16.0、npm 的实际执行结果。
- npm 镜像上的 `openclaw@2026.6.1` 元数据及 DeepSeek 接口可达性；不保证所有依赖下载均成功。
- 安装入口、程序版本、本机配置、网关 HTTP 响应。
- DeepSeek 官方 `/models` 目录：验证密钥和默认模型名称，不生成对话、不检查余额。只将密钥发送到固定的 `https://api.deepseek.com/models`，不验证其他模型服务商或自定义地址。
- 七个业务技能、工作区指引、当前用户桌面输入/输出目录、DOCX 脚本和启动文件夹中的自启入口。
- 技能检查同时尝试 OpenClaw 的 `skills list --json`，只有七项全部就绪才显示绿色；命令无法确认时显示黄色，不将文件存在误判为已加载。
- 检查目标为七大场景业务增强版；基础版缺少业务 Skill 会显示失败，这是验收基准差异。
- 登录自启自动检查针对当前交付包的 VBS 启动文件夹方案，计划任务及 Windows 服务需人工核实。
- Skill 文件或导出工具存在不能证明业务成功，仍需实际使用验收。
- 普通检查不写入目标安装目录；Node/npm 检查可触发系统运行环境安装。“保存并检查密钥”会备份并修改目标启动配置；部署按钮会真实安装程序和启动网关。报告导出由浏览器下载到用户指定位置。

## 实现

`server.ps1` 使用 PowerShell 7 和 .NET TCP listener，仅绑定 `127.0.0.1`；静态 H5 页面和检测接口共用一个端口。没有前端构建或依赖安装步骤。检测接口只接受白名单检查 ID 与本地英文 Windows 路径；浏览器请求需要本次启动的会话令牌，并检查 Host/Origin。普通诊断和报告不返回 API Key 或 Gateway token；网关访问专用接口按页面需求读取并返回本机 Token，不返回模型密钥。

## 网关 Token 与访问地址

页面自动读取上方安装目录 `config/openclaw.json` 的真实 Token 与端口，支持重新读取、复制 Token 和打开 OpenClaw。Token 明文仅显示在当前本机页面，不写入检查报告、部署状态或日志。切换目录会清空旧 Token；读取不会重新生成或更改 Token。

部署验证成功后自动用系统默认浏览器打开带 `#token=…` 的本机地址，浏览器打开失败会提示手动复制地址和 Token。已有安装不会因刷新检查台反复打开浏览器，可点击“打开 OpenClaw”。打开前必须实际收到 OpenClaw 网关页面响应。

实现位于 `gateway-access.ps1` 和 `public/gateway-access.js`。`POST /api/gateway/access` 读取配置，`POST /api/gateway/open` 检查网关后调用系统浏览器；两者均受会话令牌与 Host/Origin 校验保护，响应禁止缓存，仅允许 loopback 配置。客户端不能指定打开的 URL，服务端根据验证后的配置构造地址。

```text
deployment-check/
  start.cmd
  server.ps1
  public/
    index.html
    style.css
    app.js
```

部署实现位于 `deployment.ps1` 和 `deploy-worker.ps1`，前端在 `public/deploy.js`。上传包与日志保存在 `%LOCALAPPDATA%\OpenClawDeploymentKit`；旧交付包原件保持不变。

Node 自动安装位于 `node-setup.ps1` 与 `public/node-setup.js`，接口为 `POST /api/node/setup`、`POST /api/node/status`；补填密钥位于 `model-key.ps1` 与 `public/model-key.js`，接口为 `POST /api/model/key`。这些操作均受会话令牌和同源校验保护。运行环境安装与程序部署互斥，安装运行中不要重启检查台；状态仅保存在当前服务进程内，原有日志留存在 LocalAppData。

## 验证

```powershell
pwsh -NoProfile -File ..\scripts\test.ps1
```

测试创建独立临时目录和随机本地端口，覆盖自检接口、ZIP 上传/校验/解压、隔离安装器成功与失败、并发拦截及日志脱敏，不修改现有 OpenClaw 安装、桌面和自启。
