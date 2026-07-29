param(
    [Parameter(Mandatory=$true)]
    [string]$Project
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

$AppDir = "C:\nifdu\src\apps\$Project"

Say ""
Say "=== NIFDU BOM STRIPPER ===" "Cyan"
Say "Project : $Project" "Gray"
Say "AppDir  : $AppDir"  "Gray"

if (!(Test-Path $AppDir)) {
    Say "[FATAL] App directory not found: $AppDir" "Red"
    exit 1
}

$patterns = @("package.json","*.json","*.js","*.jsx","*.ts","*.tsx")

$files = Get-ChildItem -Path $AppDir -Recurse -File -Include $patterns

if (-not $files) {
    Say "[WARN] No matching files found to scan." "DarkYellow"
    exit 0
}

$fixed = 0

foreach ($f in $files) {
    $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
    if ($bytes.Length -ge 3 -and
        $bytes[0] -eq 0xEF -and
        $bytes[1] -eq 0xBB -and
        $bytes[2] -eq 0xBF) {

        $newBytes = $bytes[3..($bytes.Length-1)]
        [System.IO.File]::WriteAllBytes($f.FullName, $newBytes)
        Say "Stripped UTF-8 BOM from $($f.FullName)" "Green"
        $fixed++
    }
}

Say ""
Say "Total files fixed: $fixed" "Cyan"
