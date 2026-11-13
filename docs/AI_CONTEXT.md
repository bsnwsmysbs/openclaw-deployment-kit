# AI 接手上下文

## 一句话定位

Windows 上用 PowerShell 7 启动的本地 H5 工具。检查已安装环境，也支持从可信 Windows Lite ZIP 新装 OpenClaw 和七大业务场景。

## 阅读顺序

1. 根目录 `AGENTS.md`：仓库规则与入口。
2. 根目录 `README.md`：使用和测试。
3. 按任务只读需要的文件：
   - 检查项：`deployment-check/server.ps1` 中 `Check`。
   - 状态文案和检查列表：`deployment-check/public/app.js`。
   - 上传/部署界面和轮询：`deployment-check/public/deploy.js`。
   - ZIP 信任和路径校验：`deployment-check/deployment.ps1`。
   - 子进程安装：`deployment-check/deploy-worker.ps1`。
   - 真正安装行为：`packages/windows/install.ps1`。
   - 助手业务行为：`packages/windows/preload/workspace/AGENTS.md` 与 `SOUL.md`。
   - 场景规则/模板：`packages/windows/preload/skills/<skill>/`。

## 流程

```text
start.cmd → pwsh server.ps1 → 本机浏览器
  ├─ POST /api/check → 逐项探测 → pass / fail / warn
  ├─ POST /api/packages (ZIP 原始字节) → 路径/体积/哈希校验 → packageId
  └─ POST /api/deploy (packageId + 目录/端口/Key/场景选项)
      → 新目录与环境检查 → 再次校验并解压 ZIP
      → 隐藏启动 pwsh deploy-worker.ps1
      → install.ps1（绑定参数，非交互）→ 网关就绪检查
      → POST /api/deploy/status → 状态与脱敏日志 → 成功后全面自检
```

所有 POST 需本次服务会话的 `X-Check-Token`，允许本机同源；Host/Origin 校验、ZIP 16 MB/展开 64 MB 上限、路径穿越/重复路径/符号链接/未知安装器拦截。UI 失败项显示红色。

请求 JSON 是 UTF-8，ZIP 是二进制；HTTP 解析器按 Content-Length 读取字节，不使用字符数读取二进制。安装器用独立进程运行，状态请求不会等整个 npm 安装。

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
