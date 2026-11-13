---
name: strategy-execution-review
description: Analyze strategy execution, target completion, departmental progress, employee or unit execution evidence, and monthly or quarterly strategy assessment materials. Use when generating strategic execution analysis reports, progress dashboards, deviation warnings, follow-up task lists, or assessment draft materials for OpenClaw. Designed for internal OpenClaw/Codex operation where strategy maps, indicators, templates, folders, and scoring rules are preconfigured. Does not create final official scores unless provided by authorized source data.
---

# Strategy Execution Review

## Operating Position

Use this skill to turn strategy goals, KPI progress, unit reports, and evidence materials into execution analysis drafts. Do not ask the client to configure scoring rules; use provided rules if present, otherwise report progress and deviations without final scoring.

## Default Case Folder

```text
OpenClaw工作台/03-任务现场/战略执行考核/
  01-输入资料/
  02-战略目标/
  03-执行数据/
  04-佐证材料/
  99-输出结果/
```

## Workflow

1. Inventory strategy targets, annual/monthly plans, KPI data, unit reports, and evidence.
2. Build target-to-unit and target-to-employee mapping when source data supports it.
3. Analyze progress, deviation, overdue tasks, evidence sufficiency, and cross-unit dependencies.
4. Generate execution report, deviation warning list, and follow-up actions.
5. Put scoring ambiguity and accountability implications into human review.

## Required Outputs

```text
99-输出结果/
  战略执行分析报告.docx
  指标进度表.xlsx
  偏差预警清单.xlsx
  单位执行对比表.xlsx
  后续督办事项清单.xlsx
  人工复核清单.xlsx
```

## Boundaries

Do not invent strategy indicators, targets, weights, or final scores. Do not determine accountability or rewards/punishments.

## Resources

- `references/execution-schema.md`: target and progress fields.
- `references/assessment-rules.md`: deviation and risk logic.
- `references/writing-style.md`: report style.
- `assets/templates/`: report/table templates.
