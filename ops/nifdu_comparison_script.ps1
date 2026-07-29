param()

$NifduStatus = @{
    CoreApiOnline = $true # Assumed based on NIFDU itself running
    VibeCodingLoop = $true
    SelfTestFixLoop = $true
    WebProbeRuntime = $true
    OpsAgentFactory = $true
    DeploymentPipeline = $true
    MultiStack = $true
    PatchingEdits = $false # NIFDU sends full files, not patches
    IntegratedGit = $true # Git tooling available
    LiveUIPreview = $false # NIFDU starts server, doesn't embed UI
}

$Competitors = @(
    @{ Name = "Replit AI (Ghostwriter)"; Focus = "Integrated Dev/Debug"; VibeCodingLoop = $true; SelfTestFixLoop = $true; WebProbeRuntime = $true; OpsAgentFactory = $false; DeploymentPipeline = $true; MultiStack = $true; PatchingEdits = $true; IntegratedGit = $true; LiveUIPreview = $true },
    @{ Name = "GitHub Copilot Workspace"; Focus = "Contextual Code Generation"; VibeCodingLoop = $false; SelfTestFixLoop = $true; WebProbeRuntime = $false; OpsAgentFactory = $false; DeploymentPipeline = $false; MultiStack = $true; PatchingEdits = $true; IntegratedGit = $true; LiveUIPreview = $false },
    @{ Name = "Cursor / Cody AI"; Focus = "Local Code Editing & Chat"; VibeCodingLoop = $false; SelfTestFixLoop = $false; WebProbeRuntime = $false; OpsAgentFactory = $false; DeploymentPipeline = $false; MultiStack = $true; PatchingEdits = $true; IntegratedGit = $true; LiveUIPreview = $false }
)

$Output = @()
$Output += "=== NIFDU VIBE CODING SYSTEM: CAPABILITY SCORECARD ==="
$Output += "Report Date: $(Get-Date)"
$Output += "Report Focus: Automated Development & Self-Correction"
$Output += "--------------------------------------------------------"

# Function to render capability as emoji
function Get-Emoji($Status) {
    if ($Status -eq $true) { return "✅" }
    if ($Status -eq $false) { return "❌" }
    return "❓"
}

$Header = "Capability`t`tNIFDU`tReplit AI`tCopilot W/S"
$Output += $Header
$Output += "--------------------------------------------------------"

$Output += "1. Full Auto-Loop (Generate + Build + Fix)`t{0}`t{1}`t{2}" -f (Get-Emoji $NifduStatus.VibeCodingLoop), (Get-Emoji $Competitors[0].VibeCodingLoop), (Get-Emoji $Competitors[1].VibeCodingLoop)
$Output += "2. Self-Test/Debug Loop (Fixes Test Failures)`t{0}`t{1}`t{2}" -f (Get-Emoji $NifduStatus.SelfTestFixLoop), (Get-Emoji $Competitors[0].SelfTestFixLoop), (Get-Emoji $Competitors[1].SelfTestFixLoop)
$Output += "3. Runtime Verification (Web Probe/Health Check)`t{0}`t{1}`t{2}" -f (Get-Emoji $NifduStatus.WebProbeRuntime), (Get-Emoji $Competitors[0].WebProbeRuntime), (Get-Emoji $Competitors[1].WebProbeRuntime)
$Output += "4. Ops Agent Factory (Builds Automation Tools)`t{0}`t{1}`t{2}" -f (Get-Emoji $NifduStatus.OpsAgentFactory), (Get-Emoji $Competitors[0].OpsAgentFactory), (Get-Emoji $Competitors[1].OpsAgentFactory)
$Output += "5. Deployment Pipeline (Deploy to Webroot)`t{0}`t{1}`t{2}" -f (Get-Emoji $NifduStatus.DeploymentPipeline), (Get-Emoji $Competitors[0].DeploymentPipeline), (Get-Emoji $Competitors[1].DeploymentPipeline)
$Output += "6. Integrated Version Control (Git)`t{0}`t{1}`t{2}`t{3}" -f (Get-Emoji $NifduStatus.IntegratedGit), (Get-Emoji $Competitors[0].IntegratedGit), (Get-Emoji $Competitors[1].IntegratedGit)
$Output += "7. Granular Patching (Sends Small Code Diffs)`t{0}`t{1}`t{2}`t{3}" -f (Get-Emoji $NifduStatus.PatchingEdits), (Get-Emoji $Competitors[0].PatchingEdits), (Get-Emoji $Competitors[1].PatchingEdits)
$Output += "8. Integrated Live UI Preview`t{0}`t{1}`t{2}`t{3}" -f (Get-Emoji $NifduStatus.LiveUIPreview), (Get-Emoji $Competitors[0].LiveUIPreview), (Get-Emoji $Competitors[1].LiveUIPreview)

$Output += "`n--------------------------------------------------------"
$Output += "NIFDU Focus: Extreme Automation and Deployment Convergence (CI/CD as the primary loop)."

$Output -join "`n" | Out-File -FilePath "$OpsDir\nifdu_comparison_scorecard_raw.txt" -Encoding UTF8
