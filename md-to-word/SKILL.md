---
name: md-to-word
description: "把 Markdown 转成交付级 Word（.docx）：中文标题正文样式、表格网格线与满宽、真正的目录域、分页与页眉页脚。用户要把 md/笔记/文档转成 Word、或抱怨生成的 docx 表格没框线/标题发蓝/目录重复/字体不对时使用。"
whenToUse: "用户说“转成 Word / 导出 docx / 生成 word 文档 / md 转 word”，或已有 docx 出现表格无竖线、标题淡蓝、目录重复或样式差、中文字体字号不对、表格没占满页宽、章节之间多出横线等问题时使用；也包括“套用某某模板的格式”“照这个格式排版”这类要求。"
metadata:
  language: "zh"
  category: "productivity"
disable-model-invocation: true
user-invocable: true
---

# Markdown 转交付级 Word（md-to-word）

## 目标

把 Markdown 转成可交付的 `.docx`：中文字体真正生效、表格有网格线且满宽居中、目录是可更新的 Word 域、标题黑色。pandoc 直接输出的产物在中文场景下这几项都不达标，**必须做后处理**。

## 环境

- **pandoc** ≥ 3.0（本机 `D:\Software\env\Pandoc\pandoc.exe`，先 `Get-Command pandoc` 确认）
- **Python** ≥ 3.8，只用标准库（`zipfile` / `re`）
- 不需要 Word、LibreOffice、python-docx、联网

不用 Word COM（`New-Object -ComObject Word.Application`）：办公机上类型库常损坏，报 `TYPE_E_CANTLOADLIBRARY`。直接改 OOXML，docx 就是 zip。

## 输入与输出

- 输入：`.md`，以及用途（作业 / 正式文档 / 内部记录），用于定字体字号与要不要目录
- 输出：`.docx`；**保留 `.md` 源文件**，改内容改 md 后重跑，不手改 docx
- 后处理脚本放临时目录（如 `_extract/`），不放交付目录

## 工作流

### 1. 确认三件事

字体字号、是否要目录、表格样式（竖线 / 满宽 / 居中）。用户未指定时套用第 4 节的默认值。

### 2. 造参考模板

```powershell
pandoc --print-default-data-file reference.docx > $env:TEMP\ref.docx
```

PowerShell 的 `>` 会破坏二进制。用二进制安全的重定向，写完校验首四字节为 `80,75,3,4`。

### 3. 修掉 pandoc 的默认缺陷

| 现象 | 根因 | 处理 |
|---|---|---|
| 表格**无竖线** | `Table` 样式不含 `tblBorders`，只在 `firstRow` 留了 `bottom` | 写入完整 `tblBorders`（`top/left/bottom/right/insideH/insideV`），表头行加 `shd` 底色 |
| 表格**不居中** | `w:tblInd=0` 只是左对齐 | `tblPr` 内加 `<w:jc w:val="center"/>`，`tblInd` 顶不了 |
| 表格**不满宽**（约 88%） | `tblLayout=fixed` 时以 `tblGrid` 各列之和为准，`tblW pct=5000` 被忽略；网格合计只有 ~7918 twips | 按比例重算 `tblGrid` 使其和 = 正文宽度；`tblW` 改同值 `dxa`；单元格残留的 `tcW` 归零 |
| 标题**淡蓝色** | 各级标题带 `w:color w:themeColor="accent1" w:themeShade="BF" w:val="0F4761"` | 删掉 `w:color`，写死 `000000`，补 `<w:b/><w:bCs/>` |
| 中文字体**不生效或变细** | 主题 `majorFont` 映射到「等线 Light」，且样式只写 `w:eastAsiaTheme` | 样式内 `w:rFonts` 改具体字体名（中英文都给）；改 theme 的 `majorFont`/`minorFont` 的 `<a:ea>` 与 `Hans` 槽位。值见第 4 节 |
| **章节间多出横线** | md 里的 `---` 是水平分割线 | 删除；保留表格分隔行，判据是上下相邻行都是表格行 |
| **目录重复**、带英文 "Table of Contents" | 同时用了 `--toc` 和手写目录 | 见第 5 节 |

### 4. 默认样式值

未指定时直接用：

| 对象 | 字体 | 字号 | 其他 |
|---|---|---|---|
| 标题（各级统一） | 等线 | 13.5pt（`w:sz="27"`） | 黑色 `000000`、`<w:b/><w:bCs/>` |
| 正文 | 等线 | 五号 10.5pt（`w:sz="21"`） | 黑色 |
| 表头行 | 等线 | 10.5pt | 加粗 + 底色 `D9E2F3` |
| 表格线 | — | 0.75pt（`w:sz="6"`） | 色 `595959`，六向全画 |

字体名中英文同时给，缺一可能不生效：

```xml
<w:rFonts w:ascii="DengXian" w:hAnsi="DengXian" w:eastAsia="等线" w:cs="DengXian"/>
```

字号字体要**同时写进 `docDefaults` 和各具体样式**：表格单元格文字没有独立段落样式，只改样式定义会让表格文字保持默认大小。

中文字号换算（XML 用半磅值 = pt×2）：

| 号 | pt | `w:sz` | 号 | pt | `w:sz` |
|---|---|---|---|---|---|
| 初号 | 42 | 84 | 小四 | 12 | 24 |
| 小初 | 36 | 72 | 五号 | 10.5 | 21 |
| 一号 | 26 | 52 | 小五 | 9 | 18 |
| 小一 | 24 | 48 | 六号 | 7.5 | 15 |
| 二号 | 22 | 44 | 小六 | 6.5 | 13 |
| 小二 | 18 | 36 | 七号 | 5.5 | 11 |
| 三号 | 16 | 32 | 八号 | 5 | 10 |
| 小三 | 15 | 30 | | | |
| 四号 | 14 | 28 | | | |

用户说"正文是 5"指五号 10.5pt，不是 5pt。

### 5. 目录

md 里只留目录标题（如 `## 目 录`），生成后注入 TOC 域：

```xml
<w:p><w:pPr><w:pStyle w:val="TOC1"/></w:pPr>
  <w:r><w:fldChar w:fldCharType="begin" w:dirty="true"/></w:r>
  <w:r><w:instrText xml:space="preserve">TOC \o "1-3" \h \z \u</w:instrText></w:r>
  <w:r><w:fldChar w:fldCharType="separate"/></w:r>
  <w:r><w:t>（占位文字）</w:t></w:r>
  <w:r><w:fldChar w:fldCharType="end"/></w:r>
</w:p>
```

- 目录标题**不能是大纲标题**，否则目录会把自己列进去。用无大纲级别的样式（`TOCTitle`）
- `TOC1/TOC2/TOC3` 样式加 `<w:tab w:val="right" w:leader="dot" w:pos="<正文宽>"/>` 才有前导点与页码；缩进递进 0 / 240 / 480
- `word/settings.xml` 的 `<w:settings>` 下加 `<w:updateFields w:val="true"/>`，打开时自动生成
- 不要用 `--toc`，也不要在 md 里手写目录列表

### 6. 页面与后处理

pandoc 的 `sectPr` 没有 `pgSz`/`pgMar`，正文宽度随 Word 语言设置变化，必须显式设定：

```
A4 纵向：pgSz w=11906 h=16838；pgMar 四边 1440（2.54cm）
正文宽度 = 11906 − 1440×2 = 9026 twips    ← tblGrid 之和按此配
```

换纸张或改页边距要重算该值。后处理用 `zipfile` 读改写 `document.xml` / `styles.xml` / `theme1.xml` / `settings.xml`，脚本需幂等。

### 7. 验证

回读 docx 自查，不能只看脚本没报错：

- 表格数与行数与 md 一致（md 表格行含 `|---|` 分隔行，差额来源于此）
- 每张表 `tblGrid` 之和**恰好等于**正文宽度
- `Table` 样式含 `tblBorders`、`insideV`、`jc=center`
- 标题样式 `w:color` 为 `000000`、有 `w:b`
- 正文**实际引用的样式**（`w:pStyle`）字号字体达标——只查样式定义不够
- 正文无行内覆盖（`w:sz` / `w:color` / `rStyle`），它会盖掉样式
- 分割线段落数为 0
- zip 完整、所有 `*.xml` 可解析

写校验正则时注意两点，否则会误报：

1. 属性顺序不固定。pandoc 会把 `<w:style w:type="table" w:styleId="Table">` 重排成 `w:styleId` 在前，用 `<w:style\b[^>]*w:styleId="Table"[^>]*>`
2. 自闭合标签带空格。`<w:jc w:val="center" />` 的 `/>` 前有空格，按无空格形式匹配会误判为未生效，统一写 `\s*/>`

## 守则

- 改内容改 md，docx 是产物
- 交付时说明所用的字体字号、表格是否满宽居中、目录是否需要更新域
- 中间脚本与临时文件告知用户，由用户决定是否清理
