---
name: blog-bookmark
description: "把 Edge/Chrome 收藏夹导出文件或任意形式的网址清单，去重、补全 logo 与描述后批量录入博客的网址导航后端。用户要批量收录网站到导航时使用。"
whenToUse: "用户提供浏览器收藏夹导出文件（Edge/Chrome 的 HTML）、粘贴的网址文本、Markdown 链接列表或口述一批网站，要求「录入 / 收录 / 加到网址导航 / 导入收藏夹 / 帮我加这些网站」时触发。"
metadata:
  language: "zh"
  category: "development"
disable-model-invocation: true
user-invocable: true
---

# 博客网址导航批量录入

## 目标

把用户给的杂乱网址信息，整理成结构化的书签数据，补全 logo 和描述，落到博客的网址导航后端。

一次可以做几十条，但每条都要有像样的名称、可用的 logo 地址和一句人话描述。

## 输入形式

用户给的可能是任意一种，都要能接：

- **浏览器导出文件**：Edge/Chrome 导出的 HTML，Netscape Bookmark File Format
- **粘贴的文本**：每行一个网址，可能带名称，也可能是 Markdown 链接 `[名称](地址)`
- **混合形式**：文件 + 口头补充，或者一份手写的清单
- **已有条目**：用户只给名称，让你自己去查地址

解析不出来或地址不合法的行，不要静默丢掉，原样列给用户确认。

## 后端接口

后端地址由用户提供，本地默认 `http://127.0.0.1:18016`。

| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/api/bookmark/list` | 全部书签 |
| GET | `/api/bookmark/category/tree` | 全部分类 |
| POST | `/api/bookmark` | 新增书签 |
| PUT | `/api/bookmark` | 更新书签 |
| DELETE | `/api/bookmark/{id}` | 删除书签（逻辑删除） |
| POST | `/api/bookmark/category` | 新增分类 |
| PUT | `/api/bookmark/category` | 更新分类 |
| DELETE | `/api/bookmark/category/{id}` | 删除分类（逻辑删除） |

统一响应格式 `{"code":1,"message":"success","data":...}`，`code` 为 `1` 才算成功。

几件必须先知道的事：

- **`category/tree` 返回的是扁平数组**，不是嵌套结构。要自己按 `parentId` 组树。
- **`POST /api/bookmark/category` 不返回新分类的 id**，创建完必须重新 GET tree 才拿得到。
- **新分类的 id 不一定比现有 id 大**（自增序列可能落在中间空档），不要用 `id > 最大值` 判断哪些是新增的。
- **`PUT /api/bookmark` 必须同时带上 `name` 和 `url`**，这两个字段有 `@NotBlank` 校验，只传 `id` + 要改的字段会报「网站名称不能为空」。
- **`PUT` 走的是 NOT_NULL 更新策略**，传 `null` 的字段不会被清空，所以只传要改的字段是安全的。
- **`POST /api/bookmark/page` 只支持按 `name` 模糊过滤**，不能按分类筛。

字段结构：

```
Bookmark         { id, name, url, description, icon, categoryId, isPin, sortOrder }
BookmarkCategory { id, name, parentId, sortOrder }
```

分类是两层：`parentId` 为 `null` 是一级，否则是二级。书签挂在二级上，一级通常只当容器。

## 工作流

### 第 1 步：先摸清现有数据

调 `GET /api/bookmark/list` 和 `GET /api/bookmark/category/tree`，拿到：

- 现有书签的全部 URL（按下面的规则规范化后建索引，用于去重）
- 分类的 `name → id` 映射和完整层级

分类数、书签数、每个二级分类下有几个书签，都记下来——后面规划分类时要用。

### 第 2 步：解析输入

**浏览器导出文件**：按 Netscape 格式解析。`<DT><H3>` 是文件夹（入栈），`</DL>` 出栈，`<DT><A HREF="...">名称</A>` 是书签。逐行扫描同时维护一个文件夹栈，就能还原出每个书签的完整文件夹路径。

注意：导出文件里的 `<A>` 可能带 `ICON="data:image/png;base64,..."` 属性。那是浏览器缓存图标的 base64 内嵌，**不要用**——要的是 logo 的 URL，不是图片数据。

**粘贴文本**：宽松匹配，常见几种都要认：

```
https://example.com
example.com
示例站 https://example.com
示例站	https://example.com
[示例站](https://example.com)
- [示例站](https://example.com)
```

只有域名没有协议头的，补 `https://`。

### 第 3 步：去重

规范化 URL 后比对，**既和库里现有的比，也和新输入内部互相比**（用户给的清单自己可能就有重复）。

规范化规则见下面「URL 规范化」一节。

- 完全相同的：跳过，列出来告诉用户
- 同域名不同路径的：**不要自动跳过**，这可能是同一站的不同产品，属于合法条目，交给用户判断

### 第 4 步：规划分类

优先复用现有二级分类。只有现成分类确实放不下时才新建，新建时遵守：

- **每个新分类至少要有 2 个书签**。只有 1 个的分类不要建，宁可先并到语义最近的现成分类里，或者和用户商量。
- **一级的名称要能涵盖它的二级**。比如一级叫「开发工具」，二级叫「视频剪辑」就不合适。
- 新分类要同时定好 `parentId` 和 `sortOrder`。
- 同一批新增尽量集中，别为了几个书签拆出一堆分类。

拿不准归属的，问用户，不要硬塞。

### 第 5 步：收集 logo 与描述

对每一条新增书签，都要备好 `icon` 和 `description`。具体做法见下面两节。

### 第 6 步：汇总成完整信息文件

把这一批整理结果写成一个 JSON 文件，结构大致：

```json
{
  "newCategories": [
    { "name": "视频剪辑", "parentName": "媒体工具", "sortOrder": 4 }
  ],
  "items": [
    {
      "name": "剪映",
      "url": "https://www.capcut.cn/",
      "icon": "https://lf3-s.vlabstatic.com/obj/.../favicon.ico",
      "description": "字节跳动出品的视频剪辑软件，内置 AI 创作与模板",
      "categoryName": "视频剪辑"
    }
  ]
}
```

写库之前，先把摘要给用户过目：新增多少条、跳过多少条重复、要新建几个分类、有没有拿不准的。确认后再动数据库。

### 第 7 步：批量写入

顺序不能反：

1. 先创建新分类
2. 重新 GET `category/tree`，拿到新分类的 id
3. 再批量写书签（每条带上 `name`、`url`、`icon`、`description`、`categoryId`）
4. 写完全部回读校验一遍

逐条调用，记录成功和失败。不要因为中间失败就静默继续——失败的条目要在最后列出来。

校验要看这几项：总数对不对、有没有未分类的书签、有没有指向不存在分类的、每个二级分类是否都至少有 2 条、`icon` 和 `description` 是否都有值。

## Logo 获取

按优先级往下试，命中即止。

**第一优先：解析首页的 `<link>` 声明**

抓站点首页 HTML，找这几个标签：

```
<link rel="icon">
<link rel="shortcut icon">
<link rel="apple-touch-icon">
<link rel="apple-touch-icon-precomposed">
```

`href` 是相对路径的要 resolve 成绝对地址。多个候选时：

- 优先 `sizes` 里尺寸最大的
- SVG 优先于位图
- **排除 `rel="mask-icon"`**——那是 Safari 固定标签页用的单色图标，不是站点 logo
- 注意有些站的图标挂在 CDN 域名上（如 `img.alicdn.com`、`lf3-s.vlabstatic.com`），那是站点自己的资源，正常用

**第二优先：`<origin>/favicon.ico`**

首页没有声明图标时，直接取站点根目录的 `favicon.ico`。覆盖面很广，是浏览器的兜底约定。

**第三优先：第三方服务**

站点反爬（403/503）拿不到时，用：

```
https://favicon.im/<域名>
```

**必须验证**

拿到候选地址后要实际请求一次，确认响应头的 `Content-Type` 以 `image/` 开头。

这一步不能省：**不少站点对不存在的路径返回 200 + HTML**（软 404），只看状态码会把一个 HTML 页面当成图标存进去。

### icon 字段存什么形式

- **存完整绝对地址**，带协议头：`https://code.visualstudio.com/favicon.ico`
- 可以扩展到 `.ico` / `.png` / `.svg`
- **绝对不要存 base64 data URI**。前端渲染逻辑是 `icon?.startsWith("http")`，data URI 不满足这个判断，会被当成 emoji 文本直接把那一长串字符显示出来。
- **确实找不到图标时填 emoji**（如 `🔗`），前端会把非 http 开头的值当 emoji 渲染。不要留空。

## URL 规范化

### 要去掉的

**追踪参数**：`spm`、`scm`、`trk`、`utm_*`、`from`、`share_*`、`ref` 等推广/统计参数，整段 `?` 后面的查询串一起判断，没有业务含义就删掉。

**会话和账户相关的路径段**：

```
https://www.doubao.com/chat/local_1042444620513316?type=2   →  https://www.doubao.com/chat
https://dash.cloudflare.com/4824ddf0.../home/overview       →  https://dash.cloudflare.com/
```

这类路径里嵌着会话 ID、账户 ID，既没意义又涉及隐私，必须去掉。

**纯下载页**：如果某个地址只是提供下载、站点的正经入口在别处，改成入口地址。

### 不要过度化简

这是最容易做过头的地方：

- **有业务含义的路径要保留**：`/product/bailian`、`/studio`、`/texlive`、`/learn/get-started` 这些指向具体产品或页面的路径，简化成首页就丢信息了
- **一个站有多个产品时不能都砍成首页**。比如同一家厂商的多个产品页，全简化成首页就会互相重复，反而制造出假重复
- **语言前缀保留**：`/zh-cn`、`/cn` 这类前缀和库里现有风格保持一致，不要为了"干净"删掉

判断标准：化简后的地址打开，用户还能不能看到原来那个东西。能就化简，不能就保留。

## 环境注意事项

这些是在 Windows 上实操时踩过的坑，会直接影响成败。

**这个 shell 实际是 Windows PowerShell 5.1**，虽然工具名写着 `pwsh`。后果是：

- `Set-Content -Encoding utf8` 会**写入 UTF-8 BOM**（文件头三个字节 `EF BB BF`）
- `utf8NoBOM` 这个取值在 5.1 里不存在，会直接报参数错误
- 要写无 BOM 的 UTF-8 文件，用：
  ```powershell
  [System.IO.File]::WriteAllText($path, $json, (New-Object System.Text.UTF8Encoding($false)))
  ```

**curl 的 HTTPS 在这个环境里用不了**，会报 `schannel: AcquireCredentialsHandle failed: SEC_E_NO_CREDENTIALS`。所以：

- 抓外部站点、访问外部 API 一律用 **Node 的原生 `fetch`**，它是正常的
- `curl.exe` 调 `http://127.0.0.1` 这类本地地址没问题

**控制台会乱码**。中文经过 PowerShell 控制台会按本地代码页解码，显示成 `ï¼`、`缃戠珯` 之类。

- 一律**写文件再用文件读取工具读**，不要靠控制台打印中文判断内容
- 响应体用 `curl -o file` 落盘，不要直接打印

**临时目录会在两次调用之间轮换**（`$env:TEMP` 会变，旧目录还会变成只读）。选一个固定的绝对路径当工作目录，不要依赖 `$env:TEMP`。

**`$pid` 是 PowerShell 的只读内置变量**，不能拿来当普通变量名，会报 `Cannot overwrite variable PID`。

**传 JSON 请求体必须用 `--data-binary @文件`**。不要把 JSON 直接写在命令行里——引号会被 shell 吃掉，导致请求体残缺，然后接口报的错会把你带偏（曾经因此误判成接口有问题）。也不要图省事用 `-d`。

## 守则

- **描述自己总结**，不要去抓站点的 `meta description`。那是 SEO 文案，又长又水，和库里现有条目的风格不搭。写 10~30 字中文，说清"这是个什么站、用来干什么"，不写营销词。
- **logo 存 URL，不存 base64**，不要让前端把一串字符当文本渲染出来。
- **重复项一定要列给用户看**，不要默默跳过——用户需要知道哪些没录进去。
- **不要创建只有 1 个书签的分类**。
- **写库前把汇总文件给用户过目**，这是批量写操作，确认后再动。
- **拿不准的归属宁可问用户**，不要硬塞进一个语义不符的分类。
- 写库后**必须回读校验**，把实际结果（分类分布、总数）报给用户，而不是只说"完成了"。
