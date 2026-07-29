Set-StrictMode -Version Latest

function A3-Say($t,$c="Gray"){ try{Write-Host $t -ForegroundColor $c}catch{Write-Host $t} }

function A3-NowIso(){ (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffK") }

function A3-EnsureDir([string]$p){
  if([string]::IsNullOrWhiteSpace($p)){ return }
  if(!(Test-Path $p)){ New-Item -ItemType Directory -Force -Path $p | Out-Null }
}

function A3-WriteUtf8NoBom([string]$path,[string]$text){
  $dir = Split-Path $path -Parent
  if($dir){ A3-EnsureDir $dir }
  $enc = New-Object System.Text.UTF8Encoding($false)
  [IO.File]::WriteAllText($path,$text,$enc)
}

function A3-ReadEnvFile([string]$envPath){
  $map = @{}
  if(!(Test-Path $envPath)){ return $map }
  $lines = Get-Content $envPath -ErrorAction Stop
  foreach($ln in $lines){
    $t = $ln.Trim()
    if($t -eq "" -or $t.StartsWith("#")){ continue }
    if($t -notmatch "^[A-Za-z_][A-Za-z0-9_]*="){ continue }
    $k = $t.Split("=",2)[0].Trim()
    $v = $t.Split("=",2)[1]
    if($v.StartsWith('"') -and $v.EndsWith('"')){ $v = $v.Substring(1,$v.Length-2) }
    $map[$k] = $v
  }
  return $map
}

function A3-Redact([string]$s,[hashtable]$envMap){
  if([string]::IsNullOrEmpty($s)){ return $s }
  $out = $s
  foreach($k in $envMap.Keys){
    $v = $envMap[$k]
    if([string]::IsNullOrEmpty($v)){ continue }
    if($v.Length -lt 8){ continue }
    $out = $out.Replace($v, "***REDACTED***")
  }
  return $out
}

function A3-Json([object]$o,[int]$depth=20){
  return ($o | ConvertTo-Json -Depth $depth)
}

function A3-LoadState([string]$statePath){
  if(Test-Path $statePath){
    try{
      return (Get-Content $statePath -Raw -Encoding UTF8 | ConvertFrom-Json)
    } catch {}
  }
  return $null
}

function A3-SaveState([string]$statePath,[object]$state){
  $json = A3-Json $state 50
  A3-WriteUtf8NoBom $statePath $json
}

function A3-BackupFile([string]$path,[string]$backupDir){
  if(!(Test-Path $path)){ return $null }
  A3-EnsureDir $backupDir
  $base = Split-Path $path -Leaf
  $ts = (Get-Date -Format "yyyyMMdd_HHmmss")
  $dst = Join-Path $backupDir ("{0}.bak_{1}" -f $base,$ts)
  Copy-Item $path $dst -Force
  return $dst
}

function A3-Hash([string]$s){
  $sha = [System.Security.Cryptography.SHA256]::Create()
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($s)
  $h = $sha.ComputeHash($bytes)
  ($h | ForEach-Object { $_.ToString("x2") }) -join ""
}

function A3-ClassifyError([string]$log){
  $x = $log
  if([string]::IsNullOrWhiteSpace($x)){ return @{ kind="none"; summary=""; fingerprint="" } }

  $kind="unknown"; $summary=""
  if($x -match "EADDRINUSE"){ $kind="port"; $summary="Address already in use" }
  elseif($x -match "ModuleBuildError|next-swc-loader|Unexpected token"){ $kind="build"; $summary="Next/TS build error" }
  elseif($x -match "LNK\d+|fatal error C\d+|error C\d+"){ $kind="build"; $summary="C++ build error" }
  elseif($x -match "502 Bad Gateway"){ $kind="proxy"; $summary="Bad gateway (upstream down)" }
  elseif($x -match "404 Not Found"){ $kind="route"; $summary="Route not found" }
  elseif($x -match "SyntaxError|ReferenceError|TypeError"){ $kind="runtime"; $summary="Runtime JS error" }

  # extract a “hot line”
  $hot = ""
  $lines = $x -split "`r?`n"
  foreach($ln in $lines){
    if($ln -match "EADDRINUSE|ModuleBuildError|Unexpected token|LNK\d+|fatal error|error C\d+|502 Bad Gateway|SyntaxError|ReferenceError|TypeError"){
      $hot = $ln.Trim(); break
    }
  }
  if($hot -eq ""){ $hot = ($lines | Select-Object -First 1).Trim() }
  $fp = A3-Hash( ($kind + "|" + $hot).ToLowerInvariant() )

  return @{ kind=$kind; summary=$summary; hot=$hot; fingerprint=$fp }
}

function A3-GetPortOwner([int]$port){
  $rows = @(cmd.exe /c "netstat -ano | findstr LISTENING | findstr :$port" 2>$null)
  foreach($r in $rows){
    if($r -match "\s+(\d+)\s*$"){
      $pIdNum = [int]$Matches[1]
      try{
        $p = Get-Process -Id $pIdNum -ErrorAction Stop
        return @{ pid=$pIdNum; name=$p.ProcessName; raw=$r }
      } catch {
        return @{ pid=$pid; name="(unknown)"; raw=$r }
      }
    }
  }
  return $null
}

function A3-KillPid([int]$pid){
  try{ Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue } catch {}
  try{ cmd.exe /c "taskkill /F /PID $pid >NUL 2>&1" | Out-Null } catch {}
}

function A3-RunCmd([string]$cmd,[string]$cwd,[int]$timeoutSec=600){
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = "cmd.exe"
  $psi.Arguments = "/c $cmd"
  $psi.WorkingDirectory = $cwd
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError  = $true
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow = $true
  $p = New-Object System.Diagnostics.Process
  $p.StartInfo = $psi
  $null = $p.Start()
  if(-not $p.WaitForExit($timeoutSec*1000)){
    try{ $p.Kill() } catch {}
    return @{ exit=124; out=""; err="TIMEOUT" }
  }
  $out = $p.StandardOutput.ReadToEnd()
  $err = $p.StandardError.ReadToEnd()
  return @{ exit=$p.ExitCode; out=$out; err=$err }
}

function A3-PolicyCheckCommand([string]$cmd){
  # deny obvious dangerous ops
  $deny = @(
    "format ", "diskpart", "bcdedit", "reg delete", "rd /s", "del /f /s /q c:\", "rmdir /s", "Remove-Item -Recurse -Force C:\",
    "shutdown", "Restart-Computer", "Stop-Computer"
  )
  $lc = $cmd.ToLowerInvariant()
  foreach($d in $deny){
    if($lc.Contains($d.ToLowerInvariant())){
      return @{ ok=$false; reason=("Denied by policy: " + $d) }
    }
  }
  return @{ ok=$true; reason="" }
}

function A3-ApplyEdits([string]$projectRoot,[array]$edits,[string]$backupDir){
  $changes = @()
  foreach($e in $edits){
    $path = Join-Path $projectRoot ($e.path)
    if(!(Test-Path $path)){ throw "Edit target missing: $path" }
    $src = Get-Content $path -Raw -Encoding UTF8
    $find = [string]$e.find
    $repl = [string]$e.replace
    if([string]::IsNullOrEmpty($find)){ throw "Edit missing find: $($e.path)" }
    if($src -notlike "*$find*"){ throw "Find string not present in $($e.path)" }
    $bak = A3-BackupFile $path $backupDir
    $dst = $src.Replace($find,$repl)
    A3-WriteUtf8NoBom $path $dst
    $changes += @{ type="edit"; path=$e.path; backup=$bak }
  }
  return $changes
}

function A3-WriteFiles([string]$projectRoot,[array]$files,[string]$backupDir){
  $changes=@()
  foreach($f in $files){
    $rel = [string]$f.path
    $path = Join-Path $projectRoot $rel
    $bak = $null
    if(Test-Path $path){ $bak = A3-BackupFile $path $backupDir }
    A3-WriteUtf8NoBom $path ([string]$f.content)
    $changes += @{ type="write"; path=$rel; backup=$bak }
  }
  return $changes
}

function A3-ApplyUnifiedDiffBasic([string]$projectRoot,[array]$patches,[string]$backupDir){
  # Basic unified diff applier (works for simple, clean hunks).
  # If it fails, throws and nothing more is applied.
  $changes=@()
  foreach($p in $patches){
    $rel = [string]$p.path
    $ud  = [string]$p.unified_diff
    if([string]::IsNullOrWhiteSpace($ud)){ continue }
    $path = Join-Path $projectRoot $rel
    if(!(Test-Path $path)){ throw "Patch target missing: $rel" }

    $origLines = @(Get-Content $path -Encoding UTF8)
    $bak = A3-BackupFile $path $backupDir

    $diffLines = $ud -split "`r?`n"
    $out = New-Object System.Collections.Generic.List[string]
    $iOrig = 0
    $i=0
    while($i -lt $diffLines.Count){
      $ln = $diffLines[$i]
      if($ln -match '^@@\s+-(\d+),?(\d*)\s+\+(\d+),?(\d*)\s+@@'){
        $startOld = [int]$Matches[1]
        # copy unchanged up to hunk start (1-based)
        while($iOrig -lt ($startOld-1) -and $iOrig -lt $origLines.Count){
          $out.Add($origLines[$iOrig]); $iOrig++
        }
        $i++
        while($i -lt $diffLines.Count -and $diffLines[$i] -notmatch '^@@'){
          $h = $diffLines[$i]
          if($h.StartsWith(" ")){
            $ctx = $h.Substring(1)
            if($iOrig -ge $origLines.Count -or $origLines[$iOrig] -ne $ctx){
              throw "Patch context mismatch in $rel near: $ctx"
            }
            $out.Add($ctx); $iOrig++
          } elseif($h.StartsWith("-")){
            $del = $h.Substring(1)
            if($iOrig -ge $origLines.Count -or $origLines[$iOrig] -ne $del){
              throw "Patch delete mismatch in $rel near: $del"
            }
            $iOrig++
          } elseif($h.StartsWith("+")){
            $add = $h.Substring(1)
            $out.Add($add)
          } else {
            # ignore
          }
          $i++
        }
        continue
      }
      $i++
    }
    # copy rest
    while($iOrig -lt $origLines.Count){ $out.Add($origLines[$iOrig]); $iOrig++ }

    A3-WriteUtf8NoBom $path ($out -join "`r`n")
    $changes += @{ type="patch"; path=$rel; backup=$bak }
  }
  return $changes
}

function A3-SmokeCurl([string]$url,[string]$resolve=""){
  $cmd = "curl.exe -k -sS -I --max-time 8 $resolve `"$url`""
  cmd.exe /c $cmd
}

function A3-WriteHtmlReport([string]$htmlPath,[object]$state){
  $title = "NIFDU Agent3 Report"
  $json  = (A3-Json $state 50) -replace "&","&amp;" -replace "<","&lt;" -replace ">","&gt;"
  $body = @"
<!doctype html>
<html><head><meta charset="utf-8"/>
<title>$title</title>
<style>
body{font-family:Segoe UI,Arial;margin:24px;background:#0b0f14;color:#e7f1ff}
.card{background:#121a24;border:1px solid #223047;border-radius:14px;padding:16px;margin:12px 0}
pre{white-space:pre-wrap;word-break:break-word;background:#0f1620;padding:12px;border-radius:12px;border:1px solid #223047}
.badge{display:inline-block;padding:3px 10px;border-radius:999px;background:#223047;margin-right:8px}
.ok{background:#103a22}.fail{background:#3a1010}.warn{background:#3a2d10}
</style>
</head><body>
<h2>$title</h2>
<div class="card">
  <div><span class="badge">Project</span> $($state.project.name)</div>
  <div><span class="badge">Root</span> $($state.project.root)</div>
  <div><span class="badge">RunId</span> $($state.run.id)</div>
  <div><span class="badge">Status</span> $($state.run.status)</div>
</div>
<div class="card">
  <h3>State JSON</h3>
  <pre>$json</pre>
</div>
</body></html>
"@
  A3-WriteUtf8NoBom $htmlPath $body
}