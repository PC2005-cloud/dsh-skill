---
name: html-ppt
description: "用现成模板把内容做成可直接演示的静态 HTML 幻灯片：主题换肤、多版式、入场动效，并支持带逐字稿的演讲者模式。用户要求做 PPT、slides、演示稿、技术分享、课程或小红书图文时使用。"
whenToUse: "用户要求做 PPT/幻灯片/slides/deck/keynote/演示稿/演讲稿/分享稿/逐字稿，或要把大纲、笔记、文档、Markdown 转成可演示的网页幻灯片时使用；提到“做一份技术分享”“做路演 pitch deck”“做小红书图文”“要带提词器/演讲者视图”时同样使用。"
metadata:
  language: "zh"
  category: "design"
disable-model-invocation: true
user-invocable: true
---

# HTML PPT Studio（html-ppt）

## 目标

把用户给的内容做成一份**纯静态的 HTML 演示文稿**：产物是一个 `index.html`（必要时加一个 `style.css`），用浏览器打开即可全屏演示，键盘翻页，按 `T` 现场换主题，按 `S` 打开带逐字稿的演讲者窗口。零构建、无框架，唯一外部依赖是 Google Fonts 的 CDN 字体。

## 输入与输出

- **输入**：主题与内容，或一份大纲/笔记/文档；最好同时知道页数、观众是谁、使用场景（现场讲 / 截图发小红书 / 交作业）。
- **输出**：`<目标目录>/index.html`（+ 可选 `style.css`），**并在同级生成 `assets/`**。deck 就是一个 **`index.html` + `assets/` 的自包含文件夹**，用浏览器打开即可演示；本 skill 不产出图片文件。
- **路径约定**：本文提到的 `assets/…`、`templates/…`、`references/…` 都相对**本 skill 目录**。
- **产物放在 skill 目录之外时**：**不要手算 `../`，用 `scripts/new-deck.ps1`**。它默认把 `assets/` 复制到 deck 同级目录，于是 `index.html` 只引用 `assets/…`，**deck 变成一个自包含、可整体拷走的文件夹**——换盘、拷 U 盘、打包发人都不会坏。只有明确要"跟随 skill 的资源实时更新"时才加 `-Link`，且必须接受它不可移植。

## 工作流

1. **先确认三件事**，没问清之前不要动笔写 slide：
   - 内容与观众：讲什么、大概几页、谁在看（工程师 / 高管 / 学生 / 小红书读者 / VC）；
   - 风格主题：见下一步的推荐表；
   - 起点：用哪套整册模板打底，还是从最简模板起手。
   用户已经给足内容时，不要反问一堆，直接给出建议默认值请他确认。
2. **选主题**（36 套全在 `assets/themes/*.css`，清单见 `references/themes.md`）。按调性推荐 2–3 个即可：
   - 技术分享 / 工程 → `tokyo-night`、`dracula`、`catppuccin-mocha`、`terminal-green`、`blueprint`
   - 商业 / 投资人 → `pitch-deck-vc`、`corporate-clean`、`swiss-grid`
   - 小红书图文 → `xiaohongshu-white`、`soft-pastel`、`rainbow-gradient`、`magazine-bold`
   - 学术 / 汇报 → `academic-paper`、`editorial-serif`、`minimal-white`
   - 发布会 / 硬核 → `cyberpunk-neon`、`vaporwave`、`y2k-chrome`、`neo-brutalism`
   落盘时写 `<link rel="stylesheet" id="theme-link" href="…/assets/themes/<主题>.css">`，并在 `<body>` 上设 `data-themes="主题1,主题2,…"`（3–5 个备选）与 `data-theme-base="…/assets/themes/"`，这样演示时按 `T` 能现场试色。
3. **列大纲**。20 分钟分享的典型结构：`cover → toc → 分区页 → 2~4 正文页 → … → cta → thanks`；相邻两页不要用同一种版式。
4. **搭骨架**。优先复制整册模板 `templates/full-decks/<name>/`（15 套，自成一体、CSS 已 scoped）；没有合适的就用 `scripts/new-deck.ps1 <名字> <目录>`（Windows）或 `scripts/new-deck.sh <名字> <目录>` 从 `templates/deck.html` 起手——**它会把 `assets/` 复制进 deck 目录，deck 自包含、可整包搬走**；只有想跟随 skill 资源实时更新时才加 `-Link`。
5. **逐页写**。从 `templates/single-page/`（31 种版式，都带可渲染的 demo 数据）整块复制 `<section class="slide">…</section>`，再替换成真实内容，**保留 class 结构**；每页补 `data-title="…"`（供 `O` 概览显示）。
6. **加动效，克制**。每页只留一个主入场动效：`data-anim="fade-up"` 或 `class="anim-fade-up"`；列表/网格用 `anim-stagger-list`；数据页用 `counter-up`；Canvas 特效写 `<div data-fx="<特效名>">` 并引入 `assets/animations/fx-runtime.js`（进入该页自动初始化、离开自动清理）。完整清单见 `references/animations.md`。
7. **写讲稿**。每页在 slide 内加 `<div class="notes">…</div>` 放演讲者备注，按 `S`/`N` 才可见。
8. **自检**。浏览器里用 `← →` 走一遍：按 `O` 看概览有没有溢出或排版塌陷，按 `T` 逐个主题确认都不崩，按 `S` 确认每页备注都在。
   这一步**必须由人在浏览器里完成**——不要为了截屏去装浏览器、开 headless 或申请额外权限。如果环境跑不了浏览器，就把 deck 交给用户，请他按 `O`/`T`/`S` 过一遍并反馈。

### 演讲者模式（要逐字稿时必须走这条）

用户提到 演讲 / 分享 / 讲稿 / 逐字稿 / 提词器 / 演讲者视图 / speaker notes，或说“怕讲不流畅”“要带逐字稿的 PPT”时，用 `templates/full-decks/presenter-mode-reveal/` 打底——它是唯一每页都配好示例逐字稿的整册模板。

按 `S` 会弹出独立窗口，含 4 张磁吸卡片：当前页预览、下一页预览、大字逐字稿、计时器。每张卡**按标题栏可拖拽、右下角可缩放**，位置与尺寸按 deck 记忆在 `localStorage`，另有「Reset layout」恢复默认排布。

它为什么可靠：

- **预览像素级一致**——每张卡是一个 `<iframe>`，加载的就是同一份 deck HTML 加 `?preview=N`，`runtime.js` 识别该参数后只渲染第 N 页并去掉外框。同一份 CSS、同一套主题与字体、同一视口，所以颜色与排版与观众视角必然相同。
- **换页不闪**——切页时演讲者窗口向 iframe 发 `postMessage({type:'preview-goto'})`，iframe 只切 `.is-active`，不重新加载文档。
- **两窗同步**——观众窗口与演讲者窗口通过 `BroadcastChannel` 互相同步页码与主题。

演讲者窗口内：`← →` 翻页（同步观众窗口）、`R` 重置计时、`Esc` 关闭弹窗。

逐字稿三铁律：
1. **是提示信号，不是念稿**——关键词加粗，过渡句独立成段，扫一眼就能接上；
2. **每页 150–300 字**——对应 2–3 分钟/页的节奏，少了会卡，多了来不及扫；
3. **用口语**——“因此”改“所以”，“该方案”改“这个方案”，写完读一遍像不像人话。

细节与写法示例见 `references/presenter-mode.md`。

## 路径与可移植性（做要交付的 deck 时必读）

本 skill 装在用户主目录（`~/.dsh/skills/html-ppt/`，Windows 上通常是 `C:\Users\<用户名>\.dsh\…`），而 deck 往往建在**另一个盘**。这带来三个必须知道的事实：

| 引用方式 | 何时能用 | 可移植性 |
|---|---|---|
| `assets/…`（**默认，推荐**）| 总是——`new-deck.ps1` 已把资源复制到 deck 同级 | ✅ 整个文件夹随便拷、随便发 |
| `../../skills/html-ppt/assets/` | 仅当 deck 与 skill **同盘** | ⚠️ 换盘即坏 |
| `file:///C:/Users/…/assets/` | 跨盘兜底 | ❌ 只在这台机器这个路径下有效 |

**关键前提：跨盘的两条路径之间不存在相对路径。** 任何 `../` 都翻不过盘符，所以"用相对路径引用别盘的 assets"这个想法本身不成立——唯一稳妥的做法是把资源复制过来。`new-deck.ps1` 的 `-Link` 在跨盘时会退化成 junction（Windows）或 `file://`，并**打印警告**；如果 deck 要交付，请忽略 `-Link`，用默认的复制模式。

交付前自检：把 `index.html` 和 `assets/` 一起复制到一个新位置（甚至换个盘），在浏览器里打开——**样式还在，才算过关**。

## 素材来源

| 位置 | 内容 |
|---|---|
| `assets/themes/*.css` | 36 套主题，每套只是一个 CSS token 文件，换一个 `<link>` 就整册换肤 |
| `assets/base.css` | 共享设计系统（颜色/字号/间距/卡片等 token 与基础组件） |
| `templates/single-page/*.html` | 31 种单页版式：cover、toc、bullets、two-column、table、code、timeline、kpi-grid、chart-*、arch-diagram、cta、thanks 等 |
| `templates/full-decks/<name>/` | 15 套整册模板（含 pitch-deck、tech-sharing、weekly-report、xhs-post、course-module、presenter-mode-reveal） |
| `assets/animations/` | 26 个 CSS 入场动效类（`data-anim`/`anim-*`）、`counter-up` 数字滚动、20 个 Canvas FX 模块（`data-fx`） |
| `templates/*-showcase.html` | 主题 / 版式 / 动效 / 整册画廊，挑样式时打开看效果 |
| `references/*.md` | 主题、版式、动效、整册、演讲者模式、完整流程的分册目录，按需读取 |
| `examples/demo-deck/` | 可直接打开的完整示例 |

演示快捷键：`← → Space` 翻页 · `F` 全屏 · `T` 换主题 · `A` 试动效 · `O` 概览网格 · `S` 演讲者窗口 · `N` 备注抽屉 · `R` 重置计时（演讲者窗口内）· 网址 `#/N` 直达第 N 页。

## 设计原理

懂这几条机制，就知道下面的守则为什么不能破：

- **一套 token 设计系统**。颜色、字号、圆角、阴影全部定义在 `assets/base.css` 的 CSS 变量里，主题文件只做变量覆盖。所以换主题 = 换一个 `<link>`，全册页面立刻同步换肤；反过来说，一旦在 slide 里写死 `#111`，这个元素就永远不跟着主题走。
- **一个主题文件 = 一种观感，一个版式文件 = 一种页面，一个动效类 = 一种入场**。三者互不耦合、可任意组合——这是 36 套主题 × 31 种版式能反复复用的原因。
- **主题循环靠属性驱动**。`T` 键从 `<body data-themes="…">` 取候选主题，再按 `data-theme-base` 拼出主题文件路径，替换 `<link id="theme-link">`；这两个属性缺一个，`T` 就失效。
- **运行时只认 `.slide`**。`runtime.js` 让 `.slide.is-active` 可见、其余隐藏，所谓翻页就是切换这个 class；键盘、`T` 换主题、`O` 概览、`S` 演讲者窗口、`N` 备注抽屉、`#/N` 深链全由它提供。所以任何一页漏引它，整个 deck 的交互都会哑掉。
- **复制版式要连 class 一起复制**。栅格、间距、响应式行为都挂在 class 上，只抄内容不抄 class，版式就不成立；要替换的只是文字与数据。
- **动效分两类，机制不同**。CSS 动效是 `data-anim` / `anim-*` 类，随页面进入播放；Canvas 特效是 `data-fx`，由 `assets/animations/fx-runtime.js` 在进入该页时初始化、离开时销毁（不销毁会一直占用帧率）。每页只留一个主效，是不抢内容的注意力。
- **`.notes` 靠 `display:none` 隐身**，只在 `S` 演讲者窗口与 `N` 抽屉里出现——这就是给讲者看的话必须放进去、而不是写在 slide 上的原因。
- **整册模板自带 scoped CSS**（`.tpl-<name>` 前缀），多套模板能共存于同一页面互不污染，改一套也不会波及另一套。

## 守则

- **一律从模板起手**，不要对着空白文件手写 slide；没有合适版式时先组合现有版式，确实需要新页型才新增 `templates/single-page/*.html`。
- **只用 token 上色**：`color: var(--text-1)` 是对的，`color: #111` 是错的；字号、圆角、阴影同理。不要为了单个 deck 改 `assets/base.css`。
- **保留既有外框**：`.deck-header`、`.deck-footer`、`.slide-number`、进度条由 `base.css` + `runtime.js` 提供，不要自己造一套。
- **每页一个 `<section class="slide">`**，并且始终引入 `assets/runtime.js`——否则键盘、主题切换、概览、演讲者模式全部失效。
- **讲者专用的话只能进 `.notes`**。“这一页要强调的是…”“这里可以补充…”这类给讲者看的文字放进 `<div class="notes">`（默认 `display:none`），slide 上只留观众该看的内容：标题、要点、数据、图表、图片。
- **不要删改 showcase 页面**（`templates/*-showcase.html`、`full-decks-index.html`），它们是素材画廊；要预览就用浏览器打开，不要为了做新 deck 去改它们。
- 中英文混排直接写，`assets/fonts.css` 已预置 Noto Sans SC / Noto Serif SC；`<html lang="zh-CN">` 便于中文排版。
