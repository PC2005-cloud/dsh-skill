---
name: skill-writer
description: "根据用户对功能的一句描述，生成符合 DSH 规范的 SKILL.md skill，并用弹窗让用户在用户级/项目级目录中二选一安装。用户说“写个 skill/创建技能/给 agent 加技能”时使用。"
whenToUse: "用户要求编写或生成一个新的 DSH skill 时使用；或 AI 需要了解 DSH 的 SKILL.md 字段规范、触发方式与安装目录约定时使用。"
metadata:
  language: "zh"
  category: "development"
disable-model-invocation: true
user-invocable: true
---

# 编写一个 DSH skill

## 目标

根据用户对一个新 skill 的功能描述，创建出符合 DSH 规范的 skill（一个目录下的 `SKILL.md`），并写入用户选择的安装目录。本文件是 DSH skill 的格式与流程说明——AI 不需要再翻 DSH 源码找格式。

## 什么是 DSH skill

- 一个 skill 就是一个目录，核心是一个 `SKILL.md` 文件。
- `SKILL.md` 顶部是 YAML frontmatter（用 `---` 包裹的元数据块），下面是给 AI 的行为指令正文。
- frontmatter 决定这个 skill 何时被触发、是否允许模型自动调用。

## frontmatter 字段（按序规划）

1. **`name`**：简短、kebab-case（小写、连字符，如 `write-skill`、`blog-write`）。尽量贴合用途。实际编写时，此字段**必须用 DSH 选择弹窗请用户确认**（见“工作流”步骤 3），不能直接默认。
2. **`description`**：**一句话（半句到两句）概括本 skill 的「功能 + 触发场景」**。这是 AI 判断是否触发本 skill 的关键依据，只需回答两个问题：这个 skill 干什么、什么场景该用。**不要写流程细节**——检索方式、接口、字段列表、工作流步骤等一律留给正文；也别把“AI 若不清楚…可从本 skill 获取”这类说明写进 description。
3. **`whenToUse`**：明确写出用户的哪些说法/场景应触发本 skill。
4. **`metadata`**：`{ language, category }`。`language` 默认 `zh`；`category` 按 skill 主题合理选取（如 writing / development / ops 等），不要生搬硬套。
5. **`disable-model-invocation`**：是否禁止模型自动调用。仅允许用户手动调用时设为 `true`。
6. **`user-invocable`**：是否允许用户手动调用。手动调用时设为 `true`。

若用户已经指定了某字段取值，以用户为准；否则按上述规则自己规划。

## 正文怎么写

- 用清晰的节标题组织内容：目标、输入与输出、工作流、素材来源、守则等。
- 步骤要足够具体，让 AI 照着就能执行，不需要再翻源码查格式。
- 用中文撰写；保持自然、避免 AI 腔（可参考 blog-write 的去 AI 味规则）。
- 不要把你的思考过程、内部检查项写进正文；以给 AI 看的操作说明口吻呈现。

## 工作流

1. **明确描述**：读取用户要写的 skill 的功能描述，若描述含糊，先请用户补充一句。
2. **规划字段**：按上面“frontmatter 字段”的顺序，确定 `name / description / whenToUse / metadata / disable-model-invocation / user-invocable`。
3. **确认 name（用 DSH 的选择弹窗）**：调用 DSH 的 `ask_user_question` 工具，把 AI 建议的 `name` 作为推荐项，另附 1~2 个备选 kebab-case 名称作为选项，让用户在弹窗里确认或自定义。除非用户已经明确指定了 name，否则**不能直接默认**。
4. **撰写正文**：写清目标、输入输出、工作流、守则。
5. **选择安装目录（用 DSH 的选择弹窗）**：调用 DSH 的 `ask_user_question` 工具，以选择弹窗形式让用户在两个目录里二选一：
   - **用户级**：`<DSH 用户 skills 目录>\<name>\SKILL.md`（Windows 一般形如 `C:\Users\<用户名>\.dsh\skills\<name>\SKILL.md`，用户名不要写死）
   - **项目级**：`<当前项目目录>\.agents\skills\<name>\SKILL.md`
     - 注意：结尾是 `.agents\skills`，**不是** `.dsh\skill`。
     - “当前项目”以本次工作目录为准。
6. **写入**：把成稿 `SKILL.md` 写入所选目录，然后简短告知已写入的路径。

## 守则

- `name` 的确认和安装目录的选择都**必须走 DSH 的选择弹窗（ask_user_question）**，不能自己猜、也不能直接默认。
- 项目级路径必须是 `<当前项目>\.agents\skills` 这种形式，不要写成 `.dsh\skill`。
- 若所选目录在工作区之外，写文件可能需要沙箱升级/审批，按 DSH 的审批流程处理，不要擅自绕过。
- 只写 `SKILL.md`，不写无关文件；成稿内不包含“我在帮 AI 写”这类过程性叙述。
- `description` 只概括「这个 skill 干什么 + 什么场景触发」，把流程/接口/细节放进正文，别把 description 写成长段。
- 新写的 skill 的触发方式（自动/手动）如用户没提，按用途合理推断并写进 frontmatter。
