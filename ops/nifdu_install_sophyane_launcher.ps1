# ==============================================
# C:\nifdu\ops\nifdu_install_sophyane_launcher.ps1
# NIFDU / SOPHYANE — INSTALL "sophyane" LAUNCHER
# ----------------------------------------------
# What this does:
#   - Ensures your PowerShell profile file exists
#   - Adds a global "sophyane" function to $PROFILE
#   - Function:
#       * Accepts a natural-language product prompt
#       * Calls sophyane_vibe_product_oneshot.ps1
#       * Opens https://sophyane.com when done
# ==============================================

param()

$ErrorActionPreference = "Stop"

function Say {
    param([string]$Text, [string]$Color = "Gray")
    try {
        $valid = [enum]::GetNames([System.ConsoleColor])
        if ($valid -notcontains $Color) { $Color = "Gray" }
        Write-Host $Text -ForegroundColor $Color
    } catch {
        Write-Host $Text
    }
}

Say "`n=== NIFDU / SOPHYANE — INSTALL 'sophyane' LAUNCHER ===`n" "Yellow"

# ----------------------------------------------
# 1) Ensure profile file exists
# ----------------------------------------------
$profilePath = $PROFILE
$profileDir  = Split-Path $profilePath -Parent

Say ("PowerShell profile path: {0}" -f $profilePath) "Cyan"

if (!(Test-Path $profileDir)) {
    Say ("Creating profile directory: {0}" -f $profileDir) "Yellow"
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
}

if (!(Test-Path $profilePath)) {
    Say "Profile file does not exist. Creating empty profile..." "Yellow"
    try {
        New-Item -ItemType File -Path $profilePath -Force | Out-Null
    } catch {
        Say ("ERROR: Could not create profile file: {0}" -f $_.Exception.Message) "Red"
        exit 1
    }
}

# Backup existing profile
$backupPath = "{0}.bak_{1}" -f $profilePath, (Get-Date -Format "yyyyMMdd_HHmmss")
Copy-Item $profilePath $backupPath -Force
Say ("Backup created: {0}" -f $backupPath) "DarkGray"

# ----------------------------------------------
# 2) Prepare sophyane function block
# ----------------------------------------------
$sophyaneFunction = @'
function sophyane {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$PromptWords
    )

    $promptText = $PromptWords -join " "

    if (-not $promptText -or $promptText.Trim().Length -eq 0) {
        Write-Host "" -ForegroundColor Gray
        Write-Host "=== SOPHYANE VIBE CODING LAUNCHER ===" -ForegroundColor Yellow
        Write-Host "Describe the product you want to build:" -ForegroundColor Cyan
        $promptText = Read-Host "Product prompt"
    }

    if (-not $promptText -or $promptText.Trim().Length -eq 0) {
        Write-Host "No prompt provided. Aborting." -ForegroundColor Red
        return
    }

    $scriptPath = "C:\nifdu\ops\sophyane_vibe_product_oneshot.ps1"

    if (-not (Test-Path $scriptPath)) {
        Write-Host "Cannot find $scriptPath" -ForegroundColor Red
        return
    }

    Write-Host "" -ForegroundColor Gray
    Write-Host ">>> Sending to NIFDU / Agent 3:" -ForegroundColor Yellow
    Write-Host ("    {0}" -f $promptText) -ForegroundColor Green
    Write-Host "" -ForegroundColor Gray

    & $scriptPath -Prompt $promptText -Project "sophyane_live" -RunBuild:$false

    Write-Host "Opening sophyane.com ..." -ForegroundColor Yellow
    Start-Process "https://sophyane.com"
}
'@

# ----------------------------------------------
# 3) Append function to profile
# ----------------------------------------------
$marker = "`n# ===== NIFDU / SOPHYANE LAUNCHER INSTALLED $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') =====`n"

Add-Content -Path $profilePath -Value $marker
Add-Content -Path $profilePath -Value $sophyaneFunction

Say "Appended 'sophyane' launcher function to PowerShell profile." "Green"

# ----------------------------------------------
# 4) Reload profile
# ----------------------------------------------
try {
    . $profilePath
    Say ("Reloaded current session profile ({0})." -f $profilePath) "Green"
} catch {
    Say ("Could not reload profile automatically: {0}" -f $_.Exception.Message) "Red"
    Say "You may need to restart PowerShell or run: . `$PROFILE" "DarkYellow"
}

# Verify
try {
    Get-Command sophyane -ErrorAction Stop | Out-Null
    Say "`nSUCCESS: 'sophyane' command is now available." "Green"
    Say "Usage examples:" "Cyan"
    Say "  sophyane" "Gray"
    Say "    -> will ask you for a product prompt" "DarkGray"
    Say "  sophyane make dog website with gallery" "Gray"
    Say "    -> direct one-shot prompt" "DarkGray"
} catch {
    Say "`nWARNING: 'sophyane' command not detected yet." "Red"
    Say "Restart PowerShell or run: . `$PROFILE" "DarkYellow"
}

Say "`n=== DONE: sophyane launcher installation complete ===`n" "Green"
