param(
    [Parameter(Mandatory = $true)]
    [string]$Project,

    [Parameter(Mandatory = $true)]
    [string]$Prompt
)

$ErrorActionPreference = "Stop"

function Say {
    param([string]$Text)
    Write-Host $Text
}

$base = 'http://127.0.0.1:8000'

Say ''
Say '=== NIFDU AGENT 3 - APPLY /api/codegen (TINY) ==='
Say ('Project: ' + $Project)
Say ('Prompt : ' + $Prompt)

# 1) Build JSON body
$body = @{
    project = $Project
    prompt  = $Prompt
    brain   = 'auto'
    mode    = 'vibe_coding'
} | ConvertTo-Json -Depth 10

Say ''
Say 'STEP: Calling /api/codegen ...'

# 2) Call /api/codegen
try {
    $resp = Invoke-RestMethod `
        -Uri ($base + '/api/codegen') `
        -Method Post `
        -ContentType 'application/json; charset=utf-8' `
        -Body $body
} catch {
    Say ('ERROR: /api/codegen call failed: ' + $_.Exception.Message)
    exit 1
}

if (-not $resp) {
    Say 'ERROR: /api/codegen returned no response body.'
    exit 1
}

Say ('RESULT: status=' + $resp.status + ' engine=' + $resp.engine + ' model=' + $resp.model)

# 3) Apply file writes
if (-not $resp.files) {
    Say 'WARN: /api/codegen returned no files array.'
} else {
    foreach ($f in $resp.files) {
        $action  = $f.action
        $path    = $f.path
        $content = $f.content

        if ($action -ne 'write') {
            Say ('SKIP: action=' + $action + ' path=' + $path)
            continue
        }

        if (-not $path) {
            Say 'SKIP: Empty path in file result.'
            continue
        }

        $dir = Split-Path $path -Parent
        if (-not (Test-Path $dir)) {
            Say ('FS: Creating directory: ' + $dir)
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }

        Say ('FS: Writing file: ' + $path)
        Set-Content -Path $path -Value $content -Encoding UTF8
    }
}

# 4) Execute post_steps if present
if ($resp.post_steps) {
    Say ''
    Say 'STEP: Executing post_steps from brain:'

    foreach ($step in $resp.post_steps) {
        Say ('  > ' + $step)
        try {
            Invoke-Expression $step
        } catch {
            Say ('  ERROR running step: ' + $_.Exception.Message)
        }
    }
} else {
    Say ''
    Say 'NOTE: No post_steps provided by brain.'
}

Say ''
Say '=== DONE NIFDU AGENT 3 CODEGEN APPLY (TINY) ==='
Say ''
