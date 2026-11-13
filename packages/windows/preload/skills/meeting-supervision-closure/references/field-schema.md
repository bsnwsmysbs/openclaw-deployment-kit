# Field Schema

Use these fields for every supervision item. Keep column names stable so downstream reports can reuse the ledger.

## Core Ledger Columns

| Column | Required | Notes |
| --- | --- | --- |
| 事项编号 | Yes | Use `DB-YYYYMMDD-001` format when no existing number is present. |
| 事项名称 | Yes | Short action-oriented title. |
| 来源会议 | Yes | Meeting name or material name. |
| 来源依据 | Yes | File name, page/section if available, and original sentence summary. |
| 领导要求/会议决定 | Yes | Preserve the actionable requirement. |
| 责任单位 | Yes | Use `责任不清` if absent. |
| 责任人 | No | Do not infer from position unless explicitly stated. |
| 协同单位 | No | Multiple units separated by `;`. |
| 完成期限 | No | Normalize to date when explicit; otherwise keep original phrase. |
| 当前反馈 | No | Latest feedback matched to the item. |
| 办结材料 | No | Evidence file names or summaries. |
| 闭环状态 | Yes | One of the allowed statuses. |
| 风险等级 | Yes | `低`, `中`, `高`. |
| 风险标签 | No | Use taxonomy labels. |
| 需复核问题 | No | Concrete question for human reviewer. |
| 建议下一步 | Yes | Operational next action, not final administrative decision. |

## Allowed Closure Statuses

- 已闭环
- 推进中
- 未反馈
- 材料不足
- 责任不清
- 需人工确认

## Output Tables

`督办事项台账` contains all core columns.

`未闭环事项清单` contains only items whose status is not `已闭环`, sorted by risk level, deadline urgency, and source order.

`人工复核清单` contains items with `需人工确认`, high risk, conflicting evidence, or missing source support.
