# ==============================================
# C:\nifdu\ops\nifdu_http80_force_chat_patch.ps1
# Force /api/chat to hit handle_api_chat() before 404
# on the nifdu::http80 router (port 8000 now).
# ==============================================

$ErrorActionPreference = "Stop"

$httpFile = "C:\nifdu\src\http\nifdu_http_server80.cpp"
$buildDir = "C:\nifdu\build"
$exePath  = "C:\nifdu\build\Release\nifdu.exe"

Write-Host ""
Write-Host "=== NIFDU http80 FORCE /api/chat PATCH ==="
Write-Host ""

if (-not (Test-Path $httpFile)) {
    Write-Host "ERROR: HTTP server source not found at: $httpFile"
    exit 1
}

# 1) Backup file
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backup    = "$httpFile.bak_force_chat_$timestamp"
Write-Host "Backing up $httpFile -> $backup"
Copy-Item $httpFile $backup -Force

# 2) Read content
$content = Get-Content $httpFile -Raw

if ($content -like "*FORCED_AGENT3_CHAT_PATCH*") {
    Write-Host "Patch marker already present; skipping injection."
} else {
    # 3) Inject forced /api/chat block before the fallback 404
    $needle = "    // Fallback 404"
    if ($content -notlike "*$needle*") {
        Write-Host "ERROR: Could not find fallback 404 marker in router; aborting."
        exit 1
    }

    $insert = @"
    // FORCED_AGENT3_CHAT_PATCH: ensure /api/chat always hits Agent 3
    if (target == "/api/chat") {
        return handle_api_chat(std::move(req));
    }

$needle"@

    $newContent = $content -replace [regex]::Escape($needle), [System.Text.RegularExpressions.Regex]::Escape($insert).Replace("\\r\\n", "`r`n")

    # The above .Replace dance is a bit ugly; simpler approach:
    # do a string replace directly instead of regex:
    $newContent = $content.Replace($needle, $insert)

    Set-Content -Path $httpFile -Value $newContent -Encoding UTF8
    Write-Host "Injected forced /api/chat patch before fallback 404."
}

# 4) Stop running nifdu.exe
Write-Host ""
Write-Host "Stopping any running nifdu.exe..."
Get-Process -Name "nifdu" -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Host " - Stopping PID $($_.Id)"
    Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
}

# 5) Build (Release)
if (-not (Test-Path $buildDir)) {
    Write-Host "ERROR: Build directory not found: $buildDir"
    exit 1
}

Write-Host ""
Write-Host "Building NIFDU (Release)..."
Push-Location $buildDir
cmake --build . --config Release
Pop-Location

# 6) Restart nifdu.exe
if (-not (Test-Path $exePath)) {
    Write-Host "ERROR: nifdu.exe not found at: $exePath"
    exit 1
}

Write-Host ""
Write-Host "Starting nifdu.exe from $exePath..."
Start-Process $exePath
Start-Sleep -Seconds 3

Write-Host ""
Write-Host "=== PATCH DONE: /api/chat should now be handled by Agent 3 on :8000. ==="
Write-Host ""
