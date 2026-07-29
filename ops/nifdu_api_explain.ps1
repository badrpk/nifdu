param(
    [Parameter(Mandatory = $true)]
    [string]$Name  # e.g. "/api/codegen"
)

$ErrorActionPreference = "Stop"

function Say {
    param([string]$Text,[string]$Color = "Gray")
    try {
        $valid = [enum]::GetNames([System.ConsoleColor])
        if ($valid -notcontains $Color) { $Color = "Gray" }
        Write-Host $Text -ForegroundColor $Color
    } catch {
        Write-Host $Text
    }
}

$path = "C:\nifdu\config\nifdu_api_38_manifest.json"
if (-not (Test-Path $path)) {
    Say "Manifest not found: $path" "Red"
    exit 1
}

$manifest = Get-Content $path | ConvertFrom-Json

$api = $manifest.apis | Where-Object { $_.name -eq $Name }

if (-not $api) {
    Say "API not found in manifest: $Name" "Red"
    exit 1
}

Say "`n=== NIFDU API EXPLAIN ===" "Yellow"
Say ("Name   : {0}" -f $api.name) "Cyan"
Say ("Method : {0}" -f $api.method) "Gray"
Say ("Group  : {0}" -f $api.group) "Gray"
Say ("Layer  : {0}" -f $api.layer) "Gray"
Say ""
Say ("Role   : {0}" -f $api.role) "Green"
Say ""
Say ("Scope  : {0}" -f $api.scope) "DarkGray"
Say "`n==========================`n" "Yellow"
