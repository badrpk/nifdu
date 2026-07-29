cd C:\nifdu\ops

@'
# ==============================================
# C:\nifdu\ops\nifdu_make_vibe_studio_full.ps1
# NIFDU Vibe Studio - Full product setup (HTTP80)
# ----------------------------------------------
# - Backs up nifdu_http_server80.cpp
# - Rewrites it with:
#     * Root -> Vibe Studio web app
#     * /agent3 -> in-memory Agent 3 UI
#     * Product APIs for projects/files/vibe/run
#     * /api/av/render stub
# - Creates static Vibe Studio web UI under:
#     C:\webroot\nifdu.com\www\apps\nifdu_vibe_studio\index.html
# - Rebuilds and restarts nifdu.exe
# ==============================================

$ErrorActionPreference = "Stop"

function Say {
    param([string]$m, [string]$c = "Gray")
    try {
        $old = [Console]::ForegroundColor
        [Console]::ForegroundColor = $c
        Write-Host $m
        [Console]::ForegroundColor = $old
    } catch {
        Write-Host $m
    }
}

$Root        = "C:\nifdu"
$SrcHttp80   = Join-Path $Root "src\http\nifdu_http_server80.cpp"
$BuildDir    = Join-Path $Root "build"
$ExePath     = Join-Path $BuildDir "Release\nifdu.exe"
$WebAppsRoot = "C:\webroot\nifdu.com\www\apps\nifdu_vibe_studio"
$ProjectsDir = "C:\nifdu\projects"

Say "`n=== NIFDU VIBE STUDIO — FULL PRODUCT SETUP ===`n" "Yellow"

# ----------------------------------------------
# 1) Backup old HTTP80 server file
# ----------------------------------------------
if (!(Test-Path $SrcHttp80)) {
    Say "[FATAL] Cannot find $SrcHttp80" "Red"
    exit 1
}

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backup = "$SrcHttp80.bak_vibestudio_$stamp"
Copy-Item $SrcHttp80 $backup -Force
Say "Backed up nifdu_http_server80.cpp -> $backup" "Cyan"

# ----------------------------------------------
# 2) Write new HTTP80 server implementation
# ----------------------------------------------
$cpp = @'
// src/http/nifdu_http_server80.cpp
// HTTP/1.1 server on port 80 for NIFDU Vibe Studio + Agent 3

#include <boost/asio.hpp>
#include <boost/beast/core.hpp>
#include <boost/beast/http.hpp>
#include <boost/beast/version.hpp>

#include <nlohmann/json.hpp>
#include "nifdu_http_ai_missing.hpp"

#include <iostream>
#include <string>
#include <thread>
#include <utility>
#include <fstream>
#include <filesystem>

#include "nifdu_http80_common.hpp"
#include "nifdu_http80_openai.hpp"
#include "nifdu_http80_ui.hpp"

namespace asio = boost::asio;
using tcp      = asio::ip::tcp;
namespace http = boost::beast::http;
using json     = nlohmann::json;

namespace nifdu {
namespace http80 {

namespace {

const std::string PROJECT_ROOT = "C:/nifdu/projects";

// Simple helpers for file I/O and project filesystem layout
bool ensure_parent_directory(const std::string& fullPath)
{
    std::error_code ec;
    std::filesystem::path p(fullPath);
    auto parent = p.parent_path();
    if (parent.empty()) return true;
    std::filesystem::create_directories(parent, ec);
    return !ec;
}

bool write_text_file(const std::string& fullPath, const std::string& content)
{
    if (!ensure_parent_directory(fullPath)) {
        std::cerr << "[NIFDU::http80] Failed to create parent directories for: "
                  << fullPath << std::endl;
        return false;
    }
    std::ofstream ofs(fullPath, std::ios::binary);
    if (!ofs) {
        std::cerr << "[NIFDU::http80] Failed to open for write: "
                  << fullPath << std::endl;
        return false;
    }
    ofs << content;
    return ofs.good();
}

std::string project_base_path(const std::string& projectSlug)
{
    return PROJECT_ROOT + "/" + projectSlug;
}

json list_projects()
{
    json arr = json::array();
    std::error_code ec;

    std::filesystem::path root(PROJECT_ROOT);
    if (!std::filesystem::exists(root, ec)) {
        return arr;
    }

    for (auto& entry : std::filesystem::directory_iterator(root, ec)) {
        if (ec) break;
        if (!entry.is_directory()) continue;
        json p;
        p["slug"] = entry.path().filename().string();
        p["name"] = p["slug"];
        arr.push_back(p);
    }
    return arr;
}

json list_files_for_project(const std::string& project)
{
    json arr = json::array();
    std::error_code ec;

    std::filesystem::path base(project_base_path(project));
    if (!std::filesystem::exists(base, ec)) {
        return arr;
    }

    for (auto& entry : std::filesystem::recursive_directory_iterator(base, ec)) {
        if (ec) break;
        if (!entry.is_regular_file()) continue;
        auto rel = std::filesystem::relative(entry.path(), base, ec);
        if (ec) continue;
        arr.push_back(rel.generic_string());
    }
    return arr;
}

std::string read_text_file(const std::string& fullPath)
{
    return read_file(fullPath); // reuse helper from nifdu_http80_common.hpp
}

// --------------------------------------------------
// Request handler
// --------------------------------------------------
http::response<http::string_body>
handle_request(http::request<http::string_body>&& req)
{
    http::response<http::string_body> res{ http::status::ok, req.version() };
    res.set(http::field::server, "NIFDU-http80");
    res.keep_alive(req.keep_alive());

    const std::string target = std::string(req.target());

    // NIFDU - Missing AI/List API stubs (auto-wired)
    if (target == "/api/list") {
        return nifdu::http80::ai_missing::handle_api_list(req);
    } else if (target == "/api/ai/embed") {
        return nifdu::http80::ai_missing::handle_ai_embed(req);
    } else if (target == "/api/ai/models") {
        return nifdu::http80::ai_missing::handle_ai_models(req);
    } else if (target == "/api/ai/config") {
        return nifdu::http80::ai_missing::handle_ai_config(req);
    } else if (target == "/api/ai/recall") {
        return nifdu::http80::ai_missing::handle_ai_recall(req);
    }

    // ==================================================
    // GET / -> redirect to Vibe Studio product UI
    // ==================================================
    if (req.method() == http::verb::get &&
        (target == "/" || target == "/index" || target == "/index.html"))
    {
        res.result(http::status::temporary_redirect);
        res.set(http::field::location, "/apps/nifdu_vibe_studio/");
        res.set(http::field::content_type, "text/plain; charset=utf-8");
        res.body() = "Redirecting to /apps/nifdu_vibe_studio/ ...";
        res.prepare_payload();
        return res;
    }

    // ==================================================
    // GET /agent3* -> in-memory Agent 3 UI (for advanced use)
    // ==================================================
    if (req.method() == http::verb::get &&
        (target == "/agent3" ||
         target == "/agent3/" ||
         target == "/agent3/start.html"))
    {
        res.set(http::field::content_type, "text/html; charset=utf-8");
        res.body() = NIFDU_UI_HTML;
        res.prepare_payload();
        return res;
    }

    // ==================================================
    // GET /health
    // ==================================================
    if (req.method() == http::verb::get && target == "/health") {
        json body = {
            {"status", "ok"},
            {"source", "nifdu_http80"},
            {"note",   "http80 brain online (OpenAI fan-out + Agent3 + Vibe Studio)"}
        };
        res.set(http::field::content_type, "application/json; charset=utf-8");
        res.body() = body.dump();
        res.prepare_payload();
        return res;
    }

    // ==================================================
    // Static apps: /apps/<project>/[file]
    // ==================================================
    if (req.method() == http::verb::get && target.rfind("/apps/", 0) == 0) {
        std::string rel = target.substr(5); // after "/apps"
        if (rel.empty() || rel == "/") {
            rel = "/index.html";
        } else if (!rel.empty() && rel.back() == '/') {
            rel += "index.html";
        }

        const std::string fullPath = "C:/webroot/nifdu.com/www/apps" + rel;
        std::string content = read_file(fullPath);

        if (content.empty()) {
            res.result(http::status::not_found);
            json not_found = {
                {"error",  "not_found"},
                {"target", target},
                {"path",   fullPath}
            };
            res.set(http::field::content_type, "application/json; charset=utf-8");
            res.body() = not_found.dump();
            res.prepare_payload();
            return res;
        }

        if (has_suffix(fullPath, ".html") || has_suffix(fullPath, ".htm")) {
            res.set(http::field::content_type, "text/html; charset=utf-8");
        } else if (has_suffix(fullPath, ".css")) {
            res.set(http::field::content_type, "text/css; charset=utf-8");
        } else if (has_suffix(fullPath, ".js")) {
            res.set(http::field::content_type, "application/javascript; charset=utf-8");
        } else if (has_suffix(fullPath, ".png")) {
            res.set(http::field::content_type, "image/png");
        } else if (has_suffix(fullPath, ".jpg") || has_suffix(fullPath, ".jpeg")) {
            res.set(http::field::content_type, "image/jpeg");
        } else if (has_suffix(fullPath, ".gif")) {
            res.set(http::field::content_type, "image/gif");
        } else {
            res.set(http::field::content_type, "text/plain; charset=utf-8");
        }

        res.body() = std::move(content);
        res.prepare_payload();
        return res;
    }

    // ==================================================
    // POST /api/chat  (Agent 3 brain)
    // ==================================================
    if (req.method() == http::verb::post && target == "/api/chat") {
        json in = json::object();
        std::string mode    = "chat";
        std::string prompt  = "";
        std::string context = "";
        std::string project = "ad_hoc_project";
        std::string brain   = "auto";

        std::string ctype;
        auto it_ct = req.base().find(http::field::content_type);
        if (it_ct != req.base().end()) {
            ctype = std::string(req[http::field::content_type]);
        }

        try {
            if (!req.body().empty() &&
                ctype.find("application/json") != std::string::npos) {
                in      = json::parse(req.body());
                mode    = in.value("mode",    mode);
                prompt  = in.value("prompt",  prompt);
                context = in.value("context", context);
                project = in.value("project", project);
                brain   = in.value("brain",   brain);
            }
            else if (!req.body().empty() &&
                     ctype.find("application/x-www-form-urlencoded") != std::string::npos) {
                auto fields = parse_form_urlencoded(req.body());
                if (fields.count("mode"))    mode    = fields["mode"];
                if (fields.count("prompt"))  prompt  = fields["prompt"];
                if (fields.count("context")) context = fields["context"];
                if (fields.count("project")) project = fields["project"];

                in["mode"]    = mode;
                in["prompt"]  = prompt;
                in["context"] = context;
                in["project"] = project;
                in["brain"]   = brain;
            }
            else {
                prompt = req.body();
                in["mode"]    = mode;
                in["prompt"]  = prompt;
                in["context"] = context;
                in["project"] = project;
                in["brain"]   = brain;
            }
        } catch (...) {
            prompt = req.body();
            in["mode"]    = mode;
            in["prompt"]  = prompt;
            in["context"] = context;
            in["project"] = project;
            in["brain"]   = brain;
        }

        json out;
        try {
            const std::string provider = getenv_str("NIFDU_BRAIN_PROVIDER", "auto");
            if (provider == "openai" || provider == "auto") {
                out = call_openai_chat_agent3(in);
            } else {
                out["status"]   = "ok";
                out["engine"]   = "nifdu_brain_stub";
                out["provider"] = provider;
                out["model"]    = "nifdu_stub";
                out["mode"]     = mode;
                out["project"]  = project;
                out["prompt"]   = prompt;
                out["context"]  = context;
                out["notes"]    = json::array({
                    "NIFDU_BRAIN_PROVIDER is not openai/auto, using stub.",
                    "Set NIFDU_BRAIN_PROVIDER=openai and OPENAI_API_KEY to enable real brain."
                });
                out["plan"]  = json::array();
                out["files"] = json::array();
            }
        } catch (const std::exception& ex) {
            out["status"] = "error";
            out["error"]  = ex.what();
            out["engine"] = "openai";
            out["model"]  = getenv_str("NIFDU_OPENAI_MODEL", "gpt-4.1-mini");
        }

        res.set(http::field::content_type, "application/json; charset=utf-8");
        res.body() = out.dump(2);
        res.prepare_payload();
        return res;
    }

    // ==================================================
    // POST /api/codegen  (Agent 3 codegen - low level)
    // (still exposed for tools; Vibe Studio uses /api/vibe/prompt)
    // ==================================================
    if (req.method() == http::verb::post && target == "/api/codegen") {
        json in = json::object();
        try {
            if (!req.body().empty()) {
                in = json::parse(req.body());
            }
        } catch (...) {
            in = json::object();
        }

        json out;
        try {
            const std::string provider = getenv_str("NIFDU_BRAIN_PROVIDER", "auto");
            if (provider == "openai" || provider == "auto") {
                out = call_openai_codegen_agent3(in);
            } else {
                std::string project = in.value("project", std::string("project"));
                std::string prompt  = in.value("prompt",  std::string(""));
                std::string brain   = in.value("brain",   std::string("auto"));
                std::string mode    = in.value("mode",    std::string("vibe_coding"));

                out["status"]     = "ok";
                out["stub"]       = true;
                out["endpoint"]   = "/api/codegen";
                out["project"]    = project;
                out["brain"]      = brain;
                out["mode"]       = mode;
                out["prompt"]     = prompt;
                out["note"]       = "NIFDU Agent 3 codegen stub (provider not openai/auto)";
                out["files"]      = json::array();
                out["post_steps"] = json::array();
                out["notes"]      = json::array({
                    "Set NIFDU_BRAIN_PROVIDER=openai and OPENAI_API_KEY to enable real codegen."
                });
            }
        } catch (const std::exception& ex) {
            out["status"] = "error";
            out["error"]  = ex.what();
            out["engine"] = "openai";
            out["model"]  = getenv_str("NIFDU_OPENAI_MODEL", "gpt-4.1-mini");
        }

        res.set(http::field::content_type, "application/json; charset=utf-8");
        res.body() = out.dump(2);
        res.prepare_payload();
        return res;
    }

    // ==================================================
    // POST /api/ai/complete  (simple stub)
    // ==================================================
    if (req.method() == http::verb::post && target == "/api/ai/complete") {
        json body_json;
        std::string prompt;

        std::string ctype;
        auto it_ct = req.base().find(http::field::content_type);
        if (it_ct != req.base().end()) {
            ctype = std::string(req[http::field::content_type]);
        }

        try {
            if (!req.body().empty() &&
                ctype.find("application/json") != std::string::npos) {
                body_json = json::parse(req.body());
                prompt    = body_json.value("prompt", "");
            } else {
                prompt = req.body();
            }
        } catch (...) {
            prompt = req.body();
        }

        json out;
        out["status"]   = "ok";
        out["engine"]   = "nifdu_ai_complete_stub";
        out["provider"] = "openai";
        out["model"]    = "gpt-4.1-mini";
        out["prompt"]   = prompt;
        out["mode"]     = body_json.value("mode", "complete");
        out["text"]     =
            "This is a stub completion from NIFDU http80.\n"
            "The real AI fan-out (OpenAI/Ollama/llama.cpp) will plug in here.\n";

        res.set(http::field::content_type, "application/json; charset=utf-8");
        res.body() = out.dump(2);
        res.prepare_payload();
        return res;
    }

    // ==================================================
    // PRODUCT APIs: projects / files / vibe / run
    // ==================================================

    // POST /api/projects/list
    if (req.method() == http::verb::post && target == "/api/projects/list") {
        json out;
        out["status"]   = "ok";
        out["projects"] = list_projects();
        res.set(http::field::content_type, "application/json; charset=utf-8");
        res.body() = out.dump(2);
        res.prepare_payload();
        return res;
    }

    // POST /api/projects/create  { project, name? }
    if (req.method() == http::verb::post && target == "/api/projects/create") {
        json in = json::object();
        try {
            if (!req.body().empty()) in = json::parse(req.body());
        } catch (...) {
            in = json::object();
        }

        std::string project = in.value("project", std::string("ad_hoc_project"));
        std::filesystem::path base(project_base_path(project));

        json out;
        std::error_code ec;
        std::filesystem::create_directories(base, ec);
        if (ec) {
            out["status"] = "error";
            out["error"]  = "failed_to_create_project_directory";
            out["project"] = project;
        } else {
            out["status"]  = "ok";
            out["project"] = project;
        }

        res.set(http::field::content_type, "application/json; charset=utf-8");
        res.body() = out.dump(2);
        res.prepare_payload();
        return res;
    }

    // POST /api/files/list  { project }
    if (req.method() == http::verb::post && target == "/api/files/list") {
        json in = json::object();
        try {
            if (!req.body().empty()) in = json::parse(req.body());
        } catch (...) {
            in = json::object();
        }
        std::string project = in.value("project", std::string("ad_hoc_project"));

        json out;
        out["status"] = "ok";
        out["project"] = project;
        out["files"] = list_files_for_project(project);

        res.set(http::field::content_type, "application/json; charset=utf-8");
        res.body() = out.dump(2);
        res.prepare_payload();
        return res;
    }

    // POST /api/file/get  { project, path }
    if (req.method() == http::verb::post && target == "/api/file/get") {
        json in = json::object();
        try {
            if (!req.body().empty()) in = json::parse(req.body());
        } catch (...) {
            in = json::object();
        }

        std::string project = in.value("project", std::string("ad_hoc_project"));
        std::string pathRel = in.value("path",    std::string(""));

        json out;
        if (pathRel.empty()) {
            out["status"] = "error";
            out["error"]  = "missing_path";
        } else {
            std::filesystem::path full = std::filesystem::path(project_base_path(project)) / pathRel;
            std::string content = read_text_file(full.generic_string());
            out["status"]  = "ok";
            out["project"] = project;
            out["path"]    = pathRel;
            out["content"] = content;
        }

        res.set(http::field::content_type, "application/json; charset=utf-8");
        res.body() = out.dump(2);
        res.prepare_payload();
        return res;
    }

    // POST /api/file/save  { project, path, content }
    if (req.method() == http::verb::post && target == "/api/file/save") {
        json in = json::object();
        try {
            if (!req.body().empty()) in = json::parse(req.body());
        } catch (...) {
            in = json::object();
        }

        std::string project = in.value("project", std::string("ad_hoc_project"));
        std::string pathRel = in.value("path",    std::string(""));
        std::string content = in.value("content", std::string(""));

        json out;
        if (pathRel.empty()) {
            out["status"] = "error";
            out["error"]  = "missing_path";
        } else {
            std::filesystem::path full = std::filesystem::path(project_base_path(project)) / pathRel;
            bool ok = write_text_file(full.generic_string(), content);
            out["status"]  = ok ? "ok" : "error";
            if (!ok) out["error"] = "write_failed";
            out["project"] = project;
            out["path"]    = pathRel;
        }

        res.set(http::field::content_type, "application/json; charset=utf-8");
        res.body() = out.dump(2);
        res.prepare_payload();
        return res;
    }

    // POST /api/vibe/prompt  { project, prompt }
    if (req.method() == http::verb::post && target == "/api/vibe/prompt") {
        json in = json::object();
        try {
            if (!req.body().empty()) in = json::parse(req.body());
        } catch (...) {
            in = json::object();
        }

        std::string project = in.value("project", std::string("ad_hoc_project"));
        std::string prompt  = in.value("prompt",  std::string(""));

        json codegen_in;
        codegen_in["project"] = project;
        codegen_in["prompt"]  = prompt;
        codegen_in["brain"]   = "auto";
        codegen_in["mode"]    = "vibe_coding";

        json out;
        try {
            out = call_openai_codegen_agent3(codegen_in);
        } catch (const std::exception& ex) {
            json err;
            err["status"] = "error";
            err["error"]  = ex.what();
            res.set(http::field::content_type, "application/json; charset=utf-8");
            res.body() = err.dump(2);
            res.prepare_payload();
            return res;
        }

        // Rewrite files[] to project filesystem and normalize paths
        json newFiles = json::array();
        if (out.contains("files") && out["files"].is_array()) {
            for (const auto& f : out["files"]) {
                std::string relPath = f.value("path", std::string("main.cpp"));
                if (relPath.empty()) relPath = "main.cpp";

                std::filesystem::path p(relPath);
                if (p.is_absolute()) {
                    relPath = p.filename().string();
                }

                std::filesystem::path full =
                    std::filesystem::path(project_base_path(project)) / relPath;

                std::string content = f.value("content", std::string(""));
                write_text_file(full.generic_string(), content);

                json nf = f;
                nf["path"] = relPath; // project-relative
                newFiles.push_back(nf);
            }
        }
        out["files"] = newFiles;
        out["project"] = project;

        res.set(http::field::content_type, "application/json; charset=utf-8");
        res.body() = out.dump(2);
        res.prepare_payload();
        return res;
    }

    // POST /api/run  { project, command }
    // For now this is a stub that does not actually execute commands.
    if (req.method() == http::verb::post && target == "/api/run") {
        json in = json::object();
        try {
            if (!req.body().empty()) in = json::parse(req.body());
        } catch (...) {
            in = json::object();
        }

        std::string project = in.value("project", std::string("ad_hoc_project"));
        std::string command = in.value("command", std::string(""));

        json out;
        out["status"]  = "ok";
        out["project"] = project;
        out["command"] = command;
        out["log"]     = "Run endpoint stub. Wire this to your build/run pipeline (PowerShell or C++).";

        res.set(http::field::content_type, "application/json; charset=utf-8");
        res.body() = out.dump(2);
        res.prepare_payload();
        return res;
    }

    // ==================================================
    // POST /api/av/render  (NIFDU AV stub)
    // ==================================================
    if (req.method() == http::verb::post && target == "/api/av/render") {
        json body_json = json::object();

        try {
            if (!req.body().empty()) {
                body_json = json::parse(req.body());
            }
        } catch (...) {
            body_json = json::object();
        }

        const std::string project = body_json.value("project", std::string("av_demo_cat"));
        const std::string prompt  = body_json.value(
            "prompt",
            std::string("show me a short cat video: a cartoon cat moving left to right")
        );
        const std::string mode    = body_json.value("mode",   std::string("video"));
        const std::string format  = body_json.value("format", std::string("mp4"));

        json out;
        out["status"]  = "ok";
        out["engine"]  = "nifdu_av_stub";
        out["project"] = project;
        out["prompt"]  = prompt;
        out["mode"]    = mode;
        out["format"]  = format;
        out["video"] = {
            { "public_url", "/media/generated/av_latest.mp4" },
            { "disk_path",  "C:/webroot/nifdu.com/www/media/generated/av_latest.mp4" }
        };

        res.set(http::field::content_type, "application/json; charset=utf-8");
        res.body() = out.dump(2);
        res.prepare_payload();
        return res;
    }

    // ==================================================
    // Fallback 404
    // ==================================================
    res.result(http::status::not_found);
    json not_found = {
        {"error",  "not_found"},
        {"target", target}
    };
    res.set(http::field::content_type, "application/json; charset=utf-8");
    res.body() = not_found.dump();
    res.prepare_payload();
    return res;
}

// --------------------------------------------------
// Session: one TCP connection
// --------------------------------------------------
void do_session(tcp::socket socket)
{
    try {
        bool close = false;
        boost::beast::flat_buffer buffer;

        while (!close) {
            http::request<http::string_body> req;

            boost::system::error_code ec;
            http::read(socket, buffer, req, ec);

            if (ec == http::error::end_of_stream) {
                break;
            }
            if (ec) {
                std::cerr << "[NIFDU::http80] Read error: " << ec.message() << std::endl;
                break;
            }

            auto res = handle_request(std::move(req));
            close    = res.need_eof();

            http::write(socket, res, ec);
            if (ec) {
                std::cerr << "[NIFDU::http80] Write error: " << ec.message() << std::endl;
                break;
            }
        }

        boost::system::error_code ec;
        socket.shutdown(tcp::socket::shutdown_send, ec);
    }
    catch (const std::exception& e) {
        std::cerr << "[NIFDU::http80] Session error: " << e.what() << std::endl;
    }
}

} // anonymous namespace

// --------------------------------------------------
// Public entry point (called from main.cpp)
// --------------------------------------------------
void start_server80()
{
    try {
        asio::io_context ioc{1};
        tcp::acceptor acceptor{ioc, tcp::endpoint{tcp::v4(), 80}};

        std::cout << "[NIFDU::http80] Listening on 0.0.0.0:80" << std::endl;

        for (;;) {
            tcp::socket socket{ioc};
            acceptor.accept(socket);
            std::thread{ &do_session, std::move(socket) }.detach();
        }
    }
    catch (const std::exception& e) {
        std::cerr << "[NIFDU::http80] start_server80 exception: " << e.what() << std::endl;
    }
}

} // namespace http80
} // namespace nifdu
'@

$cpp | Set-Content -Encoding UTF8 $SrcHttp80
Say "Updated $SrcHttp80 with Vibe Studio HTTP80 server." "Green"

# ----------------------------------------------
# 3) Create projects root + Vibe Studio web app
# ----------------------------------------------
New-Item -ItemType Directory -Force -Path $ProjectsDir | Out-Null
New-Item -ItemType Directory -Force -Path $WebAppsRoot | Out-Null

$html = @'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>NIFDU Vibe Studio</title>
  <style>
    body {
      margin: 0;
      font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      background: #020617;
      color: #e5e7eb;
      display: flex;
      height: 100vh;
    }
    .sidebar {
      width: 220px;
      border-right: 1px solid #1f2937;
      padding: 12px;
      box-sizing: border-box;
      background: #020617;
    }
    .sidebar h1 {
      font-size: 16px;
      margin: 0 0 8px 0;
      color: #22c55e;
    }
    select, input, button, textarea {
      font-family: inherit;
      font-size: 13px;
    }
    .sidebar label {
      font-size: 11px;
      text-transform: uppercase;
      color: #9ca3af;
      display: block;
      margin-top: 8px;
      margin-bottom: 2px;
    }
    .sidebar button {
      margin-top: 4px;
      width: 100%;
      padding: 6px 8px;
      border-radius: 6px;
      border: none;
      cursor: pointer;
    }
    .sidebar button.primary {
      background: #22c55e;
      color: #020617;
      font-weight: 600;
    }
    .sidebar button.secondary {
      background: #111827;
      color: #e5e7eb;
    }
    .file-list {
      margin-top: 8px;
      background: #020617;
      border: 1px solid #111827;
      border-radius: 6px;
      padding: 4px;
      max-height: 50vh;
      overflow-y: auto;
      font-size: 12px;
    }
    .file-item {
      padding: 2px 4px;
      border-radius: 4px;
      cursor: pointer;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    .file-item:hover {
      background: #1f2937;
    }
    .file-item.active {
      background: #22c55e;
      color: #020617;
    }
    .main {
      flex: 1;
      display: flex;
      flex-direction: column;
    }
    .top-bar {
      padding: 8px 12px;
      border-bottom: 1px solid #1f2937;
      font-size: 13px;
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    .top-bar span.brand {
      color: #22c55e;
      font-weight: 600;
    }
    .top-bar span.sub {
      color: #9ca3af;
      margin-left: 6px;
    }
    .top-bar button {
      padding: 4px 10px;
      border-radius: 6px;
      border: none;
      background: #111827;
      color: #e5e7eb;
      cursor: pointer;
      font-size: 12px;
    }
    .panes {
      flex: 1;
      display: grid;
      grid-template-columns: 1.2fr 1fr;
      gap: 0;
      min-height: 0;
    }
    .pane {
      display: flex;
      flex-direction: column;
      border-right: 1px solid #1f2937;
    }
    .pane:last-child {
      border-right: none;
    }
    .pane-header {
      padding: 6px 10px;
      border-bottom: 1px solid #1f2937;
      font-size: 12px;
      color: #9ca3af;
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    .pane-body {
      flex: 1;
      display: flex;
      flex-direction: column;
      padding: 8px;
      box-sizing: border-box;
      min-height: 0;
    }
    textarea.code-editor {
      flex: 1;
      resize: none;
      background: #020617;
      color: #e5e7eb;
      border-radius: 6px;
      border: 1px solid #111827;
      padding: 8px;
      font-family: "JetBrains Mono", Consolas, monospace;
      font-size: 12px;
      box-sizing: border-box;
    }
    textarea.prompt-box {
      width: 100%;
      height: 90px;
      resize: none;
      background: #020617;
      color: #e5e7eb;
      border-radius: 6px;
      border: 1px solid #111827;
      padding: 6px;
      font-size: 12px;
      box-sizing: border-box;
    }
    .button-row {
      margin-top: 6px;
      display: flex;
      gap: 6px;
    }
    .button-row button {
      padding: 5px 8px;
      border-radius: 6px;
      border: none;
      cursor: pointer;
      font-size: 12px;
    }
    .button-row button.primary {
      background: #22c55e;
      color: #020617;
      font-weight: 600;
    }
    .button-row button.secondary {
      background: #111827;
      color: #e5e7eb;
    }
    .log-box {
      flex: 1;
      margin-top: 6px;
      background: #020617;
      border-radius: 6px;
      border: 1px solid #111827;
      padding: 6px;
      font-size: 11px;
      overflow-y: auto;
      white-space: pre-wrap;
      box-sizing: border-box;
    }
    .status-bar {
      padding: 4px 8px;
      font-size: 11px;
      color: #9ca3af;
    }
    .status-bar span.ok {
      color: #22c55e;
    }
    .status-bar span.err {
      color: #ef4444;
    }
  </style>
</head>
<body>
  <div class="sidebar">
    <h1>NIFDU Vibe Studio</h1>
    <label>Project</label>
    <select id="projectSelect"></select>
    <input id="newProjectInput" type="text" placeholder="new_project_slug" style="width:100%;margin-top:4px;padding:4px 6px;border-radius:6px;border:1px solid #111827;background:#020617;color:#e5e7eb;box-sizing:border-box;">
    <button class="secondary" onclick="createProject()">Create Project</button>

    <label style="margin-top:10px;">Files</label>
    <div id="fileList" class="file-list"></div>
  </div>

  <div class="main">
    <div class="top-bar">
      <div>
        <span class="brand">NIFDU</span>
        <span class="sub">Vibe Coding Studio (local)</span>
      </div>
      <div>
        <button onclick="window.open('/agent3/', '_blank')">Open Agent 3 UI</button>
      </div>
    </div>

    <div class="panes">
      <div class="pane">
        <div class="pane-header">
          <span>Code Editor</span>
          <button onclick="saveFile()" style="background:#22c55e;color:#020617;border-radius:6px;border:none;padding:3px 8px;font-size:11px;cursor:pointer;">Save</button>
        </div>
        <div class="pane-body">
          <div style="font-size:11px;color:#9ca3af;margin-bottom:4px;">
            <span id="currentFileLabel">No file selected</span>
          </div>
          <textarea id="codeEditor" class="code-editor" placeholder="Select or generate a file to start editing." ></textarea>
        </div>
      </div>

      <div class="pane">
        <div class="pane-header">
          <span>Vibe Prompt / Run</span>
        </div>
        <div class="pane-body">
          <div style="font-size:11px;color:#9ca3af;margin-bottom:2px;">Describe what you want to build:</div>
          <textarea id="promptBox" class="prompt-box" placeholder="Example: Build a todo app with C++ backend and HTML frontend."></textarea>
          <div class="button-row">
            <button class="primary" onclick="sendVibePrompt()">Generate / Refine</button>
            <button class="secondary" onclick="runProject()">Run (stub)</button>
          </div>
          <div class="log-box" id="logBox">Waiting for first run...</div>
        </div>
      </div>
    </div>
    <div class="status-bar">
      Status:
      <span id="statusText" class="ok">Ready</span>
    </div>
  </div>

<script>
let currentProject = null;
let currentFile = null;

function setStatus(text, isError) {
  const el = document.getElementById('statusText');
  el.textContent = text;
  el.className = isError ? 'err' : 'ok';
}

async function apiPost(path, body) {
  const res = await fetch(path, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: body ? JSON.stringify(body) : '{}'
  });
  const text = await res.text();
  try {
    return JSON.parse(text);
  } catch (e) {
    throw new Error('Server did not return JSON: ' + text.slice(0, 200));
  }
}

async function loadProjects() {
  setStatus('Loading projects...', false);
  try {
    const data = await apiPost('/api/projects/list', {});
    const sel = document.getElementById('projectSelect');
    sel.innerHTML = '';
    const projects = data.projects || [];
    if (projects.length === 0) {
      // create default project
      await apiPost('/api/projects/create', { project: 'ad_hoc_project' });
      return loadProjects();
    }
    projects.forEach(p => {
      const opt = document.createElement('option');
      opt.value = p.slug;
      opt.textContent = p.slug;
      sel.appendChild(opt);
    });
    currentProject = sel.value;
    sel.onchange = () => {
      currentProject = sel.value;
      loadFiles();
    };
    await loadFiles();
    setStatus('Projects loaded.', false);
  } catch (e) {
    console.error(e);
    setStatus('Error loading projects: ' + e.message, true);
  }
}

async function createProject() {
  const inp = document.getElementById('newProjectInput');
  const slug = inp.value.trim();
  if (!slug) {
    alert('Enter a project slug.');
    return;
  }
  setStatus('Creating project...', false);
  try {
    await apiPost('/api/projects/create', { project: slug });
    inp.value = '';
    await loadProjects();
    setStatus('Project created.', false);
  } catch (e) {
    console.error(e);
    setStatus('Error creating project: ' + e.message, true);
  }
}

function renderFileList(files) {
  const listEl = document.getElementById('fileList');
  listEl.innerHTML = '';
  files.forEach(path => {
    const div = document.createElement('div');
    div.className = 'file-item' + (path === currentFile ? ' active' : '');
    div.textContent = path;
    div.onclick = () => {
      currentFile = path;
      loadFile();
      renderFileList(files);
    };
    listEl.appendChild(div);
  });
}

async function loadFiles() {
  if (!currentProject) return;
  setStatus('Loading files...', false);
  try {
    const data = await apiPost('/api/files/list', { project: currentProject });
    const files = data.files || [];
    renderFileList(files);
    if (!currentFile && files.length > 0) {
      currentFile = files[0];
      await loadFile();
      renderFileList(files);
    }
    setStatus('Files loaded.', false);
  } catch (e) {
    console.error(e);
    setStatus('Error loading files: ' + e.message, true);
  }
}

async function loadFile() {
  if (!currentProject || !currentFile) return;
  setStatus('Loading file...', false);
  try {
    const data = await apiPost('/api/file/get', {
      project: currentProject,
      path: currentFile
    });
    document.getElementById('codeEditor').value = data.content || '';
    document.getElementById('currentFileLabel').textContent =
      currentProject + ' / ' + currentFile;
    setStatus('File loaded.', false);
  } catch (e) {
    console.error(e);
    setStatus('Error loading file: ' + e.message, true);
  }
}

async function saveFile() {
  if (!currentProject || !currentFile) {
    alert('No file selected.');
    return;
  }
  const content = document.getElementById('codeEditor').value;
  setStatus('Saving file...', false);
  try {
    await apiPost('/api/file/save', {
      project: currentProject,
      path: currentFile,
      content: content
    });
    setStatus('File saved.', false);
  } catch (e) {
    console.error(e);
    setStatus('Error saving file: ' + e.message, true);
  }
}

async function sendVibePrompt() {
  if (!currentProject) {
    alert('No project selected.');
    return;
  }
  const prompt = document.getElementById('promptBox').value.trim();
  if (!prompt) {
    alert('Enter a prompt first.');
    return;
  }
  setStatus('Sending prompt to Agent 3...', false);
  const logBox = document.getElementById('logBox');
  logBox.textContent = 'Generating code via Agent 3...';
  try {
    const data = await apiPost('/api/vibe/prompt', {
      project: currentProject,
      prompt: prompt
    });
    const files = (data.files || []).map(f => f.path).filter(Boolean);
    if (files.length > 0) {
      currentFile = files[0];
      await loadFiles();
    } else {
      await loadFiles();
    }
    logBox.textContent = JSON.stringify({
      status: data.status,
      model: data.model,
      plan: data.plan,
      notes: data.notes
    }, null, 2);
    setStatus('Code generation complete.', false);
  } catch (e) {
    console.error(e);
    logBox.textContent = 'Error: ' + e.message;
    setStatus('Error generating code: ' + e.message, true);
  }
}

async function runProject() {
  if (!currentProject) {
    alert('No project selected.');
    return;
  }
  setStatus('Calling run stub...', false);
  const logBox = document.getElementById('logBox');
  try {
    const data = await apiPost('/api/run', {
      project: currentProject,
      command: ''
    });
    logBox.textContent = data.log || 'Run stub completed.';
    setStatus('Run stub completed.', false);
  } catch (e) {
    console.error(e);
    logBox.textContent = 'Error: ' + e.message;
    setStatus('Error running project: ' + e.message, true);
  }
}

window.addEventListener('load', () => {
  loadProjects();
});
</script>
</body>
</html>
'@

$html | Set-Content -Encoding UTF8 (Join-Path $WebAppsRoot "index.html")
Say "Wrote Vibe Studio web UI -> $WebAppsRoot\index.html" "Green"

# ----------------------------------------------
# 4) Rebuild and restart nifdu.exe
# ----------------------------------------------
if (!(Test-Path $BuildDir)) {
    Say "[FATAL] Build directory not found: $BuildDir" "Red"
    exit 1
}

Say "`nStopping any running nifdu.exe..." "Yellow"
Stop-Process -Name nifdu -Force -ErrorAction SilentlyContinue

Say "Rebuilding NIFDU (Release)..." "Yellow"
cd $BuildDir
cmake --build . --config Release

if (!(Test-Path $ExePath)) {
    Say "[FATAL] Build finished but nifdu.exe not found at $ExePath" "Red"
    exit 1
}

Say "Starting nifdu.exe..." "Yellow"
Start-Process $ExePath

Say "`n=== NIFDU VIBE STUDIO READY ===" "Green"
Say "Open:  http://nifdu.com/" "Green"
Say "       http://www.nifdu.com/" "Green"
'@ | Set-Content -Encoding UTF8 .\nifdu_make_vibe_studio_full.ps1
