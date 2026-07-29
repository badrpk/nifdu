#include "truth_engine.hpp"
#define _WIN32_WINNT 0x0A00
#define _CRT_SECURE_NO_WARNINGS 1

#include "http/api_chat.hpp"
#include "http/api_lead.hpp"
#include "http/api_av_sprite.hpp"

#include <boost/asio.hpp>
#include <boost/asio/ip/tcp.hpp>
#include <boost/beast/core.hpp>
#include <boost/beast/http.hpp>
#include <boost/beast/version.hpp>

#include <boost/iostreams/filtering_stream.hpp>
#include <boost/iostreams/device/back_inserter.hpp>
#include <boost/iostreams/filter/gzip.hpp>

#include <algorithm>
#include <cctype>
#include <chrono>
#include <cstdio>
#include <ctime>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <locale>
#include <sstream>
#include <string>
#include <vector>
#include <thread>
#include <system_error>

#include <nlohmann/json.hpp>
#include "nifdu_log.hpp"

namespace beast = boost::beast;
namespace http  = beast::http;
namespace net   = boost::asio;
using     tcp   = net::ip::tcp;

namespace nifdu {
namespace http_api {
    // Provided by api_chat.hpp / api_av_sprite.hpp
    void handle_chat_api(
        const http::request<http::string_body>&,
        http::response<http::string_body>&
    );

    void handle_av_sprite_api(
        const http::request<http::string_body>&,
        http::response<http::string_body>&
    );
}
}

// ========================================================================
// Helpers and prerouter (projects + deploy proxy + static)
// ========================================================================
namespace nifdu_patch {

// ----------------- small helpers -----------------
static inline std::string tolower_str(std::string s) {
    std::transform(s.begin(), s.end(), s.begin(),
        [](unsigned char c){ return static_cast<char>(std::tolower(c)); });
    return s;
}

static bool accepts(const std::string& hdr, const std::string& token) {
    auto h = tolower_str(hdr);
    auto t = tolower_str(token);
    return h.find(t) != std::string::npos;
}

static std::string guess_type(const std::filesystem::path& p) {
    auto e = tolower_str(p.extension().string());
    if (e == ".html" || e == ".htm")   return "text/html; charset=utf-8";
    if (e == ".css")                   return "text/css; charset=utf-8";
    if (e == ".js")                    return "application/javascript";
    if (e == ".json" || e == ".map")   return "application/json";
    if (e == ".wasm")                  return "application/wasm";
    if (e == ".svg")                   return "image/svg+xml";
    if (e == ".png")                   return "image/png";
    if (e == ".jpg" || e == ".jpeg")   return "image/jpeg";
    if (e == ".gif")                   return "image/gif";
    if (e == ".ico")                   return "image/x-icon";
    if (e == ".webp")                  return "image/webp";
    if (e == ".woff2")                 return "font/woff2";
    if (e == ".woff")                  return "font/woff";
    if (e == ".ttf")                   return "font/ttf";
    if (e == ".otf")                   return "font/otf";
    if (e == ".txt")                   return "text/plain; charset=utf-8";
    return "application/octet-stream";
}

static bool is_compressible(const std::string& mime) {
    auto m = tolower_str(mime);
    return m.rfind("text/", 0) == 0 ||
           m.find("javascript") != std::string::npos ||
           m.find("json") != std::string::npos ||
           m.find("svg") != std::string::npos;
}

static std::filesystem::path resolve_root_from_host(const std::string& hostHdr) {
    std::string h = hostHdr;
    auto pos = h.find(':');
    if (pos != std::string::npos) h = h.substr(0, pos);
    h = tolower_str(h.empty() ? std::string("localhost") : h);    // START PATCH: Canonical Host Redirection
    if (h == "nifdu.com" || h == "www.nifdu.com" || h == "127.0.0.1") {
        h = "nifdu.com"; // Force all common hosts to use the canonical folder
    }
    // END PATCH


#ifdef _WIN32
    std::filesystem::path base("C:\\webroot");
#else
    std::filesystem::path base("/webroot");
#endif
    return base / h / "www";
}

static std::filesystem::path sanitize_target(std::string target) {
    if (target.empty() || target == "/") target = "index.html";
    while (!target.empty() && (target.front() == '/' || target.front() == '\\')) {
        target.erase(target.begin());
    }
    std::replace(target.begin(), target.end(), '\\', '/');
    std::filesystem::path rel;
    for (size_t i = 0, j = 0; i <= target.size(); ++i) {
        if (i == target.size() || target[i] == '/') {
            auto part = target.substr(j, i - j);
            j = i + 1;
            if (part.empty() || part == ".") continue;
            if (part == "..") return {};
            rel /= part;
        }
    }
    return rel;
}

static std::string read_all_file(const std::filesystem::path& p) {
    std::ifstream ifs(p, std::ios::binary);
    if (!ifs) return {};
    ifs.seekg(0, std::ios::end);
    std::string s;
    s.resize(static_cast<size_t>(ifs.tellg()));
    ifs.seekg(0);
    ifs.read(s.data(), static_cast<std::streamsize>(s.size()));
    return s;
}

struct FileMeta {
    std::uint64_t size{};
};

// Simple stat for size only (we’ll skip ETag/Last-Modified complexity)
static FileMeta stat_file(const std::filesystem::path& full) {
    FileMeta fm{};
    std::error_code ec;
    auto sz = std::filesystem::file_size(full, ec);
    if (!ec) fm.size = static_cast<std::uint64_t>(sz);
    return fm;
}

// ----------------- CORS helper (used by deploy proxy) -----------------
template<class Req, class Res>
inline void apply_cors(const Req& req, Res& res) {
    using namespace boost;
    using namespace boost::beast;
    namespace http_local = beast::http;

    auto it = req.find(http_local::field::origin);
    if (it != req.end()) {
        res.set(http_local::field::access_control_allow_origin, it->value());
        res.set(http_local::field::vary, "Origin");
    } else {
        res.set(http_local::field::access_control_allow_origin, "*");
    }
    res.set(http_local::field::access_control_allow_methods, "GET, POST, HEAD, OPTIONS");
    res.set(http_local::field::access_control_allow_headers, "Content-Type, Authorization");
    res.set(http_local::field::access_control_expose_headers, "*");
    res.set(http_local::field::access_control_allow_credentials, "false");
}

// ----------------- /projects prerouter -----------------
template<class Req, class Res>
static bool try_projects(const Req& req, Res& res) {
    std::string target(req.target().begin(), req.target().end());
    const std::string prefix = "/projects";
    if (target.rfind(prefix, 0) != 0) return false;

    // Normalize relative path
    std::string rel = target.substr(prefix.size()); // may start with '/'
    if (rel.empty() || rel == "/") rel = "/index.html";
    if (rel.find("..") != std::string::npos) {
        res.result(http::status::forbidden);
        res.set(http::field::content_type, "text/plain; charset=utf-8");
        res.body() = "Forbidden";
        res.prepare_payload();
        return true;
    }

    std::string full = "C:\\webroot\\nifdu.com\\www\\studio\\projects" + rel;
    std::replace(full.begin(), full.end(), '/', '\\');

    std::ifstream f(full, std::ios::binary);
    if (!f) {
        res.result(http::status::not_found);
        res.set(http::field::content_type, "text/plain; charset=utf-8");
        res.body() = "Not Found";
        res.prepare_payload();
        return true;
    }

    std::ostringstream ss;
    ss << f.rdbuf();
    res.result(http::status::ok);
    res.set(http::field::content_type, "text/html; charset=utf-8");
    res.body() = ss.str();
    res.prepare_payload();
    return true;
}

// ----------------- /api/deploy proxy -----------------
template<class Req, class Res>
static bool try_deploy_proxy(net::io_context& ioc, const Req& req, Res& res) {
    std::string target(req.target().begin(), req.target().end());
    if (!(target == "/api/deploy" || target == "/api/deploy/")) return false;

    if (req.method() == http::verb::options) {
        res.result(http::status::no_content);
        apply_cors(req, res);
        res.prepare_payload();
        return true;
    }

    try {
        tcp::resolver resolver{ioc};
        auto const results = resolver.resolve("127.0.0.1", "8099");

        beast::tcp_stream stream{ioc};
        stream.connect(results);

        http::request<http::string_body> fwd{http::verb::post, "/api/deploy", 11};
        fwd.set(http::field::host, "127.0.0.1");
        auto ct = req[http::field::content_type];
        fwd.set(http::field::content_type, ct.empty() ? "application/json" : ct);
        fwd.body() = std::string(req.body());
        fwd.prepare_payload();

        http::write(stream, fwd);

        beast::flat_buffer buffer;
        http::response<http::string_body> fwdres;
        http::read(stream, buffer, fwdres);

        beast::error_code ec;
        stream.socket().shutdown(tcp::socket::shutdown_both, ec);

        res.result(fwdres.result());
        for (auto const& h : fwdres.base())
            res.set(h.name(), h.value());
        res.body() = std::move(fwdres.body());

        apply_cors(req, res);
        res.prepare_payload();
        return true;
    } catch (std::exception const& e) {
        res.result(http::status::bad_gateway);
        res.set(http::field::content_type, "text/plain; charset=utf-8");
        res.body() = std::string("Upstream error: ") + e.what();
        res.prepare_payload();
        return true;
    }
}

// ----------------- static file handler -----------------
static bool try_static(const http::request<http::string_body>& req,
                       http::response<http::string_body>& out)
{
    // /api/log — NIFDU REAL v1.6 (try_static)
    {
        std::string target(req.target().begin(), req.target().end());
        if (target == "/api/log" || target.rfind("/api/log?", 0) == 0) {
            auto buf = nifdu_log::get();
            nlohmann::json j;
            j["log"] = buf;

            out.version(req.version());
            out.keep_alive(req.keep_alive());
            out.result(http::status::ok);
            out.set(http::field::server, "nifdu-real/1.6");
            out.set(http::field::content_type, "application/json; charset=utf-8");
            out.body() = j.dump();
            out.content_length(out.body().size());
            return true;
        }
    }

    // /api/log — NIFDU REAL v1.6 (try_static)
    {
        std::string target(req.target().begin(), req.target().end());
        if (target == "/api/log" || target.rfind("/api/log?", 0) == 0) {
            auto buf = nifdu_log::get();
            nlohmann::json j;
            j["log"] = buf;

            out.version(req.version());
            out.keep_alive(req.keep_alive());
            out.result(http::status::ok);
            out.set(http::field::server, "nifdu-real/1.6");
            out.set(http::field::content_type, "application/json; charset=utf-8");
            out.body() = j.dump();
            out.content_length(out.body().size());
            return true;
        }
    }

    // Temporary stub: disable gzip/static patch to avoid zlib link issues
    return false;
}

} // namespace nifdu_patch

// ========================================================================
// Session + main
// ========================================================================

static void do_session(tcp::socket socket) {
    beast::flat_buffer buffer;
    beast::error_code ec;

    http::request<http::string_body> req;
    http::read(socket, buffer, req, ec);
    if (ec == http::error::end_of_stream) {
        socket.shutdown(tcp::socket::shutdown_send, ec);
        return;
    }
    if (ec) {
        socket.shutdown(tcp::socket::shutdown_send, ec);
        return;
    }

    // === NIFDU STATIC FILE HANDLER (FINAL) ===
    {
        auto target = req.target();

        if (target.rfind("/api/", 0) != 0) {
            std::string path(target.begin(), target.end());

        if (path == "/") path = "/index.html";

            if (path.find("..") == std::string::npos) {
                std::string root = "C:/webroot/nifdu.com/www";
                std::string full = root + path;

                std::ifstream f(full, std::ios::binary);
                if (f) {
                    std::string body((std::istreambuf_iterator<char>(f)),
                                      std::istreambuf_iterator<char>());

                    http::response<http::string_body> res{http::status::ok, req.version()};
                    res.keep_alive(req.keep_alive());
                    res.body() = std::move(body);
                    res.content_length(res.body().size());

                    if (path.ends_with(".html")) res.set(http::field::content_type, "text/html; charset=utf-8");
                    else if (path.ends_with(".css")) res.set(http::field::content_type, "text/css");
                    else if (path.ends_with(".js")) res.set(http::field::content_type, "application/javascript");
                    else if (path.ends_with(".png")) res.set(http::field::content_type, "image/png");
                    else if (path.ends_with(".jpg") || path.ends_with(".jpeg")) res.set(http::field::content_type, "image/jpeg");
                    else res.set(http::field::content_type, "application/octet-stream");

                    http::write(socket, res, ec);
                    socket.shutdown(tcp::socket::shutdown_send, ec);
                    return;
                }
            }
        }
    }
    // === END STATIC FILE HANDLER ===
// === NIFDU AI + AV SPRITE ENDPOINTS ===
        if (req.target() == "/api/lead") {
        http::response<http::string_body> res{http::status::ok, req.version()};
        res.keep_alive(req.keep_alive());
        nifdu::http_api::handle_lead_api(req, res);
        http::write(socket, res, ec);
        socket.shutdown(tcp::socket::shutdown_send, ec);
        return;
    }

// NIFDU /api-log handler (main_real)
    if (req.target() == "/api/log") {
        http::response<http::string_body> res{http::status::ok, req.version()};
        res.keep_alive(req.keep_alive());
        res.set(http::field::server, "nifdu/core");
        res.set(http::field::content_type, "application/json; charset=utf-8");

        nlohmann::json j;
        j["log"] = nifdu_log::get();
        res.body() = j.dump();
        res.content_length(res.body().size());

        http::write(socket, res, ec);
        socket.shutdown(tcp::socket::shutdown_send, ec);
        return;
    }

    if (req.target() == "/api/codegen" && req.method() == http::verb::post)
{
    nlohmann::json body;
    try {
        if (!req.body().empty()) {
            body = nlohmann::json::parse(req.body());
        } else {
            body = nlohmann::json::object();
        }
    } catch (const std::exception& e) {
        nlohmann::json err;
        err["status"]   = "error";
        err["endpoint"] = "/api/codegen";
        err["message"]  = std::string("Invalid JSON: ") + e.what();

        res.result(http::status::bad_request);
        res.set(http::field::content_type, "application/json; charset=utf-8");
        res.body() = err.dump(2);
        res.prepare_payload();
        return;
    }

    nlohmann::json out;
    out["status"]   = "ok";
    out["endpoint"] = "/api/codegen";
    out["engine"]   = "nifdu_codegen_v0";
    out["request"]  = body;
    out["note"]     = "NIFDU codegen v0 stub on port 8000 (Beast AV stack).";

    // Simple "plan" + "files" structure so Agent 3 can inspect.
    out["plan"] = {
        { "steps", {
            {
                { "id",          1 },
                { "title",       "Create todo.cpp" },
                { "description", "In-memory TODO list with add/list/delete operations." }
            }
        }}
    };

    out["files"] = {
        {
            { "path",      "apps/todo/todo.cpp" },
            { "language",  body.value("language", "cpp") },
            { "framework", body.value("framework", "nifdu") },
            { "mode",      body.value("mode", "plan_and_code") },
            { "note",      "Stub only. Real codegen will write this file via NIFDU later." }
        }
    };

    res.result(http::status::ok);
    res.set(http::field::content_type, "application/json; charset=utf-8");
    res.body() = out.dump(2);
    res.prepare_payload();
    return;
}
else if (req.target() == "/api/chat" || req.target() == "/api/ai/complete") {
        http::response<http::string_body> res{http::status::ok, req.version()};
        res.keep_alive(req.keep_alive());

        if (req.method() != http::verb::post) {
            res.result(http::status::bad_request);
            res.set(http::field::content_type, "text/plain; charset=utf-8");
            res.body() = "POST required for AI endpoint";
            res.content_length(res.body().size());
            http::write(socket, res, ec);
            socket.shutdown(tcp::socket::shutdown_send, ec);
            return;
        }

        nifdu::http_api::handle_chat_api(req, res);
        http::write(socket, res, ec);
        socket.shutdown(tcp::socket::shutdown_send, ec);
        return;
    }

    if (req.target() == "/api/av/sprite") {
        http::response<http::string_body> res{http::status::ok, req.version()};
        res.keep_alive(req.keep_alive());

        if (req.method() != http::verb::post) {
            res.result(http::status::bad_request);
            res.set(http::field::content_type, "application/json");
            res.body() = R"({"error":"POST required"})";
            res.content_length(res.body().size());
            http::write(socket, res, ec);
            socket.shutdown(tcp::socket::shutdown_send, ec);
            return;
        }

        nifdu::http_api::handle_av_sprite_api(req, res);
        http::write(socket, res, ec);
        socket.shutdown(tcp::socket::shutdown_send, ec);
        return;
    }
    // === END AI + AV SPRITE ENDPOINTS ===

    
// /api/ping — health check
    // === /api/db_health (Hybrid stub) ===
    if (req.target() == "/api/db_health" && req.method() == http::verb::get) {
        nlohmann::json j;
        j["ok"]     = true;
        j["source"] = "nifdu_hybrid_main";
        j["note"]   = "DB health stub is wired. Core DB logic can be moved here later.";
        res.result(http::status::ok);
        res.set(http::field::content_type, "application/json");
        res.set(http::field::server, "Nifdu Hybrid");
        res.body() = j.dump();
        res.prepare_payload();
        http::write(stream, res, ec);
        return;
    }

    // === AV PLAN HANDLER (Nifdu Hybrid) ===
    if (req.target() == "/api/av/plan" && req.method() == http::verb::post) {
        std::error_code ec;
        std::string body = req.body();
        std::string t = body;
        std::transform(t.begin(), t.end(), t.begin(), ::tolower);

        std::string obj = "cat";
        std::string env = "day";
        std::string act = "idle";

        // Objects
        if (t.find("dog")   != std::string::npos || t.find("puppy")  != std::string::npos) obj = "dog";
        if (t.find("car")   != std::string::npos || t.find("auto")   != std::string::npos) obj = "car";
        if (t.find("house") != std::string::npos || t.find("home")   != std::string::npos) obj = "house";
        if (t.find("tree")  != std::string::npos || t.find("forest") != std::string::npos) obj = "tree";
        if (t.find("cat")   != std::string::npos || t.find("kitten") != std::string::npos) obj = "cat";

        // Environment
        if (t.find("rain")   != std::string::npos || t.find("storm")  != std::string::npos) env = "rain";
        if (t.find("night")  != std::string::npos || t.find("dark")   != std::string::npos) env = "night";
        if (t.find("day")    != std::string::npos || t.find("sun")    != std::string::npos) env = "day";
        if (t.find("sunset") != std::string::npos) env = "sunset";
        if (t.find("garden") != std::string::npos) env = "garden";

        // Actions (kinetic)
        if (t.find("right")  != std::string::npos || t.find("east")   != std::string::npos) act = "move_right";
        if (t.find("left")   != std::string::npos || t.find("west")   != std::string::npos) act = "move_left";
        if (t.find("up")     != std::string::npos || t.find("north")  != std::string::npos) act = "move_up";
        if (t.find("down")   != std::string::npos || t.find("south")  != std::string::npos) act = "move_down";
        if (t.find("stop")   != std::string::npos || t.find("wait")   != std::string::npos || t.find("halt") != std::string::npos) act = "idle";
        if (t.find("jump")   != std::string::npos || t.find("bounce") != std::string::npos) act = "jump";
        if (t.find("circle") != std::string::npos || t.find("spin")   != std::string::npos) act = "circle";
        if (t.find("bark")   != std::string::npos || t.find("speak")  != std::string::npos) act = "bark";

        // Rain overrides action visually
        if (env == "rain") act = "rain";

        nlohmann::json plan = {
            { "object",      obj },
            { "action",      act },
            { "environment", env }
        };

        try {
            std::ofstream ofs("C:/webroot/nifdu.com/www/media/generated/av_control.json");
            ofs << plan.dump();
            std::cout << "[AV] (Hybrid) /api/av/plan plan=" << plan.dump() << std::endl;
        } catch (...) {
            std::cerr << "[AV] (Hybrid) Failed to write av_control.json" << std::endl;
        }

        nlohmann::json j = {
            { "engine", "nifdu-av" },
            { "status", "ok" },
            { "prompt", body },
            { "plan",   plan }
        };

        http::response<http::string_body> res{http::status::ok, req.version()};
        res.set(http::field::content_type, "application/json");
        res.set(http::field::server, "Nifdu Hybrid");
        res.body() = j.dump();
        res.prepare_payload();
        http::write(stream, res, ec);
        return;
    }

    if ((req.target() == "/api/ping" || req.target() == "/api/health") && req.method() == http::verb::get) {
    http::response<http::string_body> res{http::status::ok, req.version()};
    res.set(http::field::content_type, "application/json");
    res.body() = R"({"ok":true,"service":"nifdu","message":"pong"})";
    res.prepare_payload();
    beast::http::send(stream, res);
    return;
}

// /api/truth — compiler oracle
if (req.target() == "/api/truth" && req.method() == http::verb::post) {
    try {
        auto j = nlohmann::json::parse(req.body());
        std::string expr = j.value("expression", "false");

        auto result = nifdu_truth::verify(expr);

        nlohmann::json out;
        out["expr"] = expr;
        out["compiled"] = result.compiled;
        out["exit"] = result.exit_code;
        out["output"] = result.output;

        http::response<http::string_body> res{http::status::ok, req.version()};
        res.set(http::field::content_type, "application/json");
        res.body() = out.dump();
        res.prepare_payload();
        beast::http::send(stream, res);
        return;
    }
    catch (...) {
        http::response<http::string_body> res{http::status::bad_request, req.version()};
        res.set(http::field::content_type, "application/json");
        res.body() = R"({"error":"invalid json or expression"})";
        res.prepare_payload();
        beast::http::send(stream, res);
        return;
    }
}
    }

    
// /api/ping — health check
if (req.target() == "/api/ping" && req.method() == http::verb::get) {
    http::response<http::string_body> res{http::status::ok, req.version()};
    res.set(http::field::content_type, "application/json");
    res.body() = R"({"ok":true,"service":"nifdu","message":"pong"})";
    res.prepare_payload();
    beast::http::send(stream, res);
    return;
}

// /api/truth — compiler oracle
if (req.target() == "/api/truth" && req.method() == http::verb::post) {
    try {
        auto j = nlohmann::json::parse(req.body());
        std::string expr = j.value("expression", "false");

        auto result = nifdu_truth::verify(expr);

        nlohmann::json out;
        out["expr"] = expr;
        out["compiled"] = result.compiled;
        out["exit"] = result.exit_code;
        out["output"] = result.output;

        http::response<http::string_body> res{http::status::ok, req.version()};
        res.set(http::field::content_type, "application/json");
        res.body() = out.dump();
        res.prepare_payload();
        beast::http::send(stream, res);
        return;
    }
    catch (...) {
        http::response<http::string_body> res{http::status::bad_request, req.version()};
        res.set(http::field::content_type, "application/json");
        res.body() = R"({"error":"invalid json or expression"})";
        res.prepare_payload();
        beast::http::send(stream, res);
        return;
    }
}
    }

        // --- FIXED API INJECTION ---
        // /api/ping
        if (req.target() == "/api/ping" && req.method() == http::verb::get) {
            http::response<http::string_body> res{http::status::ok, req.version()};
            res.set(http::field::content_type, "application/json");
            res.body() = R"({"ok":true,"service":"nifdu","message":"pong"})";
            res.prepare_payload();
            send(std::move(res));
            return;
        }

        // /api/truth
        if (req.target() == "/api/truth" && req.method() == http::verb::post) {
            try {
                auto j = nlohmann::json::parse(req.body());
                std::string expr = j.value("expression", "false");
                
                // Call Truth Engine
                auto result = nifdu_truth::verify(expr);

                nlohmann::json out;
                out["expr"] = expr;
                out["compiled"] = result.compiled;
                out["exit"] = result.exit_code;
                // out["output"] removed because it doesn't exist in struct
                
                http::response<http::string_body> res{http::status::ok, req.version()};
                res.set(http::field::content_type, "application/json");
                res.body() = out.dump();
                res.prepare_payload();
                send(std::move(res));
                return;

            } catch (const std::exception& e) {
                http::response<http::string_body> res{http::status::bad_request, req.version()};
                res.body() = "Invalid JSON: " + std::string(e.what());
                res.prepare_payload();
                send(std::move(res));
                return;
            }
        }
        // --- END FIXED INJECTION ---


    
// /api/ping — health check
if (req.target() == "/api/ping" && req.method() == http::verb::get) {
    http::response<http::string_body> res{http::status::ok, req.version()};
    res.set(http::field::content_type, "application/json");
    res.body() = R"({"ok":true,"service":"nifdu","message":"pong"})";
    res.prepare_payload();
    beast::http::send(stream, res);
    return;
}

// /api/truth — compiler oracle
if (req.target() == "/api/truth" && req.method() == http::verb::post) {
    try {
        auto j = nlohmann::json::parse(req.body());
        std::string expr = j.value("expression", "false");

        auto result = nifdu_truth::verify(expr);

        nlohmann::json out;
        out["expr"] = expr;
        out["compiled"] = result.compiled;
        out["exit"] = result.exit_code;
        out["output"] = result.output;

        http::response<http::string_body> res{http::status::ok, req.version()};
        res.set(http::field::content_type, "application/json");
        res.body() = out.dump();
        res.prepare_payload();
        beast::http::send(stream, res);
        return;
    }
    catch (...) {
        http::response<http::string_body> res{http::status::bad_request, req.version()};
        res.set(http::field::content_type, "application/json");
        res.body() = R"({"error":"invalid json or expression"})";
        res.prepare_payload();
        beast::http::send(stream, res);
        return;
    }
}
    }

    // /healthz
    if (req.method() == http::verb::get && req.target() == "/healthz") {
        http::response<http::string_body> res{http::status::ok, req.version()};
        res.keep_alive(req.keep_alive());
        res.set(http::field::server, "nifdu-real/1.7");
        res.set(http::field::content_type, "application/json");
        res.body() = R"({"ok":true})";
        res.content_length(res.body().size());
        http::write(socket, res, ec);
        socket.shutdown(tcp::socket::shutdown_send, ec);
        return;
    }

    // ==== NIFDU prerouter (projects + deploy proxy) ====
    {
        http::response<http::string_body> res{http::status::ok, req.version()};
        res.keep_alive(req.keep_alive());

        net::io_context ioc;
        if (nifdu_patch::try_projects(req, res)) {
            http::write(socket, res, ec);
            socket.shutdown(tcp::socket::shutdown_send, ec);
            return;
        }
        if (nifdu_patch::try_deploy_proxy(ioc, req, res)) {
            http::write(socket, res, ec);
            socket.shutdown(tcp::socket::shutdown_send, ec);
            return;
        }
    }
    // ==== end prerouter ====

    // /api/log — NIFDU REAL v1.6
    if (req.method() == http::verb::get) {
        std::string target(req.target().begin(), req.target().end());
        if (target == "/api/log" || target.rfind("/api/log?", 0) == 0) {
            http::response<http::string_body> res{http::status::ok, req.version()};
            res.keep_alive(req.keep_alive());
            res.set(http::field::server, "nifdu-real/1.6");
            res.set(http::field::content_type, "application/json; charset=utf-8");

            auto buf = nifdu_log::get();
            nlohmann::json j;
            j["log"] = buf;

            res.body() = j.dump();
            res.content_length(res.body().size());

            http::write(socket, res, ec);
            socket.shutdown(tcp::socket::shutdown_send, ec);
            return;
        }
    }

    // /api/log — NIFDU REAL v1.6 (do_session)
    if (req.method() == http::verb::get) {
        std::string target(req.target().begin(), req.target().end());
        if (target == "/api/log" || target.rfind("/api/log?", 0) == 0) {
            http::response<http::string_body> res{http::status::ok, req.version()};
            res.keep_alive(req.keep_alive());
            res.set(http::field::server, "nifdu-real/1.6");
            res.set(http::field::content_type, "application/json; charset=utf-8");

            auto buf = nifdu_log::get();
            nlohmann::json j;
            j["log"] = buf;

            res.body() = j.dump();
            res.content_length(res.body().size());

            http::write(socket, res, ec);
            socket.shutdown(tcp::socket::shutdown_send, ec);
            return;
        }
    }

    // Static files
    {
        http::response<http::string_body> res{http::status::ok, req.version()};
        res.keep_alive(req.keep_alive());
        if (nifdu_patch::try_static(req, res)) {
            http::write(socket, res, ec);
            socket.shutdown(tcp::socket::shutdown_send, ec);
            return;
        }
    }

    // 404 for everything else
    {
        http::response<http::string_body> res{http::status::not_found, req.version()};
        res.keep_alive(req.keep_alive());
        res.set(http::field::server, "nifdu-real/1.7");
        res.set(http::field::content_type, "text/plain; charset=utf-8");
        res.body() = "Not Found\n";
        res.content_length(res.body().size());
        http::write(socket, res, ec);
        socket.shutdown(tcp::socket::shutdown_send, ec);
        return;
    }
}

int main(int argc, char** argv) {
    try {
        unsigned short port = 80;
        for (int i = 1; i + 1 < argc; ++i) {
            if (std::string(argv[i]) == "--port") {
                port = static_cast<unsigned short>(std::stoi(argv[i + 1]));
            }
        }

        net::io_context ioc{1};
    // [NIFDU-AUTO] ensure io_context is running (thread pool)
    {
        unsigned n = std::thread::hardware_concurrency();
        if(n < 2) n = 2;
        std::vector<std::thread> _nifdu_pool;
        _nifdu_pool.reserve(n);
        for(unsigned i=0;i<n;i++){
            _nifdu_pool.emplace_back([&](){ ioc.run(); });
        }
        // NOTE: pool threads are intentionally detached to keep server alive
        for(auto& t : _nifdu_pool) t.detach();
    }
        tcp::acceptor acceptor(ioc, {tcp::v4(), port});
    /* TLS frontend disabled for now */

for (;;) {
            tcp::socket socket(ioc);
            acceptor.accept(socket);
            do_session(std::move(socket));
        }
    } catch (std::exception const& e) {
        std::fprintf(stderr, "fatal: %s\n", e.what());
        return 1;
    }
}
















