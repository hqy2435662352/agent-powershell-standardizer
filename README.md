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

```powershell
# PowerShell 5.1
Set-Content -Path $path -Value $data -Encoding utf8

# PowerShell 7+
Set-Content -Path $path -Value $data  # UTF-8 by default
```

### 5. Risk Control

```powershell
param([switch]$WhatIf)

if ($WhatIf) {
    Write-Warning "Simulating: Will delete files..."
} else {
    Remove-Item -Path $target -Recurse
}
```

## Trigger Conditions

The skill automatically activates when:

1. **Self-Execution**: Agent needs to execute commands on Windows
2. **Code Generation**: Writing `.ps1` scripts for automation
3. **Translation**: Converting Bash/Shell to PowerShell
4. **Troubleshooting**: Previous PowerShell command failed

## Pre-Flight Checks

Every generated script must include:

- ✅ `Test-Path` before file operations
- ✅ `$PSVersionTable` compatibility check
- ✅ `-WhatIf` for destructive actions

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

```
agent-powershell-standardizer/
├── SKILL.md          # Main skill definition
├── LICENSE           # MIT License
├── README.md         # This file
└── examples/        # Usage examples (optional)
    └── demo.ps1
```

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
