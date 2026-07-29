$ErrorActionPreference = "Stop"

function Say {
    param(
        [string]$m,
        [string]$c
    )
    if (-not $c) { $c = "Gray" }
    try {
        $old = [Console]::ForegroundColor
        [Console]::ForegroundColor = $c
        Write-Host $m
        [Console]::ForegroundColor = $old
    } catch {
        Write-Host $m
    }
}

$Base = "http://127.0.0.1"

Say -m "" -c "Gray"
Say -m "=== NIFDU HTTP SURFACE REALITY CHECK (/api/list + /api/ai/models) ===" -c "Yellow"

# /api/list
try {
    $resp  = Invoke-WebRequest -Uri "$Base/api/list" -TimeoutSec 5 -ErrorAction Stop
    $json  = $resp.Content | ConvertFrom-Json
    $count = if ($json.total_apis) { $json.total_apis } elseif ($json.apis) { $json.apis.Count } else { 0 }

    Say -m ("[OK] /api/list reachable. total_apis = {0}" -f $count) -c "Green"
} catch {
    Say -m ("[FATAL] /api/list failed: {0}" -f $_.Exception.Message) -c "Red"
}

# /api/ai/models
try {
    $resp2 = Invoke-WebRequest -Uri "$Base/api/ai/models" -TimeoutSec 5 -ErrorAction Stop
    $json2 = $resp2.Content | ConvertFrom-Json
    $mc    = if ($json2.models) { $json2.models.Count } else { 0 }

    Say -m ("[OK] /api/ai/models reachable. models = {0}, status = {1}" -f $mc, $json2.status) -c "Green"
} catch {
    Say -m ("[FATAL] /api/ai/models failed: {0}" -f $_.Exception.Message) -c "Red"
}

Say -m "" -c "Gray"
Say -m "=== NIFDU HTTP SURFACE REALITY CHECK COMPLETE ===" -c "Yellow"
