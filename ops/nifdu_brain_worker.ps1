param(
  [string]$EnvFile,
  [string]$Runtime,

  [string]$DefaultTenant,
  [string]$DefaultUser,
  [string]$DefaultProject,

  [string]$OllamaUrl,
  [string]$OllamaModel,

  [string]$OpenAIBase,
  [string]$OpenAIModel
)

$ErrorActionPreference="Stop"
function Say($t,$c="Gray"){ try{Write-Host $t -ForegroundColor $c}catch{Write-Host $t} }
function Ensure-Dir($p){ if(!(Test-Path $p)){ New-Item -ItemType Directory -Force -Path $p | Out-Null } }
function NowRid(){ (Get-Date -Format "yyyyMMdd_HHmmss_fff") }

function Read-DotEnv([string]$path){
  $map = @{}
  if(!(Test-Path $path)){ return $map }
  $dq = [char]34
  $sq = [char]39
  Get-Content $path -Encoding UTF8 | ForEach-Object {
    $line = $_.Trim()
    if(!$line -or $line.StartsWith("#")){ return }
    $eq = $line.IndexOf("=")
    if($eq -lt 1){ return }
    $k = $line.Substring(0,$eq).Trim()
    $v = $line.Substring($eq+1).Trim()
    if(($v.StartsWith($dq) -and $v.EndsWith($dq)) -or ($v.StartsWith($sq) -and $v.EndsWith($sq))){
      if($v.Length -ge 2){ $v = $v.Substring(1,$v.Length-2) }
    }
    $map[$k]=$v
  }
  return $map
}

function Json-LoadFile([string]$p){
  $raw = Get-Content -LiteralPath $p -Raw -Encoding UTF8
  if([string]::IsNullOrWhiteSpace($raw)){ return $null }
  return ($raw | ConvertFrom-Json)
}
function Json-SaveFile([string]$p, $obj){
  ($obj | ConvertTo-Json -Depth 80) | Set-Content -LiteralPath $p -Encoding UTF8
}

# Layout
$Events  = Join-Path $Runtime "events"
$Queue   = Join-Path $Runtime "queue"
$Done    = Join-Path $Runtime "done"
$Fail    = Join-Path $Runtime "fail"
$Signals = Join-Path $Runtime "signals"
$EmbOut  = Join-Path $Runtime "embeddings"

Ensure-Dir $Runtime
Ensure-Dir $Events
Ensure-Dir $Queue
Ensure-Dir $Done
Ensure-Dir $Fail
Ensure-Dir $Signals
Ensure-Dir $EmbOut

Say "`n=== NIFDU BRAIN WORKER (RUN-ONCE v5: DISK ONLY) ===`n" Yellow
Say ("Runtime: " + $Runtime) DarkGray

# Load env (no override)
$envMap = Read-DotEnv $EnvFile
foreach($k in $envMap.Keys){
  $ep="Env:\$k"
  if(-not (Test-Path $ep)){ Set-Item -Path $ep -Value $envMap[$k] }
}

function Try-OllamaEmbed([string]$text){
  try{
    $u = "$OllamaUrl/api/embeddings"
    $body = @{ model = $OllamaModel; prompt = $text } | ConvertTo-Json -Depth 10
    $r = Invoke-RestMethod -Method Post -Uri $u -ContentType "application/json" -Body $body -TimeoutSec 30
    if($r -and $r.embedding){ return ,$r.embedding }
  }catch{}
  return $null
}
function Try-OpenAIEmbed([string]$text){
  $key = $env:OPENAI_API_KEY
  if([string]::IsNullOrWhiteSpace($key)){ return $null }
  try{
    $u = "$OpenAIBase/embeddings"
    $body = @{ model = $OpenAIModel; input = $text } | ConvertTo-Json -Depth 10
    $hdrs = @{ Authorization = "Bearer $key" }
    $r = Invoke-RestMethod -Method Post -Uri $u -Headers $hdrs -ContentType "application/json" -Body $body -TimeoutSec 30
    if($r -and $r.data -and $r.data.Count -gt 0 -and $r.data[0].embedding){ return ,$r.data[0].embedding }
  }catch{}
  return $null
}
function Make-EmbedText($obj){ return ($obj | ConvertTo-Json -Compress -Depth 80) }

function Guess-LatestEventRid(){
  $ev = Get-ChildItem $Events -Filter "brain_event_*.json" -File -EA SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if(!$ev){ return $null }
  if($ev.BaseName -match "^brain_event_(.+)$"){ return $matches[1] }
  return $null
}

# ---------------- STEP 2: Signals ----------------
Say "`n[STEP 2] Signals" Cyan
$feedbackFiles = Get-ChildItem $Events -Filter "brain_feedback_*.json" -File -EA SilentlyContinue | Sort-Object LastWriteTime
$signalsMade = 0

foreach($ff in $feedbackFiles){
  $marker = Join-Path $Done ($ff.BaseName + ".signal.done.json")
  if(Test-Path $marker){ continue }

  $fb = Json-LoadFile $ff.FullName
  if(!$fb){
    Json-SaveFile (Join-Path $Fail ($ff.BaseName + ".signal.fail.json")) @{ ok=$false; why="invalid_feedback_json"; file=$ff.FullName; ts=(Get-Date).ToString("o") }
    continue
  }

  $eventRid = $null
  if($fb.PSObject.Properties.Name -contains "event_rid"){ $eventRid = [string]$fb.event_rid }
  if([string]::IsNullOrWhiteSpace($eventRid) -and ($fb.PSObject.Properties.Name -contains "rid")){ $eventRid = [string]$fb.rid }
  if($eventRid -eq "x" -or $eventRid -eq "0" -or $eventRid -eq "unknown"){ $g=Guess-LatestEventRid; if($g){ $eventRid=$g } }
  if([string]::IsNullOrWhiteSpace($eventRid)){ $eventRid="unknown_event" }

  $rating=0; if($fb.PSObject.Properties.Name -contains "rating"){ try{ $rating=[int]$fb.rating }catch{ $rating=0 } }
  $signal=0; $label="neutral"
  if($rating -gt 0){ $signal=1; $label="keep" } elseif($rating -lt 0){ $signal=-1; $label="suppress" }

  $tenant=[string]$fb.tenant; if([string]::IsNullOrWhiteSpace($tenant)){ $tenant=$DefaultTenant }
  $user  =[string]$fb.user;   if([string]::IsNullOrWhiteSpace($user)){   $user=$DefaultUser }
  $proj  =[string]$fb.project;if([string]::IsNullOrWhiteSpace($proj)){   $proj=$DefaultProject }

  $rid = NowRid
  $sigPath = Join-Path $Signals ("signal_" + $eventRid + "_" + $rid + ".json")
  Json-SaveFile $sigPath @{ ok=$true; kind="reinforcement_signal"; event_rid=$eventRid; rating=$rating; signal=$signal; label=$label; tenant=$tenant; user=$user; project=$proj; ts=(Get-Date).ToString("o") }

  $jobRid = NowRid
  $jobPath = Join-Path $Queue ("reinforce_" + $jobRid + ".job.json")
  Json-SaveFile $jobPath @{ kind="reinforce"; rid=$jobRid; event_rid=$eventRid; signal_path=$sigPath; tenant=$tenant; user=$user; project=$proj; ts=(Get-Date).ToString("o") }

  Json-SaveFile $marker @{ ok=$true; signal_path=$sigPath; job_path=$jobPath; ts=(Get-Date).ToString("o") }
  $signalsMade++
}
Say ("Signals created: " + $signalsMade) Green

# ---------------- STEP 3: Embeds (disk output) ----------------
Say "`n[STEP 3] Embeds (disk output)" Cyan
$embedJobs = Get-ChildItem $Queue -Filter "embed_*.job.json" -File -EA SilentlyContinue | Sort-Object LastWriteTime

$embedded=0; $failed=0
foreach($job in $embedJobs){
  $doneMarker = Join-Path $Done ($job.BaseName + ".done.json")
  $failMarker = Join-Path $Fail ($job.BaseName + ".fail.json")
  if((Test-Path $doneMarker) -or (Test-Path $failMarker)){ continue }

  $j = Json-LoadFile $job.FullName
  if(!$j){ Json-SaveFile $failMarker @{ ok=$false; why="invalid_job_json"; job=$job.FullName; ts=(Get-Date).ToString("o") }; $failed++; continue }

  $eventPath = [string]$j.event_path
  if([string]::IsNullOrWhiteSpace($eventPath) -or !(Test-Path $eventPath)){
    Json-SaveFile $failMarker @{ ok=$false; why="missing_event_path"; job=$job.FullName; event_path=$eventPath; ts=(Get-Date).ToString("o") }; $failed++; continue
  }

  $ev = Json-LoadFile $eventPath
  if(!$ev){ Json-SaveFile $failMarker @{ ok=$false; why="invalid_event_json"; job=$job.FullName; event_path=$eventPath; ts=(Get-Date).ToString("o") }; $failed++; continue }

  $tenant=[string]$j.tenant;  if([string]::IsNullOrWhiteSpace($tenant)){ $tenant=$DefaultTenant }
  $user  =[string]$j.user;    if([string]::IsNullOrWhiteSpace($user)){   $user=$DefaultUser }
  $proj  =[string]$j.project; if([string]::IsNullOrWhiteSpace($proj)){   $proj=$DefaultProject }
  $surface=[string]$j.surface;if([string]::IsNullOrWhiteSpace($surface)){ $surface="brain_event" }
  $rid=[string]$j.rid; if([string]::IsNullOrWhiteSpace($rid)){ $rid=NowRid }

  $text = Make-EmbedText $ev

  $emb = Try-OllamaEmbed $text
  $provider="ollama"
  if(!$emb){ $emb = Try-OpenAIEmbed $text; $provider="openai" }

  if(!$emb){
    Json-SaveFile $failMarker @{ ok=$false; why="no_embedding_provider"; job=$job.FullName; ts=(Get-Date).ToString("o") }
    $failed++; continue
  }

  # Save embedding to disk (this is the stable handoff for later DB ingest)
  $embPath = Join-Path $EmbOut ("embedding_" + $rid + ".json")
  Json-SaveFile $embPath @{
    ok=$true
    rid=$rid
    provider=$provider
    tenant=$tenant
    user=$user
    project=$proj
    surface=$surface
    event_path=$eventPath
    embedding=$emb
    ts=(Get-Date).ToString("o")
  }

  Json-SaveFile $doneMarker @{ ok=$true; rid=$rid; provider=$provider; embedding_path=$embPath; job=$job.FullName; ts=(Get-Date).ToString("o") }
  $embedded++
}

Say "`n=== SUMMARY ===" Yellow
Say ("Signals made : " + $signalsMade) Green
Say ("Embeds done  : " + $embedded) Green
Say ("Embeds fail  : " + $failed) DarkYellow

