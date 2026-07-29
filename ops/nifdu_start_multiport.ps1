$ErrorActionPreference = 'SilentlyContinue'

# Don't spawn duplicates
if (Get-Process nifdu -ErrorAction SilentlyContinue) { exit 0 }

# Ensure log dir exists
New-Item -ItemType Directory -Force 'C:\nifdu\runtime' | Out-Null

$env:NIFDU_HTTP_PORTS = '80,8000'

$ts  = Get-Date -Format 'yyyyMMdd_HHmmss'
$log = Join-Path 'C:\nifdu\runtime' ("boot_multiport_" + $ts + ".log")

# Pre-create log so cmd redirection can't fail silently
'--- NIFDU MULTIPORT BOOT ---' | Out-File -FilePath $log -Encoding ASCII
('Time: ' + (Get-Date))        | Out-File -FilePath $log -Append -Encoding ASCII
('Exe:  ' + 'C:\nifdu\build\Release\nifdu.exe')            | Out-File -FilePath $log -Append -Encoding ASCII
('Ports:' + $env:NIFDU_HTTP_PORTS) | Out-File -FilePath $log -Append -Encoding ASCII
'' | Out-File -FilePath $log -Append -Encoding ASCII

# Start via cmd.exe so stdout+stderr redirection works under SYSTEM reliably
cmd.exe /c ""C:\nifdu\build\Release\nifdu.exe" > "$log" 2>&1"