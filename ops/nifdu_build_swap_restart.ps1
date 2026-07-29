param(
  [string]$Repo   = "C:\nifdu",
  [string]$Build  = "C:\nifdu\build",
  [string]$ExeDir = "C:\nifdu\build\Release",
  [ValidateSet("Debug","Release")] [string]$Cfg = "Release",
  [string]$Ops    = "C:\nifdu\ops\nifdu_restart_safe_wait.ps1"
)

$ErrorActionPreference="Stop"
function Say($t,$c="Gray"){ try{Write-Host $t -ForegroundColor $c}catch{Write-Host $t} }

Say "`n=== NIFDU: BUILD -> SWAP -> RESTART ===`n" Yellow

Push-Location $Repo
cmake -S . -B $Build | Out-Host
cmake --build $Build --config $Cfg | Out-Host
Pop-Location

if(!(Test-Path $Ops)){
  throw "Missing restart helper: $Ops"
}

powershell -ExecutionPolicy Bypass -File $Ops -ExeDir $ExeDir

Say "`nDONE." Green