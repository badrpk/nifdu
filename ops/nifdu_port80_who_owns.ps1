$ErrorActionPreference = "Stop"

Write-Host "`n=== NIFDU PORT 80 WHO-OWNS-DIAG ===`n" -ForegroundColor Yellow

# Collect listeners on port 80
try {
    $listeners = Get-NetTCPConnection -LocalPort 80 -State Listen -ErrorAction Stop
} catch {
    Write-Host "Get-NetTCPConnection failed, falling back to netstat ..." -ForegroundColor DarkYellow
    $listeners = @()
}

if (-not $listeners -or $listeners.Count -eq 0) {
    # fallback: netstat
    $netstat = netstat -ano | Select-String "LISTENING" | Select-String ":80 "
    $tmp = @()
    foreach ($line in $netstat) {
        $parts = $line.ToString().Split(" ", [System.StringSplitOptions]::RemoveEmptyEntries)
        if ($parts.Count -lt 5) { continue }
        $procId = [int]$parts[-1]
        $addr   = $parts[1]
        $tmp += [PSCustomObject]@{
            LocalAddress  = $addr.Split(":")[0]
            LocalPort     = 80
            State         = "Listen"
            OwningProcess = $procId
        }
    }
    $listeners = $tmp
}

if (-not $listeners -or $listeners.Count -eq 0) {
    Write-Host "No one is currently listening on port 80." -ForegroundColor Green
    return
}

$result = @()

foreach ($l in $listeners) {
    $procId = $l.OwningProcess
    $proc   = $null
    $pname  = "<unknown>"
    $path   = "<unknown>"

    try {
        $proc  = Get-Process -Id $procId -ErrorAction Stop
        $pname = $proc.ProcessName
        try {
            $path = $proc.Path
        } catch {
            $path = "<no path available>"
        }
    } catch {}

    # Find Windows services running under this PID (if any)
    $services = Get-WmiObject -Class Win32_Service -Filter "ProcessId = $procId" -ErrorAction SilentlyContinue
    $svcNames = $services | Select-Object -ExpandProperty Name        -ErrorAction SilentlyContinue
    $svcDisp  = $services | Select-Object -ExpandProperty DisplayName -ErrorAction SilentlyContinue

    $result += [PSCustomObject]@{
        LocalAddress       = $l.LocalAddress
        LocalPort          = $l.LocalPort
        State              = $l.State
        PID                = $procId
        ProcessName        = $pname
        ProcessPath        = $path
        ServiceNames       = ($svcNames -join ", ")
        ServiceDisplayName = ($svcDisp -join ", ")
    }
}

$result | Format-Table -AutoSize

Write-Host "`nTip: Any row where ProcessName is NOT 'nifdu' is a candidate to disable/stop." -ForegroundColor Cyan
