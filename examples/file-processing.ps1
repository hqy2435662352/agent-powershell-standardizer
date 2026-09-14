# Example: File Processing Script
# Demonstrates path safety, built-in -WhatIf support, and JSON output.
# Verified on: Windows PowerShell 5.1.19041 and PowerShell 7.6.6

# -WhatIf comes from SupportsShouldProcess - do not declare your own [switch]$WhatIf.
# Run with -WhatIf to preview, -Confirm to prompt per item, neither to execute.
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$SourceDirectory,

    [Parameter(Mandatory)]
    [string]$DestinationDirectory
)

if ($PSVersionTable.PSVersion.Major -lt 5) {
    throw "This script requires PowerShell 5.0 or higher. Current version: $($PSVersionTable.PSVersion)"
}

if (-not (Test-Path -Path $SourceDirectory)) {
    throw "Source directory does not exist: $SourceDirectory"
}

$destinationPath = Join-Path -Path $DestinationDirectory -ChildPath "processed"

if ($PSCmdlet.ShouldProcess($destinationPath, "Create directory and copy *.txt")) {
    if (-not (Test-Path -Path $destinationPath)) {
        New-Item -ItemType Directory -Path $destinationPath -Force | Out-Null
    }

    $files = Get-ChildItem -Path $SourceDirectory -Filter "*.txt"

    $results = $files | ForEach-Object {
        $srcFile = $_.FullName
        $dstFile = Join-Path -Path $destinationPath -ChildPath $_.Name

        try {
            # -WhatIf:$WhatIfPreference passes the caller's intent down to the cmdlet,
            # so -WhatIf actually reaches the operation instead of only the wrapper.
            Copy-Item -Path $srcFile -Destination $dstFile -ErrorAction Stop -WhatIf:$WhatIfPreference

            [PSCustomObject]@{
                FileName = $_.Name
                Status = "Copied"
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

    # -Depth is required: the default of 2 silently truncates nested objects.
    $results | ConvertTo-Json -Compress -Depth 10
}
