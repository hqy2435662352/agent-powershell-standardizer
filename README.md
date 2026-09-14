# Agent PowerShell Standardizer

A high-reliability PowerShell execution & generation skill for AI agents. Ensures all generated PowerShell scripts follow "object-oriented" philosophy, avoid Linux/Bash thinking, and achieve enterprise-level maintainability.

## Problem

AI agents (like Claude, Cursor, Trae) often generate PowerShell scripts with Linux/Bash patterns that fail on Windows:

- ❌ Using `ls` instead of `Get-ChildItem`
- ❌ String concatenation for paths (`$dir + "\" + $file`)
- ❌ No encoding specified for file operations
- ❌ No error handling or `-WhatIf` support

## Solution

This skill provides a comprehensive set of rules and patterns that AI agents follow when generating PowerShell code:

- ✅ Enforces Verb-Noun command format
- ✅ Object-oriented pipeline thinking
- ✅ Path safety with `Join-Path`
- ✅ Explicit encoding for file operations
- ✅ Error handling with structured analysis
- ✅ Safe destructive operations with `-WhatIf`

## Installation

### For Trae/Cursor/Windsurf Users

1. Copy the `agent-powershell-standardizer` folder to your project's `.trae/skills/` directory:
   ```
   your-project/.trae/skills/agent-powershell-standardizer/
   ```

2. The skill will be automatically loaded when:
   - Executing PowerShell commands
   - Writing `.ps1` scripts
   - Translating Bash/Shell to PowerShell
   - Troubleshooting PowerShell errors

### Manual Installation

Copy the `agent-powershell-standardizer` folder to:
- **Trae**: `.trae/skills/`
- **Cursor**: `.cursor/rules/`
- **Windsurf**: `.windsurf/rules/`

## Core Principles

### 1. Never Use Aliases

| Never Use | Must Use |
|-----------|----------|
| `ls` | `Get-ChildItem` |
| `cp` | `Copy-Item` |
| `rm` | `Remove-Item` |
| `cat` | `Get-Content` |
| `grep` | `Where-Object` |
| `curl` | `Invoke-RestMethod` |
| `echo` | `Write-Output` |

### 2. Object-Oriented First

```powershell
# ❌ Never (Bash thinking)
$content = Get-Content -Path "config.txt" -Raw
if ($content -match "server=(\w+)") { ... }

# ✅ Must (PowerShell thinking)
$config = Get-Content -Path "config.txt" | ConvertFrom-StringData
$server = $config.server
```

### 3. Path Safety

```powershell
# ❌ Never
$file = $folder + "\" + $filename

# ✅ Must
$file = Join-Path -Path $folder -ChildPath $filename
```

### 4. Character Encoding

Encoding is a **silent** failure mode — the command succeeds and the data is wrong:

| | `Set-Content -Encoding utf8` |
|---|---|
| Windows PowerShell 5.1 | writes a BOM (`EF BB BF`) |
| PowerShell 7 | no BOM |

Both produce valid UTF-8, but a BOM will break many JSON parsers. When data crosses
versions or tools, go through .NET explicitly so both behave identically:

```powershell
[System.IO.File]::WriteAllText($path, $json, [System.Text.UTF8Encoding]::new($false))
$json = [System.IO.File]::ReadAllText($path, [System.Text.UTF8Encoding]::new($false))
```

### 5. Risk Control

`-WhatIf` is a built-in common parameter — do not hand-roll an `if/else` simulation
branch, and do not declare your own `[switch]$WhatIf`. Pass it through instead:

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

`SupportsShouldProcess` supplies `-WhatIf` / `-Confirm` automatically, and the switch
flows down to every cmdlet in the pipeline. `-WhatIf:$false` executes for real.

## Trigger Conditions

Loading a skill costs context on every turn, so the trigger is deliberately narrow —
it fires on the situations where an agent would otherwise guess wrong:

1. **Windows-only capability**: registry, services, event log, CIM/WMI, ACL, scheduled tasks
2. **5.1 compatibility**: a `.ps1` that must run on Windows PowerShell 5.1 as well as 7
3. **Troubleshooting**: a PowerShell command failed and needs diagnosis rather than a retry
4. **Cross-boundary data**: JSON text or non-ASCII paths moving between shells or tools

It intentionally does **not** fire for every Windows command, nor for POSIX text
processing inside Git Bash / WSL.

## Pre-Flight Checks

- ✅ Version established (`$PSVersionTable`) before using any version-specific feature
- ✅ `ConvertTo-Json -Depth` specified whenever the object nests
- ✅ Encoding/BOM behaviour identical on every machine that reads the output
- ✅ Destructive actions use the built-in `-WhatIf:$WhatIf`, not a hand-written branch

Note on `Test-Path`: it returns `False` both for "does not exist" and "no permission",
so it cannot distinguish the two. When that distinction matters, catch the error instead:

```powershell
try   { $item = Get-Item -LiteralPath $path -ErrorAction Stop }
catch { $null = $_.Exception.GetType().FullName }   # UnauthorizedAccessException vs ItemNotFoundException
```

## Examples

### Before (Agent generates)

```powershell
ls | grep "test"
cat config.json
rm -rf temp/*
curl -X POST -d 'data' https://api.example.com
```

### After (With skill applied)

```powershell
Get-ChildItem | Where-Object { $_.Name -match "test" }
Get-Content -Path "config.json" -Encoding utf8
Get-ChildItem -Path "temp" -Recurse | Remove-Item -WhatIf
Invoke-RestMethod -Method Post -Body 'data' -Uri "https://api.example.com"
```

## Project Structure

The skill lives in a subdirectory that shares the repository name — copy **that**
directory, not the repository root:

```
agent-powershell-standardizer/                  # repository root
├── README.md                                   # this file
├── LICENSE                                     # MIT License
├── agent-powershell-standardizer/              # ← copy THIS folder into your skills dir
│   └── SKILL.md                                # main skill definition
└── examples/
    ├── file-processing.ps1                     # path safety, -WhatIf, JSON output
    └── rest-api-call.ps1                       # error handling across PS 5.1 / 7
```

## Scope

This skill is deliberately narrow. It does not teach PowerShell syntax and it does
not cover POSIX tooling — an agent already handles `Get-ChildItem` and `Join-Path`
without help. It covers only the things a capable agent still gets wrong:

- **Which version am I on** — 5.1 vs 7 changes what runs at all
- **Which failures are silent** — `ConvertTo-Json` depth truncation, BOM differences
- **How to read a failure** — the structured error object, not a retry loop

See [`SKILL.md`](agent-powershell-standardizer/SKILL.md) for the full text.

## Requirements

- **Platform**: Windows
- **PowerShell**: 5.1 or 7+
- **AI Agent**: Trae, Cursor, Windsurf, or similar

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please open an issue or pull request for:

- New anti-patterns to flag
- Additional common patterns
- Documentation improvements

## Acknowledgments

- Inspired by PowerShell best practices from Microsoft Docs
- Built for AI agent reliability on Windows platforms
