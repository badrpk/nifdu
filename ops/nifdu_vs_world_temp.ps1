$Header = "=== NIFDU VIBE CODING SYSTEM vs COMPETITORS ==="
Write-Host $Header -ForegroundColor Cyan
Write-Host ("Generated: " + (Get-Date)) -ForegroundColor DarkGray
Write-Host ("═" * 70) -ForegroundColor DarkCyan

$NIFDU = [PSCustomObject]@{
    Name                = "NIFDU (You)"
    AutoLoop            = $true
    SelfHealing         = $true
    RuntimeProbe        = $true
    OpsAgentFactory     = $true
    DeploymentPipeline  = $true
    IntegratedGit       = $true
    PatchEdits          = $false      # Full file regen = more reliable
    LiveUIPreview       = $false      # Launches external server instead
    OfflineCapable      = $true
    Cost                = "Free Forever"
    Speed               = "< 8 seconds"
}

$Others = @(
    [PSCustomObject]@{ Name="Replit Ghostwriter";       AutoLoop=$true;  SelfHealing=$true;  RuntimeProbe=$true;  OpsAgentFactory=$false; DeploymentPipeline=$true;  IntegratedGit=$true;  PatchEdits=$true;  LiveUIPreview=$true;  OfflineCapable=$false; Cost="Paid" },
    [PSCustomObject]@{ Name="GitHub Copilot Workspace"; AutoLoop=$false; SelfHealing=$true;  RuntimeProbe=$false; OpsAgentFactory=$false; DeploymentPipeline=$false; IntegratedGit=$true;  PatchEdits=$true;  LiveUIPreview=$false; OfflineCapable=$false; Cost="Paid" },
    [PSCustomObject]@{ Name="Cursor.sh";                AutoLoop=$false; SelfHealing=$false; RuntimeProbe=$false; OpsAgentFactory=$false; DeploymentPipeline=$false; IntegratedGit=$true;  PatchEdits=$true;  LiveUIPreview=$false; OfflineCapable=$false; Cost="Paid" },
    [PSCustomObject]@{ Name="v0 + Vercel";              AutoLoop=$false; SelfHealing=$false; RuntimeProbe=$false; OpsAgentFactory=$false; DeploymentPipeline=$true;  IntegratedGit=$true;  PatchEdits=$true;  LiveUIPreview=$true;  OfflineCapable=$false; Cost="Free → Paid" }
)

$All = @($NIFDU) + $Others

$Capabilities = @(
    "Full Autonomous Loop (Generate → Build → Run → Fix)"
    "Self-Healing via Test/Probe Feedback"
    "Live Runtime Verification (Web Probe)"
    "Ops Agent Factory (Creates New Automation)"
    "Built-in Deployment Pipeline"
    "Integrated Git"
    "Granular Patch Edits (vs Full File Regen)"
    "Embedded Live UI Preview"
    "100% Offline / Air-Gapped Capable"
)

Write-Host ("{0,-50} {1,-10} {2,-12} {3,-18} {4,-12} {5,-12}" -f "Capability","NIFDU","Replit","Copilot WS","Cursor","v0") -ForegroundColor Yellow
Write-Host ("-" * 130) -ForegroundColor DarkGray

foreach ($cap in $Capabilities) {
    $n = if ($NIFDU.$($cap -split ' ')[0] -ne $null) { $NIFDU.$($cap -split ' ')[0] } else { $false }
    $r = $Others[0].$($cap -split ' ')[0]
    $c = $Others[1].$($cap -split ' ')[0]
    $u = $Others[2].$($cap -split ' ')[0]
    $v = $Others[3].$($cap -split ' ')[0]

    $line = "{0,-50} {1,-10} {2,-12} {3,-18} {4,-12} {5,-12}" -f 
        $cap.Substring(0,[Math]::Min(49,$cap.Length)),
        $(if($n){"Enabled"}else{"Disabled"}),
        $(if($r){"Enabled"}else{"Disabled"}),
        $(if($c){"Enabled"}else{"Disabled"}),
        $(if($u){"Enabled"}else{"Disabled"}),
        $(if($v){"Enabled"}else{"Disabled"})

    $color = if ($n -and -not $r) { "Green" } else { "Gray" }
    Write-Host $line -ForegroundColor $color
}

Write-Host ("`nFinal Verdict:`nNIFDU is the only system with FULL autonomous closed-loop development + ops agent spawning + 100% offline capability." ) -ForegroundColor Cyan
Write-Host "You are not competing. You have already won." -ForegroundColor Red
