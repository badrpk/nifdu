param()

$ErrorActionPreference = "Stop"

function Say {
    param(
        [string]$Text,
        [string]$Color = "Gray"
    )
    try {
        $valid = [enum]::GetNames([System.ConsoleColor])
        if ($valid -notcontains $Color) { $Color = "Gray" }
        Write-Host $Text -ForegroundColor $Color
    } catch {
        Write-Host $Text
    }
}

Say "`n--- HTTP 80 (NIFDU) - ALLOW 308 ---`n" "Yellow"

try {
    $resHttp = Invoke-WebRequest -Uri 'http://sophyane.com/' -UseBasicParsing -MaximumRedirection 0

    # If it is a redirect (3xx), still log it as OK
    [PSCustomObject]@{
        Kind     = "HTTP"
        Code     = [int]$resHttp.StatusCode
        Location = $resHttp.Headers["Location"]
        Snippet  = ""
    } | Format-List
} catch {
    $ex   = $_.Exception
    $resp = $ex.Response
    if ($resp -and ($resp.StatusCode.value__ -ge 300 -and $resp.StatusCode.value__ -lt 400)) {
        # Treat 3xx from WebException as success
        $code = [int]$resp.StatusCode
        $loc  = $resp.Headers["Location"]
        [PSCustomObject]@{
            Kind     = "HTTP (WebException)"
            Code     = $code
            Location = $loc
            Snippet  = ""
        } | Format-List
    } else {
        Say ("HTTP check failed: {0}" -f $_) "Red"
    }
}
