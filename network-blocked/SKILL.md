---
name: network-blocked
description: "处理 Windows 受限令牌导致的 HTTPS 失败：判定是否为沙箱阻塞，再按本次任务的网络访问次数分别走一次性授权或暂停等用户切换。命令报 schannel 凭据错误、.NET 连接被关闭，但 DNS/TCP/纯 HTTP 正常时使用。"
whenToUse: "命令因网络报错且疑似沙箱阻塞时——curl 报 schannel / SEC_E_NO_CREDENTIALS、Invoke-RestMethod 或 Invoke-WebRequest 报“基础连接已经关闭”、git/pip/其他走 Schannel 的工具 HTTPS 失败，而 DNS、TCP、http:// 正常；也包括用户直接说“网络不通”“连不上外网”“帮我看看是不是沙箱”这类情况。"
metadata:
  language: "zh"
  category: "development"
disable-model-invocation: false
user-invocable: false
---

# 网络被沙箱阻塞时的处置（network-blocked）

## 目标

网络请求失败时，快速判定是不是 Windows 受限令牌把 Schannel 的凭据获取掐断了，然后按本次任务的网络访问需求选对动作：只有一次访问就直接申请授权；要访问很多次就先停下来等用户切换模式。

## 判定：是不是沙箱阻塞

同时满足这几条，才算沙箱阻塞，才走下面两条路径：

- DNS 解析正常、TCP 能连上目标端口；
- 纯 `http://` 请求能拿到正常响应；
- 只有 `https://` 失败，并且是走 Schannel / WinHTTP / WinINET 的客户端在失败。

典型的失败痕迹：

| 客户端 | 表现 |
|---|---|
| `curl.exe` | `exit 35`，`schannel: AcquireCredentialsHandle failed: SEC_E_NO_CREDENTIALS (0x8009030e)` |
| PowerShell `Invoke-RestMethod` / `Invoke-WebRequest` | “基础连接已经关闭: 接收时发生错误” |
| 其他走 Schannel 的工具 | HTTPS 失败，换 `http://` 就正常 |

**不要绕过判定、直接假定是沙箱问题。** 下面这些不是沙箱阻塞，按真正的网络/业务问题处理：

- DNS 解析不了、TCP 连不上；
- URL 写错、需要代理、证书过期；
- 服务端返回 4xx/5xx（请求已经到服务器了）；
- 客户端自带 TLS 栈（Node 的 `fetch` / undici 等）能通——这类不受影响，别硬说它也被挡。

另外，是否处于受限令牌要用实际探测确认，不要凭会话印象断言。写工作区外的路径（比如 `C:\Windows\Temp`）被拒，就说明当前是受限的。

## 动作一：只有一次网络访问 → 直接申请权限

本次任务只需要发一次请求时，不要为了这一次就打断用户，直接发起一次性升级申请：

- 用 DSH 的 `sandbox_permissions: danger-full-access` 重跑**同一条命令**，并带上 `justification`。
- `justification` 要写清三点：受限令牌挡住了 Schannel 的凭据获取、不是网络本身不通；这是**仅此一次**的调用，不会改会话模式。
- 升一次只作用于那一次调用。拿到结果后继续原任务，**不要**把这当成会话已经切到 full access。

申请被用户拒绝，就停下来说明情况，不要换别的路子重试。没有可用的审批通道时，请求会失败关闭——如实报告，不要绕过沙箱去拿结果。

## 动作二：以后还有很多次网络访问 → 暂停任务，等用户切换

本次任务后续还有多次网络访问（批量拉数据、循环调 API、多次 clone、装依赖等）时：

1. **先停下手上的任务**，不要一条条去申请一次性授权。
2. 停下来时用最多三四行说清：什么命令失败了、报的什么错、判定为沙箱受限令牌阻塞、后面还需要多少次网络访问。
3. 请用户把会话切到 `danger-full-access`，然后等用户回复。
4. 用户确认切换后，继续原来的任务，不要重头再来。

模式切换由用户操作，**不要**自己反复申请升级来代替切换。

## 守则

- 判定、动作一、动作二按顺序执行，不要跳步。
- 输出里只写实际观察到的事实，不要把没跑过的对照说成跑过了，也不要声称"full access 下验证正常"除非真的切换并跑过。
- 别用脚本、别改系统配置、别动沙箱的 ACL 或任何绕过手段来"修"这个问题——只需按上面两条路径处置。
- 用户已经切到 `danger-full-access` 后，本 skill 不再适用，直接干活。
