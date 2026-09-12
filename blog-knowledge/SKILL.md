---
name: blog-knowledge
description: "当开发或解题需要某个技术方向的知识、而用户博客里很可能已有对应教程时，从本地博客（http://localhost:18016）按关键词检索相关文章并读取全文，作为 AI 做任务的知识来源，避免联网乱搜。用于“查我博客/用我博客里的知识/按我的教程来做”等场景。"
whenToUse: "AI 接到开发/解题任务，涉及某个技术方向的知识，而该方向用户博客很可能有对应教程；或用户明确要求从自己的博客检索知识、用自己教程里的做法时使用。"
metadata:
  language: "zh"
  category: "development"
disable-model-invocation: true
user-invocable: true
---

# 从个人博客检索技术知识

## 目标

用户维护了一个博客，里面的文章都是他自己的技术教程与实践总结（GitHub、数据库、前端、框架、工具用法等）。当你在开发项目或解决某个技术问题时，如果这个方向的知识用户很可能已经写进博客了，就**优先从用户博客里检索相关文章、读取正文，把它作为你的知识来源**，而不是漫无目的地联网搜索。这样既能贴合用户自己的习惯和踩过的坑，也更快、更准。

## 何时用 / 何时别用

- **应该用**：当前任务涉及一个具体技术方向（用关键词能描述出来），且用户博客很可能写过该方向；或用户明确让你“查我博客”“用我博客里的知识”“按我的教程来做”。
- **不该用**：任务是通用常识、与用户个人技术栈无关，或明显博客里不可能有的内容；用户没要求、且你也没有把握博客里有相关文章时，不要每次任务都查。

## 素材来源与接口

- **后端地址**：`http://localhost:18016`（本地博客后端，接口公开、无需登录）。
- **统一返回**：`{ code, message, data }`，`code == 1` 表示成功；分页 `data` 含 `total` 和 `rows`。
- 两个关键接口：
  1. `POST /api/article/public/page` —— 分页检索已发布文章。请求体 `{"pageNum":1,"pageSize":N,"query":{"keyword":"关键词"}}`。返回 `data.rows`，每项是 `ArticleListVO`，**只含 title / summary / coverImage / categoryName / tags / series / viewCount 等，不含正文**。
  2. `GET /api/article/public/{id}` —— 按 id 拿单篇详情，返回 `data.content` **才是文章完整正文**。

> 关键：列表接口给你的只是标题和摘要，**要拿到真实教程内容必须再按 id 拉详情正文**。判断相关性靠 title+summary，取正文靠详情接口。

## 工作流

1. **判断是否要查**：看当前任务是否落在一个“用户很可能写过教程”的技术方向上。是 → 查；否 → 不查。
2. **提取关键词**：从当前任务里提炼 1~3 个具体关键词（领域 / 工具 / 概念，如 `GitHub Action`、`游标分页`、`Docker`）。优先用具体术语，别用“技术”“教程”这类泛词。
3. **列表检索**：用关键词调 `public/page` 接口搜标题与摘要，`pageSize` 可放大到 20 左右覆盖更多结果。首页没有命中时，可换更宽或更具体的关键词再搜一次，但**不要为了找文章逐页翻完 100 多篇、把全量塞进上下文**。
4. **挑选相关文章**：凭返回的 title + summary 判断相关性，选出**最相关的几篇**（一般 3 篇以内，够用即可）。
5. **拉取正文**：对选中的文章 id 逐个调 `GET /api/article/public/{id}`，读取 `content` 正文。
6. **使用知识**：把正文里的做法、命令、配置、注意事项作为你解答当前任务的依据；结合任务实际使用，必要时说明“这条来自你博客的某篇文章”。

## Python 脚本（统一用这一种方式调接口）

用 **Python 脚本 + 标准库 urllib**（无需安装 requests），并**先写成临时 `.py` 文件再运行**（`python 脚本.py`），不要用 `python -c "…"` 内联——内联中文/引号会被 shell 转义搞坏，且按 UTF-8 编解码才能避免中文乱码。

```python
import json, urllib.request, sys
try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

BASE = "http://localhost:18016"

def post_json(url, payload):
    body = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=body,
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=20) as resp:
        return json.loads(resp.read().decode("utf-8"))

def get_json(url):
    with urllib.request.urlopen(url, timeout=20) as resp:
        return json.loads(resp.read().decode("utf-8"))

# 1) 列表检索：按当前任务填关键词（1~3 个）
kw = "GitHub"   # ← 换成从任务里提炼的关键词
res = post_json(BASE + "/api/article/public/page",
                {"pageNum": 1, "pageSize": 20, "query": {"keyword": kw}})
data = res.get("data") or {}
print("code:", res.get("code"), "| total:", data.get("total"))
for r in data.get("rows") or []:
    print(r["id"], "|", r["title"], "|", (r.get("summary") or "")[:60])

# 2) 详情正文：对选中的文章 id 逐个拉全文
for aid in [210]:   # ← 换成上一步选中的文章 id
    d = get_json(f"{BASE}/api/article/public/{aid}")
    art = d.get("data") or {}
    print("\n==== 正文:", art.get("title"), "====")
    print((art.get("content") or "")[:3000])
```

- 成功看 `code == 1`；`code != 1` 或 HTTP 400 → 多半是请求体/转义问题，先自查，不是服务端问题。
- 全文按 UTF-8 编解码，不要按系统 GBK 解码，否则中文乱码。

## 守则

- 只在确实需要该领域知识时才调，不要任何任务都无脑查博客。
- 列表接口**不含正文**，务必按 id 拉详情拿真实内容；同时**不要把所有命中文章全文都灌进上下文**，只拉最相关的几篇。
- 只读这个博客，**不要调用任何写接口**（不新增/发布文章，不碰 `/api/article` 的 POST/PUT/DELETE）。
- 取到的知识当作参考来源使用；若正文与当前任务不完全匹配，说明情况并照常继续，别硬套。
- 把过程性思考留在工作里，不要把“我在调自己博客接口”这类叙述写进交付给用户的最终材料。
