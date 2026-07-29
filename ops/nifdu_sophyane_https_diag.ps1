param()
$ErrorActionPreference = "Continue"

function Say($t,$c="Gray"){Write-Host $t -ForegroundColor $c}

$domain = "sophyane.com"

Say "`n=== SOPHYANE HTTPS DIAG (LOCAL vs PUBLIC) ===`n" "Yellow"

# 1) DNS resolution
Say "[1] DNS resolution" "Cyan"
try {
  $dns = Resolve-DnsName $domain -Type A -ErrorAction Stop
  $ips = $dns | Where-Object {$_.IPAddress} | Select-Object -ExpandProperty IPAddress
  Say ("Resolved {0} -> {1}" -f $domain, ($ips -join ", ")) "Green"
} catch {
  Say ("DNS failed: " + $_.Exception.Message) "Red"
  $ips = @()
}

# 2) Who is listening locally on 80/443?
Say "`n[2] Local listeners (80/443)" "Cyan"
foreach($p in 80,443){
  $conns = Get-NetTCPConnection -State Listen -LocalPort $p -ErrorAction SilentlyContinue
  if(!$conns){ Say ("PORT {0}: (no listener)" -f $p) "Yellow"; continue }
  foreach($c in $conns){
    $proc = Get-Process -Id $c.OwningProcess -ErrorAction SilentlyContinue
    Say ("PORT {0} PID {1} {2}" -f $p,$c.OwningProcess,$proc.Path) "Green"
  }
}

# 3) Can we connect to local 127.0.0.1:443 (this bypasses router/NAT)?
Say "`n[3] Local HTTPS tests (bypass router): https://127.0.0.1 with Host header" "Cyan"
Say "Running: curl -k -I https://127.0.0.1/ -H Host:$domain" "DarkGray"
curl.exe -k -I "https://127.0.0.1/" -H "Host: $domain" --max-time 4

Say "`nRunning: curl -k -I https://127.0.0.1/api/health -H Host:$domain" "DarkGray"
curl.exe -k -I "https://127.0.0.1/api/health" -H "Host: $domain" --max-time 4

# 4) Can we connect to the PUBLIC IP:443 from this LAN? (this is where NAT loopback often fails)
Say "`n[4] Public TCP tests (may fail if NAT loopback is OFF)" "Cyan"
if($ips.Count -gt 0){
  foreach($ip in $ips){
    $r = Test-NetConnection -ComputerName $ip -Port 443 -WarningAction SilentlyContinue
    Say ("Public {0}:443 TcpTestSucceeded = {1}" -f $ip,$r.TcpTestSucceeded) ($(if($r.TcpTestSucceeded){"Green"}else{"Yellow"}))
  }
} else {
  Say "Skipping public test: no DNS IPs." "Yellow"
}

# 5) If local works but public fails, tell the truth
Say "`n=== INTERPRETATION ===" "Yellow"
Say "If step [3] works but step [4] fails -> your router likely blocks NAT loopback. The stack is OK locally." "Gray"
Say "If step [3] fails AND step [2] shows no listener on 443 -> Caddy is not running/binding 443 (config/startup issue)." "Gray"
Say "If step [2] shows 443 is listening but step [3] fails -> TLS/cert mismatch or Caddy not serving that host." "Gray"

Say "`nDONE." "Green"
