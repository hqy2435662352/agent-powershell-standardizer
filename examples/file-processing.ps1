# Example: File Processing Script
# This demonstrates the skill's best practices

param(
    [Parameter(Mandatory)]
    [string]$SourceDirectory,

    [Parameter(Mandatory)]
    [string]$DestinationDirectory,

    [switch]$WhatIf
)

if ($PSVersionTable.PSVersion.Major -lt 5) {
    throw "This script requires PowerShell 5.0 or higher. Current version: $($PSVersionTable.PSVersion)"
}

if (-not (Test-Path -Path $SourceDirectory)) {
    throw "Source directory does not exist: $SourceDirectory"
}

$destinationPath = Join-Path -Path $DestinationDirectory -ChildPath "processed"

if ($WhatIf) {
    Write-Warning "=== SIMULATION MODE ==="
    Write-Warning "Source: $SourceDirectory"
    Write-Warning "Destination: $destinationPath"
    Write-Warning ""
    Write-Warning "Files to be copied:"

    $files = Get-ChildItem -Path $SourceDirectory -Filter "*.txt"
    $files | ForEach-Object {
        Write-Warning "  - $($_.Name) ($([math]::Round($_.Length / 1KB, 2)) KB)"
    }

    Write-Warning ""
    Write-Warning "Total: $($files.Count) files"
} else {
    if (-not (Test-Path -Path $destinationPath)) {
        New-Item -ItemType Directory -Path $destinationPath -Force | Out-Null
    }

    $files = Get-ChildItem -Path $SourceDirectory -Filter "*.txt"

    $results = $files | ForEach-Object {
        $srcFile = $_.FullName
        $dstFile = Join-Path -Path $destinationPath -ChildPath $_.Name

        try {
            Copy-Item -Path $srcFile -Destination $dstFile -ErrorAction Stop

            [PSCustomObject]@{
                FileName = $_.Name
                Status = "Success"
                SizeKB = [math]::Round($_.Length / 1KB, 2)
            }
        } catch {
            [PSCustomObject]@{
                FileName = $_.Name
                Status = "Failed: $($_.Exception.Message)"
                SizeKB = $null
            }
        }
    }

    $results | ConvertTo-Json -Compress
}
