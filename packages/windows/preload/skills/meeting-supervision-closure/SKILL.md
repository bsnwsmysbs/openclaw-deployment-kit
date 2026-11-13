---
name: meeting-supervision-closure
description: Generate text-based meeting supervision closure deliverables from preconfigured OpenClaw meeting case folders. Use when processing meeting records, meeting minutes, leadership requirements, supervision feedback, completion materials, or human corrections to produce meeting supervision reports, task ledgers, closure status, pending item lists, and human review checklists. Designed for internal OpenClaw/Codex operation where the client does not configure prompts, folders, rules, templates, or knowledge paths. Does not process video, audio, OCR, scanned images, or meeting transcription.
---

# Meeting Supervision Closure

## Operating Position

Use this skill as an internal OpenClaw capability. Do not ask the client to configure prompts, YAML, rules, templates, folder mappings, or status definitions. Treat defaults as already configured by the delivery side.

The client-facing workflow is only:

1. Put text meeting materials into the prepared task folder, or provide the folder to OpenClaw.
2. Select/use the meeting supervision closure scenario.
3. Receive Word reports, Excel/CSV ledgers, and review lists.

If a required input is missing, create an item in `人工复核清单` instead of inventing facts or pushing configuration work to the client.

## Default Case Folder

Use an existing folder if the user provides one. If no folder is provided, create or recommend this default structure under the OpenClaw workbench:

```text
OpenClaw工作台/
  03-任务现场/
    会议督办闭环/
      YYYYMMDD-会议名称/
        01-会议资料/
        02-领导要求/
        03-督办反馈/
        04-办结材料/
        05-人工修正/
        99-输出结果/
```

Do not require a `case.yaml` or `rules.yaml` for first-phase delivery. If such files exist, read them as optional overrides; otherwise use the bundled references.

## Workflow

1. Inventory files by folder and file name. Process text, Markdown, Word, Excel, CSV, and plain text materials. Do not process video/audio/OCR assets.
2. Extract meeting decisions, leadership requirements, tasks, responsible units, responsible people, deadlines, evidence, and source citations.
3. Normalize each task using `references/field-schema.md`.
4. Match feedback and completion materials to tasks using task name, responsible unit, date, keywords, and cited source.
5. Judge closure status with `references/closure-judgment-rules.md`.
6. Mark unclear or high-risk items using `references/risk-taxonomy.md`.
7. Draft output using `references/writing-style.md`.
8. Produce all required deliverables in `99-输出结果`.

## Required Outputs

Produce these files whenever possible:

```text
99-输出结果/
  会议督办闭环报告.docx
  督办事项台账.xlsx
  未闭环事项清单.xlsx
  人工复核清单.xlsx
  材料引用索引.md
  生成过程日志.md
```

If the runtime cannot write `.docx` or `.xlsx`, create clean Markdown and CSV fallbacks with the same content and state the conversion need in `生成过程日志.md`.

## Judgment Boundary

Generate management drafts and analysis, not final administrative decisions.

Never claim a task is complete unless source material supports the result. Prefer `材料不足` or `需人工确认` over unsupported closure.

Human review is mandatory when:

- Responsible unit/person or deadline is unclear.
- Feedback conflicts across departments.
- Completion proof is only a process description, not result evidence.
- The item affects accountability, performance scoring, funds, legal risk, acceptance, external submission, or official archive.
- The material uses vague requirements such as `尽快`, `适时`, `持续推进`, `按要求落实`, or `进一步研究`.

## Resources

Load these reference files as needed:

- `references/field-schema.md`: canonical ledger fields and output table columns.
- `references/extraction-guidelines.md`: extraction and matching rules.
- `references/closure-judgment-rules.md`: closure status definitions and decision rules.
- `references/risk-taxonomy.md`: risk flags and human review triggers.
- `references/writing-style.md`: report structure and wording style.

Use these templates from `assets/templates/` when creating final files:

- `会议督办闭环报告模板.docx`
- `督办事项台账模板.xlsx`
- `未闭环事项清单模板.xlsx`
- `人工复核清单模板.xlsx`
- `会议督办闭环报告结构.md`
- `督办事项台账字段.csv`
