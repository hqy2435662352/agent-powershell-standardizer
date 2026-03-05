# Example: REST API Call
# Demonstrates proper error handling and JSON handling

param(
    [Parameter(Mandatory)]
    [string]$ApiEndpoint,

    [string]$RequestMethod = "GET",

    [string]$RequestBody = $null
)

if ($PSVersionTable.PSVersion.Major -lt 5) {
    throw "This script requires PowerShell 5.0 or higher."
}

$headers = @{
    "Content-Type" = "application/json"
    "Accept" = "application/json"
}

try {
    $invokeParams = @{
        Uri = $ApiEndpoint
        Method = $RequestMethod
        Headers = $headers
        ErrorAction = "Stop"
    }

    if ($RequestBody) {
        $invokeParams.Body = $RequestBody
    }

    $response = Invoke-RestMethod @invokeParams

    [PSCustomObject]@{
        Success = $true
        StatusCode = 200
        Data = $response
        Timestamp = Get-Date -Format "o"
    } | ConvertTo-Json -Compress

} catch {
    $errorType = $_.Exception.GetType().FullName
    $errorMessage = $_.Exception.Message

    $result = [PSCustomObject]@{
        Success = $false
        StatusCode = 0
        Error = @{
            Type = $errorType
            Message = $errorMessage
        }
        Timestamp = Get-Date -Format "o"
    }

    if ($errorType -eq "System.Net.WebException") {
        $httpResponse = $_.Exception.Response
        if ($httpResponse) {
            $result.StatusCode = [int]$httpResponse.StatusCode
        }
    }

    $result | ConvertTo-Json -Compress
}
