---
name: agent-powershell-standardizer
description: >
  Windows PowerShell 边界手册。不教语法，只回答三件模型自己答不好的事：
  (1) 本机是 PowerShell 5.1 还是 7，能力分水岭在哪；
  (2) 哪些写法在 5.1 上直接报错或在 7 上静默损坏数据；
  (3) 命令失败后如何从结构化错误对象定位真因，而不是重试。

  TRIGGERS（满足任一即加载）：
  1. 任务需要 Windows 本地能力：注册表、服务、事件日志、CIM/WMI、ACL、计划任务。
  2. 生成的 .ps1 需要同时兼容 Windows PowerShell 5.1（大量生产机仍在跑）。
  3. 之前的 PowerShell 命令报错，需要诊断而非重试。
  4. 需要跨 shell 传递数据（JSON 文本、含中文的路径或文件）。

  不适用：纯 POSIX 文本流处理、仅用 git/npm 等跨平台 CLI 的任务、已能一次跑通的简单管道命令。
---

# PowerShell 边界手册

**唯一原则：先确定版本，再写代码。** 5.1 与 7 的分歧不是风格问题，是能不能跑的问题，
而且部分失败是静默的（数据被破坏但命令返回成功）。

## 1. 环境门检

把它放在每个 .ps1 的开头，不要假设 5.1 或 7：

```powershell
$isPS7 = $PSVersionTable.PSVersion.Major -ge 7
# $IsWindows / $IsLinux / $IsMacOS 是 PS7 自动变量，5.1 上为 $null
$onWindows = if ($isPS7) { $IsWindows } else { $true }
```

在 5.1 上运行 pwsh 专有语法有两种失败形态（详见第 2 节）：
运算符类（`? :`、`??`、`&&`）是**解析期**失败，整个脚本无法启动；
参数类（`-Parallel`、`-StatusCodeVariable`）是**运行期**失败，跑到那行才炸。
需要硬性拦截前者用 `#Requires`：

```powershell
#Requires -Version 7.0   # 仅当确实必须用 PS7 特性时添加
```

## 2. 版本分水岭

**失败分两类，后果不同：解析期报错 = 整个脚本一行都不执行；
运行期报错 = 跑到那一行才炸，可能已经改了一半系统。**

| 特性 | 5.1 | 7+ | 5.1 上的失败形态 |
|---|---|---|---|
| 三元 `? :`、`??`、`&&`/`\|\|` 链 | ❌ | ✅ | **解析期**——脚本完全无法启动 |
| `Invoke-RestMethod -StatusCodeVariable` | ❌ | ✅ | **运行期**：`Parameter set cannot be resolved` |
| `Invoke-RestMethod -SkipHttpErrorCheck` | ❌ | ✅ | **运行期**；5.1 上非 2xx 一律抛异常 |
| `ForEach-Object -Parallel` / `-ThrottleLimit` | ❌ | ✅ | **运行期**：`Parameter set cannot be resolved` |
| `$IsWindows` / `$PSStyle` | ❌ | ✅ | **静默**：为 `$null`，条件判断走错分支且不报错 |
| `Set-ItemProperty -Name Mode` | ❌ 报错 | ❌ 报错 | **没有 chmod 等价物**，见第 5 节 |
| 服务 / 证书 / CIM | ✅ | ✅ | 两边都可用，写法有差异 |

用 `-Parallel` 尤其危险：在 5.1 上脚本能正常解析、前面的逻辑照常执行，
直到这一行才失败，容易留下做了一半的状态。

## 3. 两个静默损坏点

**这两处命令返回成功但数据是坏的，不报错，必须显式指定。**

**JSON 深度**——`ConvertTo-Json` 默认 `-Depth 2`，超出部分被截断成
`@{L4=}`（类型从对象退化成字符串），仅给出一条 warning：

```powershell
# 嵌套 4 层以上就会中招
$obj | ConvertTo-Json -Depth 10
```

**编码 BOM**——两边都写得出 UTF-8，但字节不同，互读时 JSON 解析器常死于 BOM：

| | `Set-Content -Encoding utf8` |
|---|---|
| PS 5.1 | 带 BOM（`EF BB BF`） |
| PS 7 | 不带 BOM |

要跨版本、跨工具传递数据时，两边都显式走 .NET：

```powershell
# 写入：显式无 BOM，5.1 / 7 行为一致
[System.IO.File]::WriteAllText($path, $json, [System.Text.UTF8Encoding]::new($false))

# 读取：显式按无 BOM UTF-8 解析
$json = [System.IO.File]::ReadAllText($path, [System.Text.UTF8Encoding]::new($false))
```

## 4. 错误诊断：读对象，不要重试

命令失败时不要换引号重试、不要加 `sudo`、不要猜。
`$_.Exception.GetType().FullName` 直接给出真因，**且 5.1 和 7 的类型不同**：

```powershell
try {
    Invoke-RestMethod -Uri $url -ErrorAction Stop
} catch {
    $type = $_.Exception.GetType().FullName
    $status = 0

    if ($type -eq 'System.Net.WebException') {
        # Windows PowerShell 5.1
        $resp = $_.Exception.Response
        if ($null -ne $resp) { $status = [int]$resp.StatusCode }
    }
    elseif ($type -eq 'Microsoft.PowerShell.Commands.HttpResponseException') {
        # PowerShell 7，HTTP 状态码非 2xx
        $resp = $_.Exception.Response
        if ($null -ne $resp) { $status = [int]$resp.StatusCode }
    }
    elseif ($type -eq 'System.Net.Http.HttpRequestException') {
        # PowerShell 7，连接层失败（DNS / TLS / 超时），无 HTTP 响应
        $status = 0
    }

    throw "$type (HTTP $status): $($_.Exception.Message)"
}
```

**PS7 有两个异常类型，只认一个会漏掉半数失败**——非 2xx 走 `HttpResponseException`，
DNS 解析失败 / TLS 握手失败 / 超时走 `HttpRequestException`，后者的 `.Response` 为 `$null`。

`System.Net.Http.HttpRequestException` 的存在也说明：不要用 `-match 'Web\w*'` 这类正则
来归类异常，它匹配不到 `...HttpResponseException`（实测为 `False`），会把 7 上的
状态码分支整个跳过。**直接枚举完整类型名，并用 `if/elseif` 精确相等比较。**

注意 `switch` 对字符串是**完整匹配、大小写不敏感**，但**支持通配符**：
`case 'WebException'` 不会命中 `'System.Net.WebException'`（少了命名空间），
而 `case '*WebException'` 才会。类型名必须写全。

## 5. 反模式（全文仅保留模型易错项）

| 错误写法 | 问题 | 正确做法 |
|---|---|---|
| `Set-ItemProperty -Path x.ps1 -Name Mode -Value 'rwxr-xr-x'` | 伪等价。PS7 实测抛 `SetValueException: 属性"Mode"的 Set 访问器不可用`；NTFS 无 Unix 权限位语义 | `.ps1` 能否运行只取决于 **ExecutionPolicy**，不是文件权限。需要时用 `powershell -ExecutionPolicy Bypass -File x.ps1` |
| `-Path $a + "\" + $b` | 分隔符硬编码 | `Join-Path -Path $a -ChildPath $b` |
| `Test-Path` 为 `False` 就断定"文件不存在" | `False` 同时表示"不存在"和"无权限访问"，无法区分 | 需要区分时用 `try { Get-Item -LiteralPath $p -ErrorAction Stop } catch { $_.Exception.GetType().FullName }` |
| 手工 `[switch]$WhatIf` + `if/else` 双分支 | 绕开 cmdlet 内置支持，且管道内对象不受控 | 直接用内置参数：`Remove-Item -Recurse -Force -WhatIf:$WhatIf` |

## 6. 破坏性操作的唯一正确写法

`-WhatIf` 是 cmdlet 的**通用参数**，`Remove-Item` / `Copy-Item` / `Stop-Service` 等原生支持，
且在 `-WhatIf:$false` 时正常执行。不要再手写模拟分支：

```powershell
function Remove-OldLogs {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$LogDirectory,
        [Parameter(Mandatory)][int]$DaysToKeep
    )
    $cutoff = (Get-Date).AddDays(-$DaysToKeep)
    Get-ChildItem -Path $LogDirectory -Filter '*.log' |
        Where-Object { $_.LastWriteTime -lt $cutoff } |
        Remove-Item -Force -WhatIf:$WhatIfPreference
}
```

`SupportsShouldProcess` 自动提供 `-WhatIf` / `-Confirm`，`$WhatIfPreference` 反映调用方意图，
`-WhatIf` 会一路向下传递给管道里的每个 cmdlet。

## 7. 自检清单

输出任何 PowerShell 前确认：

- [ ] 我确定目标机器是 5.1 还是 7 吗？不确定就走版本门检。
- [ ] 用到的特性在第 2 节表里属于哪一边？5.1 会解析期报错吗？
- [ ] `ConvertTo-Json` 指定 `-Depth` 了吗？
- [ ] 跨版本/跨工具读写文件时，BOM 行为一致吗？
- [ ] 破坏性操作传的是 `-WhatIf:$WhatIf` 而不是手写分支吗？
- [ ] 出错时我读的是 `$_.Exception.GetType().FullName`，而不是在猜吗？

## 8. 推荐的 Windows Agent 默认运行方式

**自己执行命令时用 `pwsh`，处理文本用 Git Bash；只有在写"要交付给别人跑"的脚本时，
才需要回头看第 2、3 节的 5.1 边界。**

选 Git Bash 处理文本不是为了快。实测同一任务（2000 行日志里数匹配行）：
`Select-String` 33.9 ms，`grep -c` 165.6 ms——grep 慢的那 135 ms 全是 Git Bash
进程启动。理由是**人体工学**：`grep` / `awk` / `sed` 语义紧凑、到处都有、不用记
cmdlet 名。而 PowerShell 不可替代的是 Git Bash 看不见的东西：注册表、服务、
事件日志、CIM/WMI、ACL、计划任务。

真正被数据决定的是**用哪个 PowerShell**。单次调用启动开销实测：

| Shell | 每次启动 |
|---|---|
| `cmd /c` | 24.9 ms |
| Git Bash `-c` | 135 ms |
| `pwsh -Command`（PS7） | 484.6 ms |
| `powershell -Command`（5.1） | **2353 ms** |

agent 的真实成本是进程启动——一条命令通常就是一个进程。5.1 每次 2.35 秒，
约是 Git Bash 的 17 倍、`pwsh` 的 5 倍（对 `cmd` 更是近百倍），还没开始干活。
**所以默认用 `pwsh`，5.1 不要进日常回路。**

但 5.1 躲不掉的地方在"交付"而不在"执行"：它是 Windows 的一个组件，跟随
Windows 支持生命周期，**没有独立 EOL、不能单独卸载**，计划任务、WinRM 会话、
未改动的服务器镜像默认给你的就是它。**你自己机器上能选 PS7，跑你脚本的那台
机器上不能。**

对照这个分界使用本手册：

- **写完自己跑** —— 只面向 PS7，现代语法随便用，第 2 节以下的兼容内容可以跳过。
- **写完给别人跑** —— 无法验证时按 5.1 处理，重点看第 2 节（哪些是解析期失败、
  哪些是运行期失败）和第 3 节（两个静默损坏点）。
