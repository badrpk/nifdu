$ErrorActionPreference = "Stop"

function Say { param([string]$m,[string]$c="Gray")
    try { $old=[Console]::ForegroundColor; [Console]::ForegroundColor=$c } catch {}
    Write-Host $m
    try { [Console]::ForegroundColor=$old } catch {}
}

# -------------------------------------------------------------------
# 1) STOP NIFDU + CLEAN PORTPROXY
# -------------------------------------------------------------------
Say "`n[1] Killing any running nifdu.exe..." "Yellow"
Get-Process nifdu -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

Say "[2] Removing any netsh portproxy rule on port 80..." "Yellow"
netsh interface portproxy delete v4tov4 listenport=80 listenaddress=0.0.0.0 2>$null | Out-Null

# -------------------------------------------------------------------
# 2) BUILD NIFDU
# -------------------------------------------------------------------
Say "`n[3] Building nifdu.exe (Release)..." "Yellow"
Set-Location "C:\nifdu\build"
cmake --build . --config Release --target nifdu | Out-Host

# -------------------------------------------------------------------
# 3) START NIFDU
# -------------------------------------------------------------------
$exe = "C:\nifdu\build\Release\nifdu.exe"
Say "`n[4] Starting nifdu.exe..." "Yellow"
Start-Process -FilePath $exe -WorkingDirectory "C:\nifdu\build" -WindowStyle Hidden
Start-Sleep -Seconds 5

# -------------------------------------------------------------------
# 4) HEALTH CHECKS
# -------------------------------------------------------------------
Say "`n[5] /health checks..." "Yellow"
Invoke-RestMethod "http://127.0.0.1/health" -TimeoutSec 5 | Format-List
Invoke-RestMethod "http://nifdu.com/health" -TimeoutSec 5 | Format-List

# -------------------------------------------------------------------
# 5) PATCH index.html FOR AGENT 3 (open code + preview tabs)
# -------------------------------------------------------------------
Say "`n[6] Patching index.html for Agent 3..." "Yellow"

$IndexPath = "C:\webroot\nifdu.com\www\index.html"
$Backup = "$IndexPath.bak_agent3fix_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
Copy-Item $IndexPath $Backup -Force
Say "[OK] Backup created -> $Backup" "DarkYellow"

$html = Get-Content $IndexPath -Raw

$inject = @"
<script>
async function interceptAgent3() {
    const promptBox = document.querySelector("#promptInput");
    const prompt = promptBox.value;

    const res = await fetch("/api/chat?dummy=1", {
        method: "POST",
        headers: { "Content-Type": "text/plain" },
        body: prompt
    });

    const json = await res.json();
    localStorage.setItem("NIFDU_CODE_EDIT", json.response || "");

    window.open("/agent3/code.html", "_blank");
    window.open("/agent3/preview.html", "_blank");
}
</script>
"@

if ($html -match "</body>") {
    $patched = $html -replace "</body>", "$inject`r`n</body>"
} else {
    $patched = $html + "`r`n" + $inject
}

$patched | Set-Content $IndexPath -Encoding UTF8
Say "[OK] index.html patched with Agent 3 JS." "Green"

# -------------------------------------------------------------------
# 6) CLEAR EDGE + CHROME HSTS, CACHES, DNS
# -------------------------------------------------------------------
Say "`n[7] Clearing browser HSTS + network caches..." "Yellow"

# Kill browsers
Get-Process chrome -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Get-Process msedge -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

# Paths
$EdgeTS = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Network\TransportSecurity"
$EdgeNW = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Network"
$ChromeTS = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\TransportSecurity"

# Delete caches
Remove-Item $EdgeTS -Force -ErrorAction SilentlyContinue
Remove-Item "$EdgeNW\*.pma" -Force -ErrorAction SilentlyContinue
Remove-Item $ChromeTS -Force -ErrorAction SilentlyContinue

# Flush DNS
Say "[8] Flushing DNS..." "Yellow"
ipconfig /flushdns | Out-Null

# -------------------------------------------------------------------
# 7) OPEN HTTP ONLY VERSION OF NIFDU
# -------------------------------------------------------------------
Say "`n[9] Opening NIFDU HTTP ONLY (no HTTPS upgrade)..." "Green"

Start-Process "msedge.exe" `
    "http://nifdu.com --incognito --no-first-run --disable-features=IsolateOrigins,site-per-process"

Say "`n=== DONE - NIFDU FIXED, AGENT 3 ENABLED, BROWSER CLEANED ===" "Green"
