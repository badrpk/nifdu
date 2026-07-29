$ErrorActionPreference = "Stop"

function Say {
    param([string]$m, [string]$c = "Gray")
    try {
        $valid = [enum]::GetNames([System.ConsoleColor])
        if ($valid -notcontains $c) { $c = "Gray" }
        $old = [Console]::ForegroundColor
        [Console]::ForegroundColor = $c
        Write-Host $m
        [Console]::ForegroundColor = $old
    } catch {
        Write-Host $m
    }
}

Say "`n=== NIFDU AGENT 3 SMOKE TEST (C++ HELLO) ===`n" "Yellow"

$baseUrl = "http://127.0.0.1"

# 1) Prepare request for /api/chat
$body = @{
    project = "smoke_test_agent3"
    prompt  = "Just say hello from NIFDU Agent 3."
    brain   = "auto"
    mode    = "vibe_coding"
}
$json = $body | ConvertTo-Json -Depth 10

Say "[1] Calling /api/chat on $baseUrl ..." "Cyan"
$resp = Invoke-RestMethod `
    -Uri "$baseUrl/api/chat" `
    -Method Post `
    -ContentType "application/json; charset=utf-8" `
    -Body $json

if ($resp.status -ne "ok") {
    Say "[FATAL] /api/chat returned status='$($resp.status)'" "Red"
    $resp | ConvertTo-Json -Depth 10
    exit 1
}

Say "[OK] /api/chat status = $($resp.status), model = $($resp.model)" "Green"

# 2) Write all files from Agent 3
if (-not $resp.files -or $resp.files.Count -eq 0) {
    Say "[FATAL] No files[] returned by Agent 3." "Red"
    exit 1
}

foreach ($f in $resp.files) {
    $path    = $f.path
    $content = $f.content

    if (-not $path) {
        Say "[WARN] Skipping file with empty path." "DarkYellow"
        continue
    }

    $dir = Split-Path $path -Parent
    if ($dir -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    Say "  -> Writing $path" "Gray"
    Set-Content -Path $path -Value $content -NoNewline -Encoding UTF8
}

Say "[2] All Agent 3 files written." "Green"

# 3) Locate vcvars64.bat (to set INCLUDE/LIB/etc)
Say "[3] Locating vcvars64.bat ..." "Cyan"

$vcvars = $null

$vcRoots = @(
    "C:\BuildTools",
    "C:\Program Files\Microsoft Visual Studio",
    "C:\Program Files (x86)\Microsoft Visual Studio"
) | Where-Object { Test-Path $_ }

foreach ($root in $vcRoots) {
    $candidate = Get-ChildItem -Path $root -Recurse -Filter vcvars64.bat -ErrorAction SilentlyContinue |
                 Select-Object -First 1
    if ($candidate) {
        $vcvars = $candidate.FullName
        break
    }
}

if (-not $vcvars) {
    Say "[FATAL] Could not find vcvars64.bat under Visual Studio / BuildTools roots." "Red"
    Say "  - Make sure C++ Build Tools are installed." "Red"
    Say "  - Or run this script from a pre-initialized 'x64 Native Tools' / 'Developer' prompt." "Red"
    exit 1
}

Say "[OK] Using vcvars64.bat at: $vcvars" "Green"

# 4) Find the C++ file
$cppFiles = Get-ChildItem "C:\smoke_test_agent3" -Filter *.cpp -Recurse -ErrorAction SilentlyContinue
if ($cppFiles.Count -eq 0) {
    Say "[FATAL] No .cpp files found under C:\smoke_test_agent3" "Red"
    exit 1
}

$cpp = $cppFiles[0].FullName
$exe = [System.IO.Path]::ChangeExtension($cpp, ".exe")

Say "[4] Compiling $($cppFiles[0].Name) with cl (via vcvars64)..." "Cyan"
$cppDir  = Split-Path $cpp -Parent
$cppName = Split-Path $cpp -Leaf

Push-Location $cppDir
try {
    # Build a CMD command: call vcvars64.bat && cl ...
    $cmdLine = "`"$vcvars`" && cl /std:c++20 /EHsc `"$cppName`" /Fe:`"$exe`""
    & cmd.exe /c $cmdLine
    if ($LASTEXITCODE -ne 0) {
        Say "[FATAL] cl.exe compilation failed with exit code $LASTEXITCODE." "Red"
        Pop-Location
        exit 1
    }
} catch {
    Say "[FATAL] cl.exe compilation threw an exception." "Red"
    Pop-Location
    throw
}
Pop-Location

if (-not (Test-Path $exe)) {
    Say "[FATAL] Expected EXE not found: $exe" "Red"
    exit 1
}

Say "[OK] Built $exe" "Green"

# 5) Run the program
Say "`n[5] Running hello program..." "Cyan"
& $exe

Say "`n=== AGENT 3 SMOKE TEST COMPLETE ===`n" "Yellow"
