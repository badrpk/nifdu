param(
    [Parameter(Mandatory = $true)]
    [string]$Project,

    [Parameter(Mandatory = $true)]
    [string]$Prompt
)

$ErrorActionPreference = "Stop"

$Executor = "C:\nifdu\ops\nifdu_agent3_apply_codegen.ps1"
$Stack    = "react"
$Brain    = "auto"
$Mode     = "vibe_coding"

function Say {
    param([string]$m,[string]$c="Gray")
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

Say ""
Say "=== NIFDU AGENT 3 REACT ONE-SHOT (SMART) ===" "Cyan"
Say ("Project : {0}" -f $Project) "Gray"

# Just show the first line of the prompt in the header to avoid huge logs
$firstLine = ($Prompt -split "`r?`n")[0]
Say ("Prompt  : {0}" -f $firstLine) "Gray"

Say "[1] Running Agent 3 (stack=react)..." "Yellow"

# CRITICAL: call the executor with real named parameters, so the entire here-string
# stays one argument and does NOT get split into 'remaining', '- Styling:', etc.
& $Executor `
    -Project $Project `
    -Prompt  $Prompt `
    -Stack   $Stack `
    -Brain   $Brain `
    -Mode    $Mode
