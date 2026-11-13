# AI 工具入口：OpenClaw Deployment Kit

这是 OpenClaw 企业场景交付工具仓库，不是 OpenClaw 上游源码。默认中文沟通。

先读本文件，再读 `README.md` 和 `docs/AI_CONTEXT.md`，即可继续开发或部署；无需历史聊天或开发者电脑的桌面路径。

## 定位与入口

- 启动检查台：`deployment-check/start.cmd`（PowerShell 7 是前提）。
- HTTP 检查与静态页面：`deployment-check/server.ps1`。
- ZIP 校验、路径校验、任务启动与状态：`deployment-check/deployment.ps1`。
- 独立安装进程：`deployment-check/deploy-worker.ps1`。
- Node/npm 检查失败后的自动安装与验证：`deployment-check/node-setup.ps1` 和 `public/node-setup.js`。
- 已安装环境补填 SK 密钥：`deployment-check/model-key.ps1` 和 `public/model-key.js`；只备份并修改启动配置，需人工重启网关生效，不修改网关令牌。
- 页面：`deployment-check/public/{index.html,app.js,deploy.js,node-setup.js,model-key.js,style.css}`。
- 可维护的 Windows 安装包源码：`packages/windows/`；不是本机已安装程序目录。
- 网页默认自动选中此目录的轻量版，经 `POST /api/packages/bundled` 创建校验快照；用户不需要另下 ZIP。独立轻量版 ZIP/SHA256 发布到 GitHub Releases，与该目录一致。
- 七大业务规则与模板：`packages/windows/preload/skills/`。
- 客户运行环境助手规则：`packages/windows/preload/workspace/{AGENTS.md,SOUL.md,WORKSPACE_GUIDE.md}`。
- 打包：`pwsh -NoProfile -File scripts/build-package.ps1`；生成 `dist/` 下 ZIP 和 SHA256。
- 验证入口：`pwsh -NoProfile -File scripts/test.ps1`。

## 约束

1. 不提交 API Key、Gateway token、客户资料、运行状态、日志或实际安装目录。报价文档默认保留在本机。
2. 仅绑定 `127.0.0.1`。不默认开放局域网、防火墙、Windows 系统服务或业务定时任务。
3. 新装默认使用当前 Windows 用户，创建桌面工作台与登录自启动。无人登录运行服务不在当前实现范围。
4. ZIP 部署只接受与本仓库逐文件一致的新包，以及 `deployment-check/config/trusted-packages.json` 中登记的已核实旧包。不为了让未知包通过而跳过校验。
5. 一键部署只接受新的空目录。不要删除已有安装来绕过保护；升级/重装应另设计备份与恢复流程。
6. UI 绿色必须有证据：安装进程结束不等于业务验收成功；失败/超时标红，需要人工确认的项标黄。
7. 打包后源码变更会使旧的“当前源码包”不再通过逐文件校验，需重新生成 ZIP。旧版登记是针对精确 SHA256。
8. 修改安装入口需同步 README、manifest、检测项和测试。不要修改开发者桌面的历史交付包。
9. 除明确授权的实机安装外，用隔离测试验证部署；避免真实创建用户自启或覆盖现有网关。

## 完成开发后

运行 `scripts/test.ps1`，按改动验证页面。说明实现了什么、测试了什么、还有哪些实机验收未完成。
