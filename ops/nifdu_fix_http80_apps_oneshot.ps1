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

$routerPath      = "C:\nifdu\src\http\router.cpp"
$routerBackup    = "C:\nifdu\src\http\router.cpp.bak"
$buildDir        = "C:\nifdu\build"
$nifduExe        = "C:\nifdu\build\Release\nifdu.exe"
$appsTestUrl1    = "http://127.0.0.1:8000/apps/dogs_karachi_site/index.html"
$appsTestUrl2    = "http://127.0.0.1:8000/apps/dogs_karachi_site/"

Say ""
Say "=== NIFDU HTTP80 /apps ROUTER FIX — ONE-SHOT ===" "Yellow"

# ----------------------------------------------------
# 1) Safety: ensure router.cpp exists, backup
# ----------------------------------------------------
if (-not (Test-Path $routerPath)) {
    Say ("ERROR: router.cpp not found at: {0}" -f $routerPath) "Red"
    exit 1
}

if (-not (Test-Path $routerBackup)) {
    Say ("Backing up router.cpp to: {0}" -f $routerBackup) "DarkCyan"
    Copy-Item -Path $routerPath -Destination $routerBackup -Force
} else {
    Say ("Backup already exists: {0}" -f $routerBackup) "DarkGray"
}

# ----------------------------------------------------
# 2) Write NEW router.cpp with /apps support
# ----------------------------------------------------
Say "Writing new router.cpp with /apps static app handler..." "Cyan"

$routerContent = @'
#include "router.hpp"
#include "http.hpp"

#include <nlohmann/json.hpp>
#include <string>
#include <fstream>
#include <sstream>
#include <algorithm>

using nlohmann::json;

// ---------------------------------------------------------------------
// Simple helpers for static file serving from C:\\webroot\\nifdu.com\\www
// ---------------------------------------------------------------------
namespace {

std::string webroot()
{
    // Single source of truth for HTTP80 static content
    return std::string("C:/webroot/nifdu.com/www");
}

std::string sanitize_path(const std::string& path)
{
    // Very small, safe normalizer:
    // - strip leading '/'
    // - reject ".." segments
    std::string p = path;
    if (!p.empty() && p[0] == '/') {
        p.erase(0, 1);
    }

    // If someone tries "../../", just block by returning empty
    if (p.find("..") != std::string::npos) {
        return std::string();
    }
    return p;
}

std::string read_file(const std::string& fullPath)
{
    std::ifstream in(fullPath, std::ios::binary);
    if (!in) {
        return std::string();
    }
    std::ostringstream ss;
    ss << in.rdbuf();
    return ss.str();
}

bool has_extension(const std::string& path, const std::string& ext)
{
    if (path.size() < ext.size()) return false;
    return std::equal(
        ext.rbegin(), ext.rend(),
        path.rbegin(),
        [](char a, char b) {
            return static_cast<char>(std::tolower(a)) == static_cast<char>(std::tolower(b));
        }
    );
}

} // namespace

// ---------------------------------------------------------------------
// Main router
// ---------------------------------------------------------------------
http::Response handle_request(const http::Request& request) {
    //
    // 1) Health checks
    //
    if (request.path == "/health" && request.method == "GET") {
        json obj;
        obj["status"] = "ok";
        obj["note"]   = "http80 brain stub online";
        obj["source"] = "nifdu_http80";
        return http::Response(200, obj.dump());
    }

    if (request.path == "/api/health" && request.method == "GET") {
        json obj;
        obj["status"]   = "ok";
        obj["note"]     = "api health on http80";
        obj["source"]   = "nifdu_http80";
        obj["endpoint"] = "/api/health";
        return http::Response(200, obj.dump());
    }

    //
    // 2) Agent 3 orchestrator — /api/codegen (POST on port 80/8000)
    //
    if ((request.path == "/api/codegen" || request.path == "/api/codegen/") &&
        request.method == "POST")
    {
        try {
            json body = json::parse(request.body.empty() ? "{}" : request.body);

            std::string project = body.value("project", std::string("project"));
            std::string prompt  = body.value("prompt",  std::string(""));
            std::string brain   = body.value("brain",   std::string("auto"));
            std::string mode    = body.value("mode",    std::string("vibe_coding"));

            json resp;
            resp["status"]   = "ok";
            resp["stub"]     = true;
            resp["endpoint"] = "/api/codegen";
            resp["project"]  = project;
            resp["brain"]    = brain;
            resp["mode"]     = mode;
            resp["prompt"]   = prompt;
            resp["note"]     = "NIFDU Agent 3 codegen stub on port 80/8000";

            // Simple HTML shell for preview tab
            std::string html;
            html += "<!DOCTYPE html>\n";
            html += "<html lang=\"en\">\n";
            html += "<head>\n";
            html += "  <meta charset=\"UTF-8\" />\n";
            html += "  <title>NIFDU Codegen Preview - " + project + "</title>\n";
            html += "  <style>";
            html += "body{background:#020617;color:#e5e7eb;font-family:system-ui,-apple-system,BlinkMacSystemFont,";
            html += "\"Segoe UI\",sans-serif;padding:40px;}";
            html += "h1{color:#22c55e;}";
            html += "pre{background:#020617;border:1px solid #334155;padding:16px;border-radius:8px;white-space:pre-wrap;}";
            html += "code{background:#111827;padding:2px 4px;border-radius:4px;}";
            html += "</style>\n";
            html += "</head>\n";
            html += "<body>\n";
            html += "  <h1>NIFDU Codegen Preview</h1>\n";
            html += "  <p>This HTML was generated by <code>/api/codegen</code> inside <b>nifdu.exe</b>.</p>\n";
            html += "  <p>Project: <b>" + project + "</b></p>\n";
            html += "  <p>Brain: <code>" + brain + "</code> (local / auto / openai)</p>\n";
            html += "  <h2>Original prompt</h2>\n";
            html += "  <pre>" + prompt + "</pre>\n";
            html += "</body>\n";
            html += "</html>\n";

            resp["html"] = html;
            return http::Response(200, resp.dump());
        }
        catch (const std::exception& e) {
            json err;
            err["status"]   = "error";
            err["endpoint"] = "/api/codegen";
            err["message"]  = e.what();
            return http::Response(500, err.dump());
        }
    }

    //
    // 3) /api/chat stub
    //
    if (request.path == "/api/chat") {
        // Support both GET (smoke test) and POST (real use)
        json body;
        try {
            if (request.method == "POST") {
                body = json::parse(request.body.empty() ? "{}" : request.body);
            } else {
                body = json::object();
            }
        } catch (...) {
            body = json::object();
        }

        std::string prompt = body.value("prompt", std::string(""));

        json resp;
        resp["brain"]    = "stub_http80";
        resp["context"]  = "NIFDU Agent 3 vibe coding UI wants a friendly C++ todo app.";
        resp["engine"]   = "nifdu_brain_stub";
        resp["mode"]     = body.value("mode", std::string("vibe_coding"));
        resp["model"]    = "gpt-4.1-mini";
        resp["prompt"]   = prompt;
        resp["provider"] = "openai";
        resp["response"] =
            u8"❤️ NIFDU Vibe Coding Stub:\n"
            "You hit /api/chat on port 80/8000.\n"
            "In the full system, this will fan out to OpenAI / llama.cpp / Ollama.\n"
            "Next: /api/codegen will produce file-level C++/HTML/etc.\n";
        resp["status"]   = "ok";

        return http::Response(200, resp.dump());
    }

    //
    // 4) WebSocket prices stub
    //
    if (request.path == "/api/ws/prices") {
        json resp;
        resp["ws_status"] = "ready";
        resp["message"]   = "Connect attempt successful (HTTP stub; real WebSocket to be implemented).";
        return http::Response(200, resp.dump());
    }

    //
    // 5) Static files: index + Agent 3 + static apps from webroot
    //
    // Root "/" -> index.html
    if (request.method == "GET" && (request.path == "/" || request.path == "")) {
        std::string fullPath = webroot() + "/index.html";
        std::string content  = read_file(fullPath);
        if (content.empty()) {
            return http::Response(404, "index.html not found in webroot");
        }
        return http::Response(200, content);
    }

    // /agent3 -> agent3/start.html
    if (request.method == "GET" &&
        (request.path == "/agent3" || request.path == "/agent3/"))
    {
        std::string fullPath = webroot() + "/agent3/start.html";
        std::string content  = read_file(fullPath);
        if (content.empty()) {
            return http::Response(404, "agent3/start.html not found in webroot");
        }
        return http::Response(200, content);
    }

    // /apps/<project>/[file] -> C:/webroot/nifdu.com/www/apps/<project>/...
    if (request.method == "GET" &&
        request.path.rfind("/apps/", 0) == 0)
    {
        // Everything after "/apps"
        std::string rel = request.path.substr(5); // "/dogs_karachi_site/" or "/dogs_karachi_site/index.html"

        if (rel.empty() || rel == "/") {
            // /apps/ -> /apps/index.html
            rel = "/index.html";
        } else {
            // If it ends with a slash, assume directory and append index.html
            if (!rel.empty() && rel.back() == '/') {
                rel += "index.html";
            }
            // If there is no dot at all, treat as directory and append /index.html
            else if (rel.find('.') == std::string::npos) {
                rel += "/index.html";
            }
        }

        const std::string fullPath = webroot() + "/apps" + rel;
        std::string content = read_file(fullPath);

        if (content.empty()) {
            return http::Response(404, "Static app file not found: " + fullPath);
        }
        return http::Response(200, content);
    }

    // Generic static handler for .html, .js, .css, images, etc.
    if (request.method == "GET") {
        if (has_extension(request.path, ".html") ||
            has_extension(request.path, ".js")   ||
            has_extension(request.path, ".css")  ||
            has_extension(request.path, ".json") ||
            has_extension(request.path, ".png")  ||
            has_extension(request.path, ".jpg")  ||
            has_extension(request.path, ".jpeg") ||
            has_extension(request.path, ".gif")  ||
            has_extension(request.path, ".ico"))
        {
            std::string rel = sanitize_path(request.path);
            if (rel.empty()) {
                return http::Response(400, "Bad path");
            }

            std::string fullPath = webroot() + "/" + rel;
            std::string content  = read_file(fullPath);
            if (content.empty()) {
                return http::Response(404, "Static file not found");
            }
            return http::Response(200, content);
        }
    }

    //
    // 6) Default catch-all
    //
    return http::Response(404, "Not Found");
}
'@

Set-Content -Path $routerPath -Value $routerContent -Encoding UTF8
Say "router.cpp updated." "Green"

# ----------------------------------------------------
# 3) Rebuild and restart nifdu
# ----------------------------------------------------
Say "Stopping existing nifdu.exe (if any)..." "DarkGray"
Stop-Process -Name nifdu -Force -ErrorAction SilentlyContinue

Say "Building NIFDU (Release)..." "Cyan"
Push-Location $buildDir
cmake --build . --config Release
Pop-Location

Say "Starting nifdu.exe..." "Cyan"
Start-Process $nifduExe

Start-Sleep -Seconds 2

# ----------------------------------------------------
# 4) Smoke-test /apps/dogs_karachi_site
# ----------------------------------------------------
Say ""
Say "=== HTTP80 /apps DOGS KARACHI SITE SMOKE TEST ===" "Yellow"

function Test-Url {
    param([string]$Url)

    try {
        $resp = Invoke-WebRequest -Uri $Url -UseBasicParsing -ErrorAction Stop
        $snippet = $resp.Content.Substring(0, [Math]::Min(200, $resp.Content.Length))
        Say ("URL: {0}" -f $Url) "Cyan"
        Say ("StatusCode: {0}" -f $resp.StatusCode) "Green"
        Say "Snippet:" "Gray"
        Say $snippet "Gray"
        Say "----" "DarkGray"
    } catch {
        Say ("URL: {0}" -f $Url) "Cyan"
        Say ("ERROR: {0}" -f $_.Exception.Message) "Red"
        if ($_.Exception.Response -and $_.Exception.Response.ContentLength -gt 0) {
            try {
                $body = (New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())).ReadToEnd()
                Say "Body:" "Gray"
                Say $body "Gray"
            } catch {}
        }
        Say "----" "DarkGray"
    }
}

Test-Url $appsTestUrl1
Test-Url $appsTestUrl2

Say ""
Say "=== DONE: NIFDU HTTP80 /apps ROUTER FIX ===" "Yellow"
Say ""
