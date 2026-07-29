#include "nifdu_ai_client.hpp"

#include <boost/beast/core.hpp>
#include <boost/beast/http.hpp>
#include <boost/beast/version.hpp>
#include <boost/beast/ssl.hpp>
#include <boost/asio/connect.hpp>
#include <boost/asio/ip/tcp.hpp>
#include <boost/asio/ssl/error.hpp>
#include <boost/asio/ssl/stream.hpp>

#include <cstdlib>
#include <iostream>
#include <string>
#include <stdexcept>

#include <nlohmann/json.hpp>

namespace nifdu_ai {

namespace beast = boost::beast;
namespace http  = beast::http;
namespace net   = boost::asio;
namespace ssl   = boost::asio::ssl;
using     tcp   = net::ip::tcp;
using     json  = nlohmann::json;

// ---------------------------------------------------------
// Small helper: fetch env as std::string
// ---------------------------------------------------------
static std::string get_env_str(const char* name) {
    const char* v = std::getenv(name);
    if (!v || !*v) {
        return {};
    }
    return std::string(v);
}

// Public readiness check used by /api/health or /api/chat wiring
bool is_ready() {
    // For now: if we have an API key in env, we consider ourselves ready.
    const char* key = std::getenv("OPENAI_API_KEY");
    return (key != nullptr && *key != '\0');
}

// ---------------------------------------------------------
// Internal helper: call OpenAI Chat Completions
// ---------------------------------------------------------
static std::string call_openai_chat(const std::string& user_prompt) {
    // 1) API key
    std::string api_key = get_env_str("OPENAI_API_KEY");
    if (api_key.empty()) {
        return "[NIFDU::AI] OPENAI_API_KEY is not set in the environment. "
               "Configure it in C:/nifdu/.env to enable the live investor model.";
    }

    // 2) Model (allow override via NIFDU_OPENAI_MODEL, fallback to gpt-4.1-mini)
    std::string model = get_env_str("NIFDU_OPENAI_MODEL");
    if (model.empty()) {
        model = "gpt-4.1-mini";
    }

    const std::string host    = "api.openai.com";
    const std::string port    = "443";
    const std::string target  = "/v1/chat/completions";
    const int         version = 11; // HTTP/1.1

    // Strong investor-focused system prompt
    const std::string system_prompt =
        "You are NIFDU, a C++ AI operating system running as a single Windows EXE on ports 80 and 443. "
        "You are speaking to an investor who may buy or back NIFDU at a valuation around $400M. "
        "Your tone is persuasive, technical, and truthful. "
        "You explain NIFDU as an OS-level alternative to traditional cloud stacks (Caddy, Nginx, Vercel, Firebase, dev tools, AI IDEs) "
        "but running locally on the user's own hardware. "
        "You can reference that NIFDU serves multiple domains, terminates TLS, and exposes an OpenAI-compatible /api/chat endpoint. "
        "Keep answers compact but high-signal: focus on architecture, moat, scale, and why this is a category-defining product. "
        "Avoid hype; be confident and specific.";

    // 3) Build JSON payload
    json payload;
    payload["model"] = model;
    payload["messages"] = json::array({
        json{
            { "role",    "system"  },
            { "content", system_prompt }
        },
        json{
            { "role",    "user" },
            { "content", user_prompt }
        }
    });
    payload["temperature"] = 0.7;
    payload["max_tokens"]  = 400;

    std::string body = payload.dump();

    try {
        // 4) Basic TLS client setup
        net::io_context ioc;
        ssl::context ctx{ssl::context::tlsv12_client};

        // For demo / dev we disable verification (you already do this elsewhere).
        // For production, plug in proper root CAs and enable verification.
        ctx.set_verify_mode(ssl::verify_none);

        tcp::resolver resolver{ioc};
        beast::ssl_stream<beast::tcp_stream> stream{ioc, ctx};

        auto const results = resolver.resolve(host, port);
        beast::get_lowest_layer(stream).connect(results);

        // SNI
        if (!SSL_set_tlsext_host_name(stream.native_handle(), host.c_str())) {
            beast::error_code ec{
                static_cast<int>(::ERR_get_error()),
                net::error::get_ssl_category()
            };
            throw beast::system_error{ec};
        }

        // TLS handshake
        stream.handshake(ssl::stream_base::client);

        // 5) Build HTTP request
        http::request<http::string_body> req{http::verb::post, target, version};
        req.set(http::field::host, host);
        req.set(http::field::user_agent, BOOST_BEAST_VERSION_STRING);
        req.set(http::field::content_type, "application/json");

        std::string bearer = "Bearer " + api_key;
        req.set(http::field::authorization, bearer);

        req.body() = body;
        req.prepare_payload();

        // 6) Send request
        http::write(stream, req);

        // 7) Receive response
        beast::flat_buffer buffer;
        http::response<http::string_body> res;
        http::read(stream, buffer, res);

        // 8) Graceful shutdown
        beast::error_code ec;
        stream.shutdown(ec);
        if (ec == net::error::eof || ec == ssl::error::stream_truncated) {
            // Common non-fatal conditions on TLS shutdown.
            ec = {};
        }
        if (ec) {
            std::cerr << "[NIFDU::AI] TLS shutdown warning: "
                      << ec.message() << std::endl;
        }

        // 9) Parse JSON body
        std::string resp_body = res.body();

        try {
            auto j = json::parse(resp_body);

            if (j.contains("error")) {
                return std::string("[OPENAI ERROR] ") + j["error"].dump();
            }

            if (j.contains("choices") &&
                j["choices"].is_array() &&
                !j["choices"].empty() &&
                j["choices"][0].contains("message") &&
                j["choices"][0]["message"].contains("content"))
            {
                return j["choices"][0]["message"]["content"].get<std::string>();
            }

            // Unexpected structure
            return "[NIFDU::AI] Unexpected OpenAI JSON response: " + j.dump(2);
        } catch (const std::exception& ex_json) {
            std::cerr << "[NIFDU::AI] JSON parse error: "
                      << ex_json.what() << std::endl;
            if (resp_body.size() > 2000) {
                resp_body.resize(2000);
            }
            return "[NIFDU::AI] Non-JSON or malformed response from OpenAI:\n"
                   + resp_body;
        }
    } catch (const std::exception& ex) {
        std::cerr << "[NIFDU::AI] OpenAI call exception: "
                  << ex.what() << std::endl;
        return std::string("[NIFDU::AI] Failed to contact OpenAI: ")
               + ex.what();
    }
}

// ---------------------------------------------------------
// Public entry used by /api/chat (Qwen is currently aliased
// to the OpenAI investor brain for this endpoint).
// ---------------------------------------------------------
std::string call_qwen_completion(const std::string& prompt) {
    return call_openai_chat(prompt);
}

} // namespace nifdu_ai
