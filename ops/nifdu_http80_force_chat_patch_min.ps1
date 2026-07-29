# ==============================================
# C:\nifdu\ops\nifdu_http80_force_chat_patch_min.ps1
# Force /api/chat to hit handle_api_chat() before 404
# on the nifdu::http80 router (now on port 8000).
# ==============================================

$ErrorActionPreference = "Stop"

$httpFile = "C:\nifdu\src\http\nifdu_http_server80.cpp"
$buildDir = "C:\nifdu\build"
$exePath  = "C:\nifdu\build\Release\nifdu.exe"

Write-Host ""
Write-Host "=== NIFDU http80 FORCE /api/chat PATCH (MINIMAL) ==="
Write-Host ""

if (-not (Test-Path $httpFile)) {
    Write-Host "ERROR: HTTP server source not found at: $httpFile"
    exit 1
}

# 1) Backup current file
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backup    = "$httpFile.bak_force_chat_$timestamp"
Write-Host "Backing up $httpFile -> $backup"
Copy-Item $httpFile $backup -Force

# 2) Read and patch
$content = Get-Content $httpFile -Raw

if ($content -match "FORCED_AGENT3_CHAT_PATCH") {
    Write-Host "Patch marker already present; skipping injection."
} else {
    $needle = '    // Fallback 404'

    if ($content.Contains($needle)) {
        Write-Host "Injecting forced /api/chat block before fallback 404..."

        $insert =
            "    // FORCED_AGENT3_CHAT_PATCH: ensure /api/chat always hits Agent 3`r`n" +
            "    if (target == `"/api/chat`") {`r`n" +
            "        return handle_api_chat(std::move(req));`r`n" +
            "    }`r`n" +
            "`r`n" +
            "    // Fallback 404"

        $newContent = $content.Replace($needle, $insert)

        Set-Content -Path $httpFile -Value $newContent -Encoding UTF8
        Write-Host "Injection complete."
    } else {
        Write-Host "ERROR: Could not find '// Fallback 404' marker in router; aborting."
        exit 1
    }
}

# 3) Stop nifdu.exe
Write-Host ""
Write-Host "Stopping any running nifdu.exe..."
Get-Process -Name "nifdu" -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Host " - Stopping PID $($_.Id)"
    Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
}

# 4) Build (Release)
if (-not (Test-Path $buildDir)) {
    Write-Host "ERROR: Build directory not found: $buildDir"
    exit 1
}

Write-Host ""
Write-Host "Building NIFDU (Release)..."
Push-Location $buildDir
cmake --build . --config Release
Pop-Location

# 5) Restart nifdu.exe
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
