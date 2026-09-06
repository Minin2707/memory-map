param(
    [switch] $Clear
)

$ErrorActionPreference = "Stop"

<#
Sets MM_API_ACCESS_TOKEN only for this PowerShell process and child processes
started from it. Closing PowerShell removes the value naturally. Use -Clear to
remove it explicitly. The token is never written to disk or printed.
#>

if ($Clear) {
    Remove-Item Env:MM_API_ACCESS_TOKEN -ErrorAction SilentlyContinue
    Write-Host "MM_API_ACCESS_TOKEN was cleared for this PowerShell process."
    return
}

$secureToken = Read-Host -Prompt "Paste Memory Story access token" -AsSecureString
$bstr = [IntPtr]::Zero
$plainToken = $null

try {
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
    $plainToken = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    $normalizedToken = if ($null -eq $plainToken) { "" } else { $plainToken.Trim() }

    if ([string]::IsNullOrWhiteSpace($normalizedToken)) {
        throw "MM_API_ACCESS_TOKEN is empty"
    }

    $env:MM_API_ACCESS_TOKEN = $normalizedToken
    Write-Host "MM_API_ACCESS_TOKEN was set for this PowerShell process."
} finally {
    if ($bstr -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }

    $plainToken = $null
    $normalizedToken = $null
    $secureToken = $null
}
