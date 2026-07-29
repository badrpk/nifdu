#define _WIN32_WINNT 0x0A00
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#define NOMINMAX

#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <winhttp.h>
#include "nifdu_log.hpp"

#include <cstdlib>
#include <iostream>
#include <memory>
#include <string>
#include <thread>
#include <vector>
#include <algorithm>
#include <fstream>
#include <sstream>
#include <iomanip>
#include <filesystem>
#include <cctype>
#include "nifdu_log.hpp"

#include <boost/beast/core.hpp>
#include <boost/beast/http.hpp>
#include <boost/beast/version.hpp>
#include <boost/asio/ip/tcp.hpp>
#include <boost/config.hpp>
#include "nifdu_log.hpp"

#include <nlohmann/json.hpp>
#include "truth_engine.hpp"
#include "nifdu_log.hpp"

#include "http/api_chat.hpp"
#include "http/api_lead.hpp"
#include "http/api_av_sprite.hpp"
#include "nifdu_log.hpp"

// Namespaces
namespace beast = boost::beast;
namespace http  = beast::http;
namespace net   = boost::asio;
using     tcp   = net::ip::tcp;
using     json  = nlohmann::json;

// --- CONFIG STRUCT ---
struct SiteConfig {
    std::string host;
    std::string root;
};

// --- HELPERS ---
static void make_plain_response(
    http::request<http::string_body> const& req,
    http::response<http::string_body>& res,
    http::status status,
    std::string body,
    std::string content_type = "text/plain") 
{
    res.result(status);
    res.set(http::field::server, "NIFDU/1.0");
    res.set(http::field::content_type, content_type);
    res.body() = body;
    res.prepare_payload();
}

static std::string mime_type(std::string const& path) {
    auto const ext = std::filesystem::path(path).extension().string();
    if(ext == ".htm" || ext == ".html") return "text/html";
    if(ext == ".css") return "text/css";
    if(ext == ".js")  return "application/javascript";
    if(ext == ".json") return "application/json";
    if(ext == ".png") return "image/png";
    if(ext == ".jpg" || ext == ".jpeg") return "image/jpeg";
    if(ext == ".gif") return "image/gif";
    if(ext == ".svg") return "image/svg+xml";
    if(ext == ".ico") return "image/vnd.microsoft.icon";
    return "application/octet-stream";
}

// --- FORWARD DECLARATIONS ---
void handle_request(http::request<http::string_body>&& req, http::response<http::string_body>& res);

// --- STATIC SITE HANDLER (Was missing before) ---
void handle_site(http::request<http::string_body> const& req, http::response<http::string_body>& res, const SiteConfig* site_ptr) {
    std::string target = std::string(req.target());
    if(target.empty() || target[0] != '/' || target.find("..") != std::string::npos) {
        make_plain_response(req, res, http::status::bad_request, "Illegal path");
        return;
    }

    if(target == "/") target = "/index.html";

    std::string root = site_ptr ? site_ptr->root : "C:/webroot/nifdu.com/www";
    std::string full_path = root + target;

    std::ifstream file(full_path, std::ios::binary);
    if(!file) {
        make_plain_response(req, res, http::status::not_found, "404 Not Found");
        return;
    }

    std::ostringstream ss;
    ss << file.rdbuf();
    
    res.result(http::status::ok);
    res.set(http::field::server, "NIFDU/1.0");
    res.set(http::field::content_type, mime_type(full_path));
    res.body() = ss.str();
    res.prepare_payload();
}

// --- SESSION HANDLER (Implemented fully to fix Linker) ---
void do_session(tcp::socket socket) {
    bool close = false;
    beast::error_code ec;
    beast::flat_buffer buffer;

    for(;;) {
        http::request<http::string_body> req;
        http::read(socket, buffer, req, ec);
        if(ec == http::error::end_of_stream) break;
        if(ec) return;

        http::response<http::string_body> res{http::status::ok, req.version()};
        
        handle_request(std::move(req), res);

        http::write(socket, res, ec);
        if(ec) return;

        if(res.need_eof()) break;
    }
    socket.shutdown(tcp::socket::shutdown_send, ec);
}

// --- MAIN DISPATCHER ---
void handle_request(http::request<http::string_body>&& req, http::response<http::string_body>& res) {
    std::string path = std::string(req.target());
    
    // 1. Ping
    if (path == "/api/ping" && req.method() == http::verb::get) {
        make_plain_response(req, res, http::status::ok, "{\"ok\":true,\"msg\":\"pong\"}", "application/json");
        return;
    }

    // 2. Truth Engine
    if (path == "/api/truth" && req.method() == http::verb::post) {
        try {
            auto j = json::parse(req.body());
            std::string expr = j.value("expression", "false");
            
            auto r = nifdu_truth::verify(expr);

            json out;
            out["compiled"] = r.compiled;
            out["exit_code"] = r.exit_code;
            out["output"] = r.output;
            out["expression"] = expr;

            make_plain_response(req, res, http::status::ok, out.dump(), "application/json");
        } catch (const std::exception& e) {
            make_plain_response(req, res, http::status::bad_request, e.what(), "text/plain");
        }
        return;
    }

        // 3. Core APIs
    if (path == "/api/chat") {
        nifdu::http_api::handle_chat_api(req, res);
        return;
    }
    if (path == "/api/lead") {
        nifdu::http_api::handle_lead_api(req, res);
        return;
    }
    if (path == "/api/av/sprite") {
        nifdu::http_api::handle_av_sprite_api(req, res);
        return;
    }

    // 4. Static Site
    std::string host = std::string(req[http::field::host]);
    SiteConfig site; 
    site.host = host;
    site.root = "C:/webroot/nifdu.com/www"; 
    
    handle_site(req, res, &site);
}

// --- MAIN ---
int main(int argc, char* argv[]) {
    try {
        auto const address = net::ip::make_address("0.0.0.0");
        unsigned short port = 80;

        net::io_context ioc{1};
        tcp::acceptor acceptor{ioc, {address, port}};
        
        std::cout << "NIFDU Server listening on port " << port << std::endl;

        for(;;) {
            tcp::socket socket{ioc};
            acceptor.accept(socket);
            
            // Correct thread lambda
            std::thread(
                [s = std::move(socket)]() mutable {
                    do_session(std::move(s));
                }
            ).detach();
        }
    } catch (const std::exception& e) {
        std::cerr << "Error: " << e.what() << std::endl;
        return 1;
    }
    return 0;
}


