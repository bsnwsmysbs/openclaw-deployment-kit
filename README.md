# OpenClaw Deployment Kit

Windows 本机部署检查台 + ZIP 一键安装 + 七大企业业务场景。用于把 OpenClaw 交付到新电脑，并逐项验收安装情况。

**AI 工具从 [AGENTS.md](AGENTS.md) 开始，再读 [AI_CONTEXT.md](docs/AI_CONTEXT.md)。**

## 最快启动

前提：Windows x64，已安装 PowerShell 7。检查台本身不依赖 Node.js。

```powershell
git clone https://github.com/bsnwsmysbs/openclaw-deployment-kit.git
cd openclaw-deployment-kit
.\deployment-check\start.cmd
```

私有仓库需先使用 GitHub 账号授权。也可以下载仓库 ZIP，解压后双击 `deployment-check/start.cmd`。

浏览器会打开 <http://127.0.0.1:18890/>。关闭检查台启动窗口会停止网页服务。

## 检查与一键部署

1. 填写安装目录，例如 `D:\OpenClawMeeting`；只有 C 盘可填 `C:\OpenClawMeeting`。
2. 点击“开始全面自检”。16 项自动检查逐项打勾；失败标红、展开处理建议，支持单项重试。
3. 新装时准备 ZIP：运行下面的打包命令，或使用已登记的历史 Windows Lite 0.2.13 ZIP。
4. 在页面中选择 ZIP，填可选 DeepSeek Key 和端口，点击“解压并一键部署”。
5. 页面自动解压、调用安装脚本、显示日志和进度，验证网关页面；成功后运行全面自检。
6. 完成实际对话、Word 导出和重启验收，再勾选人工验收项，导出 TXT 报告。

```powershell
# 从仓库源码生成安装包与校验文件
pwsh -NoProfile -File .\scripts\build-package.ps1
```

安装需要系统 Node.js **≥ 24.16.0** 和正常的 npm，以及 npm 镜像与模型服务网络。检查台会提示缺失环境，不自动安装 Node。交付版固定 OpenClaw **2026.6.1**，关闭自动更新。

一键部署仅安装到新的空目录，不覆盖现有部署。默认安装七大场景、创建“桌面\龙虾工作台”并启用当前用户登录自启。基础版可以取消勾选七大场景；自动检查清单仍以业务增强版为基准，因此基础版 Skill 项会显示失败，需要按交付范围人工判定。

## 仓库结构

| 目录 | 用途 |
| --- | --- |
| `deployment-check/` | H5 页面、PowerShell 检测接口、ZIP 校验与后台部署任务 |
| `packages/windows/` | Windows Lite 安装包源码、维护工具、七大场景规则和模板 |
| `scripts/build-package.ps1` | 从源码生成 ZIP 和 SHA256，不提交生成物 |
| `scripts/test.ps1` | 语法检查、接口和隔离部署测试 |
| `docs/AI_CONTEXT.md` | AI 工具的架构、修改位置、API 与约束入口 |
| `docs/DEPLOYMENT.md` | 新电脑部署步骤、失败处理与运行目录 |
| `OpenClaw_Mac_方案A安装说明.md` | 早期 Mac 方案参考，未整合进 Windows 一键部署 |

七大场景：会议督办、合同风险、政策简报、人力绩效、战略执行、员工行为、管理优化量化。资料处理结果为草案，正式使用前需业务复核。

## 开发与验证

无前端编译或 npm install 步骤。直接修改 HTML/CSS/JS 或 PowerShell 后重启服务、刷新页面。

```powershell
pwsh -NoProfile -File .\scripts\test.ps1
```

测试使用隔离目录和模拟安装器，验证 ZIP 上传/解压/任务状态/失败处理，不安装真实 OpenClaw，也不修改用户自启动。本机真实联网自检、文件缺失标红、单项重试、报告导出已验证；完整云端 npm 安装和客户电脑重启仍需现场验收。

## 运行与数据

- 检查台：`127.0.0.1:18890`，仅本机可访问；端口可用 `server.ps1 -Port 18891` 修改。
- OpenClaw 网关默认：`127.0.0.1:18789`，与检查台不同。
- 上传包、解压目录、任务状态和脱敏日志：`%LOCALAPPDATA%\OpenClawDeploymentKit\`。
- 实际程序、状态、配置：用户选择的安装目录，不在仓库中。
- 用户资料：`桌面\龙虾工作台\01-输入资料`；成果：`02-输出成果`。
- API Key 不进入仓库、HTTP 响应或部署日志；安装器会将 Key 写入目标电脑的启动配置供 OpenClaw 使用。
- 新包生成随机 Gateway token，保存在目标目录 `config/openclaw.json` 的 `gateway.auth.token`；旧版包保留其历史行为。

ZIP 只在本机上传。新包逐文件匹配仓库源码；已登记旧包匹配完整 SHA256。页面不执行任意命令。安装会下载并执行固定 OpenClaw 版本及其依赖，属于真实本机安装操作。

仓库不包含上游 OpenClaw 源码、Node runtime、node_modules、API 账号、客户资料、报价文档及历史聊天。
