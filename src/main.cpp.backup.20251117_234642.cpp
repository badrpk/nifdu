#include <boost/asio.hpp>
#include "nifdu_secrets.h"

#include <boost/asio/ssl.hpp>
#include "nifdu_secrets.h"

#include <boost/beast.hpp>
#include "nifdu_secrets.h"

#include <boost/beast/http.hpp>
#include "nifdu_secrets.h"

#include <boost/beast/ssl.hpp>
#include "nifdu_secrets.h"

#include <boost/smart_ptr/make_shared.hpp>
#include "nifdu_secrets.h"

#include <fstream>
#include "nifdu_secrets.h"

#include <iostream>
#include "nifdu_secrets.h"

#include <string>
#include "nifdu_secrets.h"

#include <thread>
#include "nifdu_secrets.h"

#include <atomic>
#include "nifdu_secrets.h"

#include <vector>
#include "nifdu_secrets.h"

#include <chrono>
#include "nifdu_secrets.h"

#include <memory>
#include "nifdu_secrets.h"

#include <toml.hpp>
#include "nifdu_secrets.h"

#include <type_traits>
#include "nifdu_secrets.h"

#include <filesystem>
#include "nifdu_secrets.h"

#include <sstream>
#include "nifdu_secrets.h"

#include <string_view>
#include "nifdu_secrets.h"

#include <algorithm>
#include "nifdu_secrets.h"

#include <cctype>
#include "nifdu_secrets.h"

#include <cstdio>
#include "nifdu_secrets.h"

#include <ctime>
#include "nifdu_secrets.h"

#include <iomanip>
#include "nifdu_secrets.h"

#include <locale>
#include "nifdu_secrets.h"

#include <cstring>
#include "nifdu_secrets.h"

#include <unordered_map>
#include "nifdu_secrets.h"

#include <libpq-fe.h> // <-- For PostgreSQL
#include "nifdu_secrets.h"

#include <fstream>      // <-- For writing files
#include "nifdu_secrets.h"

#include <openssl/ssl.h>
#include "nifdu_secrets.h"


// ADD THESE:
#include "ai/engine.hpp"
#include "nifdu_secrets.h"

#include <nlohmann/json.hpp> // The AI stub uses this
#include "nifdu_secrets.h"

#include <future> // For std::async
#include "nifdu_secrets.h"


#ifdef _WIN32
   #ifndef WIN32_LEAN_AND_MEAN
   #define WIN32_LEAN_AND_MEAN
   #endif
   #include <windows.h>
#endif

namespace beast = boost::beast;
namespace http  = beast::http;
namespace net   = boost::asio;
namespace ssl   = net::ssl;
using tcp = net::ip::tcp;

// === [STATIC FILE HELPERS] ===
static std::string read_file(const std::string& path) {
    std::ifstream ifs(path, std::ios::binary);
    if (!ifs) return {};
    return std::string((std::istreambuf_iterator<char>(ifs)), std::istreambuf_iterator<char>());
}

static void fail(beast::error_code ec, const char* what) {
    if (ec == net::error::operation_aborted ||
        ec == http::error::end_of_stream ||
        ec == ssl::error::stream_truncated)
        return;
    std::cerr << what << ": " << ec.message() << "\n";
}

template<class RequestBody>
static http::response<http::string_body> bad_request_response(
    const http::request<RequestBody>& req,
    const std::string& msg,
    http::status s = http::status::bad_request)
{
    http::response<http::string_body> res{s, req.version()};
    res.set(http::field::content_type, "text/plain; charset=utf-8");
    res.set(http::field::server, "NIFDU");
    res.set(http::field::cache_control, "no-cache");
    res.body() = msg;
    res.prepare_payload();
    return res;
}

static http::response<http::string_body> not_found_response(
    const http::request<http::string_body>& req,
    const std::filesystem::path& root)
{
    std::filesystem::path notf = root / "404.html";
    std::string body = read_file(notf.string());
    if (!body.empty()) {
        http::response<http::string_body> res{http::status::not_found, req.version()};
        res.set(http::field::content_type, "text/html; charset=utf-8");
        res.set(http::field::server, "NIFDU");
        res.set(http::field::cache_control, "no-cache");
        res.body() = std::move(body);
        res.prepare_payload();
        return res;
    }
    return bad_request_response(req, "404 Not Found", http::status::not_found);
}

static std::string tolower_str(std::string s) {
    std::transform(s.begin(), s.end(), s.begin(), [](unsigned char c){ return (char)::tolower(c); });
    return s;
}

static bool accepts(std::string_view hdr, std::string_view token) {
    return hdr.find(token) != std::string_view::npos;
}

static std::string guess_type(const std::filesystem::path& p) {
    auto e = tolower_str(p.extension().string());
    if (e == ".html" || e == ".htm") return "text/html; charset=utf-8";
    if (e == ".css")                  return "text/css; charset=utf-8";
    if (e == ".js")                   return "application/javascript";
    if (e == ".json" || e == ".map")  return "application/json";
    if (e == ".wasm")                 return "application/wasm";
    if (e == ".svg")                  return "image/svg+xml";
    if (e == ".png")                  return "image/png";
    if (e == ".jpg" || e == ".jpeg")  return "image/jpeg";
    if (e == ".gif")                  return "image/gif";
    if (e == ".ico")                  return "image/x-icon";
    if (e == ".webp")                 return "image/webp";
    if (e == ".woff2")                return "font/woff2";
    if (e == ".woff")                 return "font/woff";
    if (e == ".ttf")                  return "font/ttf";
    if (e == ".otf")                  return "font/otf";
    if (e == ".txt")                  return "text/plain; charset=utf-8";
    return "application/octet-stream";
}

static bool is_compressible(const std::string& mime) {
    std::string_view m(mime);
    return m.rfind("text/", 0) == 0 ||
           m.find("javascript") != std::string_view::npos ||
           m.find("json") != std::string_view::npos ||
           m.find("svg")  != std::string_view::npos;
}

static std::string cache_policy_for(const std::filesystem::path& full) {
    auto ext = tolower_str(full.extension().string());
    std::string fname = full.filename().string();
    auto dot = fname.rfind('.');
    bool hashed = false;
    if (dot != std::string::npos) {
        auto base = fname.substr(0, dot);
        auto dot2 = base.rfind('.');
        if (dot2 != std::string::npos) {
            auto tag = base.substr(dot2 + 1);
            if (tag.size() >= 8 &&
                std::all_of(tag.begin(), tag.end(),
                            [](unsigned char c){ return std::isxdigit(c) != 0; }))
                hashed = true;
        }
    }
    if (ext == ".html" || ext == ".htm") return "no-cache";
    if (hashed)                          return "public, max-age=31536000, immutable";
    return "public, max-age=86400";
}

static std::filesystem::path resolve_root_from_host(const std::string& hostHdr) {
    std::string h = hostHdr;
    auto pos = h.find(':');
    if (pos != std::string::npos) h = h.substr(0, pos);
    h = tolower_str(h.empty() ? "localhost" : h);
#ifdef _WIN32
    return std::filesystem::path("C:\\webroot") / h / "www";
#else
    return std::filesystem::path("/webroot") / h / "www";
#endif
}

static std::filesystem::path sanitize_target(std::string target) {
    if (target.empty() || target == "/") target = "index.html";
    while (!target.empty() && (target.front() == '/' || target.front() == '\\'))
        target.erase(target.begin());

    std::replace(target.begin(), target.end(), (char)'\\', (char)'/');

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

static std::string http_date(std::time_t t) {
    std::tm g = *std::gmtime(&t);
    std::ostringstream oss;
    oss << std::put_time(&g, "%a, %d %b %Y %H:%M:%S GMT");
    return oss.str();
}

#ifdef _WIN32
static inline std::time_t timegm_compat(std::tm* tm) { return _mkgmtime(tm); }
#else
static inline std::time_t timegm_compat(std::tm* tm) { return timegm(tm); }
#endif

static std::time_t parse_http_date(std::string_view s) {
    std::tm tm{};
    tm.tm_isdst = 0;
    if (s.size() < 5) return -1;
    size_t p = s.find(',');
    std::string core = (p != std::string_view::npos)
                       ? std::string(s.substr(p + 1))
                       : std::string(s);
    std::istringstream is2(core);
    is2.imbue(std::locale::classic());
    is2 >> std::get_time(&tm, " %d %b %Y %H:%M:%S");
    if (is2.fail()) return -1;
    return timegm_compat(&tm);
}

struct FileMeta {
    std::uint64_t size{};
    std::time_t   mtime{};
    std::string   weak_etag;
};

static FileMeta stat_file(const std::filesystem::path& full) {
    FileMeta fm{};
    std::error_code ec;
    auto sz = std::filesystem::file_size(full, ec);
    if (!ec) fm.size = sz;
    auto ft = std::filesystem::last_write_time(full, ec);
    if (!ec) {
        auto sctp = std::chrono::time_point_cast<std::chrono::system_clock::duration>(
            ft - decltype(ft)::clock::now() + std::chrono::system_clock::now());
        fm.mtime = std::chrono::system_clock::to_time_t(sctp);
    }
    fm.weak_etag = "W/\"" + std::to_string(fm.size) + "-" + std::to_string(fm.mtime) + "\"";
    return fm;
}

// === [SNI + TLS CONFIG] ===
struct VhostTLS {
    std::string host;
    std::string cert_path;
    std::string key_path;
};

struct ServerConfig {
    std::string bind         = "0.0.0.0:80";
    std::string tls_bind     = "0.0.0.0:443";
    std::string default_host = "nifdu.com";
    std::string tls_default_cert;
    std::string tls_default_key;
    std::vector<VhostTLS> vhosts;
};

static ServerConfig parse_nifdu_toml(const std::string& path) {
    ServerConfig cfg;
    try {
        auto data = toml::parse(path);

        cfg.bind             = toml::find_or(data, "server", "bind", cfg.bind);
        cfg.tls_bind         = toml::find_or(data, "server", "tls_bind", cfg.tls_bind);
        cfg.default_host     = toml::find_or(data, "server", "default_host", cfg.default_host);
        cfg.tls_default_cert = toml::find_or(data, "server", "tls_default_cert", std::string{});
        cfg.tls_default_key  = toml::find_or(data, "server", "tls_default_key",  std::string{});

        if (data.contains("vhost")) {
            for (const auto& v : toml::find<toml::array>(data, "vhost")) {
                VhostTLS vt;
                vt.host      = toml::find<std::string>(v, "host");
                vt.cert_path = toml::find_or(v, "tls_cert", cfg.tls_default_cert);
                vt.key_path  = toml::find_or(v, "tls_key",  cfg.tls_default_key);
                if (!vt.host.empty() && !vt.cert_path.empty() && !vt.key_path.empty()) {
                    cfg.vhosts.push_back(vt);
                }
            }
        }
    } catch (const std::exception& e) {
        std::cerr << "[TOML] Parse error: " << e.what() << "\n";
    }
    return cfg;
}

static std::shared_ptr<ssl::context> create_ssl_context(
    const ServerConfig& cfg,
    const std::string& host)
{
    auto ctx = std::make_shared<ssl::context>(ssl::context::tls_server);
    ctx->set_options(
        ssl::context::default_workarounds |
        ssl::context::no_sslv2 | ssl::context::no_sslv3 |
        ssl::context::no_tlsv1 | ssl::context::no_tlsv1_1 |
        ssl::context::single_dh_use
    );

    std::string cert = cfg.tls_default_cert;
    std::string key  = cfg.tls_default_key;
    for (const auto& v : cfg.vhosts) {
        if (v.host == host) {
            cert = v.cert_path;
            key  = v.key_path;
            break;
        }
    }

    if (!cert.empty() && !key.empty()) {
        try {
            ctx->use_certificate_chain_file(cert);
            ctx->use_private_key_file(key, ssl::context::pem);
        } catch (const std::exception& e) {
            std::cerr << "SSL Error: Failed to load cert/key for host "
                      << host << ": " << e.what() << "\n";
            return nullptr;
        }
    } else {
        std::cerr << "SSL Error: No cert/key provided for host " << host << "\n";
        return nullptr;
    }
    return ctx;
}

// === [TLS SNI STATE + CALLBACK] ===
struct TlsState {
    std::shared_ptr<ssl::context> fallback; // default ctx (tls_default_* or some host)
    std::unordered_map<std::string, std::shared_ptr<ssl::context>> by_host; // host -> ctx
};

// OpenSSL SNI callback: choose SSL_CTX based on SNI hostname.
static int nifdu_sni_callback(SSL* ssl, int* /*ad*/, void* arg) {
    auto* state = static_cast<TlsState*>(arg);
    if (!state) return SSL_TLSEXT_ERR_NOACK;

    const char* servername = SSL_get_servername(ssl, TLSEXT_NAMETYPE_host_name);
    std::string host = servername ? tolower_str(servername) : std::string();

    // Try exact host first (e.g. "sophyane.com", "www.nifdu.com", etc.)
    if (!host.empty()) {
        auto it = state->by_host.find(host);
        if (it != state->by_host.end() && it->second) {
            SSL_set_SSL_CTX(ssl, it->second->native_handle());
            return SSL_TLSEXT_ERR_OK;
        }
    }

    // Fallback: use default (tls_default_cert/tls_default_key or default_host)
    if (state->fallback) {
        SSL_set_SSL_CTX(ssl, state->fallback->native_handle());
        return SSL_TLSEXT_ERR_OK;
    }

    // No match, no fallback => let OpenSSL decide (likely fail)
    return SSL_TLSEXT_ERR_NOACK;
}

// Helper: create a fresh ssl::context from explicit paths (no host lookup)
static std::shared_ptr<ssl::context> create_ctx_from_paths(
    const std::string& cert_path,
    const std::string& key_path)
{
    if (cert_path.empty() || key_path.empty()) {
        return nullptr;
    }

    auto ctx = std::make_shared<ssl::context>(ssl::context::tls_server);
    ctx->set_options(
        ssl::context::default_workarounds |
        ssl::context::no_sslv2 | ssl::context::no_sslv3 |
        ssl::context::no_tlsv1 | ssl::context::no_tlsv1_1 |
        ssl::context::single_dh_use
    );

    try {
        ctx->use_certificate_chain_file(cert_path);
        ctx->use_private_key_file(key_path, ssl::context::pem);
    } catch (const std::exception& e) {
        std::cerr << "SSL Error: Failed to load cert/key (" << cert_path
                  << ", " << key_path << "): " << e.what() << "\n";
        return nullptr;
    }

    return ctx;
}

// === [REQUEST HANDLER] ===
template<class Stream, class Send>
// ==== HELPER: Safely escape SQL strings (libpq) ====
static std::string escape_sql(PGconn* conn, const std::string& s) {
    if (!conn) return "''";
    std::unique_ptr<char, void(*)(void*)> escaped(
        PQescapeLiteral(conn, s.c_str(), s.size()),
        PQfreemem
    );
    if (!escaped) return "''";
    return std::string(escaped.get());
}

// ==== HELPER: Send a JSON response (simple form) ====
template<class Send>
static void send_json(
    const std::string& body,
    Send&& send,
    http::status st = http::status::ok)
{
    http::response<http::string_body> res{st, 11}; // HTTP/1.1
    res.set(http::field::server, "NIFDU");
    res.set(http::field::content_type, "application/json; charset=utf-8");
    res.set(http::field::access_control_allow_origin, "*");
    res.set(http::field::cache_control, "no-cache");
    res.body() = body;
    res.prepare_payload();
    return send(std::move(res));
}

static void handle_request(
    http::request<http::string_body>&& req,
    const ServerConfig& cfg,
    Stream& /*stream*/,
    Send&& send)
{
    std::string_view target = req.target();
    if (target.empty()) target = "/";

    // Health endpoint
    if ((req.method() == http::verb::get || req.method() == http::verb::head) &&
        target == "/healthz")
    {
        http::response<http::string_body> res{http::status::ok, req.version()};
        res.set(http::field::content_type, "application/json");
        res.set(http::field::server, "NIFDU");
        if (req.method() == http::verb::get)
            res.body() = R"({"ok":true,"service":"nifdu"})";
        res.prepare_payload();
        return send(std::move(res));
    }

        // === [NEW API ROUTER BLOCK] ===
    if (target.rfind("/api/", 0) == 0) {
        
        // --- /api/ai/complete ---
                // --- /api/ai/complete (CORS Preflight) ---
        if (target == "/api/ai/complete" && req.method() == http::verb::options) {
            http::response<http::string_body> res{http::status::no_content, req.version()};
            res.set(http::field::server, "NIFDU");
            res.set(http::field::access_control_allow_origin, "*");
            res.set(http::field::access_control_allow_methods, "POST, OPTIONS");
            res.set(http::field::access_control_allow_headers, "Content-Type");
            res.prepare_payload();
            return send(std::move(res));
        }

        if (target == "/api/ai/complete" && req.method() == http::verb::post) {
            
            // Call our AI stub function with the request body
            std::string json_output = nifdu::ai::complete(req.body());

            http::response<http::string_body> res{http::status::ok, req.version()};
            res.set(http::field::server, "NIFDU");
            res.set(http::field::content_type, "application/json; charset=utf-8");
            res.set(http::field::cache_control, "no-cache");
            // Add CORS headers for API (useful for testing from different domains)
            res.set(http::field::access_control_allow_origin, "*"); 
            
            res.body() = std::move(json_output);
            res.prepare_payload();
            return send(std::move(res));
        }

                // --- /api/deploy ---
        // We run the blocking proxy call in a separate thread so it doesn't
        // block the main server event loop.
        if ((target == "/api/deploy" || target == "/api/deploy/") && 
            (req.method() == http::verb::post || req.method() == http::verb::options)) 
        {
            // Handle CORS preflight
            if (req.method() == http::verb::options) {
                http::response<http::string_body> res{http::status::no_content, req.version()};
                res.set(http::field::server, "NIFDU");
                res.set(http::field::access_control_allow_origin, "*");
                res.set(http::field::access_control_allow_methods, "POST, OPTIONS");
                res.set(http::field::access_control_allow_headers, "Content-Type");
                res.prepare_payload();
                return send(std::move(res));
            }

            // Handle POST by proxying in a new thread
            auto proxy_future = std::async(std::launch::async, 
                [req_body = req.body(), 
                 req_ct = req[http::field::content_type], 
                 req_ver = req.version()]() 
            {
                try {
                    net::io_context proxy_ioc; 
                    tcp::resolver resolver{proxy_ioc};
                    auto const results = resolver.resolve("127.0.0.1", "8099");
                    beast::tcp_stream stream{proxy_ioc};
                    
                    stream.expires_after(std::chrono::seconds(10));
                    stream.connect(results);

                    http::request<http::string_body> fwd{http::verb::post, "/api/deploy", req_ver};
                    fwd.set(http::field::host, "127.0.0.1:8099");
                    fwd.set(http::field::content_type, req_ct);
                    fwd.body() = req_body;
                    fwd.prepare_payload();

                    stream.expires_after(std::chrono::seconds(10));
                    http::write(stream, fwd);
                    
                    beast::flat_buffer buffer;
                    http::response<http::string_body> fwdres;
                    stream.expires_after(std::chrono::seconds(10));
                    http::read(stream, buffer, fwdres);
                    
                    beast::error_code ec;
                    stream.socket().shutdown(tcp::socket::shutdown_both, ec);
                    
                    return fwdres; // Return the successful response
                } 
                catch (const std::exception& e) 
                {
                    // Return an error response
                    http::response<http::string_body> err_res{http::status::bad_gateway, req_ver};
                    err_res.body() = "Upstream error: " + std::string(e.what());
                    err_res.prepare_payload();
                    return err_res;
                }
            });

            // Get the response from the other thread
            http::response<http::string_body> fwdres = proxy_future.get();

            // Forward the response (headers, body, status) to the original client
            http::response<http::string_body> res{fwdres.result(), req.version()};
            for(auto const& h: fwdres.base()) {
                res.set(h.name(), h.value());
            }
            res.set(http::field::access_control_allow_origin, "*"); // Add CORS
            res.body() = std::move(fwdres.body());
            res.prepare_payload();
            return send(std::move(res));
        }

        // --- Add other /api/ routes here later (e.g., /api/deploy) ---


        // If no API route matched, send a 404
        // [AI Studio block removed by patch script]

        // --- /ai/vibe (Generate code with Qwen and store draft) ---
        if (target == "/ai/vibe" && req.method() == http::verb::post) {
            try {
                auto j = nlohmann::json::parse(req.body());
                std::string prompt = j.value("prompt", "");
                std::string mode   = j.value("mode", "web");

                if (prompt.empty()) {
                    return send_json(nlohmann::json{{"error","missing_prompt"}}.dump(), send, http::status::bad_request);
                }

                std::string full_prompt =
                    std::string("You are a world-class full-stack developer inside NIFDU. ") +
                    "Generate a single COMPLETE standalone HTML document (with inline CSS and optional JS) implementing the user's idea. " +
                    "Do NOT include markdown ticks or explanations. Just the HTML.\n\n" +
                    "Mode: " + mode + "\n" +
                    "User description: " + prompt;

                nlohmann::json aiReq = {{"prompt", full_prompt}};

                // Call Qwen/llama.cpp
                std::string raw_ai = nifdu::ai::complete(aiReq.dump());
                nlohmann::json aiRes;
                try {
                    aiRes = nlohmann::json::parse(raw_ai);
                } catch (...) {
                    aiRes = nlohmann::json{{"output", raw_ai}};
                }

                std::string code;
                if (aiRes.contains("output") && aiRes["output"].is_string()) {
                    code = aiRes["output"].get<std::string>();
                } else if (aiRes.contains("html") && aiRes["html"].is_string()) {
                    code = aiRes["html"].get<std::string>();
                } else {
                    code =
                        "<!doctype html><html><head><meta charset='utf-8'><title>NIFDU</title></head>"
                        "<body><h1>AI did not return HTML</h1><pre>" + aiRes.dump() + "</pre></body></html>";
                }

                // Fixed: direct DSN for nifdu.com
                std::string conninfo =
                    "host=127.0.0.1 port=5433 user=badrpk password=Karachi5846$ dbname=nifdu_com_db";

  // NIFDU HARDENING: env-first conninfo + block default passwords + never log raw secrets
  NifduApplyConninfoEnvOverride(conninfo);
  NifduEnforceNoDefaultPassword(conninfo);
                PGconn* conn = PQconnectdb(NifduMaskConninfo(conninfo).c_str());
                if (PQstatus(conn) != CONNECTION_OK) {
                    std::string err = PQerrorMessage(conn);
                    PQfinish(conn);
                    return send_json(nlohmann::json{{"error","db_connect_failed"},{"detail",err}}.dump(),
                                     send, http::status::internal_server_error);
                }

                std::string sql =
                    "INSERT INTO projects (description, mode, code) VALUES (" +
                    escape_sql(conn, prompt) + ", " +
                    escape_sql(conn, mode)   + ", " +
                    escape_sql(conn, code)   +
                    ") RETURNING id;";

                PGresult* pgRes = PQexec(conn, sql.c_str());
                if (PQresultStatus(pgRes) != PGRES_TUPLES_OK) {
                    std::string err = PQerrorMessage(conn);
                    PQclear(pgRes);
                    PQfinish(conn);
                    return send_json(nlohmann::json{{"error","db_insert_failed"},{"detail",err}}.dump(),
                                     send, http::status::internal_server_error);
                }

                long id = std::strtol(PQgetvalue(pgRes, 0, 0), nullptr, 10);
                PQclear(pgRes);
                PQfinish(conn);

                nlohmann::json out = {
                    {"id",   id},
                    {"code", code},
                    {"mode", mode}
                };
                return send_json(out.dump(), send);
            }
            catch (const std::exception& e) {
                return send_json(nlohmann::json{{"error", e.what()}}.dump(),
                                 send, http::status::internal_server_error);
            }
        }

        // --- /api/projects/accept (Mark accepted, write file, update DB) ---
        if (target == "/api/projects/accept" && req.method() == http::verb::post) {
            try {
                auto j = nlohmann::json::parse(req.body());
                long id = 0;
                if (j.contains("id")) {
                    if (j["id"].is_number_integer())
                        id = j["id"].get<long>();
                    else if (j["id"].is_string())
                        id = std::strtol(j["id"].get<std::string>().c_str(), nullptr, 10);
                }
                std::string code = j.value("code", "");

                if (id <= 0 || code.empty()) {
                    return send_json(nlohmann::json{{"error","missing_id_or_code"}}.dump(),
                                     send, http::status::bad_request);
                }

                // Write HTML file (directory created by PowerShell script)
                std::string path = "C:/webroot/nifdu.com/www/projects/" + std::to_string(id) + ".html";
                {
                    std::ofstream f(path, std::ios::binary);
                    f << code;
                }

                // Fixed: direct DSN for nifdu.com
                std::string conninfo =
                    "host=127.0.0.1 port=5433 user=badrpk password=Karachi5846$ dbname=nifdu_com_db";

  // NIFDU HARDENING: env-first conninfo + block default passwords + never log raw secrets
  NifduApplyConninfoEnvOverride(conninfo);
  NifduEnforceNoDefaultPassword(conninfo);
                PGconn* conn = PQconnectdb(NifduMaskConninfo(conninfo).c_str());
                if (PQstatus(conn) != CONNECTION_OK) {
                    std::string err = PQerrorMessage(conn);
                    PQfinish(conn);
                    return send_json(nlohmann::json{{"error","db_connect_failed"},{"detail",err}}.dump(),
                                     send, http::status::internal_server_error);
                }

                std::string sql =
                    "UPDATE projects SET code = " + escape_sql(conn, code) +
                    ", status = 'published', published = true, accepted_at = now() " +
                    "WHERE id = " + std::to_string(id) + ";";

                PGresult* pgRes = PQexec(conn, sql.c_str());
                if (PQresultStatus(pgRes) != PGRES_COMMAND_OK) {
                    std::string err = PQerrorMessage(conn);
                    PQclear(pgRes);
                    PQfinish(conn);
                    return send_json(nlohmann::json{{"error","db_update_failed"},{"detail",err}}.dump(),
                                     send, http::status::internal_server_error);
                }
                PQclear(pgRes);
                PQfinish(conn);

                return send_json(nlohmann::json{
                    {"status","published"},
                    {"id", id},
                    {"path","/projects/" + std::to_string(id) + ".html"}
                }.dump(), send);
            }
            catch (const std::exception& e) {
                return send_json(nlohmann::json{{"error", e.what()}}.dump(),
                                 send, http::status::internal_server_error);
            }
        }

                // [AI Studio block removed by patch script]

// Extract host (fixes "use of undeclared identifier 'host'")
std::string host_header = req[http::field::host].to_string();
std::string host = host_header.empty() ? "localhost" : host_header;
auto colon = host.find(':');
if (colon != std::string::npos) host.erase(colon);

// Helper: safe SQL escape
static std::string escape_sql(PGconn* conn, const std::string& s) {
    if (!conn || s.empty()) return "''";
    char* escaped = PQescapeLiteral(conn, s.c_str(), s.length());
    if (!escaped) return "''";
    std::string result(escaped);
    PQfreemem(escaped);
    return result;
}

// Helper: send JSON
template<class Send>
static void send_json(const std::string& body, Send&& send, http::status status = http::status::ok) {
    http::response<http::string_body> res{status, req.version()};
    res.set(http::field::content_type, "application/json");
    res.set(http::field::access_control_allow_origin, "*");
    res.body() = body;
    res.prepare_payload();
    return send(std::move(res));
}

// === /ai/vibe — Generate + Save Draft ===
if (target == "/ai/vibe" && req.method() == http::verb::post) {
    try {
        auto j = nlohmann::json::parse(req.body());
        std::string prompt = j.value("prompt", "Make a beautiful website");
        std::string mode    = j.value("mode", "web");

        std::string full_prompt = 
            "You are a world-class full-stack developer at NIFDU. "
            "Generate ONE complete standalone HTML file with inline CSS and JS. "
            "Return ONLY the raw HTML — no markdown, no explanations.\n\n"
            "User wants: " + prompt;

        std::string raw = nifdu::ai::complete(nlohmann::json{{"prompt", full_prompt}}.dump());
        auto res = nlohmann::json::parse(raw);
        std::string code = res.value("output", "<h1>Qwen is thinking...</h1>");

        PGconn* conn = PQconnectdb("host=127.0.0.1 port=5433 user=badrpk password=Karachi5846$ dbname=nifdu_com_db");
        if (PQstatus(conn) != CONNECTION_OK) {
            PQfinish(conn);
            return send_json(R"({"error":"db_connect_failed"})", send, http::status::internal_server_error);
        }

        std::string sql = 
            "INSERT INTO projects (prompt, code, status) VALUES (" +
            escape_sql(conn, prompt) + ", " +
            escape_sql(conn, code) + ", 'draft') RETURNING id";

        PGresult* pg = PQexec(conn, sql.c_str());
        std::string id_str = "0";
        if (PQntuples(pg) > 0) id_str = PQgetvalue(pg, 0, 0);
        PQclear(pg);
        PQfinish(conn);

        nlohmann::json out = {{"id", std::stoll(id_str)}, {"code", code}};
        return send_json(out.dump(), send);

    } catch (...) {
        return send_json(R"({"error":"vibe_failed"})", send, http::status::internal_server_error);
    }
}

// === /api/projects/accept — Publish ===
if (target == "/api/projects/accept" && req.method() == http::verb::post) {
    try {
        auto j = nlohmann::json::parse(req.body());
        long long id = j["id"];
        std::string code = j.value("code", "");

        // Write file
        std::ofstream f("C:/webroot/nifdu.com/www/projects/" + std::to_string(id) + ".html");
        f << code; f.close();

        // Update DB
        PGconn* conn = PQconnectdb("host=127.0.0.1 port=5433 user=badrpk password=Karachi5846$ dbname=nifdu_com_db");
        std::string sql = "UPDATE projects SET code = " + escape_sql(conn, code) +
                          ", status = 'published', published = true, updated_at = NOW() WHERE id = " + std::to_string(id);
        PQexec(conn, sql.c_str());
        PQfinish(conn);

        nlohmann::json out = {{"status","published"}, {"url","/projects/" + std::to_string(id) + ".html"}};
        return send_json(out.dump(), send);

    } catch (...) {
        return send_json(R"({"error":"accept_failed"})", send, http::status::internal_server_error);
    }
}
    return send(bad_request_response(req, "API route not found", http::status::not_found));
    }
    // ============================

        // [AI Homepage block removed by patch script]
if (req.method() == http::verb::get && (target == "/" || target == "/index.html"))
    std::cerr << "[DEBUG] AI HOMEPAGE HANDLER REACHED FOR HOST: " << req[http::field::host] << " PATH: " << target << std::endl;
{
    std::string ai_raw;
    bool is_error = false;
    std::string html;

    try {
        nlohmann::json jreq;
        jreq["prompt"] = 
            "Render the live NIFDU Vibe Coding Studio homepage as full HTML. "
            "Three-column layout: prompt input, code editor, live preview. "
            "Dark theme, responsive, no external CDNs. Include Local AI badge.";

        throw std::runtime_error("AI disabled for testing"); // ai_raw = ...

        auto j = nlohmann::json::parse(ai_raw);

        if (j.contains("error")) {
            is_error = true;
            std::cerr << "[NIFDU] AI error: " << j.value("details", "unknown") << "\n";
        }

// [old NIFDU Vibe Studio block removed by repair script]

        else if (j.contains("output") && j["output"].is_object() && j["output"].contains("html")) {
            html = j["output"]["html"].get<std::string>();
        }
        else {
            is_error = true;  // unexpected format
        }
    }
    catch (const std::exception& e) {
        std::cerr << "[NIFDU] AI homepage failed: " << e.what() << "\n";
        is_error = true;
    }

    if (is_error || html.empty()) {
        html = 
            "<!doctype html><html><head>"
            "<meta charset='utf-8'><title>NIFDU</title>"
            "<style>body{font-family:system-ui;background:#111;color:#0f0;text-align:center;padding:4rem;}</style>"
            "</head><body>"
            "<h1>NIFDU AI Studio</h1>"
            "<p>The local AI backend is starting up or unavailable.</p>"
            "<p><small>Waiting for llama.cpp to load model...</small></p>"
            "</body></html>";
    }

    http::response<http::string_body> res{
        is_error ? http::status::internal_server_error : http::status::ok,
        req.version()
    };
    res.set(http::field::server, "NIFDU-AI");
    res.set(http::field::content_type, "text/html; charset=utf-8");
    res.set(http::field::cache_control, "no-store");
    res.body() = std::move(html);
    res.prepare_payload();
    return send(std::move(res));
}

// Static files handler continues below...
if (req.method() == http::verb::get || req.method() == http::verb::head) {
        std::string host = req[http::field::host].empty()
                           ? cfg.default_host
                           : std::string(req[http::field::host]);
        auto root = resolve_root_from_host(host);
        auto rel  = sanitize_target(std::string(target));
        if (rel.empty())
            return send(bad_request_response(req, "403 Forbidden", http::status::forbidden));

        std::filesystem::path full = root / rel;
        std::error_code fec;
        if (std::filesystem::is_directory(full, fec))
            full /= "index.html";
        if (!std::filesystem::exists(full, fec))
            return send(not_found_response(req, root));

        auto meta = stat_file(full);
        auto mime = guess_type(full);

        // Conditional GET — ETag
        if (!req[http::field::if_none_match].empty() &&
            std::string(req[http::field::if_none_match]) == meta.weak_etag)
        {
            http::response<http::string_body> res{http::status::not_modified, req.version()};
            res.set(http::field::server, "NIFDU");
            res.set(http::field::etag, meta.weak_etag);
            res.prepare_payload();
            return send(std::move(res));
        }

        // Conditional GET — If-Modified-Since
        auto ims = req[http::field::if_modified_since];
        if (!ims.empty()) {
            auto t = parse_http_date(ims);
            if (t != -1 && meta.mtime <= t) {
                http::response<http::string_body> res{http::status::not_modified, req.version()};
                res.set(http::field::server, "NIFDU");
                res.prepare_payload();
                return send(std::move(res));
            }
        }

        if (req.method() == http::verb::head) {
            http::response<http::string_body> res{http::status::ok, req.version()};
            res.set(http::field::server, "NIFDU");
            res.set(http::field::content_type, mime);
            res.set(http::field::cache_control, cache_policy_for(full));
            res.set(http::field::etag, meta.weak_etag);
            res.set(http::field::last_modified, http_date(meta.mtime));
            res.content_length(meta.size);
            res.prepare_payload();
            return send(std::move(res));
        }

        // Precompressed variants
        if (is_compressible(mime)) {
            std::string ae = std::string(req[http::field::accept_encoding]);
            auto brPath = full; brPath += ".br";
            auto gzPath = full; gzPath += ".gz";
            std::error_code pec;

            if (!ae.empty() && accepts(ae, "br") &&
                std::filesystem::exists(brPath, pec))
            {
                auto body = read_file(brPath.string());
                if (!body.empty()) {
                    http::response<http::string_body> res{http::status::ok, req.version()};
                    res.set(http::field::server, "NIFDU");
                    res.set(http::field::content_encoding, "br");
                    res.set(http::field::vary, "Accept-Encoding");
                    res.set(http::field::content_type, mime);
                    res.set(http::field::cache_control, cache_policy_for(full));
                    res.set(http::field::etag, meta.weak_etag);
                    res.set(http::field::last_modified, http_date(meta.mtime));
                    res.body() = std::move(body);
                    res.prepare_payload();
                    return send(std::move(res));
                }
            }

            if (!ae.empty() && accepts(ae, "gzip") &&
                std::filesystem::exists(gzPath, pec))
            {
                auto body = read_file(gzPath.string());
                if (!body.empty()) {
                    http::response<http::string_body> res{http::status::ok, req.version()};
                    res.set(http::field::server, "NIFDU");
                    res.set(http::field::content_encoding, "gzip");
                    res.set(http::field::vary, "Accept-Encoding");
                    res.set(http::field::content_type, mime);
                    res.set(http::field::cache_control, cache_policy_for(full));
                    res.set(http::field::etag, meta.weak_etag);
                    res.set(http::field::last_modified, http_date(meta.mtime));
                    res.body() = std::move(body);
                    res.prepare_payload();
                    return send(std::move(res));
                }
            }
        }

        // Serve file_body
        http::response<http::file_body> res{http::status::ok, req.version()};
        res.set(http::field::server, "NIFDU");
        res.set(http::field::content_type, mime);
        res.set(http::field::cache_control, cache_policy_for(full));
        res.set(http::field::etag, meta.weak_etag);
        res.set(http::field::last_modified, http_date(meta.mtime));
        if (is_compressible(mime)) res.set(http::field::vary, "Accept-Encoding");

        beast::error_code ec;
        res.body().open(full.string().c_str(), beast::file_mode::read, ec);
        if (ec)
            return send(not_found_response(req, root));

        res.content_length(res.body().size());
        res.prepare_payload();
        return send(std::move(res));
    }

    return send(bad_request_response(req, "405 Method Not Allowed", http::status::method_not_allowed));
}

// === [GENERIC SESSION] ===
template<typename T> struct is_ssl_stream       : std::false_type {};
template<typename L> struct is_ssl_stream<beast::ssl_stream<L>> : std::true_type {};
template<typename T> inline constexpr bool is_ssl_stream_v = is_ssl_stream<T>::value;

template<class StreamType>
class session : public std::enable_shared_from_this<session<StreamType>> {
    StreamType                       stream_;
    beast::flat_buffer               buffer_;
    ServerConfig                     cfg_;
    http::request<http::string_body> req_;
    struct send_lambda {
        session& self_;
        explicit send_lambda(session& s) : self_(s) {}
        template<bool isRequest, class Body, class Fields>
        void operator()(http::message<isRequest, Body, Fields>&& msg) const {
            auto sp = boost::make_shared<http::message<isRequest, Body, Fields>>(std::move(msg));
            http::async_write(self_.stream_, *sp,
                beast::bind_front_handler(
                    &session::on_write,
                    self_.shared_from_this(),
                    sp->need_eof()));
        }
    } send_;

public:
    session(tcp::socket&& socket, const ServerConfig& cfg)
        : stream_(std::move(socket)), cfg_(cfg), send_(*this) {}

    session(tcp::socket&& socket,
            std::shared_ptr<ssl::context> ctx,
            const ServerConfig& cfg)
        : stream_(std::move(socket), *ctx), cfg_(cfg), send_(*this) {}

    void run() {
        if constexpr (is_ssl_stream_v<StreamType>) {
            beast::get_lowest_layer(stream_).expires_after(std::chrono::seconds(30));
            stream_.async_handshake(
                ssl::stream_base::server,
                beast::bind_front_handler(
                    &session::on_handshake,
                    this->shared_from_this()));
        } else {
            beast::get_lowest_layer(stream_).expires_after(std::chrono::seconds(30));
            do_read();
        }
    }

    void on_handshake(beast::error_code ec) {
        if (ec) return fail(ec, "handshake");
        do_read();
    }

    void do_read() {
        req_ = {};
        if constexpr (is_ssl_stream_v<StreamType>)
            beast::get_lowest_layer(stream_).expires_after(std::chrono::seconds(30));
        else
            beast::get_lowest_layer(stream_).expires_after(std::chrono::seconds(30));

        http::async_read(
            stream_, buffer_, req_,
            beast::bind_front_handler(
                &session::on_read,
                this->shared_from_this()));
    }

    void on_read(beast::error_code ec, std::size_t) {
        if (ec == http::error::end_of_stream)
            return do_close();
        if (ec) return fail(ec, "read");
        handle_request(std::move(req_), cfg_, stream_, send_);
    }

    void on_write(bool close, beast::error_code ec, std::size_t) {
        if (ec) return fail(ec, "write");
        if (close) return do_close();
        do_read();
    }

    void do_close() {
        beast::error_code ec;
        if constexpr (is_ssl_stream_v<StreamType>) {
            stream_.async_shutdown(
                beast::bind_front_handler(
                    &session::on_shutdown,
                    this->shared_from_this()));
        } else {
            stream_.socket().shutdown(tcp::socket::shutdown_send, ec);
        }
    }

    void on_shutdown(beast::error_code) {}
};

using http_session  = session<beast::tcp_stream>;
using https_session = session<beast::ssl_stream<beast::tcp_stream>>;

// === [LISTENERS] ===
class listener : public std::enable_shared_from_this<listener> {
    net::io_context&           ioc_;
    tcp::acceptor              acceptor_;
    ServerConfig               cfg_;
    std::shared_ptr<ssl::context> ssl_ctx_; // Only for HTTPS listener

public:
    listener(net::io_context& ioc,
             tcp::endpoint ep,
             ServerConfig cfg,
             std::shared_ptr<ssl::context> ctx = nullptr)
        : ioc_(ioc),
          acceptor_(ioc),
          cfg_(std::move(cfg)),
          ssl_ctx_(std::move(ctx))
    {
        beast::error_code ec;
        acceptor_.open(ep.protocol(), ec);   if (ec) { fail(ec, "open");   return; }
        acceptor_.set_option(net::socket_base::reuse_address(true), ec);
        if (ec) { fail(ec, "reuse");  return; }
        acceptor_.bind(ep, ec);             if (ec) { fail(ec, "bind");   return; }
        acceptor_.listen(net::socket_base::max_listen_connections, ec);
        if (ec) { fail(ec, "listen"); return; }
    }

    void run() {
        if (acceptor_.is_open()) do_accept();
    }

    void do_accept() {
        if (ioc_.stopped()) return;
        acceptor_.async_accept(
            net::make_strand(ioc_),
            beast::bind_front_handler(
                &listener::on_accept,
                shared_from_this()));
    }

    void on_accept(beast::error_code ec, tcp::socket socket) {
        if (ec) {
            fail(ec, "accept");
        } else {
            if (ssl_ctx_) {
                std::make_shared<https_session>(
                    std::move(socket),
                    ssl_ctx_,
                    cfg_)->run();
            } else {
                std::make_shared<http_session>(
                    std::move(socket),
                    cfg_)->run();
            }
        }
        do_accept();
    }
};

// === [MAIN] ===
int main(int argc, char** argv) {
    try {
        std::string cfg_path = "C:\\nifdu\\config\\nifdu.toml";
        for (int i = 1; i < argc; ++i) {
            if (std::string(argv[i]) == "--config" && i + 1 < argc)
                cfg_path = argv[++i];
        }

        auto cfg = parse_nifdu_toml(cfg_path);

        // === [NEW CODE] ===
        // Initialize the AI engine (we'll use a stub path for now)
        std::cout << "[NIFDU] Initializing AI engine..." << std::endl;
        nifdu::ai::init("C:\\models\\placeholder.gguf");
        // ==================

        auto thread_count_hw = std::max(1u, std::thread::hardware_concurrency());
        auto ioc = net::io_context{ static_cast<int>(thread_count_hw) };

        auto bind_addr = net::ip::make_address(
            cfg.bind.substr(0, cfg.bind.find(':')));
        auto http_port = static_cast<unsigned short>(
            std::stoi(cfg.bind.substr(cfg.bind.find(':') + 1)));
        auto http_ep   = tcp::endpoint{bind_addr, http_port};
        std::make_shared<listener>(ioc, http_ep, cfg)->run();
        std::cout << "[NIFDU] HTTP  → " << cfg.bind << "\n";

        // --- HTTPS / TLS with real SNI ---
        if (!cfg.tls_bind.empty()) {
            auto tls_addr = net::ip::make_address(
                cfg.tls_bind.substr(0, cfg.tls_bind.find(':')));
            auto tls_port = static_cast<unsigned short>(
                std::stoi(cfg.tls_bind.substr(cfg.tls_bind.find(':') + 1)));
            auto https_ep = tcp::endpoint{tls_addr, tls_port};

            // Build TLS state: fallback + per-host contexts
            auto* tlsState = new TlsState(); // lives for process lifetime

            // 1) Fallback from tls_default_* if set
            if (!cfg.tls_default_cert.empty() && !cfg.tls_default_key.empty()) {
                tlsState->fallback = create_ctx_from_paths(
                    cfg.tls_default_cert,
                    cfg.tls_default_key);
            } else {
                // Fallback: vhost whose host == default_host
                for (const auto& v : cfg.vhosts) {
                    if (tolower_str(v.host) == tolower_str(cfg.default_host)) {
                        tlsState->fallback = create_ctx_from_paths(
                            v.cert_path,
                            v.key_path);
                        break;
                    }
                }
            }

            // 2) Per-host contexts
            for (const auto& v : cfg.vhosts) {
                if (v.cert_path.empty() || v.key_path.empty()) continue;
                auto ctx = create_ctx_from_paths(v.cert_path, v.key_path);
                if (!ctx) continue;
                std::string host_lc = tolower_str(v.host);
                tlsState->by_host[host_lc] = ctx;
            }

            // 3) Decide initial context
            std::shared_ptr<ssl::context> master_ctx;
            if (tlsState->fallback) {
                master_ctx = tlsState->fallback;
            } else if (!tlsState->by_host.empty()) {
                master_ctx = tlsState->by_host.begin()->second;
            }

            if (!master_ctx) {
                std::cerr << "[NIFDU] No usable TLS context (no certs). HTTPS disabled.\n";
            } else {
                SSL_CTX* raw = master_ctx->native_handle();
                SSL_CTX_set_tlsext_servername_callback(raw, &nifdu_sni_callback);
                SSL_CTX_set_tlsext_servername_arg(raw, tlsState);

                std::make_shared<listener>(ioc, https_ep, cfg, master_ctx)->run();
                std::cout << "[NIFDU] HTTPS → " << cfg.tls_bind
                          << " (SNI enabled, " << tlsState->by_host.size()
                          << " host certificate(s) loaded)\n";
            }
        }

        std::vector<std::thread> threads;
        auto const thread_count = thread_count_hw;
        threads.reserve(thread_count);
        for (unsigned i = 0; i < thread_count; ++i) {
            threads.emplace_back([&ioc] {
                try {
                    ioc.run();
                } catch (const std::exception& e) {
                    std::cerr << "ioc.run() exception: " << e.what() << "\n";
                }
            });
        }
        for (auto& t : threads) t.join();
    } catch (const std::exception& e) {
        std::cerr << "FATAL: " << e.what() << "\n";
        return 1;
    }
    return 0;
}




















