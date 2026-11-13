# OpenClawMeeting DOCX 固定交付工具

本工具用于把内部文本草稿导出为 `.docx` 文件，不依赖 Microsoft Word 或 Office。

本工具只支持 PowerShell 7 `pwsh.exe`。请不要使用 Windows 自带 PowerShell 5.1 `powershell.exe` 执行。

## 工具位置

安装后默认位于：

```text
D:\OpenClawMeeting\tools\export-docx.ps1
```

## 交付口径

- 用户最终看到的正式成果应为 `.docx`、`.xlsx`、`.pptx` 或 `.txt`。
- 默认不要把 `.md` 文件作为用户交付物。
- 如果内部需要临时文本草稿，转换完成后只向用户说明最终 `.docx` 文件路径。

## 示例

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "D:\OpenClawMeeting\tools\export-docx.ps1" `
  -InputPath "D:\OpenClawMeeting\tools\temp-draft.txt" `
  -OutputPath "$env:USERPROFILE\Desktop\龙虾工作台\02-输出成果\会议督办\会议督办闭环报告.docx" `
  -Title "会议督办闭环报告" `
  -Scenario "meeting-supervision-closure" `
  -Force
```

## 支持内容

- 一级、二级、三级标题
- 普通段落
- 无序列表
- 编号列表
- 简单表格
- 基础 Word 样式和 A4 页面

## 注意

- 该工具生成的是稳定可打开的基础 Word 文档，不负责复杂封面、页眉页脚、图表、母版、PPT 或高级排版。
- 若需要更漂亮的正式模板，可在后续版本增加模板化导出器。
