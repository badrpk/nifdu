param(
  [string]$Repo      = "C:\nifdu",
  [string]$SrcRoot   = "C:\nifdu\src",
  [string]$BuildDir  = "C:\nifdu\build",
  [ValidateSet("Debug","Release")] [string]$Cfg = "Release",
  [string]$Restart   = "C:\nifdu\ops\nifdu_restart_safe_wait.ps1",
  [string]$Pattern   = "LISTENING (PROOF)"
)

$ErrorActionPreference="Stop"
function Say($t,$c="Gray"){ try{Write-Host $t -ForegroundColor $c}catch{Write-Host $t} }
function Backup($p){ $b="$p.bak_$(Get-Date -Format yyyyMMdd_HHmmss)"; Copy-Item -LiteralPath $p $b -Force; return $b }
function WriteUtf8NoBom($p,$t){ [IO.File]::WriteAllText($p,$t,(New-Object System.Text.UTF8Encoding($false))) }

Say "`n=== PATCH: ATOMIC LOGGING (PS 5.1 SAFE) ===`n" Yellow
foreach($p in @($Repo,$SrcRoot,$BuildDir,$Restart)){ if(!(Test-Path $p)){ throw "Missing: $p" } }

Say "[1] Scanning *.cpp for: $Pattern" Cyan
$cpps  = Get-ChildItem -LiteralPath $SrcRoot -Recurse -File -Filter *.cpp -EA Stop
$hits  = $cpps | Select-String -Pattern $Pattern -EA SilentlyContinue
if(!$hits){
  Say "No matches found under $SrcRoot for '$Pattern'." DarkYellow
  Say "Nothing to patch." DarkYellow
  exit 0
}

$files = $hits | Select-Object -ExpandProperty Path -Unique
Say ("Found " + $files.Count + " file(s) to patch.") Green
$files | ForEach-Object { Say ("  - " + $_) DarkGray }

$loggerBlock = @"
namespace {
  static std::mutex g_nifdu_log_mx;

  template<typename... Ts>
  inline void NifduLogLine(Ts&&... parts) {
    std::lock_guard<std::mutex> lk(g_nifdu_log_mx);
    std::ostringstream ss;
    (ss << ... << parts);
    std::cerr << ss.str() << "\n";
  }
}
"@

$patched = 0
foreach($f in $files){
  Say "`n--- Patching: $f" Yellow
  $src    = Get-Content -LiteralPath $f -Raw -Encoding UTF8
  $before = $src
  $did    = $false

  # Avoid \b or any escape sequences in PS strings
  $hasLogger = ($src -match 'NifduLogLine\s*\(') -or ($src -match 'g_nifdu_log_mx')

  if(-not $hasLogger){
    # Ensure includes exist (only add if missing)
    if($src -notmatch '^\s*#include\s*<mutex>\s*$'){
      $m = [regex]::Matches($src,'^\s*#include[^\r\n]*\s*$',[Text.RegularExpressions.RegexOptions]::Multiline)
      if($m.Count -gt 0){
        $last = $m[$m.Count-1]
        $src = $src.Insert($last.Index + $last.Length, "`r`n#include <mutex>")
        $did = $true
      }
    }
    if($src -notmatch '^\s*#include\s*<sstream>\s*$'){
      $m = [regex]::Matches($src,'^\s*#include[^\r\n]*\s*$',[Text.RegularExpressions.RegexOptions]::Multiline)
      if($m.Count -gt 0){
        $last = $m[$m.Count-1]
        $src = $src.Insert($last.Index + $last.Length, "`r`n#include <sstream>")
        $did = $true
      }
    }

    # Insert logger block after last include
    $m2 = [regex]::Matches($src,'^\s*#include[^\r\n]*\s*$',[Text.RegularExpressions.RegexOptions]::Multiline)
    if($m2.Count -gt 0){
      $last2 = $m2[$m2.Count-1]
      $src = $src.Insert($last2.Index + $last2.Length, "`r`n`r`n" + $loggerBlock.TrimEnd() + "`r`n")
      $did = $true
      Say "  + Injected NifduLogLine() + mutex" Green
    } else {
      Say "  ! No #include lines found; skipping logger injection" DarkYellow
    }
  } else {
    Say "  = Logger already present" DarkGray
  }

  # Replace LISTENING line: capture RHS expression after the fixed prefix, until ';'
  # Example expected:
  # std::cerr << "[NIFDU::http80] LISTENING (PROOF) on 127.0.0.1:" << port << std::endl;
  $rx  = 'std::cerr\s*<<\s*"\[NIFDU::http80\]\s*LISTENING\s*\(PROOF\)\s*on\s*127\.0\.0\.1:"\s*<<\s*(.+?)\s*;\s*'
  $rep = 'NifduLogLine("[NIFDU::http80] LISTENING (PROOF) on 127.0.0.1:", $1);'

  $src2 = [regex]::Replace($src, $rx, $rep)
  if($src2 -ne $src){
    $src = $src2
    $did = $true
    Say "  + Rewrote LISTENING -> NifduLogLine(...)" Green
  } else {
    Say "  = LISTENING pattern not matched (different log format?)" DarkYellow
  }

  if($did -and $src -ne $before){
    Say ("  Backup -> " + (Backup $f)) DarkGray
    WriteUtf8NoBom $f $src
    $patched++
    Say "  ✔ Patched" Green
  } else {
    Say "  (No changes written)" DarkGray
  }
}

Say "`nPatched files: $patched / $($files.Count)" Yellow

Say "`n=== BUILD ($Cfg) ===`n" Yellow
Push-Location $Repo
cmake -S . -B $BuildDir | Out-Host
cmake --build $BuildDir --config $Cfg | Out-Host
Pop-Location

Say "`n=== RESTART (safe swap) ===`n" Yellow
powershell -NoProfile -ExecutionPolicy Bypass -File $Restart

Say "`nDONE. LISTENING logs should no longer interleave." Green