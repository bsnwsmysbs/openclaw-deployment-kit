#requires -Version 7.0

param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [string]$Title = "",
    [string]$Scenario = "",
    [switch]$Force
)

$ErrorActionPreference = "Stop"
if ($PSVersionTable.PSEdition -ne "Core" -or $PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "[ERROR] This tool requires PowerShell 7 pwsh.exe." -ForegroundColor Red
    Write-Host "[ERROR] Windows PowerShell 5.1 powershell.exe is not supported." -ForegroundColor Red
    Write-Host "[INFO]  Run with: pwsh -NoProfile -ExecutionPolicy Bypass -File .\tools\export-docx.ps1" -ForegroundColor Yellow
    exit 1
}

function Escape-XmlText {
    param([AllowNull()][string]$Text)
    if ($null -eq $Text) { return "" }
    return [System.Security.SecurityElement]::Escape($Text)
}

function New-ParagraphXml {
    param(
        [string]$Text,
        [string]$Style = "",
        [switch]$Bold
    )
    $escaped = Escape-XmlText $Text
    $styleXml = ""
    if (-not [string]::IsNullOrWhiteSpace($Style)) {
        $styleXml = "<w:pPr><w:pStyle w:val=`"$Style`"/></w:pPr>"
    }
    $runPr = ""
    if ($Bold) { $runPr = "<w:rPr><w:b/></w:rPr>" }
    return "<w:p>$styleXml<w:r>$runPr<w:t xml:space=`"preserve`">$escaped</w:t></w:r></w:p>"
}

function New-TableXml {
    param([string[][]]$Rows)
    $table = @()
    $table += "<w:tbl><w:tblPr><w:tblStyle w:val=`"TableGrid`"/><w:tblW w:w=`"0`" w:type=`"auto`"/><w:tblBorders><w:top w:val=`"single`" w:sz=`"4`" w:space=`"0`" w:color=`"auto`"/><w:left w:val=`"single`" w:sz=`"4`" w:space=`"0`" w:color=`"auto`"/><w:bottom w:val=`"single`" w:sz=`"4`" w:space=`"0`" w:color=`"auto`"/><w:right w:val=`"single`" w:sz=`"4`" w:space=`"0`" w:color=`"auto`"/><w:insideH w:val=`"single`" w:sz=`"4`" w:space=`"0`" w:color=`"auto`"/><w:insideV w:val=`"single`" w:sz=`"4`" w:space=`"0`" w:color=`"auto`"/></w:tblBorders></w:tblPr>"
    foreach ($row in $Rows) {
        $table += "<w:tr>"
        foreach ($cell in $row) {
            $table += "<w:tc><w:tcPr><w:tcW w:w=`"2400`" w:type=`"dxa`"/></w:tcPr>"
            $table += (New-ParagraphXml -Text $cell)
            $table += "</w:tc>"
        }
        $table += "</w:tr>"
    }
    $table += "</w:tbl>"
    return ($table -join "")
}

function Convert-MarkdownToBodyXml {
    param([string[]]$Lines)
    $body = New-Object System.Collections.Generic.List[string]
    $i = 0
    while ($i -lt $Lines.Count) {
        $line = $Lines[$i].TrimEnd()
        $trimmed = $line.Trim()

        if ([string]::IsNullOrWhiteSpace($trimmed)) {
            $body.Add((New-ParagraphXml -Text "")) | Out-Null
            $i++
            continue
        }

        if ($trimmed -match '^(#{1,3})\s+(.+)$') {
            $level = $Matches[1].Length
            $text = $Matches[2]
            $style = if ($level -eq 1) { "Heading1" } elseif ($level -eq 2) { "Heading2" } else { "Heading3" }
            $body.Add((New-ParagraphXml -Text $text -Style $style -Bold)) | Out-Null
            $i++
            continue
        }

        if ($trimmed -match '^\|.+\|$' -and ($i + 1) -lt $Lines.Count -and $Lines[$i + 1].Trim() -match '^\|[\s:\-\|]+\|$') {
            $rows = New-Object System.Collections.Generic.List[string[]]
            $header = @($trimmed.Trim("|").Split("|") | ForEach-Object { $_.Trim() })
            $rows.Add([string[]]$header) | Out-Null
            $i += 2
            while ($i -lt $Lines.Count -and $Lines[$i].Trim() -match '^\|.+\|$') {
                $cells = @($Lines[$i].Trim().Trim("|").Split("|") | ForEach-Object { $_.Trim() })
                $rows.Add([string[]]$cells) | Out-Null
                $i++
            }
            $body.Add((New-TableXml -Rows $rows.ToArray())) | Out-Null
            continue
        }

        if ($trimmed -match '^[-*]\s+(.+)$') {
            $body.Add((New-ParagraphXml -Text ("- " + $Matches[1]))) | Out-Null
            $i++
            continue
        }

        if ($trimmed -match '^\d+[\.\)]\s+(.+)$') {
            $body.Add((New-ParagraphXml -Text $trimmed)) | Out-Null
            $i++
            continue
        }

        $body.Add((New-ParagraphXml -Text $line)) | Out-Null
        $i++
    }
    return ($body -join "`n")
}

function Write-Utf8File {
    param([string]$Path, [string]$Value)
    $dir = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    Set-Content -LiteralPath $Path -Value $Value -Encoding UTF8
}

if (-not (Test-Path -LiteralPath $InputPath)) {
    throw "Input file not found: $InputPath"
}
if ((Test-Path -LiteralPath $OutputPath) -and -not $Force) {
    throw "Output already exists. Use -Force to overwrite: $OutputPath"
}

$inputFull = (Resolve-Path -LiteralPath $InputPath).Path
$outputFull = [System.IO.Path]::GetFullPath($OutputPath)
$outputDir = Split-Path -Parent $outputFull
if (-not (Test-Path -LiteralPath $outputDir)) {
    New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
}

$lines = Get-Content -LiteralPath $inputFull -Encoding UTF8
if ([string]::IsNullOrWhiteSpace($Title)) {
    $firstHeading = $lines | Where-Object { $_ -match '^#\s+(.+)$' } | Select-Object -First 1
    if ($firstHeading -and $firstHeading -match '^#\s+(.+)$') {
        $Title = $Matches[1]
    } else {
        $Title = [System.IO.Path]::GetFileNameWithoutExtension($inputFull)
    }
}

$createdAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$metaLines = @(
    "# $Title",
    "",
    "| 项目 | 内容 |",
    "| --- | --- |",
    "| 生成时间 | $createdAt |",
    "| 适用功能 | $Scenario |",
    "| 来源文件 | $inputFull |",
    "| 版本 | 草稿 |",
    "",
    "----",
    ""
)

$bodyXml = Convert-MarkdownToBodyXml -Lines ($metaLines + $lines)

$documentXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:wpc="http://schemas.microsoft.com/office/word/2010/wordprocessingCanvas" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math" xmlns:v="urn:schemas-microsoft-com:vml" xmlns:wp14="http://schemas.microsoft.com/office/word/2010/wordprocessingDrawing" xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" xmlns:w10="urn:schemas-microsoft-com:office:word" xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:w14="http://schemas.microsoft.com/office/word/2010/wordml" xmlns:wpg="http://schemas.microsoft.com/office/word/2010/wordprocessingGroup" xmlns:wpi="http://schemas.microsoft.com/office/word/2010/wordprocessingInk" xmlns:wne="http://schemas.microsoft.com/office/word/2006/wordml" xmlns:wps="http://schemas.microsoft.com/office/word/2010/wordprocessingShape" mc:Ignorable="w14 wp14">
  <w:body>
    $bodyXml
    <w:sectPr>
      <w:pgSz w:w="11906" w:h="16838"/>
      <w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="708" w:footer="708" w:gutter="0"/>
    </w:sectPr>
  </w:body>
</w:document>
"@

$stylesXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/><w:qFormat/><w:pPr><w:spacing w:after="120" w:line="276" w:lineRule="auto"/></w:pPr><w:rPr><w:rFonts w:ascii="Microsoft YaHei" w:eastAsia="Microsoft YaHei" w:hAnsi="Microsoft YaHei"/><w:sz w:val="21"/></w:rPr></w:style>
  <w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="heading 1"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:qFormat/><w:pPr><w:spacing w:before="240" w:after="120"/><w:outlineLvl w:val="0"/></w:pPr><w:rPr><w:b/><w:rFonts w:ascii="Microsoft YaHei" w:eastAsia="Microsoft YaHei" w:hAnsi="Microsoft YaHei"/><w:sz w:val="32"/></w:rPr></w:style>
  <w:style w:type="paragraph" w:styleId="Heading2"><w:name w:val="heading 2"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:qFormat/><w:pPr><w:spacing w:before="200" w:after="100"/><w:outlineLvl w:val="1"/></w:pPr><w:rPr><w:b/><w:rFonts w:ascii="Microsoft YaHei" w:eastAsia="Microsoft YaHei" w:hAnsi="Microsoft YaHei"/><w:sz w:val="26"/></w:rPr></w:style>
  <w:style w:type="paragraph" w:styleId="Heading3"><w:name w:val="heading 3"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:qFormat/><w:pPr><w:spacing w:before="160" w:after="80"/><w:outlineLvl w:val="2"/></w:pPr><w:rPr><w:b/><w:rFonts w:ascii="Microsoft YaHei" w:eastAsia="Microsoft YaHei" w:hAnsi="Microsoft YaHei"/><w:sz w:val="23"/></w:rPr></w:style>
  <w:style w:type="table" w:styleId="TableGrid"><w:name w:val="Table Grid"/><w:basedOn w:val="TableNormal"/><w:uiPriority w:val="59"/><w:tblPr><w:tblBorders><w:top w:val="single" w:sz="4" w:space="0" w:color="auto"/><w:left w:val="single" w:sz="4" w:space="0" w:color="auto"/><w:bottom w:val="single" w:sz="4" w:space="0" w:color="auto"/><w:right w:val="single" w:sz="4" w:space="0" w:color="auto"/><w:insideH w:val="single" w:sz="4" w:space="0" w:color="auto"/><w:insideV w:val="single" w:sz="4" w:space="0" w:color="auto"/></w:tblBorders></w:tblPr></w:style>
</w:styles>
"@

$contentTypesXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
</Types>
"@

$relsXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>
"@

$documentRelsXml = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"/>
"@

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("openclaw-docx-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path (Join-Path $tempRoot "_rels") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $tempRoot "word\_rels") | Out-Null

try {
    Write-Utf8File -Path (Join-Path $tempRoot "[Content_Types].xml") -Value $contentTypesXml
    Write-Utf8File -Path (Join-Path $tempRoot "_rels\.rels") -Value $relsXml
    Write-Utf8File -Path (Join-Path $tempRoot "word\document.xml") -Value $documentXml
    Write-Utf8File -Path (Join-Path $tempRoot "word\styles.xml") -Value $stylesXml
    Write-Utf8File -Path (Join-Path $tempRoot "word\_rels\document.xml.rels") -Value $documentRelsXml

    if (Test-Path -LiteralPath $outputFull) {
        Remove-Item -LiteralPath $outputFull -Force
    }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::CreateFromDirectory($tempRoot, $outputFull)
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}

Write-Host "[OK] DOCX exported: $outputFull" -ForegroundColor Green
