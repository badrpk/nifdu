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

$WebRoot      = "C:\webroot\nifdu.com\www"
$AgentDir     = Join-Path $WebRoot "agent3"
$IndexPath    = Join-Path $WebRoot "index.html"
$Agent3Path   = Join-Path $AgentDir "start.html"

Say "`n=== NIFDU — GENERATE AGENT 3 VIBE CODING UI ===`n" "Yellow"

# Ensure directories
New-Item -ItemType Directory -Path $WebRoot -Force | Out-Null
New-Item -ItemType Directory -Path $AgentDir -Force | Out-Null

# -------------------------------
# 1) Simple landing page (index)
# -------------------------------
$IndexHtml = @'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8" />
    <title>NIFDU Monolith — Public Portal</title>
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <style>
        :root {
            color-scheme: dark;
        }
        body {
            margin: 0;
            padding: 40px 24px;
            background: radial-gradient(circle at top, #0f172a 0, #020617 55%, #000 100%);
            color: #e5e7eb;
            font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
        }
        .shell {
            max-width: 960px;
            margin: 0 auto;
        }
        h1 {
            font-size: 2.25rem;
            margin-bottom: 0.5rem;
            color: #22c55e;
        }
        h2 {
            font-size: 1.25rem;
            margin-top: 2rem;
            margin-bottom: 0.5rem;
            color: #38bdf8;
        }
        p {
            color: #9ca3af;
            line-height: 1.6;
        }
        .card {
            margin-top: 2rem;
            border-radius: 1.5rem;
            border: 1px solid #1f2937;
            padding: 20px 20px 16px;
            background: linear-gradient(145deg, rgba(15,23,42,0.98), rgba(15,23,42,0.7));
            box-shadow: 0 18px 40px rgba(0,0,0,0.6);
        }
        .actions {
            display: flex;
            flex-wrap: wrap;
            gap: 12px;
            margin-top: 16px;
        }
        a.button {
            display: inline-flex;
            align-items: center;
            justify-content: center;
            padding: 10px 18px;
            border-radius: 999px;
            border: 1px solid #22c55e;
            background: radial-gradient(circle at top left, #22c55e33, #16a34a00);
            color: #e5e7eb;
            text-decoration: none;
            font-weight: 500;
            font-size: 0.95rem;
            gap: 6px;
        }
        a.button span.dot {
            width: 8px;
            height: 8px;
            border-radius: 999px;
            background: #22c55e;
            box-shadow: 0 0 10px #22c55e;
        }
        .meta {
            margin-top: 10px;
            font-size: 0.8rem;
            color: #6b7280;
        }
        code {
            background: #020617;
            padding: 2px 6px;
            border-radius: 5px;
            font-size: 0.85rem;
            border: 1px solid #111827;
        }
    </style>
</head>
<body>
<div class="shell">
    <h1>NIFDU Monolith</h1>
    <p>All organs, brain, consciousness and soul are now running inside a single C++ binary. This is your private cloud launcher.</p>

    <div class="card">
        <h2>Agent 3 — Vibe Coding Studio</h2>
        <p>
            A full-stack vibe coding interface. Type a sentence, let the brain think, then see code, HTML and future AV come alive.
        </p>
        <div class="actions">
            <a class="button" href="/agent3/">
                <span class="dot"></span>
                <span>Open Agent 3</span>
            </a>
        </div>
        <div class="meta">
            Served directly by <code>nifdu.exe</code> on port 80 · Static webroot: <code>C:\webroot\nifdu.com\www</code>
        </div>
    </div>
</div>
</body>
</html>
'@

Set-Content -Path $IndexPath -Value $IndexHtml -Encoding UTF8
Say "[OK] index.html written to $IndexPath" "Green"

# -------------------------------
# 2) Agent 3 Vibe Coding UI
# -------------------------------
$Agent3Html = @'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8" />
    <title>NIFDU Agent 3 — Vibe Coding Studio</title>
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <style>
        :root {
            color-scheme: dark;
        }
        * {
            box-sizing: border-box;
        }
        body {
            margin: 0;
            padding: 16px;
            background: radial-gradient(circle at top, #020617 0, #000 60%);
            color: #e5e7eb;
            font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
        }
        .layout {
            max-width: 1200px;
            margin: 0 auto;
            display: grid;
            grid-template-columns: minmax(0, 1.1fr) minmax(0, 1.4fr);
            gap: 16px;
        }
        @media (max-width: 900px) {
            .layout {
                grid-template-columns: minmax(0, 1fr);
            }
        }
        header {
            max-width: 1200px;
            margin: 0 auto 10px auto;
            display: flex;
            align-items: center;
            justify-content: space-between;
            gap: 12px;
        }
        header h1 {
            font-size: 1.4rem;
            margin: 0;
            color: #22c55e;
        }
        header .tagline {
            font-size: 0.8rem;
            color: #9ca3af;
        }
        .pill {
            border-radius: 999px;
            padding: 4px 10px;
            font-size: 0.75rem;
            border: 1px solid #1f2937;
            background: rgba(15,23,42,0.85);
            display: inline-flex;
            align-items: center;
            gap: 6px;
        }
        .pill span.dot {
            width: 7px;
            height: 7px;
            border-radius: 999px;
            background: #22c55e;
            box-shadow: 0 0 8px #22c55e;
        }
        .panel {
            border-radius: 1.25rem;
            border: 1px solid #1f2937;
            background: linear-gradient(140deg, rgba(15,23,42,0.98), rgba(15,23,42,0.8));
            padding: 14px 14px 10px;
            box-shadow: 0 16px 40px rgba(0,0,0,0.55);
        }
        .panel h2 {
            font-size: 0.95rem;
            margin: 0 0 8px 0;
            color: #e5e7eb;
        }
        label {
            font-size: 0.8rem;
            color: #9ca3af;
            display: block;
            margin-bottom: 4px;
        }
        input, select, textarea {
            width: 100%;
            background: #020617;
            border-radius: 0.75rem;
            border: 1px solid #111827;
            padding: 8px 10px;
            color: #e5e7eb;
            font-size: 0.85rem;
            font-family: inherit;
            outline: none;
        }
        input:focus, select:focus, textarea:focus {
            border-color: #22c55e;
            box-shadow: 0 0 0 1px #22c55e33;
        }
        textarea {
            min-height: 160px;
            resize: vertical;
        }
        .row {
            display: flex;
            gap: 8px;
        }
        .row > div {
            flex: 1;
        }
        .buttons {
            margin-top: 10px;
            display: flex;
            flex-wrap: wrap;
            gap: 8px;
        }
        button {
            border-radius: 999px;
            border: 1px solid #22c55e;
            background: radial-gradient(circle at top left, #22c55e33, #16a34a00);
            padding: 8px 14px;
            font-size: 0.85rem;
            font-weight: 500;
            color: #e5e7eb;
            cursor: pointer;
            display: inline-flex;
            align-items: center;
            gap: 6px;
        }
        button.secondary {
            border-color: #38bdf8;
            background: radial-gradient(circle at top left, #38bdf833, #0ea5e900);
        }
        button:disabled {
            opacity: 0.5;
            cursor: default;
        }
        .status-bar {
            display: flex;
            justify-content: space-between;
            align-items: center;
            font-size: 0.75rem;
            color: #9ca3af;
            margin-top: 6px;
        }
        .status-bar span.badge {
            border-radius: 999px;
            padding: 2px 10px;
            border: 1px solid #1f2937;
            background: #020617;
        }
        .status-bar span.good {
            color: #22c55e;
        }
        .status-bar span.bad {
            color: #f97373;
        }
        .tabs {
            display: flex;
            gap: 6px;
            margin-bottom: 8px;
        }
        .tab {
            font-size: 0.8rem;
            padding: 5px 10px;
            border-radius: 999px;
            border: 1px solid #1f2937;
            background: #020617;
            cursor: pointer;
            color: #9ca3af;
        }
        .tab.active {
            border-color: #22c55e;
            color: #e5e7eb;
            box-shadow: 0 0 0 1px #22c55e33;
        }
        .out-pane {
            display: none;
            border-radius: 0.9rem;
            border: 1px solid #111827;
            background: #020617;
            padding: 8px;
            font-size: 0.8rem;
            max-height: 420px;
            overflow: auto;
        }
        .out-pane.active {
            display: block;
        }
        pre {
            margin: 0;
            white-space: pre-wrap;
            word-break: break-word;
            font-family: ui-monospace, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace;
            font-size: 0.8rem;
            color: #e5e7eb;
        }
        iframe.preview-frame {
            width: 100%;
            height: 360px;
            border: none;
            border-radius: 0.9rem;
            background: #020617;
        }
        .log-line {
            margin-bottom: 4px;
        }
        .log-line time {
            color: #6b7280;
            margin-right: 6px;
        }
    </style>
</head>
<body>
<header>
    <div>
        <h1>NIFDU Agent 3 · Vibe Coding</h1>
        <div class="tagline">Single sentence in → brainstorm, codegen and preview out of <code>nifdu.exe</code>.</div>
    </div>
    <div class="pill" id="health-pill">
        <span class="dot"></span>
        <span id="health-text">Checking /api/health…</span>
    </div>
</header>

<div class="layout">
    <!-- LEFT: Prompt + controls -->
    <section class="panel">
        <h2>Sentence → Intent</h2>
        <div class="row">
            <div>
                <label for="projectInput">Project</label>
                <input id="projectInput" type="text" value="todo_app_urdu" />
            </div>
            <div>
                <label for="brainSelect">Brain</label>
                <select id="brainSelect">
                    <option value="auto" selected>auto (OpenAI → local)</option>
                    <option value="openai">OpenAI first</option>
                    <option value="local">Local only</option>
                </select>
            </div>
        </div>
        <div style="margin-top:8px;">
            <label for="modeSelect">Mode</label>
            <select id="modeSelect">
                <option value="vibe_coding" selected>Vibe coding (default)</option>
                <option value="diagnostics">Diagnostics</option>
            </select>
        </div>

        <div style="margin-top:10px;">
            <label for="promptInput">Sentence / task</label>
            <textarea id="promptInput" placeholder="Example: Make a small Urdu todo app with C++ backend and HTML frontend that uses PostgreSQL."></textarea>
        </div>

        <div class="buttons">
            <button id="chatBtn">
                🧠 Chat only (/api/chat)
            </button>
            <button id="codegenBtn" class="secondary">
                🛠️ Codegen plan (/api/codegen)
            </button>
        </div>

        <div class="status-bar">
            <span class="badge">Last call: <span id="lastCall">none</span></span>
            <span id="lastStatus">Idle</span>
        </div>
    </section>

    <!-- RIGHT: Output panes -->
    <section class="panel">
        <h2>Brain · Codegen · Logs</h2>
        <div class="tabs">
            <div class="tab active" data-tab="json">JSON</div>
            <div class="tab" data-tab="preview">HTML Preview</div>
            <div class="tab" data-tab="logs">Logs</div>
        </div>

        <div id="pane-json" class="out-pane active">
            <pre id="jsonOut">{}</pre>
        </div>

        <div id="pane-preview" class="out-pane">
            <iframe class="preview-frame" id="previewFrame"></iframe>
        </div>

        <div id="pane-logs" class="out-pane">
            <div id="logArea"></div>
        </div>
    </section>
</div>

<script>
(function() {
    const healthText = document.getElementById('health-text');
    const healthPill = document.getElementById('health-pill');
    const lastCall   = document.getElementById('lastCall');
    const lastStatus = document.getElementById('lastStatus');
    const jsonOut    = document.getElementById('jsonOut');
    const preview    = document.getElementById('previewFrame');
    const logArea    = document.getElementById('logArea');

    const projectInput = document.getElementById('projectInput');
    const brainSelect  = document.getElementById('brainSelect');
    const modeSelect   = document.getElementById('modeSelect');
    const promptInput  = document.getElementById('promptInput');

    const chatBtn    = document.getElementById('chatBtn');
    const codegenBtn = document.getElementById('codegenBtn');

    function log(line) {
        const div = document.createElement('div');
        div.className = 'log-line';
        const now = new Date();
        const t = document.createElement('time');
        t.textContent = now.toLocaleTimeString();
        div.appendChild(t);
        const span = document.createElement('span');
        span.textContent = ' ' + line;
        div.appendChild(span);
        logArea.prepend(div);
    }

    function selectTab(name) {
        document.querySelectorAll('.tab').forEach(tab => {
            tab.classList.toggle('active', tab.dataset.tab === name);
        });
        document.querySelectorAll('.out-pane').forEach(pane => {
            pane.classList.toggle('active', pane.id === 'pane-' + name);
        });
    }

    document.querySelectorAll('.tab').forEach(tab => {
        tab.addEventListener('click', () => {
            selectTab(tab.dataset.tab);
        });
    });

    async function apiRequest(path, options) {
        const url = path;
        const opts = Object.assign({
            method: 'GET',
            headers: {}
        }, options || {});
        lastCall.textContent = path;
        lastStatus.textContent = 'Calling ' + path + '…';
        try {
            const res = await fetch(url, opts);
            const text = await res.text();
            let parsed = null;
            try {
                parsed = JSON.parse(text);
            } catch (_) {
                parsed = { raw: text };
            }
            lastStatus.textContent = 'HTTP ' + res.status;
            log(path + ' → ' + res.status);
            return { status: res.status, json: parsed, raw: text };
        } catch (err) {
            lastStatus.textContent = 'Error';
            log('Error: ' + err.message);
            throw err;
        }
    }

    async function checkHealth() {
        try {
            const res = await apiRequest('/api/health', { method: 'GET' });
            if (res.status === 200 && res.json && res.json.status === 'ok') {
                healthText.textContent = 'API health OK (' + (res.json.source || 'http80') + ')';
            } else {
                healthText.textContent = 'API health check failed';
            }
        } catch (e) {
            healthText.textContent = 'Health check error';
        }
    }

    async function doChat() {
        const body = {
            prompt: promptInput.value,
            project: projectInput.value,
            brain: brainSelect.value,
            mode: modeSelect.value
        };
        const payload = JSON.stringify(body);
        chatBtn.disabled = true;
        codegenBtn.disabled = true;
        try {
            const res = await apiRequest('/api/chat', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: payload
            });
            jsonOut.textContent = JSON.stringify(res.json, null, 2);
            selectTab('json');
        } catch (e) {
            jsonOut.textContent = 'Error: ' + e.message;
            selectTab('json');
        } finally {
            chatBtn.disabled = false;
            codegenBtn.disabled = false;
        }
    }

    async function doCodegen() {
        const body = {
            prompt: promptInput.value,
            project: projectInput.value,
            brain: brainSelect.value,
            mode: modeSelect.value
        };
        const payload = JSON.stringify(body);
        chatBtn.disabled = true;
        codegenBtn.disabled = true;
        try {
            const res = await apiRequest('/api/codegen', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: payload
            });
            jsonOut.textContent = JSON.stringify(res.json, null, 2);

            if (res.json && res.json.html) {
                const doc = `
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>Preview</title>
</head>
<body>
${res.json.html}
</body>
</html>`;
                const blob = new Blob([doc], { type: 'text/html' });
                const url = URL.createObjectURL(blob);
                preview.src = url;
                selectTab('preview');
            } else {
                selectTab('json');
            }
        } catch (e) {
            jsonOut.textContent = 'Error: ' + e.message;
            selectTab('json');
        } finally {
            chatBtn.disabled = false;
            codegenBtn.disabled = false;
        }
    }

    chatBtn.addEventListener('click', doChat);
    codegenBtn.addEventListener('click', doCodegen);

    checkHealth();
})();
</script>
</body>
</html>
'@

Set-Content -Path $Agent3Path -Value $Agent3Html -Encoding UTF8
Say "[OK] Agent 3 UI written to $Agent3Path" "Green"

Say "`n[DONE] Agent 3 Vibe Coding UI is ready. Open: http://nifdu.com/agent3/`n" "Yellow"
