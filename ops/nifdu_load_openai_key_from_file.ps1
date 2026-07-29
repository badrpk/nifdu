# ==============================================
# NIFDU – FORCE OPENAI KEY FROM C:\ENV\openai.key
# ==============================================

$ErrorActionPreference = "Stop"

$keyFile = "C:\ENV\openai.key"

Write-Host ""
Write-Host "=== NIFDU OPENAI KEY LOADER (FILE-BASED) ==="
Write-Host ""

if (-not (Test-Path $keyFile)) {
    Write-Host "ERROR: OpenAI key file not found at $keyFile" -ForegroundColor Red
    exit 1
}

$key = (Get-Content $keyFile -Raw).Trim()

if (-not $key.StartsWith("sk-")) {
    Write-Host "ERROR: Invalid OpenAI key format in $keyFile" -ForegroundColor Red
    exit 1
}

# Set at MACHINE scope so nifdu.exe always sees it
[Environment]::SetEnvironmentVariable("OPENAI_API_KEY", $key, "Machine")

Write-Host "✅ OPENAI_API_KEY loaded from $keyFile (Machine scope)"
Write-Host "✅ NIFDU will now ALWAYS pick key from file"
Write-Host ""

# Restart NIFDU
Write-Host "Restarting NIFDU..."
Stop-Process -Name nifdu -Force -ErrorAction SilentlyContinue
Start-Process C:\nifdu\build\Release\nifdu.exe

Write-Host ""
Write-Host "=== DONE: OPENAI KEY LOCKED TO FILE ==="
Write-Host ""
