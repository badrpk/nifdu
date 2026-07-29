param(
  [string]$WorkerPath = "C:\nifdu\ops\nifdu_brain_worker_oneshot.ps1"
)

$ErrorActionPreference="Stop"
function Say($t,$c="Gray"){ try{Write-Host $t -ForegroundColor $c}catch{Write-Host $t} }
function Ensure-Dir($p){ if(!(Test-Path $p)){ New-Item -ItemType Directory -Force -Path $p | Out-Null } }

Ensure-Dir (Split-Path $WorkerPath -Parent)

# 1) If file doesn't exist, create it from clipboard (you just pasted it; easiest capture method)
if(!(Test-Path $WorkerPath)){
  Say "Worker not found. I will create it from clipboard content..." Yellow
  $clip = Get-Clipboard -Raw
  if([string]::IsNullOrWhiteSpace($clip)){ throw "Clipboard is empty. Copy the whole worker script first, then re-run this patch." }
  Set-Content -LiteralPath $WorkerPath -Encoding UTF8 -Value $clip
  Say "✔ Created: $WorkerPath" Green
}else{
  Say "✔ Found: $WorkerPath" Green
}

# 2) Backup
$bk = "$WorkerPath.bak_$(Get-Date -Format yyyyMMdd_HHmmss_fff)"
Copy-Item -LiteralPath $WorkerPath -Destination $bk -Force
Say "Backup -> $bk" DarkGray

# 3) Patch: fix Test-Path -or parsing
$src = Get-Content -LiteralPath $WorkerPath -Raw -Encoding UTF8
$before = $src

# Patch all common variants in one go
$src = $src -replace 'if\s*\(\s*Test-Path\s+\$doneMarker\s+-or\s+Test-Path\s+\$failMarker\s*\)\s*\{\s*continue\s*\}', 'if( (Test-Path $doneMarker) -or (Test-Path $failMarker) ){ continue }'
$src = $src -replace 'if\s*\(\s*Test-Path\s+\$doneMarker\s+-or\s+\(Test-Path\s+\$failMarker\)\s*\)', 'if( (Test-Path $doneMarker) -or (Test-Path $failMarker) )'
$src = $src -replace 'if\s*\(\s*\(Test-Path\s+\$doneMarker\)\s+-or\s+Test-Path\s+\$failMarker\s*\)', 'if( (Test-Path $doneMarker) -or (Test-Path $failMarker) )'

if($src -eq $before){
  Say "No changes matched. I'll show the exact line you need to fix:" DarkYellow
  Select-String -Path $WorkerPath -Pattern 'Test-Path\s+\$doneMarker|Test-Path\s+\$failMarker' -Context 0,2 | Out-Host
  throw "Patch not applied automatically. Replace: if(Test-Path ... -or Test-Path ...) with parentheses."
}

Set-Content -LiteralPath $WorkerPath -Encoding UTF8 -Value $src
Say "✔ Patched: fixed Test-Path -or parsing." Green

# 4) Run worker
Say "`n=== RUN WORKER ===`n" Yellow
powershell -NoProfile -ExecutionPolicy Bypass -File $WorkerPath

Say "`nDONE. Inspect:" Green
Say "  dir C:\nifdu\runtime\brain\signals | sort LastWriteTime -desc | select -First 5" DarkGray
Say "  dir C:\nifdu\runtime\brain\queue   | sort LastWriteTime -desc | select -First 10" DarkGray
Say "  dir C:\nifdu\runtime\brain\done    | sort LastWriteTime -desc | select -First 10" DarkGray
Say "  dir C:\nifdu\runtime\brain\fail    | sort LastWriteTime -desc | select -First 10" DarkGray

