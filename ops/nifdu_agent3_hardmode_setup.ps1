cd C:\nifdu\build
$ErrorActionPreference = "Stop"

Write-Host "`n=== NIFDU Agent 3 HARDMODE SETUP (Prompt + Fix Loop + UI) ===`n" -ForegroundColor Yellow

# --- Paths ---
$ProjectRoot = "C:\nifdu"
$BuildDir    = Join-Path $ProjectRoot "build"
$OpsDir      = Join-Path $ProjectRoot "ops"
$WebRoot     = "C:\webroot\nifdu.com\www"
$AgentDir    = Join-Path $WebRoot "agent3"

New-Item -ItemType Directory -Path $BuildDir, $OpsDir, $WebRoot, $AgentDir -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $BuildDir "_diag") -Force | Out-Null

# =====================================================================
# 1) Rewrite Agent 3 executor: strong meta-prompt + multi-round fix loop
# =====================================================================
$ExecutorPath = Join-Path $OpsDir "nifdu_agent3_apply_codegen.ps1"

$ExecutorScript = @'
param(
    [Parameter(Mandatory=$true)]
    [string]$Project,

    [Parameter(Mandatory=$true)]
    [string]$Prompt,

    [string]$Brain      = "auto",
    [int]   $MaxRounds  = 3,
    [string]$CodegenUrl = "http://127.0.0.1/api/codegen",
    [string]$LogDir     = "C:\nifdu\build\_diag",
    [string]$ExePath    = "C:\nifdu\build\Release\nifdu.exe"
)

$ErrorActionPreference = "Stop"

function Say {
    param([string]$m,[string]$c="Gray")
    try {
        $valid = [enum]::GetNames([System.ConsoleColor])
        if ($valid -notcontains $c) { $c = "Gray" }
        $old = [Console]::ForegroundColor
        [Console]::ForegroundColor = $c
        Write-Host $m
        [Console]::ForegroundColor = $old
    } catch {
        Write-Host $m
    }
}

function New-NifduAgent3Prompt {
    param(
        [string]$Project,
        [string]$UserPrompt,
        [string]$Mode,
        [string]$ErrorLog = "",
        [string]$PreviousFilesJson = ""
    )

    $schema = @'
You are **NIFDU Agent 3**, a strict code generator for the NIFDU C++ monolith.

You MUST always reply with a single well-formed JSON object. No prose. No markdown. No code fences.

JSON SCHEMA (top level):

{
  "status": "ok" | "error",
  "engine": "openai",
  "model": "gpt-4.1-mini",
  "project": "<project_slug>",
  "files": [
    {
      "path": "C:/nifdu/src/apps/<project>/main.cpp" | "C:/webroot/nifdu.com/www/apps/<project>/index.html" | ...,
      "language": "cpp" | "html" | "js" | "css" | "txt",
      "action": "write",
      "status": "complete",
      "content": "<file contents as plain text>"
    }
  ],
  "post_steps": [
    "cmake --build C:/nifdu/build --config Release"
  ],
  "notes": [
    "<short bullet points about design decisions>"
  ]
}

RULES:

- Paths:
  - C++ app code MUST live under: C:/nifdu/src/apps/<project>/
  - Web assets MUST live under:  C:/webroot/nifdu.com/www/apps/<project>/
- Languages:
  - Use **C++20** for backend.
  - Use plain HTML + minimal vanilla JavaScript for frontend.
  - Do NOT generate Python, Node, React, or other frameworks.
- Escaping:
  - Escape all backslashes and quotes correctly for JSON.
  - `content` MUST be valid UTF-8 text, not base64, and safely JSON-escaped.
- Behaviour:
  - Make sure all generated C++ files compile with MSVC /std:c++20.
  - Prefer small, focused files instead of giant ones.
  - When fixing errors, change as little as possible.
'@

    $modeText = if ($Mode -eq "fix_errors") {
        "MODE: FIX_ERRORS. You are receiving a build log that shows compiler/linker errors. Use it to minimally patch your previous files."
    } else {
        "MODE: FRESH_CODEGEN. You are designing new code and HTML for the project."
    }

    $errorSection = if ($ErrorLog) {
@"
BUILD LOG / ERROR CONTEXT:
----------------------------------------
$ErrorLog
----------------------------------------
"@
    } else {
        "(no previous errors; first attempt)"
    }

    $filesSection = if ($PreviousFilesJson) {
@"
PREVIOUS FILES JSON (from your last reply):
----------------------------------------
$PreviousFilesJson
----------------------------------------
"@
    } else {
        "(no previous files yet; first attempt)"
    }

    $userSection = @"
USER PROJECT SLUG: $Project

USER REQUEST:
----------------------------------------
$UserPrompt
----------------------------------------
"@

    return @"
SYSTEM INSTRUCTIONS:
$schema

$modeText

$userSection

$errorSection

$filesSection

Remember: reply with ONE JSON OBJECT ONLY, no commentary.
"@
}

Say "`n=== NIFDU AGENT 3 CODEGEN EXECUTOR (HARDMODE) ===`n" "Cyan"
Say "Project : $Project" "Gray"
Say "Brain   : $Brain"   "Gray"
Say "Rounds  : $MaxRounds" "Gray"
Say "BaseUrl : http://127.0.0.1" "Gray"

if (!(Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

$LastResponseJson = ""
$LastFilesJson    = ""

for ($round = 1; $round -le $MaxRounds; $round++) {
    Say "`n--- ROUND $round of $MaxRounds ---" "Yellow"

    # 0. Kill old nifdu.exe to free DLLs before build
    Say "[0] Stopping any running nifdu.exe ..." "DarkYellow"
    Stop-Process -Name "nifdu" -ErrorAction SilentlyContinue | Out-Null

    # 1. Build meta-prompt
    $mode     = if ($round -eq 1) { "vibe_coding" } else { "fix_errors" }
    $logPath  = Join-Path $LogDir "build_$($Project).log"
    $errorLog = if (Test-Path $logPath) { Get-Content $logPath -Raw } else { "" }
    $metaPrompt = New-NifduAgent3Prompt -Project $Project -UserPrompt $Prompt -Mode $mode -ErrorLog $errorLog -PreviousFilesJson $LastFilesJson

    $Body = @{
        project = $Project
        prompt  = $metaPrompt
        brain   = $Brain
        mode    = $mode
    }
    $JsonBody = $Body | ConvertTo-Json -Depth 6

    # 2. Call /api/codegen
    Say "[1] Calling /api/codegen (mode=$mode) ..." "Cyan"
    try {
        $Response = Invoke-RestMethod -Uri $CodegenUrl -Method Post -Body $JsonBody -ContentType "application/json; charset=utf-8"
    } catch {
        Say "[FATAL] Error calling /api/codegen: $($_.Exception.Message)" "Red"
        exit 1
    }

    $LastResponseJson = ($Response | ConvertTo-Json -Depth 8)
    $LastFilesJson    = ($Response.files | ConvertTo-Json -Depth 8)

    if ($Response.status -ne "ok") {
        Say "[FATAL] /api/codegen returned status='$($Response.status)'" "Red"
        $LastResponseJson | Out-File -FilePath (Join-Path $LogDir "agent3_$($Project)_last_response.json") -Encoding UTF8 -Force
        exit 1
    }

    Say "[OK] /api/codegen status = $($Response.status), engine = $($Response.engine), model = $($Response.model)" "Green"

    # 3. Write files
    Say "[2] Writing files..." "Cyan"
    $writeCount = 0
    foreach ($f in $Response.files) {
        $path    = $f.path
        $content = $f.content
        if (-not $path) { continue }
        $dir = Split-Path $path -Parent
        if ($dir -and -not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        $content | Out-File -FilePath $path -Encoding UTF8 -Force
        $writeCount++
        Say "  -> $path" "Gray"
    }
    Say "[OK] $writeCount file(s) written." "Green"

    # 4. Run post_steps (build etc.) and capture output
    Say "[3] Running post_steps and capturing build log..." "Cyan"
    $allOutput = @()
    $buildSuccess = $true

    foreach ($cmd in $Response.post_steps) {
        if (-not $cmd) { continue }
        Say "  >> $cmd" "Gray"
        $output = cmd /c $cmd 2>&1
        $allOutput += $output

        if ($output -match "error LNK|fatal error|: error C[0-9]{4}|Build FAILED") {
            $buildSuccess = $false
        }
    }

    $buildLogPath = Join-Path $LogDir "build_$($Project).log"
    $allOutput | Out-File -FilePath $buildLogPath -Encoding UTF8 -Force

    if ($buildSuccess) {
        Say "`n✅ ROUND $round: Build succeeded." "Green"

        # Restart monolith if it's not already running
        if (-not (Get-Process -Name "nifdu" -ErrorAction SilentlyContinue)) {
            Say "[4] Starting nifdu.exe ..." "Cyan"
            Start-Process -FilePath $ExePath -WindowStyle Hidden
        }

        $respPath = Join-Path $LogDir "agent3_$($Project)_last_response.json"
        $LastResponseJson | Out-File -FilePath $respPath -Encoding UTF8 -Force

        Say "`n=== AGENT 3 HARDMODE COMPLETE (SUCCESS) ===`n" "Yellow"
        Say "Last JSON: $respPath" "Gray"
        Say "Build log: $buildLogPath" "Gray"
        exit 0
    }
    else {
        Say "`n❌ ROUND $round: Build failed, will try fix_errors if rounds remain." "Red"
        if ($round -eq $MaxRounds) {
            Say "`n[FATAL] Maximum rounds reached; giving up." "Red"
            $respPath = Join-Path $LogDir "agent3_$($Project)_last_response.json"
            $LastResponseJson | Out-File -FilePath $respPath -Encoding UTF8 -Force
            Say "Last JSON: $respPath" "Gray"
            Say "Build log: $buildLogPath" "Gray"
            exit 1
        }
    }
}

Say "[UNREACHABLE] Loop ended unexpectedly." "Red"
exit 1
'@

Set-Content -Path $ExecutorPath -Value $ExecutorScript -Encoding UTF8
Write-Host "✓ Updated Agent 3 executor at $ExecutorPath" -ForegroundColor Green

# ============================================================
# 2) Rewrite /agent3/index.html to use the same meta-prompt
# ============================================================
$IndexPath = Join-Path $AgentDir "index.html"

$html = @'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <title>NIFDU Agent 3 — Vibe Coding (Hardmode)</title>
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <style>
    :root {
      color-scheme: dark;
      --bg:#020617;--bg2:#020617;--border:#1f2937;
      --accent:#22c55e;--accent-soft:rgba(34,197,94,.12);
      --text:#e5e7eb;--muted:#9ca3af;--danger:#f97373;
    }
    *{box-sizing:border-box;}
    body{
      margin:0;min-height:100vh;background:#020617;color:var(--text);
      font-family:system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;
      display:flex;flex-direction:column;
    }
    header{
      padding:10px 14px;border-bottom:1px solid var(--border);
      display:flex;justify-content:space-between;align-items:center;gap:8px;
      background:rgba(15,23,42,.96);backdrop-filter:blur(12px);
    }
    h1{margin:0;font-size:16px;letter-spacing:.12em;text-transform:uppercase;color:var(--accent);}
    .sub{font-size:11px;color:var(--muted);}
    .pill{font-size:11px;border-radius:999px;border:1px solid var(--border);padding:2px 10px;color:var(--muted);}
    main{flex:1;display:grid;grid-template-columns:minmax(0,1.1fr) minmax(0,1.1fr);gap:12px;padding:12px;}
    @media(max-width:900px){main{grid-template-columns:1fr;}}
    .card{
      border-radius:12px;border:1px solid var(--border);background:var(--bg2);
      padding:12px;display:flex;flex-direction:column;gap:10px;
    }
    label{font-size:11px;color:var(--muted);display:block;margin-bottom:3px;}
    input,textarea,select{
      width:100%;background:#020617;border-radius:9px;border:1px solid var(--border);
      padding:7px 9px;font-size:13px;color:var(--text);outline:none;
    }
    textarea{min-height:120px;resize:vertical;}
    input:focus,textarea:focus,select:focus{border-color:var(--accent);box-shadow:0 0 0 1px var(--accent-soft);}
    .row{display:grid;grid-template-columns:1fr 1fr;gap:8px;}
    button{
      border-radius:999px;border:none;padding:7px 12px;font-size:13px;cursor:pointer;
      background:var(--accent);color:#022c22;font-weight:500;
    }
    button.secondary{background:transparent;color:var(--muted);border:1px solid var(--border);}
    button.danger{background:transparent;color:var(--danger);border:1px solid var(--danger);}
    button:hover{filter:brightness(1.05);}
    .btn-row{display:flex;gap:6px;flex-wrap:wrap;}
    pre{
      margin:0;font-family:ui-monospace,Menlo,Consolas,monospace;
      font-size:11px;background:#020617;border-radius:9px;border:1px solid var(--border);
      padding:8px;overflow:auto;min-height:150px;white-space:pre-wrap;word-wrap:break-word;
    }
    .status{font-size:11px;color:var(--muted);}
    .status span{font-weight:600;}
  </style>
</head>
<body>
  <header>
    <div>
      <h1>NIFDU Agent 3</h1>
      <div class="sub">Hardmode: schema + fix loop (vibe coding, C++ only).</div>
    </div>
    <div class="pill">
      Engine: <span id="engineLabel">–</span> · Model: <span id="modelLabel">–</span>
    </div>
  </header>

  <main>
    <section class="card">
      <div class="row">
        <div>
          <label for="projectInput">Project</label>
          <input id="projectInput" value="todo_app_urdu" />
        </div>
        <div>
          <label for="brainSelect">Brain</label>
          <select id="brainSelect">
            <option value="auto" selected>auto</option>
            <option value="openai">openai</option>
            <option value="llama">llama.cpp</option>
            <option value="ollama">ollama</option>
          </select>
        </div>
      </div>
      <div>
        <label for="promptInput">Sentence / task</label>
        <textarea id="promptInput"
          placeholder="Example: Create a small Urdu Todo App with C++ backend and HTML frontend that runs under NIFDU."></textarea>
      </div>
      <div class="btn-row">
        <button id="chatBtn" class="secondary">Plan only (/api/chat)</button>
        <button id="codegenBtn">Codegen (/api/codegen) + open tabs</button>
        <button id="clearBtn" class="secondary">Clear</button>
      </div>
      <div class="status" id="statusLine">
        Status: <span>idle</span>
      </div>
      <div class="status">
        Tip: Allow pop-ups for <code>127.0.0.1</code> so Code + Preview tabs open.
      </div>
    </section>

    <section class="card">
      <div class="status">JSON output (last response)</div>
      <pre id="jsonBox">// Run Agent 3 to see JSON here.</pre>
    </section>
  </main>

  <script>
  (function(){
    const projectInput = document.getElementById("projectInput");
    const brainSelect  = document.getElementById("brainSelect");
    const promptInput  = document.getElementById("promptInput");
    const chatBtn      = document.getElementById("chatBtn");
    const codegenBtn   = document.getElementById("codegenBtn");
    const clearBtn     = document.getElementById("clearBtn");
    const jsonBox      = document.getElementById("jsonBox");
    const statusLine   = document.getElementById("statusLine");
    const engineLabel  = document.getElementById("engineLabel");
    const modelLabel   = document.getElementById("modelLabel");

    let preCodeWin = null;
    let prePreviewWin = null;

    function setStatus(txt,isError){
      const span = statusLine.querySelector("span");
      span.textContent = txt;
      span.style.color = isError ? "var(--danger)" : "var(--accent)";
    }
    function logJson(obj){
      try{ jsonBox.textContent = JSON.stringify(obj,null,2); }
      catch(e){ jsonBox.textContent = String(obj); }
    }
    function storeResponse(resp, project, userPrompt, endpoint){
      try{
        localStorage.setItem("nifdu_agent3_last_response", JSON.stringify(resp));
        localStorage.setItem("nifdu_agent3_last_project", project || "");
        localStorage.setItem("nifdu_agent3_last_user_prompt", userPrompt || "");
        localStorage.setItem("nifdu_agent3_last_endpoint", endpoint || "");
      }catch(e){ console.warn("localStorage failed:", e); }
    }

    function buildMetaPrompt(project,userPrompt,mode){
      const schema = `
You are **NIFDU Agent 3**, a strict code generator for the NIFDU C++ monolith.

Reply with ONE JSON OBJECT ONLY, matching this shape:

{
  "status": "ok" | "error",
  "engine": "openai",
  "model": "gpt-4.1-mini",
  "project": "<project>",
  "files": [
    {
      "path": "C:/nifdu/src/apps/<project>/main.cpp" | "C:/webroot/nifdu.com/www/apps/<project>/index.html" | ...,
      "language": "cpp" | "html" | "js" | "css" | "txt",
      "action": "write",
      "status": "complete",
      "content": "<file contents>"
    }
  ],
  "post_steps": [
    "cmake --build C:/nifdu/build --config Release"
  ],
  "notes": [
    "<short bullet notes>"
  ]
}

RULES:
- C++20 backend only, no Python/Node/React.
- Web UI: plain HTML + minimal vanilla JS.
- C++ lives in C:/nifdu/src/apps/${project}/
- Web files live in C:/webroot/nifdu.com/www/apps/${project}/
- Escape all quotes/backslashes so the JSON parses correctly.
`;
      const modeText = mode === "fix_errors"
        ? "MODE: FIX_ERRORS. You are patching existing files based on compiler errors."
        : "MODE: FRESH_CODEGEN. You are creating new files.";

      return `SYSTEM INSTRUCTIONS:
${schema}

${modeText}

USER PROJECT SLUG: ${project}

USER REQUEST:
----------------------------------------
${userPrompt}
----------------------------------------
`;
    }

    function openCodeTab(){
      const html = localStorage.getItem("nifdu_agent3_code_viewer_html");
      const w = window.open("about:blank","_blank");
      if(!w){
        alert("Browser blocked the code tab. Please allow pop-ups for 127.0.0.1");
        return null;
      }
      const doc = html || "";
      w.document.open();
      if(html){
        w.document.write(html);
      }else{
        w.document.write("<!doctype html><title>Agent 3 code viewer</title><pre>Run Codegen once from /agent3 to populate viewer template.</pre>");
      }
      w.document.close();
      return w;
    }

    // Seed a reusable code viewer HTML template into localStorage (to keep JS small here)
    (function seedCodeViewer(){
      if(localStorage.getItem("nifdu_agent3_code_viewer_html")) return;
      const viewer = `<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8" /><title>Agent 3 · Code Editor</title><meta name="viewport" content="width=device-width, initial-scale=1" /><style>:root{color-scheme:dark;--bg:#020617;--border:#1f2937;--accent:#22c55e;--accent-soft:rgba(34,197,94,.12);--text:#e5e7eb;--muted:#9ca3af;}*{box-sizing:border-box;}body{margin:0;min-height:100vh;background:#020617;color:var(--text);font-family:system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;display:flex;flex-direction:column;}header{padding:10px 14px;border-bottom:1px solid var(--border);display:flex;justify-content:space-between;align-items:center;gap:8px;background:rgba(15,23,42,.96);}h1{margin:0;font-size:15px;color:var(--accent);}main{flex:1;display:grid;grid-template-columns:minmax(0,0.9fr) minmax(0,1.1fr);gap:8px;padding:8px;}@media(max-width:900px){main{grid-template-columns:1fr;}}.card{border-radius:10px;border:1px solid var(--border);background:#020617;padding:8px;display:flex;flex-direction:column;gap:6px;min-height:0;}.list{font-size:12px;border-radius:8px;border:1px solid var(--border);background:#020617;padding:4px;max-height:230px;overflow:auto;}.item{padding:4px 6px;border-radius:6px;cursor:pointer;display:flex;justify-content:space-between;gap:6px;}.item:hover{background:#111827;}.item.active{background:rgba(34,197,94,.22);}.path{white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:210px;}.meta2{font-size:10px;color:var(--muted);}.meta{font-size:11px;color:var(--muted);}textarea{flex:1;min-height:200px;border-radius:8px;border:1px solid #1f2937;background:#020617;color:var(--text);padding:8px;font-family:ui-monospace,Menlo,Consolas,monospace;font-size:12px;resize:none;white-space:pre;}textarea:focus{border-color:var(--accent);box-shadow:0 0 0 1px var(--accent-soft);outline:none;}button{border-radius:999px;border:none;padding:5px 10px;font-size:11px;cursor:pointer;background:var(--accent);color:#022c22;}button.secondary{background:transparent;color:var(--muted);border:1px solid var(--border);}</style></head><body><header><div><h1>Agent 3 · Code Editor</h1><div class="meta">Reading last response from localStorage.</div></div><div class="meta" id="metaBox">engine/model</div></header><main><section class="card"><div class="meta">Files</div><div id="fileList" class="list"></div><div style="display:flex;gap:6px;margin-top:4px;flex-wrap:wrap;"><button id="copyBtn">Copy</button><button id="reloadBtn" class="secondary">Reload</button></div></section><section class="card"><div class="meta" id="pathLabel">No file selected</div><textarea id="codeArea" spellcheck="false">// Select a file</textarea></section></main><script>(function(){const fileList=document.getElementById("fileList");const codeArea=document.getElementById("codeArea");const metaBox=document.getElementById("metaBox");const pathLabel=document.getElementById("pathLabel");const copyBtn=document.getElementById("copyBtn");const reloadBtn=document.getElementById("reloadBtn");let files=[];let currentIndex=-1;function load(){let raw=localStorage.getItem("nifdu_agent3_last_response");if(!raw){fileList.textContent="No stored response. Run Codegen from /agent3.";codeArea.value="// No stored response.";metaBox.textContent="engine/model";return;}let resp;try{resp=JSON.parse(raw);}catch(e){fileList.textContent="Failed to parse stored response.";codeArea.value=String(e);return;}metaBox.textContent=(resp.engine||"engine")+" · "+(resp.model||"model")+" · project="+(resp.project||"?");files=Array.isArray(resp.files)?resp.files:[];fileList.innerHTML="";if(!files.length){fileList.textContent="No files[] in response.";codeArea.value="// No files[] available.";return;}files.forEach(function(f,idx){const d=document.createElement("div");d.className="item";d.dataset.index=String(idx);const p=document.createElement("span");p.className="path";p.textContent=f.path||"(no path)";const m=document.createElement("span");m.className="meta2";m.textContent=(f.language||"plain")+" · "+(f.action||"write");d.appendChild(p);d.appendChild(m);d.addEventListener("click",function(){select(idx);});fileList.appendChild(d);});select(0);}function select(i){if(i<0||i>=files.length)return;currentIndex=i;Array.from(fileList.children).forEach(function(el){el.classList.remove("active");});const active=Array.from(fileList.children).find(function(el){return el.dataset.index===String(i);});if(active)active.classList.add("active");const f=files[i];pathLabel.textContent=f.path||"(no path)";codeArea.value=f.content||"";}copyBtn.addEventListener("click",function(){navigator.clipboard.writeText(codeArea.value||"").catch(function(e){alert("Clipboard failed: "+e);});});reloadBtn.addEventListener("click",load);load();})();<\/script></body></html>`;
      try{ localStorage.setItem("nifdu_agent3_code_viewer_html", viewer); }catch(e){ console.warn(e); }
    })();

    async function callEndpoint(endpoint){
      const project    = projectInput.value.trim() || "todo_app_urdu";
      const brain      = brainSelect.value || "auto";
      const userPrompt = promptInput.value.trim();
      const mode       = "vibe_coding";

      if(!userPrompt){
        setStatus("prompt required", true);
        return;
      }

      const metaPrompt = buildMetaPrompt(project,userPrompt,mode);

      setStatus("calling " + endpoint + " …");
      jsonBox.textContent = "// waiting for " + endpoint + " …";

      try{
        const resp = await fetch(endpoint,{
          method:"POST",
          headers:{"Content-Type":"application/json; charset=utf-8"},
          body:JSON.stringify({ project, prompt: metaPrompt, brain, mode })
        });

        if(!resp.ok){
          setStatus("HTTP " + resp.status, true);
          jsonBox.textContent = "// HTTP " + resp.status + ": " + resp.statusText;
          return;
        }

        const data = await resp.json();
        engineLabel.textContent = data.engine || "–";
        modelLabel.textContent  = data.model  || "–";
        logJson(data);
        storeResponse(data, project, userPrompt, endpoint);
        setStatus("done · status=" + (data.status || "unknown"));
      }catch(e){
        console.error(e);
        setStatus("network / parse error", true);
        jsonBox.textContent = "// error: " + e;
      }
    }

    chatBtn.addEventListener("click", function(){
      callEndpoint("/api/chat");
    });

    codegenBtn.addEventListener("click", function(){
      const project = projectInput.value.trim() || "todo_app_urdu";

      // Open preview + code tabs synchronously to avoid popup blocking
      prePreviewWin = window.open("/apps/" + encodeURIComponent(project) + "/", "_blank");
      preCodeWin    = openCodeTab();

      if(!prePreviewWin || !preCodeWin){
        // Already alerted in openCodeTab or popup blocked
      }

      callEndpoint("/api/codegen");
    });

    clearBtn.addEventListener("click", function(){
      promptInput.value = "";
      jsonBox.textContent = "// cleared.";
      engineLabel.textContent = "–";
      modelLabel.textContent  = "–";
      setStatus("idle");
    });

    setStatus("idle");
  })();
  </script>
</body>
</html>
'@

Set-Content -Path $IndexPath -Value $html -Encoding UTF8
Write-Host "✓ Updated Agent 3 web UI at $IndexPath" -ForegroundColor Green

Write-Host "`n=== NIFDU Agent 3 HARDMODE SETUP COMPLETE ===" -ForegroundColor Yellow
Write-Host "Next:" -ForegroundColor Yellow
Write-Host "  1) Build NIFDU   : cd C:\nifdu\build; cmake --build . --config Release" -ForegroundColor Gray
Write-Host "  2) Run monolith  : C:\nifdu\build\Release\nifdu.exe" -ForegroundColor Gray
Write-Host "  3) Open UI       : http://127.0.0.1/agent3/" -ForegroundColor Gray
Write-Host "  4) CLI loop test : powershell -File C:\nifdu\ops\nifdu_agent3_apply_codegen.ps1 -Project 'todo_app_urdu' -Prompt 'Create a small Urdu todo app with C++ backend and HTML frontend.'" -ForegroundColor Gray
