---
name: md-to-word
description: "把 Markdown 转成交付级 Word（.docx）：中文字体真正生效、表格网格线与满宽居中、图片按版心缩放、真正的目录域、分页与页眉页脚。用户要把 md/笔记/文档转成 Word、或抱怨生成的 docx 表格没框线/标题发蓝/目录重复/字体不对/图片超出纸边时使用。"
whenToUse: "用户说“转成 Word / 导出 docx / 生成 word 文档 / md 转 word”，或已有 docx 出现表格无竖线、标题淡蓝、目录重复或样式差、中文字体字号不对、表格没占满页宽、图片超出纸边、章节之间多出横线等问题时使用；也包括“套用某某模板的格式”“照这个格式排版”这类要求。"
metadata:
  language: "zh"
  category: "productivity"
disable-model-invocation: true
user-invocable: true
---

# Markdown 转交付级 Word（md-to-word）

## 目标

把 Markdown 转成可交付的 `.docx`：中文字体真正生效、表格有网格线且满宽居中、图片不越出版心、目录是可更新的 Word 域、标题黑色。pandoc 直接输出的产物在中文场景下这几项都不达标，**必须做后处理**。

## 环境

- **pandoc** ≥ 3.0（本机 `D:\Software\env\Pandoc\pandoc.exe`，先 `Get-Command pandoc` 确认）
- **Python** ≥ 3.8，只用标准库（`zipfile` / `re`）
- 不需要 Word、LibreOffice、python-docx、联网

不用 Word COM（`New-Object -ComObject Word.Application`）：办公机上类型库常损坏，报 `TYPE_E_CANTLOADLIBRARY`。直接改 OOXML，docx 就是 zip。

**Windows 命令行的两个坑**：

1. **不要在命令里手写中文路径字面量**（含 `python -c "…中文…"`）：命令串会被按 ANSI 编码传递，中文变乱码、`SyntaxError` 或找不到文件。改为从已有文件推导，例如 `$md = (Get-ChildItem "$root\*.md").FullName`，或把脚本写成 UTF-8 文件再执行。
2. 若交付目录的 ACL 不允许子进程写入（`PermissionError: [WinError 5]`），让脚本先写到临时目录，再由 shell `Copy-Item` 进交付目录。

## 输入与输出

- 输入：`.md`，以及用途（作业 / 正式文档 / 内部记录），用于定字体字号与要不要目录
- **若用户给了模板 docx（学校/公司/课程模板），模板优先于第 5 节的默认值**
- 输出：`.docx`；**保留 `.md` 源文件**，改内容改 md 后重跑，不手改 docx
- 后处理脚本放临时目录（如 `_extract/`），不放交付目录

## 工作流

### 1. 定三件事

字体字号、是否要目录、表格样式（竖线 / 满宽 / 居中）。用户未指定时套用第 5 节默认值。

**有模板时先探测模板**，不要凭猜或直接用默认值。导出模板的字体与页面设置：

```python
import re, zipfile
with zipfile.ZipFile(template_docx) as z:
    styles = z.read("word/styles.xml").decode("utf-8")
    doc = z.read("word/document.xml").decode("utf-8")
print(re.findall(r"<w:rFonts[^>]*/>", doc))                     # 正文/标题实际用的字体
dd = re.search(r"<w:docDefaults>.*?</w:docDefaults>", styles, re.S)
print(re.findall(r"<w:rFonts[^>]*/>", dd.group(0)))             # 默认中英文字体
print(re.findall(r'<w:sz w:val="(\d+)" />', doc))               # 出现的字号（半磅）
```

同时看模板**有没有目录**：模板没有目录就不要自作主张加（加进去反而多一块）。

已实测的一种模板规格（南昌大学实验报告）：

| 对象 | 字体 | 字号 |
|---|---|---|
| 大标题 | 华文新魏 | 26pt 居中加粗 |
| 节标题 | 宋体 | 14pt 加粗黑色 |
| 正文 | 宋体 + 西文 Times New Roman | 小四 12pt（`w:sz="24"`） |

### 2. md 预检（先修 md，再转）

转之前扫一遍 md，把下面几类问题修在 md 里（**只加空行/改结构，不要顺手改文字**）：

- **列表 / 引用块 / 表格紧跟正文行**（前面没有空行）：pandoc 的 markdown 会把它们并进上一段，**列表不会渲染成列表**，而是挤成一行。修法是在 md 里补一个空行。扫描判据：本行匹配 `^\s*([-*+]|\d+\.)\s` 或 `^\s*>`，且上一行非空、且上一行不是列表/引用/表格/标题。
- 图片相对路径是否存在（路径错会在 docx 里留下坏链接或丢图）
- 表格分隔行 `|---|` 是否齐全
- 残留的 `---` 水平分割线（会在章节间多出横线）

### 3. 造参考模板

```powershell
pandoc --print-default-data-file reference.docx > $env:TEMP\ref.docx
```

PowerShell 的 `>` 会破坏二进制。用二进制安全的重定向（`cmd /c`，或 Python 里 `subprocess.run(..., stdout=open(path,"wb"))`），写完校验首四字节为 `80,75,3,4`。

### 4. 修掉 pandoc 的默认缺陷

| 现象 | 根因 | 处理 |
|---|---|---|
| 表格**无竖线** | `Table` 样式不含 `tblBorders`，只在 `firstRow` 留了 `bottom` | 写入完整 `tblBorders`（`top/left/bottom/right/insideH/insideV`），表头行加 `shd` 底色 |
| 表格**不居中** | `w:tblInd=0` 只是左对齐 | `tblPr` 内加 `<w:jc w:val="center"/>`，`tblInd` 顶不了 |
| 表格**不满宽**（约 88%） | `tblLayout=fixed` 时以 `tblGrid` 各列之和为准，`tblW pct=5000` 被忽略；网格合计只有 ~7918 twips | 按比例重算 `tblGrid` 使其和 = 正文宽度；`tblW` 改同值 `dxa`；`tcW` 按同一比例缩放（比"归零"更稳） |
| 标题**淡蓝色** | 各级标题带 `w:color w:themeColor="accent1" w:themeShade="BF" w:val="0F4761"` | 删掉 `w:color`，写死 `000000`，补 `<w:b/><w:bCs/>` |
| 中文字体**不生效或变细** | 主题 `majorFont` 映射到「等线 Light」，且样式只写 `w:eastAsiaTheme` | 样式内 `w:rFonts` 改具体字体名（中英文都给）；改 theme 的 `majorFont`/`minorFont` 的 `<a:ea>` 与 `Hans` 槽位。值见第 5 节 |
| 图片下方多出一行**重复题注** | `implicit_figures`：独占一段的图片会把 **alt 文本**变成题注（`ImageCaption` 样式），与文档自带的图注重复 | 删除 `w:pStyle="ImageCaption"` 的段落 |
| 代码块**退化成正文**（没有等宽与底纹） | pandoc 默认 reference.docx 里**没有** `SourceCode` 样式 | 在 `styles.xml` 里补一个 `SourceCode` 段落样式（等宽字体 + 浅底 `F2F2F2` + 左缩进） |
| **章节间多出横线** | md 里的 `---` 是水平分割线 | 删除；保留表格分隔行，判据是上下相邻行都是表格行 |
| **目录重复**、带英文 "Table of Contents" | 同时用了 `--toc` 和手写目录 | 见第 6 节 |

### 5. 默认样式值

模板缺席时才用：

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

**表格内字号单独定**：多列表格（7 列以上）用正文号会挤成竖条，按列数降到小五 9pt（`w:sz="18"`）甚至六号；做法是在 `document.xml` 里给表格内每个 run 统一写 `w:sz`（正文段落仍然不加行内字号）。

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

### 6. 目录

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

### 7. 页面与后处理

pandoc 的 `sectPr` 没有 `pgSz`/`pgMar`，正文宽度随 Word 语言设置变化，必须显式设定：

```
A4 纵向：pgSz w=11906 h=16838；pgMar 四边 1440（2.54cm）
正文宽度 = 11906 − 1440×2 = 9026 twips    ← tblGrid 之和按此配
可用页高 = 16838 − 1440×2 = 13958 twips   ← 图片高度上限按此配
```

**sectPr 子元素顺序**：CT_SectPr 规定 `headerReference*/footerReference*/footnotePr?/endnotePr?/type?/pgSz?/pgMar?/…`，即 `footnotePr` 必须排在 `pgSz` **之前**。把 `pgSz/pgMar` 插到 `footnotePr` 后面属 schema 违规，渲染器可能整段忽略。最省事：正文没有脚注时，直接把 pandoc 留下的 `<w:footnotePr>` 删掉。

换纸张或改页边距要重算上述值。后处理用 `zipfile` 读改写 `document.xml` / `styles.xml` / `theme1.xml` / `settings.xml`，脚本需幂等。

**表格**：`tblGrid` 按比例缩放到正文宽 → `tblW` 同值 `dxa` + `tblLayout=fixed` + `jc=center` → `tcW` 同比例缩放 → 表头行加粗加底色 → 表内 run 统一字号。

**图片（容易漏，必做）**：pandoc 按 PNG 像素/DPI 元数据给出 `wp:extent`，matplotlib 等导出的图常**远超版心宽度**，在 Word 里会顶到纸边甚至被裁。后处理要等比缩小：

```
1 twip = 635 EMU
宽度上限 = 9026 twips  = 5,731,510 EMU
高度上限 = 13958 twips = 8,863,330 EMU
k = min(1, 宽上限/cx, 高上限/cy)，k<1 时 cx,cy 同乘 k
```

- **两处都要改**：`<wp:extent cx cy/>`（Word 实际使用的尺寸）与同段落内的 `<a:ext cx cy/>`（图形属性），只改一处会导致不一致
- 图片所在段落加 `<w:jc w:val="center"/>`，否则图偏左很难看

**水平分割线**：删掉 `pPr` 里带 `w:pBdr`/`w:bottom` 的段落。

### 8. 验证

回读 docx 自查，不能只看脚本没报错：

- 表格数与行数与 md 一致（**docx 行数 = md 数据行 + 1 个表头行**；md 侧统计时要去掉 `|---|` 分隔行）
- **列表项数、图片数与 md 一致**（`<w:numPr>` 个数 ↔ md 列表行数；`word/media/` 文件数 ↔ md 图片数）
- 每张表 `tblGrid` 之和**恰好等于**正文宽度；每张表 `tblW` 同值且 `jc=center`
- `Table` 样式含 `tblBorders`、`insideV`、`jc=center`
- 标题样式 `w:color` 为 `000000`、有 `w:b`、无 `themeColor`
- 正文**实际引用的样式**（`w:pStyle`）字号字体达标——只查样式定义不够
- 正文无行内覆盖（`w:sz` / `w:color`）
- 无 `ImageCaption` 残留题注；分割线段落数为 0
- 每张图的 `wp:extent` 不超宽/高上限
- 页面 `pgSz`/`pgMar` 为设定值
- zip 完整、所有 `*.xml` 可解析

**行内字符样式（`w:rStyle`）要按白名单判**，否则必然误报：行内代码是 `VerbatimChar`，超链接是 `Hyperlink`，代码块高亮是 skylighting 的 `KeywordTok`/`NormalTok`/…（以 `Tok` 结尾）。判据写成"除这三类外无其它 `rStyle`"。

写校验正则时注意三点，否则会误报：

1. **属性顺序不固定**。pandoc 会把 `<w:style w:type="table" w:styleId="Table">` 重排成 `w:styleId` 在前；`<w:pgSz w:w="11906" w:h="16838" />` 会被写成 `w:h` 在前。匹配要么用 `<w:style\b[^>]*w:styleId="Table"[^>]*>`，要么两种顺序都试。
2. **自闭合标签的空格不固定**。`<w:jc w:val="center" />` 有空格，而主题里是 `<a:font script="Hans" typeface="等线 Light"/>` **没有空格**。统一写 `\s*/>`，不要按 `" />"` 匹配（否则主题字体槽位会替换失败且不报错）。
3. **判据别写成"某字串必须不存在"而忘了子串关系**。例如校验"主题无等线 Light"时，替换后仍可能有其它含"等线"的槽位，断言要针对具体槽位。

### 9. 视觉抽查与渲染器可信度

渲染只用于看**结构与纵向排版**（内容顺序、表格线、图片位置、有没有缺字方块）。做之前先**验证渲染器本身**：

1. 拿一份已知正确的对照文档（**用户给的模板最好**）先渲染一页；
2. 如果对照文档本身就溢出、错位、字体怪异，说明是**渲染器/字体度量**的问题，**不要**据此改自己的文档；
3. 横向版心一律以**数值校验**为准（twips / EMU），不要用肉眼从渲染图判断宽窄；
4. `missingFonts` 为空也不代表字体度量正确——渲染器可能用了替换字体而不报告。

实测经验：沙箱内 LibreOffice 渲染中文时字符宽度被放大，**连老师给的模板都向右溢出**，图片与文字一并出界。这类现象是环境缺陷，不是文档缺陷；判定依据是"对照文档同样出错"。

## 守则

- 改内容改 md，docx 是产物
- **有模板以模板为准**（字体、字号、要不要目录）；模板没有目录就不要加
- 交付文件名：用户或课程有命名规则时按规则命名（如 `n_文件名_姓名_学号`）
- 交付物正文不要出现本机绝对路径、虚拟环境、构建工具等环境噪音
- 交付时说明所用字体字号、表格是否满宽居中、图片是否按版心缩放、目录是否需要更新域
- 中间脚本与临时文件告知用户，由用户决定是否清理
