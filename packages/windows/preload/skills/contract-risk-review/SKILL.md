---
name: contract-risk-review
description: Review contracts and legal/risk materials against a preconfigured local legal knowledge base for OpenClaw client delivery. Use when processing contracts, legal clause folders, compliance rules, risk review requests, or contract amendment tasks to produce contract risk review reports, risky clause lists, legal basis indexes, and mitigation suggestions. Designed for internal OpenClaw/Codex operation where the client does not configure prompts, legal paths, templates, or review rules. Does not provide final legal opinions or replace lawyer review.
---

# Contract Risk Review

## Operating Position

Use this skill as an internal OpenClaw capability. The client provides contracts and a legal provisions folder; do not ask the client to configure prompts, knowledge paths, review rules, or output templates.

Default legal knowledge base:

```text
OpenClaw工作台/02-甲方资料/法律条文知识库/
```

If the folder has no relevant law files, flag `知识库不足` and still produce a review draft based only on supplied materials. Do not fabricate legal provisions.

## Default Case Folder

```text
OpenClaw工作台/03-任务现场/合同风控初审/
  01-输入资料/
  02-合同文本/
  03-补充材料/
  04-法律条文引用/
  99-输出结果/
```

## Workflow

1. Inventory contract files, attachments, review requirements, and local legal knowledge files.
2. Identify contract type, parties, amount/payment, term, deliverables, acceptance, liability, termination, confidentiality, dispute resolution, and special risks.
3. Compare risky clauses against local legal provisions and company rules when available.
4. Create a risky clause list with source clause, risk type, severity, basis, and amendment suggestion.
5. Generate a Word review report and citation index.
6. Put legal uncertainty, missing materials, and business decisions into the human review list.

## Required Outputs

```text
99-输出结果/
  合同风控初审报告.docx
  风险条款清单.xlsx
  修改建议清单.xlsx
  法律依据引用索引.md
  人工复核清单.xlsx
  生成过程日志.md
```

## Boundaries

Never issue final legal opinions, litigation predictions, final compliance conclusions, or approval decisions. Use draft language such as `初步提示`, `建议法务复核`, and `需结合业务事实确认`.

Always require human review for high-value contracts, liability caps, penalty terms, exclusivity, termination, governing law, external commitments, government/regulatory matters, unclear authorization, or any missing legal basis.

## Resources

- `references/review-rules.md`: contract review dimensions and risk rules.
- `references/output-schema.md`: report and table fields.
- `references/legal-boundaries.md`: legal review boundaries and required human review.
- `assets/templates/`: report/table templates.
