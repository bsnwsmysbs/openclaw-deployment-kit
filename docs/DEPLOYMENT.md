# 新 Windows 电脑部署

1. 准备 PowerShell 7：尚未安装时先双击 `deployment-check/public/powershell7.html` 查看独立指南。在系统终端运行 `winget install --id Microsoft.PowerShell --exact --source winget`；安装后重新打开终端，执行 `pwsh --version` 确认 7.x。没有 winget 可按指南中的微软官方链接安装 x64 MSI。
2. 获取私有仓库或完整仓库 ZIP，双击 `deployment-check/start.cmd`。
3. 填写新安装目录，运行自检。缺 Node 时安装系统 Node >= 24.16.0，确保 npm 可用，再关闭并重新启动检查台。
4. 在已获取仓库的电脑运行 `pwsh -NoProfile -File scripts/build-package.ps1`，得到 `dist/OpenClawMeeting-Windows-0.3.0.zip`；将它传到目标电脑，网页选择该 ZIP。
5. 填写可选 API Key，选择网关端口和是否安装业务场景，点击“解压并一键部署”。
6. 等待依赖下载、脚本安装和网关验证。失败显示红色，展开日志查看原因；成功后自动全面自检。
7. 用实际资料验证对话与 DOCX 导出，重启并登录原用户验证自启，导出检查报告交接。

## 发生失败

- ZIP 拒绝：请选择本仓库当前源码生成的完整安装包。修改源码后要重新打包；旧版仅接受已登记精确 SHA256。
- 目标目录非空：不会覆盖现有环境。新装选择其他空目录；升级/修复应先备份并设计迁移流程。
- 端口占用：修改网页端口，或核实正在运行的已有 Gateway。不要无差别结束 Node 进程。
- npm 下载失败：检查镜像、网络、代理和 DNS。脚本日志中的最后一个阶段可用于定位。
- 网关启动失败：查看安装任务日志及目标目录日志；安装脚本退出不代表页面已可访问。
- 密钥/模型失败：新装 Key 可留空，随后运行目标目录 `tools/set-deepseek-key.ps1`；用自检确认模型名称是否仍可用。
- 检查台断开：部署任务可能仍在后台运行。刷新页面重新查询；若重启了检查台，应先核对旧进程与任务日志，不要直接重复提交。

ZIP 解压和日志保留在 `%LOCALAPPDATA%\OpenClawDeploymentKit`。失败安装保留已写入的目录，不自动递归删除。

## 当前验证范围

自动测试覆盖本地接口、真实 ZIP 上传和解压、可信度与路径校验、隔离安装任务成功/失败、日志脱敏与并发阻止。隔离安装器不下载真实 OpenClaw，不触碰桌面自启。

客户现场仍需验证完整 npm 下载、DeepSeek 实际对话、七场景效果、办公文件打开和重启后的启动行为。
