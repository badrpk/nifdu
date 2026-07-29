param(
  [Parameter(Mandatory=$true)][string]$Domain,
  [string]$Exe    = "C:\nifdu\build\Release\nifdu.exe",
  [string]$DotEnv = "C:\ENV\.env"
)

$ErrorActionPreference="Stop"

function Load-DotEnv([string]$path){
  if(!(Test-Path $path)){ throw "Missing .env: $path" }
  foreach($raw in [IO.File]::ReadAllLines($path,[Text.Encoding]::UTF8)){
    $line = $raw.Trim()
    if(!$line -or $line.StartsWith("#")){ continue }
    $i = $line.IndexOf("=")
    if($i -lt 1){ continue }
    $k = $line.Substring(0,$i).Trim()
    $v = $line.Substring($i+1).Trim()
    if($v.StartsWith('"') -and $v.EndsWith('"')){ $v = $v.Substring(1,$v.Length-2) }
    if($k){ [Environment]::SetEnvironmentVariable($k,$v,"Process") }
  }
}

function GetEnv([string]$k){
  return [Environment]::GetEnvironmentVariable($k,"Process")
}

# domain -> SUFFIX (nifdu.com => NIFDU_COM)
$suffix = $Domain.ToUpper().Replace(".","_").Replace("-","_")

Load-DotEnv $DotEnv

$pgHost = GetEnv ("PGHOST_"     + $suffix)
$pgPort = GetEnv ("PGPORT_"     + $suffix)
$pgDb   = GetEnv ("PGDATABASE_" + $suffix)
$pgUser = GetEnv ("PGUSER_"     + $suffix)
$pgPass = GetEnv ("PGPASSWORD_" + $suffix)

if(!$pgHost -or !$pgPort -or !$pgDb -or !$pgUser -or !$pgPass){
  Write-Host "Missing PG vars for $suffix" -ForegroundColor Red
  Write-Host ("Need: PGHOST_{0}, PGPORT_{0}, PGDATABASE_{0}, PGUSER_{0}, PGPASSWORD_{0}" -f $suffix) -ForegroundColor Yellow
  exit 1
}

$env:NIFDU_PG_CONNINFO = "host=$pgHost port=$pgPort dbname=$pgDb user=$pgUser password=$pgPass"
$shown = $env:NIFDU_PG_CONNINFO -replace 'password=[^ ]+','password=***'
Write-Host ("NIFDU_PG_CONNINFO = " + $shown) -ForegroundColor Cyan

# kill running nifdu
Get-Process nifdu -EA SilentlyContinue | % { try{ Stop-Process -Id $_.Id -Force }catch{} }
cmd /c "taskkill /F /IM nifdu.exe >NUL 2>&1" | Out-Null
Start-Sleep -Milliseconds 250

$ts = Get-Date -Format yyyyMMdd_HHmmss
$out = "C:\nifdu\runtime\nifdu_${suffix}_$ts.out.log"
$err = "C:\nifdu\runtime\nifdu_${suffix}_$ts.err.log"

Write-Host ("Starting NIFDU...") -ForegroundColor Yellow
Write-Host ("  out: " + $out) -ForegroundColor DarkGray
Write-Host ("  err: " + $err) -ForegroundColor DarkGray

$null = Start-Process -FilePath $Exe -RedirectStandardOutput $out -RedirectStandardError $err

# small, safe peek (don’t spam console)
Start-Sleep -Milliseconds 800
if(Test-Path $out){
  $m = Select-String -Path $out -Pattern "LISTENING \(PROOF\)|\[NIFDU::DB\]" -EA SilentlyContinue | Select-Object -First 6
  if($m){ $m | % { $_.Line } }
}
if(Test-Path $err){
  $m2 = Select-String -Path $err -Pattern "\[NIFDU::DB\]" -EA SilentlyContinue | Select-Object -First 6
  if($m2){ $m2 | % { $_.Line } }
}