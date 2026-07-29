param()

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

$script:NifduApiManifestPath = "C:\nifdu\config\nifdu_api_38_manifest.json"
$script:NifduApiManifest     = $null

if (Test-Path $script:NifduApiManifestPath) {
    Say ("[NIFDU] Loading API manifest: {0}" -f $script:NifduApiManifestPath) "DarkGray"
    $script:NifduApiManifest = Get-Content $script:NifduApiManifestPath | ConvertFrom-Json
} else {
    Say ("[NIFDU] API manifest not found: {0}" -f $script:NifduApiManifestPath) "Red"
}

function Get-NifduApiRole {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name  # e.g. "/api/codegen"
    )

    if (-not $script:NifduApiManifest) {
        Say "[NIFDU] Manifest is not loaded." "Red"
        return $null
    }

    $api = $script:NifduApiManifest.apis | Where-Object { $_.name -eq $Name }
    if (-not $api) {
        Say ("[NIFDU] API not found in manifest: {0}" -f $Name) "Yellow"
        return $null
    }
    return $api
}

function Get-NifduToolInfo {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ToolName  # e.g. "stripe_payments"
    )

    if (-not $script:NifduApiManifest) {
        Say "[NIFDU] Manifest is not loaded." "Red"
        return $null
    }

    $tool = $script:NifduApiManifest.tools | Where-Object { $_.name -eq $ToolName }
    if (-not $tool) {
        Say ("[NIFDU] Tool not found in manifest: {0}" -f $ToolName) "Yellow"
        return $null
    }
    return $tool
}

Say "[NIFDU] API manifest helpers ready in this session." "Green"
