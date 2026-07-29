param()
$ErrorActionPreference = "Stop"

function Say([string]$t,[string]$c="Gray"){ Write-Host $t -ForegroundColor $c }

$CADDY_EXE = "C:\caddy\caddy.exe"
$CADDYFILE = "C:\caddy\Caddyfile"
$OUT = "C:\caddy\caddy_out.log"
$ERR = "C:\caddy\caddy_err.log"

$HOST = "sophyane.com"

function Backup([string]$path) {
  $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
  $bak = "$path.bak_$stamp"
  Copy-Item $path $bak -Force
  return $bak
}
function Write-Utf8NoBom([string]$path, [string]$content) {
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($path, $content, $utf8NoBom)
}
function Show-Listeners([int[]]$ports) {
  foreach ($p in $ports) {
    $conns = Get-NetTCPConnection -State Listen -LocalPort $p -ErrorAction SilentlyContinue
    if (!$conns) { Say ("PORT {0}: (no listener)" -f $p) "Yellow"; continue }
    foreach ($c in $conns) {
      $proc = Get-Process -Id $c.OwningProcess -ErrorAction SilentlyContinue
      Say ("PORT {0}  PID {1}  {2}" -f $p,$c.OwningProcess,$proc.Path) "Green"
    }
  }
}

if (!(Test-Path $CADDYFILE)) { throw "Missing: $CADDYFILE" }
if (!(Test-Path $CADDY_EXE)) { throw "Missing: $CADDY_EXE" }

Say "`n=== FIX CADDY: DUPLICATE MATCHERS (@ws/@api) + START 80/443 ===`n" "Yellow"

# 1) Backup
$bak = Backup $CADDYFILE
Say ("[1/6] Backup -> " + $bak) "DarkGray"

# 2) Read & isolate sophyane block
$cf = Get-Content $CADDYFILE -Raw

# NOTE: this supports either "sophyane.com, www.sophyane.com {" or "www.sophyane.com, sophyane.com {"
$siteRx = '(?ms)(^\s*(?:sophyane\.com\s*,\s*www\.sophyane\.com|www\.sophyane\.com\s*,\s*sophyane\.com)\s*\{\s*)(.*?)(^\s*\}\s*)$'
$m = [regex]::Match($cf, $siteRx)
if (!$m.Success) {
  throw "Could not find sophyane.com site block in Caddyfile. Ensure you have a site label line for sophyane.com + www.sophyane.com."
}

$head = $m.Groups[1].Value
$body = $m.Groups[2].Value
$tail = $m.Groups[3].Value

# 3) Rename duplicate matchers inside the block:
#    - Keep the FIRST '@ws' as '@ws'
#    - Rename subsequent '@ws' to '@ws_2', '@ws_3'...
#    - Same for '@api'
#    - Also update 'handle @ws' and 'handle @api' references accordingly (line-by-line safe rename)
$lines = $body -split "(`r`n|`n|`r)"
$wsCount = 0
$apiCount = 0

for ($i=0; $i -lt $lines.Length; $i++) {
  $ln = $lines[$i]

  # Matcher definitions: "@ws path /socket*"
  if ($ln -match '^\s*@ws\s+') {
    $wsCount++
    if ($wsCount -ge 2) {
      $new = "@ws_$wsCount"
      $lines[$i] = ($ln -replace '(@ws)(\s+)', ($new + '$2'))
    }
    continue
  }

  # handle blocks: "handle @ws {"
  if ($ln -match '^\s*handle\s+@ws(\s*\{|\s*$)') {
    # This handle corresponds to the most recent @ws definition count we are in.
    # If we already renamed the matcher definition, rename this handle too.
    if ($wsCount -ge 2) {
      $lines[$i] = ($ln -replace 'handle\s+@ws\b', ("handle @ws_$wsCount"))
    }
    continue
  }

  # Matcher definitions: "@api path /api/*"
  if ($ln -match '^\s*@api\s+') {
    $apiCount++
    if ($apiCount -ge 2) {
      $new = "@api_$apiCount"
      $lines[$i] = ($ln -replace '(@api)(\s+)', ($new + '$2'))
    }
    continue
  }

  # handle blocks: "handle @api {"
  if ($ln -match '^\s*handle\s+@api(\s*\{|\s*$)') {
    if ($apiCount -ge 2) {
      $lines[$i] = ($ln -replace 'handle\s+@api\b', ("handle @api_$apiCount"))
    }
    continue
  }
}

$body2 = ($lines -join "`r`n")

# 4) Write back updated site block (no other sites touched)
$patched = $cf.Substring(0, $m.Index) + $head + $body2 + $tail + $cf.Substring($m.Index + $m.Length)
Write-Utf8NoBom $CADDYFILE $patched

Say ("[2/6] Patched Caddyfile. Found @ws={0}, @api={1} (duplicates renamed, not deleted)." -f $wsCount,$apiCount) "Green"

# 5) Start Caddy and capture logs
Say "`n[3/6] Restarting Caddy..." "Cyan"
Get-Process caddy -EA SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 250
Remove-Item $OUT,$ERR -Force -ErrorAction SilentlyContinue

Start-Process -FilePath $CADDY_EXE `
  -ArgumentList @("run","--config",$CADDYFILE,"--adapter","caddyfile") `
  -RedirectStandardOutput $OUT `
  -RedirectStandardError  $ERR `
  -WindowStyle Hidden

Start-Sleep -Milliseconds 1200

Say "`n--- Caddy ERR (tail) ---" "DarkCyan"
Get-Content $ERR -Tail 120 -ErrorAction SilentlyContinue
Say "`n--- Caddy OUT (tail) ---" "DarkCyan"
Get-Content $OUT -Tail 80 -ErrorAction SilentlyContinue

# 6) Verify listeners + smoke tests (LOCAL)
Say "`n[4/6] Port listeners:" "Cyan"
Show-Listeners @(80,443)

$con80  = Get-NetTCPConnection -State Listen -LocalPort 80  -ErrorAction SilentlyContinue
$con443 = Get-NetTCPConnection -State Listen -LocalPort 443 -ErrorAction SilentlyContinue
if (!$con80 -or !$con443) {
  Say "`n[FAIL] Caddy still not listening on 80/443. The error above is the reason." "Red"
  throw "Caddy did not bind 80/443."
}

Say "`n[5/6] Local HTTPS smoke (bypass router):" "Cyan"
curl.exe -k -I "https://127.0.0.1/" -H "Host: $HOST" --max-time 4
curl.exe -k -I "https://127.0.0.1/api/health" -H "Host: $HOST" --max-time 4

Say "`n[6/6] If the above works, your local stack is healthy. If you want PUBLIC access from internet, test from mobile data (not same LAN)." "Yellow"
Say "`nDONE." "Green"
