param(
  [string]$Repo  = "C:\nifdu",
  [string]$Build = "C:\nifdu\build",
  [string]$Exe   = "C:\nifdu\build\Release\nifdu.exe",
  [ValidateSet("Debug","Release")]
  [string]$Cfg   = "Release",
  [switch]$Restart
)

$ErrorActionPreference="Stop"
function Say($t,$c="Gray"){ try{Write-Host $t -ForegroundColor $c}catch{Write-Host $t} }

function Kill-Nifdu {
  Say "Killing nifdu.exe (hard)..." Yellow
  Get-Process nifdu -EA SilentlyContinue | % { try{ Stop-Process -Id $_.Id -Force -EA SilentlyContinue }catch{} }
  cmd /c "taskkill /F /IM nifdu.exe >NUL 2>&1" | Out-Null
  Start-Sleep -Milliseconds 500
}

function Wait-Unlock([string]$Path, [int]$TimeoutSec=8){
  $sw = [Diagnostics.Stopwatch]::StartNew()
  while($sw.Elapsed.TotalSeconds -lt $TimeoutSec){
    try{
      if(!(Test-Path $Path)){ return $true }
      $fs = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
      $fs.Close()
      return $true
    } catch {
      Start-Sleep -Milliseconds 250
    }
  }
  return $false
}

Say "`n=== FIX LNK1104 (unlock nifdu.exe) ===`n" Yellow

Kill-Nifdu

if(Test-Path $Exe){
  Say "Waiting for unlock: $Exe" Cyan
  if(-not (Wait-Unlock $Exe 10)){ throw "nifdu.exe still locked." }
  Say "Unlocked OK." Green
}

Say "`n=== BUILD ($Cfg) ===`n" Yellow
Push-Location $Repo
cmake -S . -B $Build | Out-Host
cmake --build $Build --config $Cfg | Out-Host
Pop-Location

if($Restart){
  Say "`n=== RESTART nifdu.exe ===`n" Yellow
  Kill-Nifdu
  Start-Process $Exe
}

Say "`nDONE." Green
