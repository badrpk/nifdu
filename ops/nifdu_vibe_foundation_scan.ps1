$ErrorActionPreference = "Stop"

function Say {
    param(
        [string]$m,
        [string]$c
    )

    if (-not $c) {
        $c = "Gray"
    }

    try {
        $old = [Console]::ForegroundColor
        if ($c) {
            [Console]::ForegroundColor = $c
        }
        Write-Host $m
        [Console]::ForegroundColor = $old
    } catch {
        Write-Host $m
    }
}

Say -m "" -c "Gray"
Say -m "=== NIFDU VIBE FOUNDATION SCAN (MINIMAL) ===" -c "Yellow"

# 1) Root + SRC

$RootDir = "C:\nifdu"
if (-not (Test-Path $RootDir)) {
    Say -m "[FATAL] NIFDU root not found at $RootDir" -c "Red"
    exit 1
}

$SrcDir = Join-Path $RootDir "src"

Say -m ("[OK] NIFDU root : {0}" -f $RootDir) -c "Cyan"
Say -m ("[OK] SRC dir    : {0}" -f $SrcDir)  -c "Cyan"

# 2) Canonical 38 APIs

$CanonicalApis = @(
    "/health",
    "/api/health",
    "/api/ping",
    "/api/db_health",
    "/api/list",
    "/api/log",
    "/api/chat",
    "/api/ai/complete",
    "/api/ai/embed",
    "/api/ai/models",
    "/api/ai/config",
    "/api/ai/recall",
    "/api/codegen",
    "/api/vibe",
    "/api/behavior_test",
    "/api/truth",
    "/api/compile",
    "/api/run",
    "/api/av",
    "/api/av/plan",
    "/api/av/sprite",
    "/api/av/render",
    "/api/av/control",
    "/api/rag",
    "/api/rl",
    "/api/train",
    "/api/retail",
    "/api/retail/blueprints",
    "/api/lead",
    "/api/project",
    "/api/projects/accept",
    "/api/auth/generate_key",
    "/api/proxy/config",
    "/api/proxy/routes",
    "/api/proxy/services",
    "/api/proxy/reload",
    "/api/deploy",
    "/api/ws/prices"
)

Say -m ("[INFO] Canonical APIs : {0}" -f $CanonicalApis.Count) -c "Gray"

# 3) Scan C++ sources for the APIs

$ImplementedMap = @{}
$HttpFiles      = @()

if (Test-Path $SrcDir) {
    $HttpFiles = Get-ChildItem -Path $SrcDir -Recurse -Include *.cpp,*.hpp,*.h -ErrorAction SilentlyContinue
}

if (-not $HttpFiles -or $HttpFiles.Count -eq 0) {
    Say -m ("[WARN] No C++ files found under {0}" -f $SrcDir) -c "DarkYellow"
} else {
    Say -m ("[OK] Scanning C++ files: {0}" -f $HttpFiles.Count) -c "Gray"
}

foreach ($file in $HttpFiles) {
    try {
        $text = Get-Content -Path $file.FullName -Raw -ErrorAction Stop
    } catch {
        continue
    }

    foreach ($api in $CanonicalApis) {
        if ($text -like "*$api*") {
            $ImplementedMap[$api] = $true
        }
    }
}

$ImplementedApis = $ImplementedMap.Keys | Sort-Object
$MissingApis     = $CanonicalApis | Where-Object { -not $ImplementedMap.ContainsKey($_) }

$implCount = $ImplementedApis.Count
$totalApis = $CanonicalApis.Count

if ($totalApis -gt 0) {
    $coverage = [Math]::Round(($implCount * 100.0) / $totalApis, 1)
} else {
    $coverage = 0
}

Say -m "" -c "Gray"
Say -m "--- API IMPLEMENTATION STATUS (C++ SOURCES) ---" -c "Yellow"
Say -m ("Implemented APIs : {0} / {1} (coverage {2})" -f $implCount, $totalApis, $coverage) -c "Green"

if ($ImplementedApis -and $ImplementedApis.Count -gt 0) {
    Say -m ("  OK : {0}" -f ($ImplementedApis -join ", ")) -c "Gray"
}

if ($MissingApis -and $MissingApis.Count -gt 0) {
    Say -m ("Missing APIs : {0}" -f $MissingApis.Count) -c "DarkYellow"
    Say -m ("  MISSING : {0}" -f ($MissingApis -join ", ")) -c "DarkYellow"
} else {
    Say -m "No APIs missing. All 38 detected in C++." -c "Green"
}

Say -m "" -c "Gray"
Say -m "=== NIFDU VIBE FOUNDATION SCAN (MINIMAL) COMPLETE ===" -c "Yellow"
