# ==============================================
# C:\nifdu\ops\nifdu_make_vibe_static_lab.ps1
# NIFDU — STATIC VIBE LAB (HTTP80)
# ==============================================
param(
    [string]$AppName = "vibe_static_lab"
)

$ErrorActionPreference = "Stop"

function Say {
    param([string]$Text, [string]$Color = "Gray")
    try {
        $valid = [enum]::GetNames([System.ConsoleColor])
        if ($valid -notcontains $Color) { $Color = "Gray" }
        Write-Host $Text -ForegroundColor $Color
    } catch {
        Write-Host $Text
    }
}

$root = "C:\webroot\nifdu.com\www\apps\$AppName"

Say "`n=== NIFDU — MAKE STATIC VIBE LAB: $AppName ===`n" "Yellow"
Say "Target folder: $root" "Cyan"

if (!(Test-Path $root)) {
    Say "Creating folder..." "Yellow"
    New-Item -ItemType Directory -Path $root -Force | Out-Null
} else {
    Say "Folder already exists, files may be overwritten." "DarkYellow"
}

$html = @"
<!DOCTYPE html>
<html lang="en" class="dark">
<head>
  <meta charset="utf-8" />
  <title>NIFDU Vibe Lab — \$AppName</title>
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <style>
    body { margin:0; font-family: system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;
           background:#020617; color:#f9fafb; height:100vh; display:flex; flex-direction:column; }
    header { padding:8px 16px; background:#020617; border-bottom:1px solid #1f2937;
             display:flex; justify-content:space-between; align-items:center; }
    .logo { font-weight:700; font-size:13px; letter-spacing:0.08em; text-transform:uppercase; }
    .status { font-size:11px; opacity:0.8; }
    .status-dot { width:8px; height:8px; border-radius:999px; background:#22c55e; display:inline-block; margin-right:4px; }
    main { flex:1; display:grid; grid-template-columns:240px minmax(0,1.6fr) minmax(0,1fr); gap:1px; background:#111827; }
    section { background:#020617; padding:10px; display:flex; flex-direction:column; overflow:hidden; }
    h2 { margin:0 0 8px; font-size:12px; text-transform:uppercase; letter-spacing:0.08em; color:#9ca3af; }
    .panel-body { flex:1; border-radius:6px; border:1px solid #1f2937; padding:8px; overflow:auto; font-size:12px; }
    .files-list { list-style:none; margin:0; padding:0; }
    .files-list li { padding:4px 6px; border-radius:4px; cursor:pointer; }
    .files-list li:hover { background:#111827; }
    .files-list li.active { background:#1f2937; color:#e5e7eb; }
    textarea { width:100%; height:100%; resize:none; border:none; outline:none; background:transparent; color:inherit;
               font-family:ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas,"Liberation Mono","Courier New",monospace;
               font-size:12px; }
    .chat-log { display:flex; flex-direction:column; gap:6px; }
    .msg { padding:6px 8px; border-radius:6px; border:1px solid #1f2937; font-size:12px; }
    .msg.user { align-self:flex-end; background:#1d4ed8; }
    .msg.ai { align-self:flex-start; background:#020617; }
    .chat-input-row { display:flex; gap:6px; margin-top:8px; }
    .chat-input-row textarea { height:60px; border-radius:6px; border:1px solid #1f2937; padding:6px; background:#020617; }
    button { border-radius:6px; border:1px solid #1f2937; background:#22c55e; color:#020617; font-weight:600;
             padding:6px 10px; cursor:pointer; font-size:12px; }
    button:disabled { opacity:0.5; cursor:default; }
  </style>
</head>
<body>
  <header>
    <div class="logo">NIFDU • RAW VIBE LAB • \$AppName</div>
    <div class="status"><span class="status-dot"></span>HTTP80 • talking to /api/chat</div>
  </header>

  <main>
    <section>
      <h2>Project Files</h2>
      <div class="panel-body">
        <ul class="files-list">
          <li class="active">app.cpp</li>
          <li>router.cpp</li>
          <li>nifdu_ops.ps1</li>
          <li>README.md</li>
        </ul>
      </div>
    </section>

    <section>
      <h2>Editor</h2>
      <div class="panel-body">
        <textarea>// NIFDU RAW LAB
// Served from /apps/\$AppName/ via nifdu.exe (HTTP80)
// Wire this to /api/codegen, /api/run, etc.</textarea>
      </div>
    </section>

    <section>
      <h2>Agent 3 Chat</h2>
      <div class="panel-body">
        <div id="chatLog" class="chat-log">
          <div class="msg ai">NIFDU Agent 3 (raw mode) ready. Describe what you want.</div>
        </div>
        <div class="chat-input-row">
          <textarea id="chatInput" placeholder="Ask Agent 3… (this calls /api/chat)"></textarea>
          <button id="sendBtn">Send</button>
        </div>
      </div>
    </section>
  </main>

  <script>
    const chatLog = document.getElementById("chatLog");
    const chatInput = document.getElementById("chatInput");
    const sendBtn = document.getElementById("sendBtn");

    async function sendMessage() {
      const text = chatInput.value.trim();
      if (!text) return;
      const userMsg = document.createElement("div");
      userMsg.className = "msg user";
      userMsg.textContent = text;
      chatLog.appendChild(userMsg);
      chatInput.value = "";
      sendBtn.disabled = true;

      try {
        const res = await fetch("/api/chat", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            project: "$AppName",
            mode: "vibe_coding",
            prompt: text,
            brain: "auto"
          })
        });
        const json = await res.json();
        const aiMsg = document.createElement("div");
        aiMsg.className = "msg ai";
        aiMsg.textContent = json.reply || JSON.stringify(json, null, 2);
        chatLog.appendChild(aiMsg);
        chatLog.scrollTop = chatLog.scrollHeight;
      } catch (err) {
        const errMsg = document.createElement("div");
        errMsg.className = "msg ai";
        errMsg.textContent = "Error calling /api/chat: " + err;
        chatLog.appendChild(errMsg);
      } finally {
        sendBtn.disabled = false;
      }
    }

    sendBtn.addEventListener("click", sendMessage);
    chatInput.addEventListener("keydown", (e) => {
      if (e.key === "Enter" && !e.shiftKey) {
        e.preventDefault();
        sendMessage();
      }
    });
  </script>
</body>
</html>
"@

Set-Content -Path (Join-Path $root "index.html") -Value $html -Encoding UTF8

Say "`nStatic vibe lab created." "Green"
Say "Test via NIFDU HTTP80:" "Yellow"
Say "  http://127.0.0.1/apps/$AppName/" "Cyan"
