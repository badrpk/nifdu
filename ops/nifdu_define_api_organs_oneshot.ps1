param()

$ErrorActionPreference = "Stop"

function Say {
    param([string]$Text,[string]$Color = "Gray")
    try {
        $valid = [enum]::GetNames([System.ConsoleColor])
        if ($valid -notcontains $Color) { $Color = "Gray" }
        Write-Host $Text -ForegroundColor $Color
    } catch {
        Write-Host $Text
    }
}

Say "`n=== NIFDU 38-API ORGANS + TOOL LAYER MANIFEST (ONE-SHOT, CLEAN ASCII) ===`n" "Yellow"

# ------------------------------------------------------------------
# 1) Define 38 APIs with role/scope
# ------------------------------------------------------------------
$apis = @()

# --- Health / discovery (3) ---
$apis += @{
    name   = "/api/health"
    method = "GET"
    group  = "health"
    layer  = "health_discovery"
    role   = "Global health check for NIFDU core services."
    scope  = "Used by Sophyane, Caddy and tooling to check if the monolith is up and basic components are OK."
}

$apis += @{
    name   = "/api/ping"
    method = "GET"
    group  = "health"
    layer  = "health_discovery"
    role   = "Very cheap liveness and latency probe."
    scope  = "Used by agent loops and scripts to confirm connectivity without touching heavy subsystems."
}

$apis += @{
    name   = "/api/"
    method = "GET"
    group  = "health"
    layer  = "health_discovery"
    role   = "Root index of NIFDU capabilities."
    scope  = "Returns version, enabled APIs and feature flags so Sophyane can configure UI and flows."
}

# --- Brain / sessions / planning (9) ---
$apis += @{
    name   = "/api/vibe"
    method = "POST"
    group  = "brain"
    layer  = "brain_planning"
    role   = "Create and manage vibe coding sessions."
    scope  = "Binds user, project, input mode and targets (web, mobile, desktop) into a session id."
}

$apis += @{
    name   = "/api/sessions"
    method = "POST"
    group  = "brain"
    layer  = "brain_planning"
    role   = "List, open and close sessions."
    scope  = "Lets Sophyane list active or past sessions and resume them."
}

$apis += @{
    name   = "/api/chat"
    method = "POST"
    group  = "brain"
    layer  = "brain_planning"
    role   = "Main conversation, planning and explanation API."
    scope  = "Turns user instructions and errors into plans, explanations and high level codegen requests. Does not write files directly."
}

$apis += @{
    name   = "/api/ai/"
    method = "POST"
    group  = "brain"
    layer  = "brain_planning"
    role   = "Brain router configuration and status."
    scope  = "Describes available AI providers and models and allows basic routing configuration."
}

$apis += @{
    name   = "/api/ai/complete"
    method = "POST"
    group  = "brain"
    layer  = "brain_planning"
    role   = "Low level text completion API."
    scope  = "Used by internal components when they need raw LLM completions without project semantics."
}

$apis += @{
    name   = "/api/train"
    method = "POST"
    group  = "brain"
    layer  = "brain_planning"
    role   = "Training and fine tuning interface."
    scope  = "Accepts curated examples and traces to tune behavior for specific users or projects."
}

$apis += @{
    name   = "/api/rl"
    method = "POST"
    group  = "brain"
    layer  = "brain_planning"
    role   = "Reinforcement learning feedback collector."
    scope  = "Stores thumbs up and thumbs down on model outputs so future behavior improves."
}

$apis += @{
    name   = "/api/truth"
    method = "POST"
    group  = "brain"
    layer  = "context_truth"
    role   = "Truth engine for capabilities and environment facts."
    scope  = "Returns authoritative information about NIFDU features, ports and environment so the brain does not hallucinate."
}

$apis += @{
    name   = "/api/rag"
    method = "POST"
    group  = "brain"
    layer  = "context_truth"
    role   = "Retrieval augmented generation gateway."
    scope  = "Ingests and queries project documents and code so the brain can answer and generate with context."
}

# --- Codegen, build, run, filesystem, logs, list (7) ---
$apis += @{
    name   = "/api/codegen"
    method = "POST"
    group  = "codegen"
    layer  = "codegen_execution"
    role   = "File level code generation."
    scope  = "Turns focused instructions and project context into file operations and post steps to build."
}

$apis += @{
    name   = "/api/compile"
    method = "POST"
    group  = "codegen"
    layer  = "codegen_execution"
    role   = "Compile and build artifacts."
    scope  = "Builds web, mobile and desktop targets and returns logs and errors."
}

$apis += @{
    name   = "/api/run"
    method = "POST"
    group  = "codegen"
    layer  = "codegen_execution"
    role   = "Run executables, servers and tests."
    scope  = "Launches built binaries or dev servers and returns logs, urls and status."
}

$apis += @{
    name   = "/api/deploy"
    method = "POST"
    group  = "codegen"
    layer  = "codegen_execution"
    role   = "Deploy artifacts into live environments."
    scope  = "Promotes build outputs into live webroots or other deployment locations."
}

$apis += @{
    name   = "/api/log"
    method = "POST"
    group  = "codegen"
    layer  = "context_truth"
    role   = "Structured log ingestion and retrieval."
    scope  = "Central log access for build logs, run logs and agent actions."
}

$apis += @{
    name   = "/api/fs"
    method = "POST"
    group  = "codegen"
    layer  = "codegen_execution"
    role   = "Controlled filesystem interface."
    scope  = "List, read and diff files inside whitelisted project roots for UI and tools."
}

$apis += @{
    name   = "/api/list"
    method = "POST"
    group  = "codegen"
    layer  = "context_truth"
    role   = "Generic list API for projects, builds or artifacts."
    scope  = "Used by Sophyane to show project lists and recent builds."
}

# --- Projects, auth and data (6) ---
$apis += @{
    name   = "/api/project"
    method = "POST"
    group  = "projects"
    layer  = "projects_auth_data"
    role   = "Single project metadata manager."
    scope  = "Create, update and read project config including stack, targets and domains."
}

$apis += @{
    name   = "/api/projects/accept"
    method = "POST"
    group  = "projects"
    layer  = "projects_auth_data"
    role   = "Accept or promote a project version."
    scope  = "Marks a project snapshot as accepted and ready for deploy or packaging."
}

$apis += @{
    name   = "/api/auth/generate_key"
    method = "POST"
    group  = "projects"
    layer  = "projects_auth_data"
    role   = "Issue API keys for users or services."
    scope  = "Generates scoped tokens so external tools or remote IDEs can call NIFDU APIs securely."
}

$apis += @{
    name   = "/api/db_health"
    method = "POST"
    group  = "projects"
    layer  = "context_truth"
    role   = "Database health check."
    scope  = "Reports Postgres and vector store status before DB heavy operations."
}

$apis += @{
    name   = "/api/lead"
    method = "POST"
    group  = "projects"
    layer  = "projects_auth_data"
    role   = "Lead capture endpoint."
    scope  = "Stores leads from forms generated by web and mobile apps."
}

$apis += @{
    name   = "/api/retail/blueprints"
    method = "POST"
    group  = "projects"
    layer  = "projects_auth_data"
    role   = "Retail and store blueprints provider."
    scope  = "Provides templates for ecommerce flows and pricing structures which codegen can implement."
}

# --- Media and AV (6) ---
$apis += @{
    name   = "/api/media/upload"
    method = "POST"
    group  = "media"
    layer  = "media_av"
    role   = "Upload audio, video or images."
    scope  = "Entry point for voice commands, video instructions and media assets."
}

$apis += @{
    name   = "/api/media/transform"
    method = "POST"
    group  = "media"
    layer  = "media_av"
    role   = "Generic media transformation."
    scope  = "Handles operations like speech to text, text to speech and basic media transforms."
}

$apis += @{
    name   = "/api/av/plan"
    method = "POST"
    group  = "media"
    layer  = "media_av"
    role   = "Plan procedural audio or video sequences."
    scope  = "Turns text instructions into a structured animation or AV plan."
}

$apis += @{
    name   = "/api/av/render"
    method = "POST"
    group  = "media"
    layer  = "media_av"
    role   = "Render AV plans to frames or video."
    scope  = "Executes AV plans using the local AV engine and writes outputs under webroot."
}

$apis += @{
    name   = "/api/av/sprite"
    method = "POST"
    group  = "media"
    layer  = "media_av"
    role   = "Manage sprite and asset metadata."
    scope  = "Register and list visual assets used in AV plans and games."
}

$apis += @{
    name   = "/api/av/control"
    method = "POST"
    group  = "media"
    layer  = "media_av"
    role   = "Control running AV sessions."
    scope  = "Play, pause, seek and adjust parameters of active AV render or playback sessions."
}

# --- Packaging and publishing (3) ---
$apis += @{
    name   = "/api/apps/package"
    method = "POST"
    group  = "packaging"
    layer  = "packaging_publish"
    role   = "Create platform specific packages."
    scope  = "Wraps built artifacts into Android, iOS and desktop installable packages."
}

$apis += @{
    name   = "/api/apps/publish"
    method = "POST"
    group  = "packaging"
    layer  = "packaging_publish"
    role   = "Register packages in internal catalog."
    scope  = "Marks packages as published so Sophyane can show downloads per platform."
}

$apis += @{
    name   = "/api/apps/export"
    method = "POST"
    group  = "packaging"
    layer  = "packaging_publish"
    role   = "Export artifacts and metadata for external stores."
    scope  = "Produces archives and manifests ready for manual upload to app stores or clients."
}

# --- Realtime, proxy and routing (4) ---
$apis += @{
    name   = "/api/ws/prices"
    method = "GET"
    group  = "realtime"
    layer  = "realtime_proxy_tools"
    role   = "Realtime streaming data endpoint."
    scope  = "Used by generated dashboards to subscribe to live prices or metrics."
}

$apis += @{
    name   = "/api/proxy/config"
    method = "POST"
    group  = "proxy"
    layer  = "realtime_proxy_tools"
    role   = "Manage reverse proxy configuration."
    scope  = "Reads or updates routing from domains and paths to backend services."
}

$apis += @{
    name   = "/api/proxy/routes"
    method = "GET"
    group  = "proxy"
    layer  = "realtime_proxy_tools"
    role   = "Inspect current routing table."
    scope  = "Shows how domains and paths map to services so brain and UI can reason about URLs."
}

$apis += @{
    name   = "/api/proxy/reload"
    method = "POST"
    group  = "proxy"
    layer  = "realtime_proxy_tools"
    role   = "Apply new proxy configuration."
    scope  = "Reloads proxy rules so new apps become live without full restart."
}

# ------------------------------------------------------------------
# 2) Define ~50 tools behind /api/codegen
# ------------------------------------------------------------------
$tools = @(
    @{ name="stripe_payments";    provider="Stripe";   category="payments";        description="Payment processing for checkouts.";                     orchestrated_via="/api/codegen" },
    @{ name="stripe_billing";     provider="Stripe";   category="billing";         description="Subscriptions and recurring billing.";                  orchestrated_via="/api/codegen" },
    @{ name="stripe_connect";     provider="Stripe";   category="payments";        description="Multi vendor and marketplace payouts.";                 orchestrated_via="/api/codegen" },
    @{ name="twilio_sms";         provider="Twilio";   category="messaging";       description="SMS notifications and one time codes.";                 orchestrated_via="/api/codegen" },
    @{ name="twilio_voice";       provider="Twilio";   category="voice";           description="Interactive voice flows and calls.";                    orchestrated_via="/api/codegen" },
    @{ name="twilio_whatsapp";    provider="Twilio";   category="messaging";       description="WhatsApp messaging integration.";                      orchestrated_via="/api/codegen" },
    @{ name="sendgrid_email";     provider="SendGrid"; category="email";           description="Transactional email for apps.";                         orchestrated_via="/api/codegen" },
    @{ name="mailgun_email";      provider="Mailgun";  category="email";           description="Alternate transactional email provider.";               orchestrated_via="/api/codegen" },
    @{ name="godaddy_domains";    provider="GoDaddy";  category="domains";         description="Domain search, purchase and DNS automation.";           orchestrated_via="/api/codegen" },
    @{ name="namecheap_domains";  provider="Namecheap";category="domains";         description="Alternate domain registrar.";                           orchestrated_via="/api/codegen" },
    @{ name="porkbun_domains";    provider="Porkbun";  category="domains";         description="Third registrar option.";                               orchestrated_via="/api/codegen" },
    @{ name="google_maps";        provider="Google";   category="maps";            description="Map tiles, places and directions.";                     orchestrated_via="/api/codegen" },
    @{ name="mapbox_maps";        provider="Mapbox";   category="maps";            description="Custom styled maps and overlays.";                      orchestrated_via="/api/codegen" },
    @{ name="supabase_auth";      provider="Supabase"; category="auth";            description="Hosted auth and user store.";                           orchestrated_via="/api/codegen" },
    @{ name="supabase_db";        provider="Supabase"; category="database";        description="Managed Postgres as a service.";                        orchestrated_via="/api/codegen" },
    @{ name="firebase_auth";      provider="Firebase"; category="auth";            description="Google sign in for web and mobile.";                    orchestrated_via="/api/codegen" },
    @{ name="firebase_push";      provider="Firebase"; category="push";            description="Push notifications for Android, iOS and web.";          orchestrated_via="/api/codegen" },
    @{ name="github_repos";       provider="GitHub";   category="version_control"; description="Repository and pull request automation.";               orchestrated_via="/api/codegen" },
    @{ name="gitlab_repos";       provider="GitLab";   category="version_control"; description="Alternate git hosting and CI.";                         orchestrated_via="/api/codegen" },
    @{ name="google_oauth";       provider="Google";   category="auth";            description="Sign in with Google.";                                 orchestrated_via="/api/codegen" },
    @{ name="github_oauth";       provider="GitHub";   category="auth";            description="Sign in with GitHub.";                                 orchestrated_via="/api/codegen" },
    @{ name="apple_signin";       provider="Apple";    category="auth";            description="Sign in with Apple.";                                  orchestrated_via="/api/codegen" },
    @{ name="openai_tools";       provider="OpenAI";   category="ai";              description="Direct OpenAI calls behind Agent 3.";                  orchestrated_via="/api/codegen" },
    @{ name="local_llama";        provider="Local";    category="ai";              description="Local llama models for offline use.";                   orchestrated_via="/api/codegen" },
    @{ name="ollama_models";      provider="Ollama";   category="ai";              description="Ollama managed local models.";                         orchestrated_via="/api/codegen" },
    @{ name="s3_storage";         provider="AWS";      category="storage";         description="Object storage for large media.";                      orchestrated_via="/api/codegen" },
    @{ name="minio_storage";      provider="MinIO";    category="storage";         description="Self hosted S3 compatible storage.";                    orchestrated_via="/api/codegen" },
    @{ name="cloudflare_dns";     provider="Cloudflare";category="dns";           description="DNS and basic security automation.";                    orchestrated_via="/api/codegen" },
    @{ name="cloudflare_pages";   provider="Cloudflare";category="hosting";       description="Static site hosting for public deployments.";           orchestrated_via="/api/codegen" },
    @{ name="vercel_deploy";      provider="Vercel";   category="hosting";         description="Preview and production deploys for web apps.";          orchestrated_via="/api/codegen" },
    @{ name="netlify_deploy";     provider="Netlify";  category="hosting";         description="Alternate static site hosting.";                        orchestrated_via="/api/codegen" },
    @{ name="redis_cache";        provider="Redis";    category="cache";           description="Key value cache for generated apps.";                   orchestrated_via="/api/codegen" },
    @{ name="rabbitmq_queue";     provider="RabbitMQ"; category="queue";           description="Queues for background jobs.";                           orchestrated_via="/api/codegen" },
    @{ name="kafka_streams";      provider="Apache";   category="streaming";       description="Streaming pipelines for analytics.";                    orchestrated_via="/api/codegen" },
    @{ name="elastic_search";     provider="Elastic";  category="search";          description="Full text search for large data sets.";                 orchestrated_via="/api/codegen" },
    @{ name="meilisearch";        provider="Meili";    category="search";          description="Lightweight search engine.";                            orchestrated_via="/api/codegen" },
    @{ name="segment_analytics";  provider="Segment";  category="analytics";       description="Event tracking and analytics routing.";                 orchestrated_via="/api/codegen" },
    @{ name="plausible_analytics";provider="Plausible";category="analytics";       description="Privacy friendly web analytics.";                       orchestrated_via="/api/codegen" },
    @{ name="sentry_errors";      provider="Sentry";   category="observability";   description="Error tracking and performance traces.";                orchestrated_via="/api/codegen" },
    @{ name="prometheus_metrics"; provider="Prometheus";category="observability"; description="Metrics collection for infra and apps.";                orchestrated_via="/api/codegen" },
    @{ name="grafana_dashboards"; provider="Grafana";  category="observability";   description="Dashboards built on top of metrics and logs.";          orchestrated_via="/api/codegen" },
    @{ name="whatsapp_business";  provider="Meta";     category="messaging";       description="Business messaging over WhatsApp.";                     orchestrated_via="/api/codegen" },
    @{ name="slack_notifications";provider="Slack";    category="messaging";       description="Notifications and bots for Slack.";                     orchestrated_via="/api/codegen" },
    @{ name="discord_bots";       provider="Discord";  category="messaging";       description="Discord bots and webhooks.";                           orchestrated_via="/api/codegen" },
    @{ name="zoom_meetings";      provider="Zoom";     category="video";           description="Create and join Zoom meetings.";                       orchestrated_via="/api/codegen" },
    @{ name="jitsi_meet";         provider="Jitsi";    category="video";           description="Self hosted video calls via Jitsi.";                    orchestrated_via="/api/codegen" },
    @{ name="wise_payouts";       provider="Wise";     category="payments";        description="International payouts for vendors.";                    orchestrated_via="/api/codegen" },
    @{ name="nifdu_local_tools";  provider="NIFDU";    category="internal";        description="Local tools like ffmpeg, git and compilers as tools.";  orchestrated_via="/api/codegen" }
)

# ------------------------------------------------------------------
# 3) Build and write manifest
# ------------------------------------------------------------------
$manifest = @{
    manifest_type = "nifdu_api_38_organs"
    version       = "1.0.0"
    generated_at  = (Get-Date).ToString("s")
    description   = "Canonical definition of NIFDU 38 API organs and tool layer for Sophyane vibe coding."
    apis          = $apis
    tools         = $tools
}

$configDir = "C:\nifdu\config"
if (-not (Test-Path $configDir)) {
    Say ("Creating config directory: {0}" -f $configDir) "Cyan"
    New-Item -ItemType Directory -Path $configDir -Force | Out-Null
}

$jsonPath = Join-Path $configDir "nifdu_api_38_manifest.json"
Say ("Writing manifest to: {0}" -f $jsonPath) "Cyan"

$manifest | ConvertTo-Json -Depth 10 | Out-File -FilePath $jsonPath -Encoding UTF8

Say "`n=== DONE: NIFDU 38-API MANIFEST WRITTEN ===`n" "Green"
Say ("Check counts with:`n`$j = Get-Content '{0}' | ConvertFrom-Json`n`$j.apis.Count; `$j.tools.Count" -f $jsonPath) "DarkGray"
