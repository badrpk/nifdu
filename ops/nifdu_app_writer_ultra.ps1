param(
    [string]$Project  = "todo_app_urdu",
    [string]$Prompt   = "Small Urdu todo app in C++ + HTML with full CRUD functionality",
    [string]$BaseUrl  = "http://127.0.0.1",
    [string]$BuildDir = "C:\nifdu\build"
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "=== NIFDU APP WRITER ULTRA SIMPLE ===" -ForegroundColor Yellow
Write-Host ("Project: " + $Project)
Write-Host ("Prompt : " + $Prompt)
Write-Host ""

# --------------------------------------------------------
# Paths / endpoints
# --------------------------------------------------------
$CodegenUrl = $BaseUrl + "/api/codegen"
$DiagDir    = "C:\nifdu\_diag"

if (-not (Test-Path $DiagDir)) {
    New-Item -ItemType Directory -Path $DiagDir -Force | Out-Null
}

$BuildLog = Join-Path $DiagDir ("build_{0}.log" -f $Project)

# --------------------------------------------------------
# 1) Call /api/codegen
# --------------------------------------------------------
$body = @{
    project = $Project
    prompt  = $Prompt
    brain   = "auto"
    mode    = "vibe_coding"
}

$bodyJson = $body | ConvertTo-Json -Depth 10

Write-Host ("STEP 1 - POST " + $CodegenUrl) -ForegroundColor Yellow
Write-Host $bodyJson

try {
    $resp = Invoke-RestMethod -Uri $CodegenUrl -Method Post -ContentType "application/json; charset=utf-8" -Body $bodyJson
} catch {
    Write-Host ("ERROR calling /api/codegen: " + $_.Exception.Message) -ForegroundColor Red
    exit 1
}

if (-not $resp.status -or $resp.status -ne "ok") {
    Write-Host "ERROR: /api/codegen returned non-ok status" -ForegroundColor Red
    $resp | ConvertTo-Json -Depth 10 | Write-Host
    exit 1
}

# --------------------------------------------------------
# 2) Write files[] to disk
# --------------------------------------------------------
$files = $resp.files

if (-not $files -or $files.Count -eq 0) {
    Write-Host "No files in response (files[] empty)." -ForegroundColor DarkYellow
} else {
    Write-Host ""
    Write-Host ("Writing " + $files.Count + " file(s)...") -ForegroundColor Cyan

    foreach ($f in $files) {
        $path     = $f.path
        $content  = $f.content
        $action   = $f.action
        $language = $f.language
        $status   = $f.status

        if (-not $path) {
            Write-Host "  SKIP: file without path" -ForegroundColor DarkYellow
            continue
        }

        if (-not $action) { $action = "write" }

        $dir = Split-Path -Path $path -Parent
        if ($dir -and -not (Test-Path $dir)) {
            Write-Host ("  MKDIR: " + $dir) -ForegroundColor DarkGray
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }

        if ($action -eq "write" -or $action -eq "propose") {
            Write-Host ("  WRITE: " + $path + " (" + $language + ", " + $status + ")") -ForegroundColor Green
            Set-Content -LiteralPath $path -Value $content -Encoding UTF8
        } else {
            Write-Host ("  SKIP: " + $path + " (unsupported action " + $action + ")") -ForegroundColor DarkYellow
        }
    }
}

# --------------------------------------------------------
# 3) Build step
# --------------------------------------------------------
Write-Host ""
Write-Host ("STEP 2 - Build in " + $BuildDir) -ForegroundColor Yellow

if (Test-Path $BuildLog) {
    Remove-Item $BuildLog -Force
}

Set-Location $BuildDir

$cmd = "cmake --build . --config Release"
Write-Host ("  CMD: " + $cmd) -ForegroundColor DarkGray

cmd.exe /c $cmd 2>&1 | Tee-Object -FilePath $BuildLog -Append

if ($LASTEXITCODE -ne 0) {
    Write-Host ("BUILD FAILED, exit code " + $LASTEXITCODE) -ForegroundColor Red
    Write-Host ("Log: " + $BuildLog) -ForegroundColor Red
    exit 1
} else {
    Write-Host "BUILD SUCCESS." -ForegroundColor Green
    Write-Host ("Open: " + $BaseUrl + "/apps/" + $Project + "/") -ForegroundColor Green
    exit 0
}
