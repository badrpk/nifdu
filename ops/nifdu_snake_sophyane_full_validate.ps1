param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Say {
    param([string]$m, [string]$c = "Gray")
    try {
        $old = [Console]::ForegroundColor
        [Console]::ForegroundColor = $c
        Write-Host $m
        [Console]::ForegroundColor = $old
    } catch {
        Write-Host $m
    }
}

$BaseApi    = "http://127.0.0.1"
$DomainHost = "www.sophyane.com"
$Project    = "snake_sophyane_full"

Say "`n=== NIFDU SNAKE VALIDATE ($Project) ===`n" "Yellow"

$pass = $true

# 1) /api/list
try {
    $list = Invoke-RestMethod -Uri "$BaseApi/api/list" -Method Get -TimeoutSec 5

    if ($list.PSObject.Properties.Name -contains 'total_apis') {
        $total = [int]$list.total_apis
    } elseif ($list.apis) {
        $total = $list.apis.Count
    } else {
        $total = 0
    }

    if ($total -ge 30) {
        Say ("[OK] /api/list APIs = {0}" -f $total) "Green"
    } else {
        Say ("[FAIL] /api/list APIs = {0} (expected >= 30)" -f $total) "Red"
        $pass = $false
    }
} catch {
    Say "[FAIL] /api/list unreachable." "Red"
    $pass = $false
}

# 2) Snake portal HTTP
try {
    $url  = "$BaseApi/apps/$Project/"
    $resp = Invoke-WebRequest -Uri $url -Headers @{ Host = $DomainHost } -TimeoutSec 5

    if ($resp.StatusCode -eq 200) {
        Say ("[OK] Snake portal HTTP {0} at {1} (Host: {2})" -f $resp.StatusCode, $url, $DomainHost) "Green"
    } else {
        Say ("[FAIL] Snake portal status = {0} at {1}" -f $resp.StatusCode, $url) "Red"
        $pass = $false
    }
} catch {
    Say "[FAIL] Snake portal not reachable on internal HTTP surface." "Red"
    $pass = $false
}

if ($pass) {
    Say "`n=== VALIDATION RESULT: PASS ===`n" "Green"
    exit 0
} else {
    Say "`n=== VALIDATION RESULT: FAIL ===`n" "Red"
    exit 1
}
