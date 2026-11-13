---
name: hr-performance-analysis
description: Analyze authorized HR, assessment, personnel archive, and monthly performance data for OpenClaw management reports. Use when generating monthly performance analysis, department-level HR metrics, personnel archive trend analysis, assessment data summaries, abnormal fluctuation lists, or management recommendations. Designed for internal OpenClaw/Codex operation where templates, indicators, folder paths, and rules are preconfigured. Does not make final personnel decisions, punishment recommendations, or unsupported individual conclusions.
---

# HR Performance Analysis

## Operating Position

Use this skill for authorized HR and performance data analysis. Keep first-phase outputs at department/monthly management-analysis level unless explicit, lawful, and authorized individual analysis data is provided.

Do not ask the client to configure indicators or templates. Use defaults and put unclear metrics into human review.

## Default Case Folder

```text
OpenClaw工作台/03-任务现场/人力绩效分析/
  01-输入资料/
  02-考核数据/
  03-人员档案/
  04-制度口径/
  99-输出结果/
```

## Workflow

1. Inventory performance data, personnel archive data, attendance/training/assessment files, and policy documents.
2. Normalize data by month, department, position, and metric.
3. Analyze trends, outliers, missing data, distribution, and department comparison.
4. Generate management explanations only when evidence supports them.
5. Produce monthly report, anomaly list, data quality list, and human review list.

## Required Outputs

```text
99-输出结果/
  月度绩效分析报告.docx
  部门绩效对比表.xlsx
  异常波动清单.xlsx
  人员档案分析表.xlsx
  数据质量问题清单.xlsx
  人工复核清单.xlsx
```

## Boundaries

Do not output final ranking, punishment, dismissal, demotion, salary decision, or personal moral judgment. Use `管理参考`, `异常提示`, and `建议复核`.

## Resources

- `references/indicator-schema.md`: default indicators and table fields.
- `references/analysis-rules.md`: analysis and risk boundaries.
- `references/writing-style.md`: report wording.
- `assets/templates/`: report/table templates.
