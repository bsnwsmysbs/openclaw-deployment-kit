# Closure Judgment Rules

## Status Definitions

`已闭环`: The task has matched feedback and result evidence showing the requirement has been completed or formally closed.

`推进中`: Feedback shows real progress but no final result evidence.

`未反馈`: A task exists but no matching feedback or completion material is found.

`材料不足`: Feedback exists but evidence cannot support the claimed result.

`责任不清`: The source does not clearly identify responsible unit/person and the task cannot be assigned.

`需人工确认`: The model cannot safely judge because of ambiguity, conflict, sensitivity, or missing context.

## Decision Order

1. If responsibility is unclear, use `责任不清`.
2. If no feedback is found, use `未反馈`.
3. If feedback conflicts or affects sensitive outcomes, use `需人工确认`.
4. If feedback shows progress but not completion, use `推进中`.
5. If completion is claimed but proof is weak, use `材料不足`.
6. If result evidence supports completion, use `已闭环`.

## Risk Level Defaults

- `高`: overdue key task, legal/compliance/funds/personnel/external submission impact, conflicting materials, possible false closure.
- `中`: unclear deadline/responsibility, weak proof, cross-department dependency, repeated delay.
- `低`: source and evidence are consistent, no sensitive consequence, task is routine.

## No Overreach

Do not produce final punishment, final performance score, legal conclusion, acceptance conclusion, or official external statement. Use management draft language and require review.
