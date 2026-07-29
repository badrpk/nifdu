param(
    [Parameter(Mandatory=$true)]
    [string]$Project,

    [Parameter(Mandatory=$true)]
    [string]$Prompt
)

$ErrorActionPreference = "Stop"

# --- CONFIG ---
$AgentExec = "C:\nifdu\ops\nifdu_agent3_apply_codegen.ps1"
$AppDir    = "C:\nifdu\src\apps\$Project"
$PkgPath   = Join-Path $AppDir "package.json"
$Stack     = "react"
$Brain     = "auto"
$Mode      = "vibe_coding"

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

function Wait-Nifdu {
    Say "[HTTP] Waiting for NIFDU on port 80..." "Cyan"
    for ($i=0; $i -lt 40; $i++) {
        try {
            $v = Invoke-WebRequest -Uri "http://127.0.0.01/health" -TimeoutSec 2
            if ($v.StatusCode -eq 200) {
                Say "[HTTP] NIFDU ACTIVE." "Green"
                return $true
            }
        } catch {}
        Start-Sleep -Milliseconds 500
    }
    Say "[HTTP] Timeout waiting for 127.0.0.1/health" "Red"
    exit 1
}

# -------------------------------------------------------------------------
# FEATURE SIMULATION: Simulates immediate file inspection (Self-Correction/Diagnosis)
# -------------------------------------------------------------------------
function Fix-BOMsAndDependencies {
    Say "`n[2] RUNTIME DIAGNOSIS & FIXES..." "Yellow"

    if (!(Test-Path $PkgPath)) {
        Say "[INFO] package.json not found. Assuming static web output. Skipping fixes." "DarkYellow"
        return $true
    }

    # 2a: Strip BOM (Fixes JSON parser error)
    Say "  [2a] Stripping UTF-8 BOMs from core files..." "Cyan"
    $files = Get-ChildItem -Path $AppDir -Recurse -File -Include "*.json", "*.js", "*.jsx", "*.ts", "*.tsx" | Select-Object -ExpandProperty FullName

    $fixedCount = 0
    foreach ($f in $files) {
        $bytes = [System.IO.File]::ReadAllBytes($f)
        if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
            $newBytes = $bytes[3..($bytes.Length-1)]
            [System.IO.File]::WriteAllBytes($f, $newBytes)
            $fixedCount++
        }
    }
    Say "  -> $fixedCount files had BOMs stripped." "Green"

    # 2b: Automatic Dependency Installation (Fixes missing @vitejs/plugin-react)
    Say "  [2b] Installing dependencies and automatic fixes..." "Cyan"
    Push-Location $AppDir

    # Check for missing crucial dependency and force install
    Say "  -> Installing @vitejs/plugin-react as dev dependency..." "Gray"
    npm install -D @vitejs/plugin-react | Out-Null

    # Reinstall all to ensure package.json contents are met
    Say "  -> Running npm install..." "Gray"
    npm install

    Pop-Location
    return $true
}

# -------------------------------------------------------------------------
# FEATURE SIMULATION: Simulates Runtime Feedback & Stateful Execution
# -------------------------------------------------------------------------
function Run-DevServer {
    Say "`n[3] STARTING DEV SERVER..." "Yellow"
    Push-Location $AppDir

    # We assume 'dev' script exists, as per the strict prompt requirements
    Say "  -> Running npm run dev (Ctrl+C to stop)..." "Cyan"
    
    # Use Start-Process to run the server in a new window/process to allow execution flow to complete
    # For a real "one-shot" that returns control, we must run it non-blocking.
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c npm run dev"
    
    Pop-Location
}

# -------------------------------------------------------------------------
# --- MAIN EXECUTION ---
# -------------------------------------------------------------------------

Say ""
Say "=== NIFDU VIBE COACH (Simulating Agent 3 Debugging Features) ===" "Cyan"
Say ("Project : {0}" -f $Project) "Gray"
Say ("Stack   : {0}" -f $Stack)  "Gray"
Say ""

# 1. Code Generation
Say "[1] Running Agent 3 Code Generation..." "Yellow"
Wait-Nifdu

# *** CRITICAL FIX: Use the call operator (&) and named parameters for reliable multi-line prompt passing. ***
& $AgentExec `
    -Project $Project `
    -Prompt  $Prompt `
    -Stack   $Stack `
    -Brain   $Brain `
    -Mode    $Mode
# Check for explicit failure from AgentExec (if it returns a non-zero exit code)
if ($LASTEXITCODE -ne 0) {
    Say "[FATAL] Agent Code Generation failed with exit code $LASTEXITCODE." "Red"
    exit $LASTEXITCODE
}
Say "  -> Code Generation SUCCESS." "Green"

# 2. Fix Errors & Dependencies
Fix-BOMsAndDependencies

# 3. Run Application
Run-DevServer

Say "`n=== VIBE COACH FLOW COMPLETE ===" "Yellow"
Say "The React dev server should be running in a separate window." "Gray"
Say "Verify application functionality in your browser at http://localhost:3000/" "Green"
