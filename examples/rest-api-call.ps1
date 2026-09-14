# Example: REST API Call
# Demonstrates version-safe error handling and JSON output.
# Verified on: Windows PowerShell 5.1.19041 and PowerShell 7.6.6
#
# 200 -> Success=true,  StatusCode=200
# 404 -> Success=false, StatusCode=404, error body captured
# DNS/TLS failure -> Success=false, StatusCode=0, exception type reported

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

$invokeParams = @{
    Uri = $ApiEndpoint
    Method = $RequestMethod
    Headers = $headers
    ErrorAction = "Stop"
}

if ($RequestBody) {
    $invokeParams.Body = $RequestBody
}

# Deliberately NOT using -SkipHttpErrorCheck / -StatusCodeVariable here.
# Those are PS7-only, and -SkipHttpErrorCheck turns a non-2xx into a NON-exception,
# which loses ErrorDetails and the response body. Letting both versions throw keeps
# one code path and preserves the server's error payload.
try {
    $response = Invoke-RestMethod @invokeParams

    [PSCustomObject]@{
        Success = $true
        StatusCode = 200
        Data = $response
        Timestamp = Get-Date -Format "o"
    } | ConvertTo-Json -Compress -Depth 10

} catch {
    # 5.1 and 7 raise DIFFERENT exception types, and PS7 has two of them.
    # Enumerate full type names - do NOT use a regex like 'Web\w*', which fails
    # to match HttpResponseException and silently skips the branch.
    #
    # Use if/elseif with -eq: full type names only. A bare 'WebException' never
    # matches 'System.Net.WebException' - the namespace is part of the value.
    $errorType = $_.Exception.GetType().FullName
    $statusCode = 0
    $errorBody = $null

    if ($errorType -eq 'System.Net.WebException') {
        # Windows PowerShell 5.1 - every HTTP failure and every transport failure
        $httpResponse = $_.Exception.Response
        if ($null -ne $httpResponse) { $statusCode = [int]$httpResponse.StatusCode }
    }
    elseif ($errorType -eq 'Microsoft.PowerShell.Commands.HttpResponseException') {
        # PowerShell 7 - the server responded, but not 2xx
        $httpResponse = $_.Exception.Response
        if ($null -ne $httpResponse) { $statusCode = [int]$httpResponse.StatusCode }
    }
    elseif ($errorType -eq 'System.Net.Http.HttpRequestException') {
        # PowerShell 7 - transport failure (DNS / TLS / timeout).
        # StatusCode stays 0: that is the signal we never reached a server.
        $statusCode = 0
    }

    # ErrorDetails carries the decoded response body on both versions.
    if ($null -ne $_.ErrorDetails -and $_.ErrorDetails.Message) {
        $errorBody = $_.ErrorDetails.Message
    }

    [PSCustomObject]@{
        Success = $false
        StatusCode = $statusCode
        Data = $errorBody
        Error = @{
            Type = $errorType
            Message = $_.Exception.Message
        }
        Timestamp = Get-Date -Format "o"
    } | ConvertTo-Json -Compress -Depth 10
}
