param(
    [string]$Url         = "http://localhost:3000/",
    [string]$ExpectText  = "",
    [int]   $MaxAttempts = 10,
    [int]   $DelayMs     = 1000
)

$ErrorActionPreference = "Stop"

function Say {
    param([string]$m,[string]$c="Gray")
    try {
        $valid = [enum]::GetNames([System.ConsoleColor])
        if ($valid -notcontains $c) { $c = "Gray" }
        $old = [Console]::ForegroundColor
        [Console]::ForegroundColor = $c
        Write-Host $m
        [Console]::ForegroundColor = $old
    } catch { Write-Host $m }
}

Say ""
Say "=== NIFDU AGENT 3 WEB PROBE ===" "Cyan"
Say ("URL         : {0}" -f $Url) "Gray"
if ($ExpectText) {
    Say ("ExpectText  : {0}" -f $ExpectText) "Gray"
}
Say ("MaxAttempts : {0}" -f $MaxAttempts) "Gray"

for ($i=1; $i -le $MaxAttempts; $i++) {
    Say ("[TRY {0}] Probing {1}" -f $i, $Url) "Cyan"
    try {
        $resp = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 5
        if ($resp.StatusCode -ge 200 -and $resp.StatusCode -lt 300) {
            if ($ExpectText) {
                if ($resp.Content -like "*$ExpectText*") {
                    Say "[OK] HTTP 2xx and expected text found in response body." "Green"
                    exit 0
                } else {
                    Say "[WARN] HTTP 2xx but expected text not found yet." "DarkYellow"
                }
            } else {
                Say "[OK] HTTP 2xx." "Green"
                exit 0
            }
        } else {
            Say ("[WARN] Non-2xx status: {0}" -f $resp.StatusCode) "DarkYellow"
        }
    } catch {
        Say ("[ERR] Probe failed: {0}" -f $_.Exception.Message) "Red"
    }

    if ($i -lt $MaxAttempts) {
        Start-Sleep -Milliseconds $DelayMs
    }
}

Say "[FAIL] Web probe did not meet success criteria." "Red"
exit 1
