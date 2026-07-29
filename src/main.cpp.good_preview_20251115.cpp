#define _WIN32_WINNT 0x0A00
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <boost/beast/core.hpp>

#include "httplib.h"

#include <boost/beast/http.hpp>

#include "httplib.h"

#include <boost/beast/version.hpp>

#include "httplib.h"

#include <boost/asio/ip/tcp.hpp>

#include "httplib.h"

#include <boost/config.hpp>

#include "httplib.h"


#include <nlohmann/json.hpp>
#include <mutex>

std::string g_last_preview_html;
std::mutex  g_preview_mutex;

#include "httplib.h"

#include "ai/engine.hpp"

#include "httplib.h"


#include <cstdlib>

#include "httplib.h"

#include <iostream>

#include "httplib.h"

#include <memory>

#include "httplib.h"

#include <string>

#include "httplib.h"

#include <thread>

#include "httplib.h"

#include <fstream>

#include "httplib.h"

#include <sstream>

#include "httplib.h"

#include <vector>

#include "httplib.h"

#include <algorithm>

#include "httplib.h"


#include <nlohmann/json.hpp>
#include <mutex>


#include "httplib.h"

#include "ai/engine.hpp"

#include "httplib.h"


#include "nifdu_routes.hpp"

#include "httplib.h"

#include "nifdu_platform.hpp"

#include "httplib.h"


#include <nlohmann/json.hpp>
#include <mutex>


#include "httplib.h"

#include "ai/engine.hpp"

#include "httplib.h"
static httplib::Server svr;


namespace beast = boost::beast;
namespace http  = beast::http;
namespace net   = boost::asio;
using     tcp   = net::ip::tcp;

using nifdu::platform::PlatformConfig;

static bool has_suffix(const std::string& s, const std::string& suf)
{
    return s.size() >= suf.size() &&
           s.compare(s.size() - suf.size(), suf.size(), suf) == 0;
}

static bool load_file(const std::string& fullPath, std::string& out)
{
    std::ifstream ifs(fullPath, std::ios::binary);
    if (!ifs) return false;
    std::ostringstream oss;
    oss << ifs.rdbuf();
    out = oss.str();
    return true;
}

static std::string get_header_host(const http::request<http::string_body>& req)
{
    auto h = req[http::field::host];
    std::string host = std::string(h);
    auto pos = host.find(':');
    if (pos != std::string::npos) {
        host.erase(pos);
    }
    std::transform(host.begin(), host.end(), host.begin(),
                   [](unsigned char c){ return static_cast<char>(std::tolower(c)); });
    return host;
}

static const SiteConfig* find_site_for_host(const std::string& host)
{
    const auto& sites = getSites();
    for (const auto& s : sites) {
        if (s.host == host) return &s;
    }
    return nullptr;
}

void make_plain_response(
    http::request<http::string_body> const& req,
    http::response<http::string_body>& res,
    http::status status,
    std::string body,
    const char* content_type = "text/plain; charset=utf-8")
{
    res.result(status);
    res.version(req.version());
    res.set(http::field::server, "nifdu/core");
    res.set(http::field::content_type, content_type);
    res.keep_alive(req.keep_alive());
    res.body() = std::move(body);
    res.prepare_payload();
}

// --- ACME handler (using platform config) ---
bool handle_acme(
    http::request<http::string_body> const& req,
    http::response<http::string_body>& res)
{
    const std::string prefix = "/.well-known/acme-challenge/";
    std::string target = std::string(req.target());

    if (target.size() < prefix.size() ||
        target.compare(0, prefix.size(), prefix) != 0) {
        return false;
    }

    std::string token = target.substr(prefix.size());
    auto qpos = token.find('?');
    if (qpos != std::string::npos) {
        token.erase(qpos);
    }

    if (token.empty() || token.find("..") != std::string::npos) {
        make_plain_response(req, res, http::status::bad_request, "Invalid ACME token");
        return true;
    }

    std::string dir = nifdu::platform::acmeChallengeDir();
    std::string full = dir + "/" + token;

    std::string body;
    if (!load_file(full, body)) {
        make_plain_response(req, res, http::status::not_found, "ACME token not found");
        return true;
    }

    make_plain_response(req, res, http::status::ok, body, "application/octet-stream");
    return true;
}

// --- API handler (/api/*) ---
bool handle_api(
    const SiteConfig& site,
    http::request<http::string_body> const& req,
    http::response<http::string_body>& res,
    const RouteMatch* routeMatch)
{
    (void)site;
    (void)routeMatch;

    std::string path = std::string(req.target());
    auto qpos = path.find('?');
    if (qpos != std::string::npos) path.erase(qpos);

    if (path == "/api/ping") {
        std::string json = R"({"ok":true,"service":"nifdu","message":"pong"})";
        make_plain_response(req, res, http::status::ok, json, "application/json; charset=utf-8");
        return true;
    }

    // Placeholder for future AI-powered endpoints (/api/codegen, etc.)
    return false;
}

// --- NIFDU 3-pane builder helpers (pure C++ / HTML, no JS) ---
#include <cctype>
#include <sstream>

static std::string url_decode(const std::string& in)
{
    std::string out;
    out.reserve(in.size());
    for (std::size_t i = 0; i < in.size(); ++i) {
        char c = in[i];
        if (c == '+') {
            out.push_back(' ');
        } else if (c == '%' && i + 2 < in.size()) {
            char h1 = in[i + 1];
            char h2 = in[i + 2];
            auto hex = [](char ch) -> int {
                if (ch >= '0' && ch <= '9') return ch - '0';
                if (ch >= 'a' && ch <= 'f') return 10 + (ch - 'a');
                if (ch >= 'A' && ch <= 'F') return 10 + (ch - 'A');
                return -1;
            };
            int v1 = hex(h1);
            int v2 = hex(h2);
            if (v1 >= 0 && v2 >= 0) {
                out.push_back(static_cast<char>(v1 * 16 + v2));
                i += 2;
            } else {
                out.push_back(c);
            }
        } else {
            out.push_back(c);
        }
    }
    return out;
}

static std::string get_form_field(const std::string& body, const std::string& name)
{
    std::string pattern = name + "=";
    std::size_t pos = body.find(pattern);
    if (pos == std::string::npos) return {};
    pos += pattern.size();
    std::size_t end = body.find('&', pos);
    if (end == std::string::npos) end = body.size();
    return url_decode(body.substr(pos, end - pos));
}

static std::string html_escape(const std::string& s)
{
    std::string out;
    out.reserve(s.size() * 2);
    for (char c : s) {
        switch (c) {
        case '&':  out += "&amp;";  break;
        case '<':  out += "&lt;";   break;
        case '>':  out += "&gt;";   break;
        case '"':  out += "&quot;"; break;
        default:   out.push_back(c); break;
        }
    }
    return out;
}

static std::string html_attr_escape(const std::string& s)
{
    std::string out;
    out.reserve(s.size() * 2);
    for (char c : s) {
        switch (c) {
        case '&':  out += "&amp;";  break;
        case '<':  out += "&lt;";   break;
        case '>':  out += "&gt;";   break;
        case '"':  out += "&quot;"; break;
        case '\'': out += "&#39;";  break;
        default:   out.push_back(c); break;
        }
    }
    return out;
}

// --- NIFDU 3-pane builder page (pure C++ + HTML, no JS/Python) ---
bool handle_builder_page(
    const SiteConfig& site,
    http::request<http::string_body> const& req,
    http::response<http::string_body>&      res)
{
    (void)site;

    std::string prompt;
    std::string code_text;
    std::string preview_html;

    if (req.method() == http::verb::post) {
        prompt = get_form_field(req.body(), "prompt");
        if (prompt.empty()) {
            prompt = "(empty prompt)";
        }

        std::ostringstream j;
        j << "{";
        j << "\"prompt\":\"" << html_escape(prompt) << "\",";
        j << "\"max_tokens\":512,";
        j << "\"temperature\":0.7,";
        j << "\"stream\":false";
        j << "}";

        std::string ai_json = nifdu::ai::complete(j.str());
        code_text = ai_json;

        std::string phdr = R"(<!doctype html>
<html lang="en">
<head><meta charset="utf-8"><title>NIFDU Preview</title></head>
<body style="font-family:system-ui, sans-serif; background:#0f172a;
color:#e5e7eb; margin:0; padding:16px;">
<h2 style="margin-top:0; font-size:18px;">Preview from NIFDU AI</h2>
<pre style="white-space:pre-wrap; font-size:12px;">)";
        std::string pfooter = R"(</pre>
</body></html>
)";
                        try {
            // Parse outer JSON (engine/meta + output field)
            auto parsed = nlohmann::json::parse(ai_json);
            std::string html = preview_html;

            if (parsed.contains("output")) {
                if (parsed["output"].is_string()) {
                    auto out = parsed["output"].get<std::string>();

                    // Try to parse nested JSON inside output
                    try {
                        auto inner = nlohmann::json::parse(out);
                        html = inner.value("html", html);
                        // Optionally: code_text = inner.value("code", code_text);
                    } catch (const std::exception& e2) {
                        std::cerr << "[NIFDU] inner preview JSON parse error: " << e2.what() << std::endl;
                        // Treat plain-string output as HTML if it isn't JSON
                        html = out;
                    } catch (...) {
                        std::cerr << "[NIFDU] inner preview JSON parse error (unknown)" << std::endl;
                        html = out;
                    }
                }
            }

            preview_html = html;
{
    std::lock_guard<std::mutex> lock(g_preview_mutex);
    g_last_preview_html = preview_html;
}
        } catch (const std::exception& e) {
            std::cerr << "[NIFDU] AI preview JSON parse error: " << e.what() << std::endl;
            preview_html = ai_json;
        } catch (...) {
            std::cerr << "[NIFDU] AI preview JSON parse error (unknown)" << std::endl;
            preview_html = ai_json;
        }
    } else {
        prompt.clear();
        code_text = "// No code yet. Type instructions on the left and press Generate.\n";
        preview_html = R"(<!doctype html><html><head><meta charset="utf-8"></head>
<body style="font-family:system-ui, sans-serif; background:#020617;
color:#9ca3af; margin:0; padding:16px;">
<p>No preview yet. Submit a project instruction to generate one.</p>
</body></html>)";
    }

    std::string h;
    h.reserve(32768);

    h += R"(<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>NIFDU — Builder</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    body{margin:0;min-height:100vh;font-family:system-ui,-apple-system,"Segoe UI",sans-serif;background:#050816;color:#e5e7eb;}
    .shell{max-width:1400px;margin:0 auto;padding:24px 16px 32px;}
    h1{margin:0 0 6px;font-size:26px;letter-spacing:.04em;}
    .sub{color:#9ca3af;font-size:13px;margin-bottom:18px;}
    .cols{display:flex;gap:12px;flex-wrap:wrap;}
    .pane{flex:1 1 0;border-radius:16px;border:1px solid #1f2937;background:#020617;padding:10px 10px 12px;min-height:320px;}
    .pane h2{margin:0 0 6px;font-size:13px;text-transform:uppercase;letter-spacing:.12em;color:#9ca3af;}
    textarea{width:100%;min-height:280px;border-radius:10px;border:1px solid #374151;background:#020617;color:#e5e7eb;padding:8px 9px;font-size:13px;font-family:inherit;resize:vertical;}
    textarea:focus{outline:none;border-color:#4f46e5;}
    .bar{margin-top:8px;display:flex;justify-content:flex-end;}
    .btn{border-radius:999px;border:1px solid #4f46e5;background:#1f2937;color:#e5e7eb;font-size:12px;padding:6px 14px;cursor:pointer;}
    pre{margin:0;white-space:pre-wrap;word-wrap:break-word;font-size:11px;font-family:ui-monospace,Consolas,monospace;}
    iframe{border:none;width:100%;height:100%;min-height:280px;border-radius:10px;background:#020617;}
  </style>
</head>
<body>
  <div class="shell">
    <h1>NIFDU · Builder</h1>
    <div class="sub">This homepage is generated by C++ only. No JavaScript, no Python — just NIFDU, HTML, and your local AI engine.</div>
    <form method="post" action="/">
      <div class="cols">
        <div class="pane">
          <h2>1. Project instruction</h2>
          <textarea name="prompt" placeholder="Describe what you want to build">)";
    h += html_escape(prompt);
    h += R"(</textarea>
          <div class="bar"><button type="submit" class="btn">Generate with NIFDU</button></div>
        </div>
        <div class="pane">
          <h2>2. Code from NIFDU</h2>
          <pre>)";
    h += html_escape(code_text);
    h += R"(</pre>
        </div>
        <div class="pane">
          <h2>3. Live preview</h2>
          <iframe title="NIFDU preview" srcdoc=")";
    h += html_attr_escape(preview_html);
    h += R"("></iframe>
        </div>
      </div>
    </form>
  </div>
</body>
</html>
)";

    res.result(http::status::ok);
    res.set(http::field::content_type, "text/html; charset=utf-8");
    res.body() = std::move(h);
    res.prepare_payload();
    return true;
}
// --- end NIFDU 3-pane builder page ---

bool handle_site(
    const SiteConfig& site,
    http::request<http::string_body> const& req,
    http::response<http::string_body>& res)
{
    // NIFDU host-local root override for nifdu.com (3-pane C++ builder)
    {
        std::string tgt = std::string(req.target());
        if (site.host == "nifdu.com" &&
            (tgt == "/" || tgt == "/index.html"))
        {
            return handle_builder_page(site, req, res);
        }
    }
    std::string path = std::string(req.target());
    auto qpos = path.find('?');
    if (qpos != std::string::npos) {
        path.erase(qpos);
    }
        if (path.empty()) path = "/";
    if (site.host == "nifdu.com" && path == "/preview") {
    void handle_preview(const SiteConfig& site, http::request<http::string_body> const& req, http::response<http::string_body>& res);
    handle_preview(site, req, res);
    return true;
}
    // NIFDU 3-pane builder homepage (pure C++ + HTML, no JS/Python)
    if (path == "/" || path == "/index.html") {
        return handle_builder_page(site, req, res);
    }

    const auto& routes = getRoutesForHost(site.host);
    RouteMatch match;
    // NIFDU AI API pre-route stub (Beast) - POST /api/ai/complete
    // This runs before route matching so it works even if not declared in config.
    if (req.method() == http::verb::post && req.target() == "/api/ai/complete") {
        try {
            std::string json = nifdu::ai::complete(req.body());

            res.result(http::status::ok);
            res.set(http::field::content_type, "application/json; charset=utf-8");
            res.body() = json;
            res.prepare_payload();
            return true;
        } catch (const std::exception& ex) {
            res.result(http::status::internal_server_error);
            res.set(http::field::content_type, "application/json; charset=utf-8");
            res.body() =
                std::string("{\"error\":\"ai_complete_failed\",\"message\":\"") +
                ex.what() + "\"}";
            res.prepare_payload();
            return true;
        }
    }

    if (matchRoute(path, routes, match) && match.route != nullptr) {
        const RouteConfig& rc = *match.route;
        if (rc.mode == RouteMode::Api) {
        // NIFDU AI API stub (Beast) - POST /api/ai/complete
        if (req.method() == http::verb::post && req.target() == "/api/ai/complete") {
            try {
                // Forward raw JSON body to the NIFDU AI engine.
                std::string json = nifdu::ai::complete(req.body());

                res.result(http::status::ok);
                res.set(http::field::content_type, "application/json; charset=utf-8");
                res.body() = json;
                res.prepare_payload();
                return true;
            } catch (const std::exception& ex) {
                res.result(http::status::internal_server_error);
                res.set(http::field::content_type, "application/json; charset=utf-8");
                res.body() =
                    std::string("{\"error\":\"ai_complete_failed\",\"message\":\"") +
                    ex.what() + "\"}";
                res.prepare_payload();
                return true;
            }
        }
            if (handle_api(site, req, res, &match)) {
                return true;
            }
            make_plain_response(req, res, http::status::not_found, "API route not implemented");
            return true;
        }

        std::string rel = rc.file;
        if (rel.empty()) {
            rel = path;
            if (rel == "/") rel = "/index.html";
        } else if (rel.front() != '/') {
            rel = "/" + rel;
        }

        std::string full = site.docRoot + rel;
        std::string body;
        if (!load_file(full, body)) {
            make_plain_response(req, res, http::status::not_found,
                                "Route file not found: " + rel);
            return true;
        }

        std::string ctype = "text/html; charset=utf-8";
        if (has_suffix(rel, ".css")) {
            ctype = "text/css; charset=utf-8";
        } else if (has_suffix(rel, ".js")) {
            ctype = "application/javascript";
        } else if (has_suffix(rel, ".json")) {
            ctype = "application/json; charset=utf-8";
        }

        make_plain_response(req, res, http::status::ok, body, ctype.c_str());
        return true;
    }

    std::string rel = path;
    if (rel == "/") rel = "/index.html";
    std::string full = site.docRoot + rel;

    std::string body;
    if (!load_file(full, body)) {
        make_plain_response(req, res, http::status::not_found, "Not found");
        return true;
    }

    std::string ctype = "text/html; charset=utf-8";
    if (has_suffix(rel, ".css")) {
        ctype = "text/css; charset=utf-8";
    } else if (has_suffix(rel, ".js")) {
        ctype = "application/javascript";
    } else if (has_suffix(rel, ".json")) {
        ctype = "application/json; charset=utf-8";
    }

    make_plain_response(req, res, http::status::ok, body, ctype.c_str());
    return true;
}
std::string g_preview_html;






void handle_preview(
    const SiteConfig& site,
    http::request<http::string_body> const& req,
    http::response<http::string_body>& res)
{
    (void)site; // currently unused; kept for symmetry with handle_request

    if (req.method() != http::verb::get)
    {
        res.result(http::status::method_not_allowed);
        res.set(http::field::content_type, "text/plain; charset=utf-8");
        res.body() = "Only GET is allowed for /preview";
        res.prepare_payload();
        return;
    }

    std::string html;
    {
        std::lock_guard<std::mutex> lock(g_preview_mutex);
        html = g_preview_html;
    }

    if (html.empty())
    {
        res.result(http::status::ok);
        res.set(http::field::content_type, "text/html; charset=utf-8");
        res.body() =
            "<!doctype html><html><head><meta charset=\"utf-8\">"
            "<title>NIFDU Preview</title></head>"
            "<body><h1>NIFDU Preview</h1>"
            "<p>No preview content has been uploaded yet.</p>"
            "</body></html>";
        res.prepare_payload();
        return;
    }

    res.result(http::status::ok);
    res.set(http::field::content_type, "text/html; charset=utf-8");
    res.body() = html;
    res.prepare_payload();
}

void handle_request(
    http::request<http::string_body>&& req,
    http::response<http::string_body>& res)
{
    // 1) ACME always wins
    if (handle_acme(req, res)) {
        return;
    }

    // 2) Host â†’ site mapping
    std::string host = get_header_host(req);
    const SiteConfig* site = find_site_for_host(host);
    if (!site) {
        static SiteConfig fallback = { "nifdu.com", "C:/webroot/nifdu.com/www" };
        site = &fallback;
    }

    // 3) Site handler (Next-like routing + static)
    handle_site(*site, req, res);
}

void do_session(tcp::socket socket)
{
    try {
        beast::flat_buffer buffer;
        for (;;) {
            http::request<http::string_body> req;
            beast::error_code ec;

            http::read(socket, buffer, req, ec);
            if (ec == http::error::end_of_stream)
                break;
            if (ec) {
                std::cerr << "read: " << ec.message() << "\n";
                break;
            }

            http::response<http::string_body> res;
            handle_request(std::move(req), res);

            http::write(socket, res, ec);
            if (ec) {
                std::cerr << "write: " << ec.message() << "\n";
                break;
            }

            if (!res.keep_alive())
                break;
        }

        beast::error_code ec;
        socket.shutdown(tcp::socket::shutdown_send, ec);
    } catch (std::exception const& e) {
        std::cerr << "do_session exception: " << e.what() << "\n";
    }
}

int main(int argc, char** argv) {
    nifdu::ai::init("C:/nifdu/models/qwen2.5-1.5b-instruct-q4_k_m.gguf");
        // --- NIFDU AI API ROUTE (/api/ai/complete) ---
        // Handles POST from homepage AI panel: body is JSON (prompt, n_predict, temperature, etc.)
        svr.Post("/api/ai/complete", [](const httplib::Request& req, httplib::Response& res) {
            try {
                // Pass raw JSON request body to NIFDU AI engine.
                // We assume nifdu::ai::complete(const std::string& json_body) -> std::string JSON.
                std::string response_json = nifdu::ai::complete(req.body);

                // Send JSON back to browser
                res.set_content(response_json, "application/json");
            } catch (const std::exception& e) {
                try {
                    nlohmann::json err_json;
                    err_json["error"] = std::string("AI API Error: ") + e.what();
                    res.set_content(err_json.dump(), "application/json");
                    res.status = 500;
                } catch (...) {
                    res.set_content(
                        "{\"error\":\"Internal server error and failed to serialize error.\"}",
                        "application/json"
                    );
                    res.status = 500;
                }
            }
        });
        // --- END AI API ROUTE ---
    try {
        std::string cfgPath = "C:/nifdu/config/nifdu_platform.toml";
        nifdu::platform::initFromFile(cfgPath);
        const PlatformConfig& cfg = nifdu::platform::getConfig();

        std::string bindStr = "0.0.0.0";
        unsigned short port = 80;

        if (argc > 1) {
            bindStr = argv[1];
        } else if (!cfg.http.bind.empty()) {
            bindStr = cfg.http.bind;
        }

        if (argc > 2) {
            port = static_cast<unsigned short>(std::atoi(argv[2]));
        } else if (cfg.http.port != 0) {
            port = cfg.http.port;
        }

        std::cout << "NIFDU core HTTP starting on "
                  << bindStr << ":" << port << std::endl;

        std::cout << "ACME dir: " << nifdu::platform::acmeChallengeDir() << std::endl;

        std::cout << "Sites:" << std::endl;
        for (const auto& s : getSites()) {
            std::cout << "  " << s.host << " -> " << s.docRoot << std::endl;
        }

        net::io_context ioc(1);
        tcp::endpoint endpoint(net::ip::make_address(bindStr), port);
        tcp::acceptor acceptor(ioc, endpoint);

        for (;;) {
            tcp::socket socket(ioc);
            acceptor.accept(socket);
            std::thread{ [](tcp::socket s) { do_session(std::move(s)); },
                         std::move(socket) }.detach();
        }
    } catch (std::exception const& e) {
        std::cerr << "Fatal error: " << e.what() << "\n";
        return EXIT_FAILURE;
    }

    return EXIT_SUCCESS;
}

























