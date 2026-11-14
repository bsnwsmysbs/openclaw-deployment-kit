# AI 接手上下文

## 一句话定位

Windows 上用 PowerShell 7 启动的本地 H5 工具。检查已安装环境，也支持从可信 Windows Lite ZIP 新装 OpenClaw 和七大业务场景。

用户启动入口位于仓库最外层 `启动部署检查台.cmd`，相对路径调用 `deployment-check/start.cmd`。部署检查台入口只放在解压目录最外层，不创建桌面快捷方式；完整文件夹可以一起移动。

默认使用仓库自带的最新轻量版 `packages/windows/`，无需用户准备第二份 ZIP。独立轻量版 ZIP 与 SHA256 发布在 GitHub Releases v0.3.0，与此目录逐文件一致。

## 阅读顺序

1. 根目录 `AGENTS.md`：仓库规则与入口。
2. 根目录 `README.md`：使用和测试。
3. 按任务只读需要的文件：
   - 检查项：`deployment-check/server.ps1` 中 `Check`。
   - 状态文案和检查列表：`deployment-check/public/app.js`。
   - 上传/部署界面和轮询：`deployment-check/public/deploy.js`。
   - ZIP 信任和路径校验：`deployment-check/deployment.ps1`。
   - 子进程安装：`deployment-check/deploy-worker.ps1`。
   - Node/npm 自动安装与验证：`deployment-check/node-setup.ps1`、`public/node-setup.js`。
   - 已安装后补填 SK：`deployment-check/model-key.ps1`、`public/model-key.js`。
   - 网关 Token 展示、复制与自动打开：`deployment-check/gateway-access.ps1`、`public/gateway-access.js`。
   - 真正安装行为：`packages/windows/install.ps1`。
   - 助手业务行为：`packages/windows/preload/workspace/AGENTS.md` 与 `SOUL.md`。
   - 场景规则/模板：`packages/windows/preload/skills/<skill>/`。

## 流程

```text
start.cmd → pwsh server.ps1 → 本机浏览器
  ├─ POST /api/check → 逐项探测 → pass / fail / warn
  ├─ POST /api/packages/bundled → 仓库轻量版打快照并校验 → packageId（默认方式）
  ├─ POST /api/packages (ZIP 原始字节) → 路径/体积/哈希校验 → packageId
  └─ POST /api/deploy (packageId + 目录/端口/Key/场景选项)
      → 新目录与环境检查 → 再次校验并解压 ZIP
      → 隐藏启动 pwsh deploy-worker.ps1
      → install.ps1（绑定参数，非交互）→ 网关就绪检查
      → POST /api/deploy/status → 状态与脱敏日志 → 成功后全面自检
```

所有 POST 需本次服务会话的 `X-Check-Token`，允许本机同源；Host/Origin 校验、ZIP 16 MB/展开 64 MB 上限、路径穿越/重复路径/符号链接/未知安装器拦截。UI 失败项显示红色。

点击全面或 Node/npm 单项自检时，运行环境缺失、过旧或无法执行会自动触发 `POST /api/node/setup`，固定通过 winget 安装 `OpenJS.NodeJS.LTS`，`POST /api/node/status` 查询日志与状态。15 分钟超时，退出成功后还须实际验证 Node/npm；安装期间禁止程序部署。缺少 winget 需人工安装。任务仅保存在当前服务进程内，不要在安装进行中重启检查台。

`POST /api/model/key` 接受已有安装目录和 sk- 密钥；严格格式、路径和官方提供商校验，备份后更新启动脚本中的环境变量，响应不含密钥。直接配置的 apiKey 覆盖环境变量时会拒绝保存并提示处理。保存后页面清空输入框、废止旧对话验收结果并验证官方模型目录；网关仍需人工停止再启动，Gateway token 不变。

`POST /api/gateway/access` 是展示 Token 的专用接口，返回验证后的 loopback 地址、真实 `gateway.auth.token` 及 `#token=…` 认证地址，不返回完整配置或 DeepSeek SK。普通诊断、部署状态、报告及日志仍不含 Token。`POST /api/gateway/open` 忽略客户端 URL，仅根据安装配置构造地址，检查网关确实返回 OpenClaw 页面后调用系统默认浏览器。部署成功时页面自动调用一次；刷新已有成功任务仅重新读取，不反复打开。路径保护、会话令牌、Host/Origin、no-store 对两条接口均有效。

请求 JSON 是 UTF-8，ZIP 是二进制；HTTP 解析器按 Content-Length 读取字节，不使用字符数读取二进制。安装器用独立进程运行，状态请求不会等整个 npm 安装。

内置包每个服务进程只生成一份快照；再次选用和真正部署时都校验快照与源码是否一致，源码变更后需重启检查台。内置与上传使用同一条校验、空目录保护、独立安装进程和进度接口。

任务状态：`idle`、`running`、`succeeded`、`failed`；阶段：`starting`、`installer`、`gateway`、`complete`。页面刷新可恢复当前服务进程内的任务状态。重启检查台后不自动重新启动或恢复旧部署；原有日志仍在 LocalAppData。先人工确认旧任务是否还在运行，避免重复安装。

## 当前交付基准

- 系统：Windows x64；PowerShell 7 前置；系统 Node >= 24.16.0 和 npm。
- Windows 源码包 0.3.0（从历史包 0.2.13 导入，保留上游 OpenClaw 2026.6.1）。
- 新版随机 token，业务技能直接预置到工作区 `skills`；不再依赖不确定的 `skills install` 子命令。
- 历史 0.2.13 ZIP 只按精确 SHA256 放行；不代表其固定 token 与旧模型列表已经升级。
- 模型验证只请求官方 DeepSeek `/models`，不生成内容、不验证余额；实际对话人工验收。
- 登录自启沿用当前用户启动文件夹 VBS；没有注册 Windows 服务。
- 定时任务模板默认禁用；不处理音视频转写、OCR、局域网多终端。

## 有效验证

`scripts/test.ps1` 做 PowerShell 解析、JS 语法（Node 可用时）、HTTP 检查与隔离部署测试。修改 ZIP/执行/路径/HTTP 解析逻辑需要补充有意义的失败测试。不要在开发者的现有 OpenClaw 安装目录试跑安装器。

前端浏览器测试用真实本机页面，不把模拟状态描述为真实安装成功。绿色网页可达仍需要后续实际对话、文档导出、重启验收。

## 给其他 AI 的最短提示

> 请读取仓库根目录 AGENTS.md、README.md 和 docs/AI_CONTEXT.md，按其中入口定位任务。PowerShell 7 已安装。先验证当前状态，保护已有安装与客户资料；修改后运行 scripts/test.ps1。
