---
name: employee-behavior-analysis
description: Analyze authorized employee behavior, work process, attendance, collaboration, compliance, or operational activity data for management reference in OpenClaw. Use when generating employee behavior trend summaries, anomaly prompts, compliance risk reminders, or department-level behavior analysis. Designed for internal OpenClaw/Codex operation with preconfigured templates and strict privacy boundaries. Does not produce personality judgments, surveillance conclusions, punishment decisions, or final personnel actions.
---

# Employee Behavior Analysis

## Operating Position

Use this skill only with authorized data. Prefer aggregated and department-level analysis. Individual-level output must be evidence-based, minimal, and framed as `异常提示` or `需复核事项`.

Do not ask the client to configure privacy or scoring rules. Use conservative defaults.

## Default Case Folder

```text
OpenClaw工作台/03-任务现场/员工个人行为分析/
  01-输入资料/
  02-授权数据/
  03-制度口径/
  99-输出结果/
```

## Workflow

1. Inventory authorized data and制度口径.
2. Identify data sensitivity and minimize personally identifiable details in outputs.
3. Analyze trends, anomalies, missing records, repeated exceptions, and compliance reminders.
4. Generate management reference report and review list.
5. Escalate individual, disciplinary, privacy, or labor-law-sensitive matters to human review.

## Required Outputs

```text
99-输出结果/
  员工行为管理参考报告.docx
  行为异常提示清单.xlsx
  部门趋势分析表.xlsx
  数据授权与质量问题清单.xlsx
  人工复核清单.xlsx
```

## Boundaries

Never infer personality, motivation, loyalty, morality, illness, political view, or private life. Never recommend punishment, dismissal, demotion, salary change, or surveillance action.

## Resources

- `references/privacy-boundaries.md`: privacy and labor-risk limits.
- `references/analysis-schema.md`: fields and anomaly categories.
- `references/writing-style.md`: neutral wording.
- `assets/templates/`: report/table templates.
