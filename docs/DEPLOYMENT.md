# 新 Windows 电脑部署

下载入口：[项目代码 ZIP](https://github.com/bsnwsmysbs/openclaw-deployment-kit/archive/refs/heads/main.zip)（公开下载，无需登录） · [PowerShell 7 微软官方下载与安装说明](https://learn.microsoft.com/zh-cn/powershell/scripting/install/installing-powershell-on-windows) · [PowerShell 官方发布页](https://github.com/PowerShell/PowerShell/releases)。手动安装选择稳定版 Windows x64 MSI。

1. 准备 PowerShell 7：尚未安装时先双击 `deployment-check/public/powershell7.html` 查看独立指南。在系统终端运行 `winget install --id Microsoft.PowerShell --exact --source winget`；安装后重新打开终端，执行 `pwsh --version` 确认 7.x。没有 winget 可按指南中的微软官方链接安装 x64 MSI。
2. 获取公开仓库或完整仓库 ZIP，双击 `deployment-check/start.cmd`。
3. 填写新安装目录，运行自检。Node/npm 缺失、过旧或无法运行时，检查台自动通过 winget 安装 Node.js LTS；按系统授权提示允许安装，等待日志和实际验证结果。没有 winget 时按失败提示手动安装。检查台会重新读取 PATH，通常无需重启。
4. 网页会自动读取完整仓库内 `packages/windows/` 的 Windows Lite 0.3.0，无需打包或下载第二份 ZIP。
5. 填写可选 API Key，选择网关端口和是否安装业务场景，点击“安装仓库自带轻量版”。
6. 等待依赖下载、脚本安装和网关验证。失败显示红色，展开日志查看原因；成功后显示实际生成的网关 Token 和地址，自动携带 Token 打开系统默认浏览器，并全面自检。已有安装也可在“网关 Token 与访问地址”重新读取和打开。
7. 用实际资料验证对话与 DOCX 导出，重启并登录原用户验证自启，导出检查报告交接。

## 发生失败

- 轻量版未就绪：确认下载并解压了完整仓库，包含 `packages/windows/`，然后重新启动检查台。修改安装源码后也要重启，避免使用旧快照。

- ZIP 拒绝：请选择本仓库当前源码生成的完整安装包。修改源码后要重新打包；旧版仅接受已登记精确 SHA256。
- 目标目录非空：不会覆盖现有环境。新装选择其他空目录；升级/修复应先备份并设计迁移流程。
- 端口占用：修改网页端口，或核实正在运行的已有 Gateway。不要无差别结束 Node 进程。
- npm 下载失败：检查镜像、网络、代理和 DNS。脚本日志中的最后一个阶段可用于定位。
- 网关启动失败：查看安装任务日志及目标目录日志；安装脚本退出不代表页面已可访问。
- 密钥/模型失败：新装 Key 可留空，随后在网页“补填／修改 SK 密钥”保存并检查。已运行的网关需先运行目标目录 `stop-gateway.cmd`，再运行 `start-gateway.cmd`，再实际对话验证；网关令牌不会改变。
- Node 自动安装失败：展开环境安装日志，检查网络、winget 和系统授权。安装退出成功但 Node/npm 验证失败仍显示红色，需处理 PATH 或旧版本冲突后重试。
- 检查台断开：部署任务可能仍在后台运行。刷新页面重新查询；若重启了检查台，应先核对旧进程与任务日志，不要直接重复提交。

ZIP 解压和日志保留在 `%LOCALAPPDATA%\OpenClawDeploymentKit`。失败安装保留已写入的目录，不自动递归删除。

## 当前验证范围

自动测试覆盖本地接口、真实 ZIP 上传和解压、可信度与路径校验、隔离安装任务成功/失败、日志脱敏与并发阻止。隔离安装器不下载真实 OpenClaw，不触碰桌面自启。

客户现场仍需验证完整 npm 下载、DeepSeek 实际对话、七场景效果、办公文件打开和重启后的启动行为。

## 单独分发轻量版（可选）

[下载 Windows Lite 0.3.0 ZIP](https://github.com/bsnwsmysbs/openclaw-deployment-kit/releases/download/v0.3.0/OpenClawMeeting-Windows-0.3.0.zip) · [下载 SHA256](https://github.com/bsnwsmysbs/openclaw-deployment-kit/releases/download/v0.3.0/OpenClawMeeting-Windows-0.3.0.zip.sha256)。解压后运行 `windows/install.cmd`，或在网页展开“其他方式”上传。该 ZIP 与仓库 `packages/windows/` 相同，安装时仍需联网下载运行依赖。使用仓库默认网页方案不需要下载此文件。
