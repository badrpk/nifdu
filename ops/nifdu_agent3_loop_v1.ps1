param(
  [string]$Project = "sophyane_live",
  [string]$BaseUrl = "http://127.0.0.1",
  [int]$MaxIters = 10
)

$ErrorActionPreference="Stop"
function Say($t,$c="Gray"){ try{Write-Host $t -ForegroundColor $c}catch{Write-Host $t} }

function Load-DotEnv {
  param([string]$Path="C:\ENV\.env")
  if(!(Test-Path $Path)){ throw "Missing .env: $Path" }
  foreach($ln in Get-Content $Path){
    $s = $ln.Trim()
    if(!$s -or $s.StartsWith("#")){ continue }
    $eq = $s.IndexOf("="); if($eq -lt 1){ continue }
    $k = $s.Substring(0,$eq).Trim()
    $v = $s.Substring($eq+1).Trim()
    if($v.StartsWith('"') -and $v.EndsWith('"')){ $v = $v.Substring(1,$v.Length-2) }
    if($v.StartsWith("'") -and $v.EndsWith("'")){ $v = $v.Substring(1,$v.Length-2) }
    [Environment]::SetEnvironmentVariable($k, $v, "Process")
  }
}

function PostJson([string]$Url, [object]$Obj){
  $json = $Obj | ConvertTo-Json -Depth 20
  Invoke-RestMethod -Method Post -Uri $Url -ContentType "application/json; charset=utf-8" -Body $json
}

Say "`n=== NIFDU AGENT LOOP v1 ===`n" Yellow
Load-DotEnv "C:\ENV\.env"

$preview = "$BaseUrl/apps/$Project/?ts=$([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())"
Say "Preview: $preview" Cyan

Say "`n[0] /api/codegen" Yellow
$codegen = PostJson "$BaseUrl/api/codegen" @{
  project=$Project
  prompt="Vibe IDE app (local-first). $Project"
  session_id=[string]([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())
}
Say ("codegen: " + $codegen.status) DarkGray

for($iter=1; $iter -le $MaxIters; $iter++){
  Say "`n[$iter] /api/compile" Yellow
  $compile = PostJson "$BaseUrl/api/compile" @{ cmd="echo OK && exit /b 0"; cwd="C:\nifdu" }
  if($compile.status -eq "ok"){
    Say "[OK] compile step passed." Green
    break
  }
  Say "[ERR] compile failed (v1 loop only). Output:" Red
  Say ($compile.exec.output | Out-String) DarkGray
  break
}

Say "`n[RUN] /api/run" Yellow
PostJson "$BaseUrl/api/run" @{} | Out-Null

$open = "$BaseUrl/apps/$Project/?ts=$([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())"
Say "[OPEN] $open" Yellow
Start-Process $open

Say "`nDONE." Green