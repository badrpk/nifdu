param(
  [string]$JobsDir   = "C:\nifdu\runtime\av_jobs",
  [string]$DoneDir   = "C:\nifdu\runtime\av_jobs_done",

  [string]$MediaRoot = "C:\webroot\nifdu.com\www",
  [string]$MediaSub  = "\media\generated",

  [string]$TemplatesDir = "C:\nifdu\av\templates",

  [string]$FfmpegExe = "ffmpeg.exe",
  [string]$WavExe    = ""   # optional
)

$ErrorActionPreference="Continue"
function Say($t,$c="Gray"){ try{Write-Host $t -ForegroundColor $c}catch{Write-Host $t} }
function Ensure-Dir($p){ New-Item -ItemType Directory -Force -Path $p | Out-Null }

Ensure-Dir $JobsDir
Ensure-Dir $DoneDir
$mediaOut = Join-Path $MediaRoot ($MediaSub.TrimStart('\'))
Ensure-Dir $mediaOut

# Find ffmpeg
$ff = (Get-Command $FfmpegExe -EA SilentlyContinue).Source
if(-not $ff){
  $candidates = @(
    "C:\ffmpeg\bin\ffmpeg.exe",
    "C:\ProgramData\chocolatey\bin\ffmpeg.exe",
    "C:\tools\ffmpeg\bin\ffmpeg.exe"
  )
  $ff = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
}
if(-not $ff){ throw "ffmpeg not found. Put ffmpeg.exe in PATH or set -FfmpegExe full path." }

# Recover stale claims (if watcher died mid-job)
$now = Get-Date
Get-ChildItem -LiteralPath $JobsDir -Filter *.working -File -EA SilentlyContinue |
  Where-Object { ($now - $_.LastWriteTime).TotalMinutes -ge 3 } |
  ForEach-Object {
    try{
      $back = $_.FullName -replace '\.working$',''
      Move-Item -LiteralPath $_.FullName -Destination $back -Force
      Say ("RECOVER: " + $_.Name + " -> " + (Split-Path $back -Leaf)) DarkYellow
    } catch {}
  }

Say "`n=== NIFDU AV WATCHER (HARD-STABLE / EXACTLY-ONCE) ===" Yellow
Say "JobsDir:      $JobsDir" DarkGray
Say "DoneDir:      $DoneDir" DarkGray
Say "MediaOut:     $mediaOut" DarkGray
Say "TemplatesDir: $TemplatesDir" DarkGray
Say "FFmpeg:       $ff" DarkGray
if($WavExe){ Say "WavExe:       $WavExe" DarkGray } else { Say "WavExe:       (not set)" DarkYellow }
Say "`nWatching... (Ctrl+C to stop)`n" Yellow

while($true){

  # only real triggers (NOT .working)
  $jobs = Get-ChildItem -LiteralPath $JobsDir -Filter *.json -File -EA SilentlyContinue |
    Where-Object { $_.Name -notmatch '\.working$' } |
    Sort-Object LastWriteTime

  foreach($j0 in $jobs){

    # claim exactly-once: rename -> .working
    $claimed = ($j0.FullName + ".working")
    if(Test-Path $claimed){ continue }

    try{
      Move-Item -LiteralPath $j0.FullName -Destination $claimed -Force
    } catch {
      continue
    }

    $j = Get-Item -LiteralPath $claimed -EA SilentlyContinue
    if(-not $j){ continue }

    try{
      $raw = Get-Content $j.FullName -Raw -Encoding UTF8
      $job = $raw | ConvertFrom-Json

      $jobId = [string]$job.job_id
      if([string]::IsNullOrWhiteSpace($jobId)){ $jobId = [IO.Path]::GetFileNameWithoutExtension(($j.Name -replace '\.working$','')) }

      $mode = [string]$job.mode
      if([string]::IsNullOrWhiteSpace($mode)){ $mode = "text" }

      $prompt = [string]$job.prompt
      if([string]::IsNullOrWhiteSpace($prompt)){ $prompt = [string]$job.text }
      if([string]::IsNullOrWhiteSpace($prompt)){ $prompt = "NIFDU AV" }

      $outMp4 = [string]$job.out_disk_path
      if([string]::IsNullOrWhiteSpace($outMp4)){
        $outMp4 = Join-Path $mediaOut ("$jobId.mp4")
      }

      $outDir = Split-Path $outMp4 -Parent
      if(!(Test-Path $outDir)){ Ensure-Dir $outDir }

      $tmp = Join-Path $env:TEMP ("nifdu_av_" + $jobId + ".log")
      Say ("JOB: " + ($j.Name -replace '\.working$','') + "  mode=" + $mode + "  id=" + $jobId) Cyan

      if($mode -ieq "wav"){
        if($WavExe -and (Test-Path $WavExe)){
          $outWav = [IO.Path]::ChangeExtension($outMp4, ".wav")
          Say ("WAV: calling " + $WavExe + " -> " + $outWav) DarkGray
          & $WavExe --text "$prompt" --out "$outWav" *> $tmp

          if(Test-Path $outWav){
            & $ff -y -f lavfi -i "color=c=black:s=1280x720:d=4" -vf "drawtext=text='WAV READY':x=(w-text_w)/2:y=(h-text_h)/2:fontsize=48:fontcolor=white" -c:v libx264 -pix_fmt yuv420p "$outMp4" *> $tmp
          } else {
            & $ff -y -f lavfi -i "color=c=black:s=1280x720:d=4" -vf "drawtext=text='WAV FAIL':x=(w-text_w)/2:y=(h-text_h)/2:fontsize=48:fontcolor=white" -c:v libx264 -pix_fmt yuv420p "$outMp4" *> $tmp
          }
        } else {
          & $ff -y -f lavfi -i "color=c=black:s=1280x720:d=4" -vf "drawtext=text='$prompt':x=(w-text_w)/2:y=(h-text_h)/2:fontsize=48:fontcolor=white" -c:v libx264 -pix_fmt yuv420p "$outMp4" *> $tmp
        }
      }
      elseif($mode -ieq "template_video"){
        $tpl = $null
        if(Test-Path $TemplatesDir){
          $tpl = Get-ChildItem -LiteralPath $TemplatesDir -Filter *.mp4 -File -EA SilentlyContinue | Select-Object -First 1
        }
        if($tpl){
          Say ("TEMPLATE: " + $tpl.FullName) DarkGray
          & $ff -y -i "$($tpl.FullName)" -vf "drawtext=text='$prompt':x=(w-text_w)/2:y=h-(text_h*2):fontsize=42:fontcolor=white:box=1:boxcolor=black@0.5" -c:v libx264 -pix_fmt yuv420p "$outMp4" *> $tmp
        } else {
          & $ff -y -f lavfi -i "color=c=black:s=1280x720:d=4" -vf "drawtext=text='NO TEMPLATE':x=(w-text_w)/2:y=(h-text_h)/2:fontsize=48:fontcolor=white" -c:v libx264 -pix_fmt yuv420p "$outMp4" *> $tmp
        }
      }
      elseif($mode -ieq "scene"){
        & $ff -y -f lavfi -i "color=c=black:s=1280x720:d=4" -vf "drawtext=text='$prompt':x=(w-text_w)/2:y=(h-text_h)/2:fontsize=48:fontcolor=white,drawbox=x=20+240*t:y=600:w=180:h=50:color=white@0.8:t=fill" -c:v libx264 -pix_fmt yuv420p "$outMp4" *> $tmp
      }
      else {
        & $ff -y -f lavfi -i "color=c=black:s=1280x720:d=4" -vf "drawtext=text='$prompt':x=(w-text_w)/2:y=(h-text_h)/2:fontsize=48:fontcolor=white" -c:v libx264 -pix_fmt yuv420p "$outMp4" *> $tmp
      }

      if(!(Test-Path $outMp4)){ throw "ffmpeg did not produce output file." }

      $doneObj = @{
        job_id = $jobId
        status = "done"
        mode   = $mode
        out_disk_path  = $outMp4
        out_public_url = ("/media/generated/" + [IO.Path]::GetFileName($outMp4))
        ts_done = (Get-Date).ToString("o")
      } | ConvertTo-Json -Depth 8

      $donePath = Join-Path $DoneDir ($jobId + ".done.json")
      [IO.File]::WriteAllText($donePath, $doneObj, (New-Object System.Text.UTF8Encoding($false)))

      # archive claimed trigger (strip .working)
      $archName = ($j.Name -replace '\.working$','')
      Move-Item -LiteralPath $j.FullName -Destination (Join-Path $DoneDir $archName) -Force

      Say ("DONE: " + $jobId) Green
    }
    catch{
      Say ("FAIL: " + ($j.Name -replace '\.working$','') + " -> " + $_.Exception.Message) Red
      try{
        $id = [IO.Path]::GetFileNameWithoutExtension(($j.Name -replace '\.working$',''))
        $failObj = @{
          job_id = $id
          status = "fail"
          error  = $_.Exception.Message
          ts_fail = (Get-Date).ToString("o")
        } | ConvertTo-Json -Depth 6

        $failPath = Join-Path $DoneDir ($id + ".fail.json")
        [IO.File]::WriteAllText($failPath, $failObj, (New-Object System.Text.UTF8Encoding($false)))

        $archName = ($j.Name -replace '\.working$','')
        Move-Item -LiteralPath $j.FullName -Destination (Join-Path $DoneDir $archName) -Force
      } catch {}
    }

  }

  Start-Sleep -Milliseconds 200
}