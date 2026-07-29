# ---------------------------------------------------------
# 5) HTTP/HTTPS smoke tests via sophyane.com
# ---------------------------------------------------------
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
[System.Net.ServicePointManager]::SecurityProtocol =
    [System.Net.SecurityProtocolType]::Tls12 -bor
    [System.Net.SecurityProtocolType]::Tls11 -bor
    [System.Net.SecurityProtocolType]::Tls

function Get-BodySnippet {
    param(
        [Parameter(Mandatory = $true)]
        $Content,
        [int]$MaxLen = 120
    )

    if ($null -eq $Content) { return "" }

    if ($Content -is [byte[]]) {
        $text = [System.Text.Encoding]::UTF8.GetString($Content)
    } else {
        $text = [string]$Content
    }

    if ($text.Length -gt $MaxLen) {
        return $text.Substring(0, $MaxLen)
    }
    return $text
}

Say "`n--- HTTP 80 (NIFDU) — FOLLOW REDIRECTS ---`n" "Yellow"
try {
    # Let Invoke-WebRequest follow the 308 to wherever NIFDU sends us.
    $resHttp = Invoke-WebRequest -Uri 'http://sophyane.com/' `
        -UseBasicParsing

    [PSCustomObject]@{
        Kind      = "HTTP"
        FinalUri  = $resHttp.BaseResponse.ResponseUri.AbsoluteUri
        Code      = $resHttp.StatusCode
        Snippet   = Get-BodySnippet -Content $resHttp.Content -MaxLen 120
    } | Format-List
} catch {
    Say ("HTTP check failed: {0}" -f $_) "Red"
}

Say "`n--- HTTPS 443 (Caddy → NIFDU) ---`n" "Yellow"
try {
    # Hit Caddy directly on 443 via domain; ServicePointManager callback ignores cert issues.
    $resHttps = Invoke-WebRequest -Uri 'https://sophyane.com/' `
        -UseBasicParsing

    [PSCustomObject]@{
        Kind      = "HTTPS"
        FinalUri  = $resHttps.BaseResponse.ResponseUri.AbsoluteUri
        Code      = $resHttps.StatusCode
        Snippet   = Get-BodySnippet -Content $resHttps.Content -MaxLen 120
    } | Format-List
} catch {
    Say ("HTTPS check failed: {0}" -f $_) "Red"
}

Say "`n=== DONE: Sophyane root + router fix applied ===`n" "Green"
