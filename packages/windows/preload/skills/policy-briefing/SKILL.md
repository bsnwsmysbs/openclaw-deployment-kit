---
name: policy-briefing
description: Generate domestic policy briefings for comprehensive energy management or other preconfigured policy directions. Use when collecting or summarizing recent Chinese policy updates, creating policy briefs, source link lists, leader reading versions, or scheduled policy monitoring drafts. Designed for internal OpenClaw/Codex operation where sources, frequency, templates, prompts, and recipients are preconfigured by the delivery side. Browse current official sources when the user asks for latest policies. Does not automatically send official messages without human review.
---

# Policy Briefing

## Operating Position

Use this skill for policy monitoring and briefing drafts. The default direction is `国内综合能源管理`; if leadership changes direction, treat it as an administrator-maintained preset, not a client configuration task.

Use current official or primary sources when the task asks for latest/current/today/recent policies. Keep source links.

## Default Case Folder

```text
OpenClaw工作台/03-任务现场/政策简报生成/
  01-输入资料/
  02-政策来源/
  03-历史简报/
  99-输出结果/
```

## Workflow

1. Confirm policy direction from preset or user request.
2. Collect policy items from configured/official sources, preserving links and publication dates.
3. Deduplicate by title, issuing agency, and date.
4. Classify by relevance, urgency, affected business, and actionability.
5. Generate briefing, leader reading version, and source link list.
6. Prepare send-ready draft text, but do not send without explicit human confirmation.

## Required Outputs

```text
99-输出结果/
  政策简报.docx
  领导阅读版.docx
  政策链接清单.xlsx
  政策影响分析表.xlsx
  一键发送文案草稿.md
  生成过程日志.md
```

## Boundaries

Do not treat media reposts as primary sources when official sources are available. Do not fabricate links, dates, issuing agencies, or policy names.

## Resources

- `references/source-rules.md`: source and freshness rules.
- `references/brief-schema.md`: output fields and briefing structure.
- `references/writing-style.md`: wording style.
- `assets/templates/`: report/table templates.
