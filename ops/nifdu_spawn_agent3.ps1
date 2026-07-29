param(
  [Parameter(Mandatory=$true)][string]$SessionId,
  [Parameter(Mandatory=$true)][string]$Project,
  [ValidateSet("next","cmake","custom")][string]$Mode = "next"
)

$ErrorActionPreference="Stop"

$RunsDir = "C:\nifdu\runtime\runs"
New-Item -ItemType Directory -Force -Path $RunsDir | Out-Null

$safeSession = ($SessionId -replace '[^a-zA-Z0-9_-]', '_')

$log     = Join-Path $RunsDir ("loop_next_{0}.log" -f $safeSession)
$errlog  = Join-Path $RunsDir ("loop_next_{0}.err.log" -f $safeSession)
$metalog = Join-Path $RunsDir ("loop_next_{0}.meta.log" -f $safeSession)

# Create headers
"[NIFDU] Vibe run started" | Out-File -FilePath $log -Encoding utf8
("[NIFDU] SessionId={0} Project={1} Mode={2}" -f $SessionId,$Project,$Mode) | Out-File -FilePath $log -Encoding utf8 -Append
("[NIFDU] Time={0}" -f (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")) | Out-File -FilePath $log -Encoding utf8 -Append
("[NIFDU] ErrLog={0}" -f $errlog) | Out-File -FilePath $log -Encoding utf8 -Append

# Ensure errlog exists/cleared
"" | Out-File -FilePath $errlog -Encoding utf8

$ps     = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
$script = "C:\nifdu\ops\nifdu_agent_loop_real.ps1"

$args = @(
  "-NoProfile",
  "-ExecutionPolicy","Bypass",
  "-File", $script,
  "-Project", $Project,
  "-Mode", $Mode
)

$p = Start-Process -FilePath $ps -ArgumentList $args -WindowStyle Hidden -PassThru `
  -RedirectStandardOutput $log -RedirectStandardError $errlog

("[NIFDU] Spawned PID={0}" -f $p.Id) | Out-File -FilePath $metalog -Encoding utf8
("[NIFDU] Log={0}" -f $log) | Out-File -FilePath $metalog -Encoding utf8 -Append
("[NIFDU] Err={0}" -f $errlog) | Out-File -FilePath $metalog -Encoding utf8 -Append

"LOG=$log"
