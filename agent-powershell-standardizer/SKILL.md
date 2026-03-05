---
name: agent-powershell-standardizer
description: >
  A high-reliability PowerShell execution & generation engine. 
  Focuses on eliminating "Linux-thinking" hallucinations and preventing runtime execution errors on Windows. 
  
  CORE MISSION: 
  Ensure every command is executable, safe, and object-oriented. 
  
  SPECIFIC TRIGGERS:
  1. [Self-Execution]: Whenever the Agent needs to execute a command on a local/remote Windows host to perform a task.
  2. [Code Generation]: When writing .ps1 scripts for user automation.
  3. [Translation]: When converting Shell/Bash snippets to Windows equivalents.
  4. [Troubleshooting]: When a previous PowerShell command failed with an error.

  MANDATORY PRE-FLIGHT CHECKS:
  - Verify Path: Use 'Test-Path' before file operations.
  - Verify Version: Check '$PSVersionTable' for compatibility.
  - Safe-Mode: Always use '-WhatIf' for destructive actions unless explicitly overridden.
---

# PowerShell Architect

## Core Principles

### 1. Never Use Aliases

All commands must use the complete **Verb-Noun** format.

| Never Use | Must Use |
|-----------|----------|
| `ls` | `Get-ChildItem` |
| `cp` | `Copy-Item` |
| `mv` | `Move-Item` |
| `rm`, `del` | `Remove-Item` |
| `cat`, `type` | `Get-Content` |
| `ps` | `Get-Process` |
| `grep` | `Where-Object` |
| `curl` | `Invoke-WebRequest` / `Invoke-RestMethod` |
| `wget` | `Invoke-WebRequest` |
| `echo` | `Write-Output` |
| `sort` | `Sort-Object` |
| `uniq` | `Select-Object -Unique` |
| `head` | `Select-Object -First` |
| `tail` | `Select-Object -Last` |
| `wc` | `(Get-Content).Count` |

### 2. Object-Oriented First

**Never** perform string slicing or complex regex matching on output. **Always** use the pipeline to pass objects.

```powershell
# Never (Bash thinking)
$content = Get-Content -Path "config.txt" -Raw
if ($content -match "server=(\w+)") { ... }

# Must (PowerShell thinking)
$config = Get-Content -Path "config.txt" | ConvertFrom-StringData
$server = $config.server
```

```powershell
# Never
$processes = ps
$ids = @()
foreach ($p in $processes) {
    if ($p.Name -eq "notepad") { $ids += $p.Id }
}

# Must
$processIds = Get-Process | Where-Object { $_.Name -eq "notepad" } | Select-Object -ExpandProperty Id
```

### 3. Strong Typing

When handling complex logic, declare variable types first:

```powershell
[string]$serverName = "localhost"
[int]$retryCount = 3
[PSCustomObject]$result = [PSCustomObject]@{
    Status = "Success"
    Message = "Operation completed"
}
```

### 4. Path Safety

**Never** manually concatenate path strings. **Must** use `Join-Path` or `Resolve-Path`.

```powershell
# Never
$file = $folder + "\" + $filename

# Must
$file = Join-Path -Path $folder -ChildPath $filename

# Multiple path segments
$configFile = Join-Path -Path (Join-Path -Path $env:ProgramData -ChildPath "MyApp") -ChildPath "config.json"
```

### 5. Character Encoding

In Windows environments, encoding issues are a common failure point (especially when handling Chinese paths or files). Always explicitly specify encoding when reading or writing files:

- **PowerShell 5.1**: Use `-Encoding utf8`
- **PowerShell 7+**: UTF-8 is default, but still recommended to be explicit

```powershell
# Read file with explicit encoding
$content = Get-Content -Path $filePath -Raw -Encoding utf8

# Write file with explicit encoding
Set-Content -Path $filePath -Value $data -Encoding utf8
Add-Content -Path $filePath -Value $newData -Encoding utf8

# For JSON files (always use UTF-8)
$json | ConvertTo-Json -Depth 10 | Set-Content -Path $jsonFile -Encoding utf8
```

### 6. Execution Policy

Scripts may fail on user machines due to Windows default script execution restrictions. Include guidance for users when scripts need to run as files:

```powershell
# If your script will be saved to a file and executed, include this note:
#
# NOTE: Before running, user may need to allow script execution:
#   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
#
# Or run with:
#   powershell -ExecutionPolicy Bypass -File script.ps1
```

## Script Structure Standards

The following standards apply to every script or command block generated:

### 1. Environment Check

Every script must check PowerShell version at the start:

```powershell
if ($PSVersionTable.PSVersion.Major -lt 5) {
    throw "This script requires PowerShell 5.0 or higher. Current version: $($PSVersionTable.PSVersion)"
}
```

### 2. Error Handling

Critical logic must be wrapped in `try/catch` blocks:

```powershell
try {
    $result = Get-Content -Path $filePath -ErrorAction Stop
    Write-Verbose "Successfully read file: $filePath"
} catch {
    Write-Error "Failed to read file: $($_.Exception.Message)"
    throw
}
```

### 3. Risk Control

For any "delete", "stop", or "modify" operations, must provide `-WhatIf` support by default:

```powershell
param(
    [switch]$WhatIf
)

if ($WhatIf) {
    Write-Warning "Simulating: Will delete the following files:"
    Get-ChildItem -Path $targetPath | ForEach-Object { Write-Warning "  - $($_.FullName)" }
} else {
    Remove-Item -Path $targetPath -Recurse -Force
}
```

### 4. Structured Output

Unless displaying simple status, internal data exchange must use JSON:

```powershell
$output = [PSCustomObject]@{
    ComputerName = $env:COMPUTERNAME
    Timestamp = Get-Date -Format "o"
    Processes = (Get-Process | Select-Object -First 5 | ForEach-Object {
        [PSCustomObject]@{
            Name = $_.Name
            Id = $_.Id
            MemoryMB = [math]::Round($_.WorkingSet64 / 1MB, 2)
        }
    })
}

$output | ConvertTo-Json -Compress
```

## Anti-Patterns Comparison Table

| Never Use (Bash) | Must Use (PowerShell) |
|-----------------|----------------------|
| `ls \| grep "test"` | `Get-ChildItem \| Where-Object { $_.Name -match "test" }` |
| `cat config.txt` | `Get-Content -Path "config.txt"` |
| `ps aux \| awk '{print $2}'` | `Get-Process \| Select-Object -ExpandProperty Id` |
| `curl -X POST -d 'data'` | `Invoke-RestMethod -Method Post -Body 'data' -Uri $url` |
| `for f in *.txt; do echo $f; done` | `Get-ChildItem -Filter "*.txt" \| ForEach-Object { Write-Output $_.Name }` |
| `if [ -f file ]; then ... fi` | `if (Test-Path -Path "file") { ... }` |
| `find . -name "*.log" -delete` | `Get-ChildItem -Recurse -Filter "*.log" \| Remove-Item -WhatIf` |
| `chmod 755 script.sh` | `Set-ItemProperty -Path "script.ps1" -Name Mode -Value "rwxr-xr-x"` |
| `tail -f log.txt` | `Get-Content -Path "log.txt" -Wait -Tail 10` |
| `tar -czf archive.tar.gz dir/` | `Compress-Archive -Path "dir/*" -DestinationPath "archive.zip"` |

## Self-Correction Checklist

Before outputting any PowerShell code, must confirm:

- [ ] **Did I use any aliases?** Check for `ls`, `cp`, `mv`, `rm`, `cat`, `ps`, `grep`, `curl`, `wget`, `echo`, etc.
- [ ] **Did I use Join-Path for paths?** Never use string concatenation `+ "\" +`
- [ ] **Did I use string matching instead of object handling?** Check for `-match` or `-replace` used for tasks that could be done with object properties
- [ ] **Is error handling complete?** Are critical operations wrapped in try/catch?
- [ ] **Do dangerous operations have -WhatIf?** Do delete/stop/modify operations have safe testing mechanisms?
- [ ] **Are variables typed?** Are type declarations like `[string]`, `[int]`, `[PSCustomObject]` used in complex logic?

## Common Patterns Reference

### Reading Configuration Files

```powershell
function Get-ApplicationConfig {
    param(
        [Parameter(Mandatory)]
        [string]$ConfigPath
    )

    if (-not (Test-Path -Path $ConfigPath)) {
        throw "Configuration file does not exist: $ConfigPath"
    }

    try {
        $config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
        return $config
    } catch {
        throw "Failed to parse configuration file: $($_.Exception.Message)"
    }
}
```

### Safe File Deletion

```powershell
function Remove-LogFiles {
    param(
        [Parameter(Mandatory)]
        [string]$LogDirectory,

        [Parameter(Mandatory)]
        [int]$DaysToKeep,

        [switch]$WhatIf
    )

    $cutoffDate = (Get-Date).AddDays(-$DaysToKeep)
    $oldLogs = Get-ChildItem -Path $LogDirectory -Filter "*.log" |
               Where-Object { $_.LastWriteTime -lt $cutoffDate }

    if ($oldLogs.Count -eq 0) {
        Write-Verbose "No log files to clean up"
        return
    }

    if ($WhatIf) {
        Write-Warning "Simulating deletion of $($oldLogs.Count) log files:"
        $oldLogs | ForEach-Object { Write-Warning "  - $($_.FullName)" }
    } else {
        $oldLogs | Remove-Item -Force
        Write-Verbose "Deleted $($oldLogs.Count) log files"
    }
}
```

### Batch Processing Objects

```powershell
function Get-SystemInfo {
    $computers = @("Server01", "Server02", "Server03")

    $results = $computers | ForEach-Object -Parallel {
        $computer = $_
        try {
            $os = Get-CimInstance -ClassName Win32_OperatingSystem -ComputerName $computer -ErrorAction Stop
            [PSCustomObject]@{
                ComputerName = $computer
                OSVersion = $os.Caption
                LastBoot = $os.LastBootUpTime
                Status = "OK"
            }
        } catch {
            [PSCustomObject]@{
                ComputerName = $computer
                OSVersion = $null
                LastBoot = $null
                Status = "Error: $($_.Exception.Message)"
            }
        }
    } -ThrottleLimit 5

    return $results
}
```

## Feedback Loop

**Important:** If an error occurs during execution, the Agent must analyze the ErrorRecord object (`$error[0]`) instead of guessing the cause.

PowerShell provides structured error information (like permission denied, path not found, etc.). The Agent should:

1. Access `$error[0]` to get the full error record
2. Inspect `$_.Exception.Message` for the error details
3. Check `$_.Exception.GetType().FullName` to understand error category
4. Use this structured information to diagnose and fix the issue

```powershell
# Example: Proper error analysis
try {
    Get-Content -Path $filePath -ErrorAction Stop
} catch {
    # Never just guess - analyze the actual error
    $errorType = $_.Exception.GetType().FullName
    $errorMessage = $_.Exception.Message

    if ($errorType -eq "System.UnauthorizedAccessException") {
        Write-Error "Permission denied. Try running as Administrator."
    } elseif ($errorType -eq "System.IO.FileNotFoundException") {
        Write-Error "File not found. Verify the path is correct."
    } else {
        Write-Error "Error ($errorType): $errorMessage"
    }
}
```
