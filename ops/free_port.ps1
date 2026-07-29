param(
  [int]$Port = 3000,
  [string[]]$AllowProcess = @()
)

$ErrorActionPreference="Stop"
function Say($t,$c="Gray"){ try{Write-Host $t -ForegroundColor $c}catch{Write-Host $t} }

Say "
=== FREE PORT $Port (KILL HOLDER) ===
" Yellow

$cmd = "netstat -ano | findstr LISTENING | findstr :$Port"
$lines = @(cmd.exe /c $cmd)

if(-not $lines -or $lines.Count -eq 0){
  Say ("OK: Port " + $Port + " is already free.") Green
  exit 0
}

$lines | Out-Host

$pids = @()
foreach($l in $lines){
  $pidX = ($l -split '\s+')[-1]
  if($pidX -match '^\d+$'){ $pids += [int]$pidX }
}
$pids = $pids | Sort-Object -Unique

foreach($pidX in $pids){
  $pname = ""
  try { $pname = (Get-Process -Id $pidX -EA Stop).ProcessName } catch { $pname = "" }

  if($AllowProcess -and $pname){
    foreach($ap in $AllowProcess){
      if($ap -and ($pname -ieq $ap)){
        Say ("SKIP: PID " + $pidX + " (" + $pname + ") is allowed") DarkGray
        continue 2
      }
    }
  }

  Say ("Killing PID " + $pidX + (if($pname){ " (" + $pname + ")" } else { "" }) + "...") Cyan
  cmd.exe /c ("taskkill /F /PID " + $pidX + " >NUL 2>&1") | Out-Null
}

Start-Sleep -Milliseconds 350
$check = @(cmd.exe /c $cmd)

if($check -and $check.Count -gt 0){
  Say "FAIL: Still in use:" Red
  $check | Out-Host
  throw ("Port " + $Port + " could not be freed.")
}

Say ("OK: Port " + $Port + " is now free.") Green