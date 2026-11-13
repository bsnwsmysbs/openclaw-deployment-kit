# OpenClaw 自动化任务执行文档

适用版本：OpenClawMeeting-Setup-Clean-20260605

本文档用于后续在甲方本机或测试机上登记、启用和验证自动化任务。默认原则是：先登记为禁用状态，确认数据来源、输出目录和人工复核人后，再启用。

## 一、执行前确认

执行前请确认：

- 已完成安装，并能访问 `http://127.0.0.1:18789/`
- 已完成模型密钥配置，默认模型可用
- 7 个业务 Skill 已存在
- 自动任务只生成草稿、清单或待复核材料
- 不自动对外发送正式通知
- 不处理会议视频、音频、OCR 或扫描件
- 不替代人工审批、验收、问责、人事决定或法律意见

7 个业务 Skill：

- `meeting-supervision-closure`
- `contract-risk-review`
- `policy-briefing`
- `hr-performance-analysis`
- `strategy-execution-review`
- `employee-behavior-analysis`
- `management-optimization-quantification`

## 二、打开执行窗口

在 Windows 开始菜单中打开 PowerShell 7，或在 CMD 中输入 `pwsh` 进入 PowerShell 7，然后执行：

```powershell
$OC = "D:\OpenClawMeeting\openclaw-local.cmd"
& $OC cron status
& $OC cron list
```

如果命令提示需要 Gateway token，可在命令末尾追加：

```powershell
--token 123456
```

## 三、登记 5 个自动任务模板

以下命令会把任务登记进去，但全部保持禁用状态，不会自动运行。

### 1. 政策源每日监测

```powershell
& $OC cron add --json --disabled --name "政策源每日监测" --description "默认禁用。启用前需确认政策来源、输出目录和人工复核人。" --cron "0 9 * * *" --tz "Asia/Shanghai" --session isolated --timeout-seconds 1800 --message "使用 policy-briefing Skill 生成政策源每日监测草稿。仅收集公开政策更新、来源链接和摘要，不发送正式通知；如来源目录、输出目录或复核人未配置，请只输出待配置清单。"
```

### 2. 政策周报生成

```powershell
& $OC cron add --json --disabled --name "政策周报生成" --description "默认禁用。启用前需确认周报频率、来源范围、输出模板和复核人。" --cron "30 9 * * 1" --tz "Asia/Shanghai" --session isolated --timeout-seconds 2400 --message "使用 policy-briefing Skill 生成政策周报草稿、来源链接清单和领导阅读版。不得自动对外发送，所有结论进入人工复核。"
```

### 3. 会议督办周报

```powershell
& $OC cron add --json --disabled --name "会议督办周报" --description "默认禁用。启用前需确认会议督办资料入口、台账口径和复核人。" --cron "30 16 * * 5" --tz "Asia/Shanghai" --session isolated --timeout-seconds 2400 --message "使用 meeting-supervision-closure Skill 汇总会议督办周报草稿，包括完成率、逾期事项、材料不足事项和人工复核清单。不得替代最终验收或问责结论。"
```

### 4. 战略执行月度汇总

```powershell
& $OC cron add --json --disabled --name "战略执行月度汇总" --description "默认禁用。启用前需确认战略目标表、月度任务表、输出口径和复核人。" --cron "30 9 1 * *" --tz "Asia/Shanghai" --session isolated --timeout-seconds 3600 --message "使用 strategy-execution-review Skill 生成战略执行月度汇总草稿，包括指标进度、偏差预警、责任单位清单和需人工确认事项。不生成最终官方评分。"
```

### 5. 人力绩效部门级月报

```powershell
& $OC cron add --json --disabled --name "人力绩效部门级月报" --description "默认禁用。启用前需确认授权数据来源、统计口径、隐私边界和复核人。" --cron "30 9 5 * *" --tz "Asia/Shanghai" --session isolated --timeout-seconds 3600 --message "使用 hr-performance-analysis Skill 生成部门级月度绩效分析草稿，包括趋势、异常波动和管理参考。不做人事处罚建议或未经授权的个人定性结论。"
```

登记完成后执行：

```powershell
& $OC cron list
```

## 四、启用任务

先用 `cron list` 查看任务 ID：

```powershell
& $OC cron list
```

确认某个任务可以运行后，执行：

```powershell
& $OC cron enable <job-id>
```

示例：

```powershell
& $OC cron enable job_abc123
```

禁用任务：

```powershell
& $OC cron disable <job-id>
```

删除任务：

```powershell
& $OC cron rm <job-id>
```

## 五、手动试跑

建议每个任务首次启用前先手动试跑一次：

```powershell
& $OC cron run <job-id> --wait --wait-timeout 30m
```

查看运行历史：

```powershell
& $OC cron runs --id <job-id> --limit 20
```

查看单个任务详情：

```powershell
& $OC cron show <job-id>
```

## 六、启用前必须补齐的信息

政策类任务需确认：

- 政策来源范围
- 输出目录
- 周报模板
- 人工复核人
- 是否允许联网检索公开来源

会议督办类任务需确认：

- 会议纪要、督办台账、完成材料入口
- 统计口径
- 周报输出目录
- 人工复核人

战略执行类任务需确认：

- 战略目标表
- 月度任务表
- 指标口径
- 输出模板
- 人工复核人

人力绩效类任务需确认：

- 授权数据来源
- 部门级统计口径
- 隐私边界
- 输出目录
- 人工复核人

## 七、给甲方的说明口径

本版本已预置业务 Skill 和自动化任务模板。自动化任务默认不启用，不会在安装后自行运行。启用前需由甲方确认数据来源、输出目录、统计口径和人工复核人。系统生成内容仅作为草稿、清单或管理参考，所有正式结论、对外发布、人事处理、法律意见和验收问责均需人工确认。

## 八、排查命令

查看调度器状态：

```powershell
& $OC cron status
```

查看任务列表：

```powershell
& $OC cron list
```

查看运行历史：

```powershell
& $OC cron runs --limit 50
```

如果网页或命令明显卡顿，先确认网关是否启动：

```powershell
Get-NetTCPConnection -LocalAddress 127.0.0.1 -LocalPort 18789 -ErrorAction SilentlyContinue
```
