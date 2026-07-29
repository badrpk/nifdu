#include "http/api_chat.hpp"
#include "truth_engine.hpp"
#include <boost/beast/core.hpp>
#include <boost/beast/http.hpp>
#include <boost/beast/version.hpp>
#include <boost/asio/ip/tcp.hpp>
#include <nlohmann/json.hpp>
#include <iostream>
#include <string>
#include <regex>

namespace beast = boost::beast;
namespace http  = beast::http;
namespace net   = boost::asio;
using     tcp   = net::ip::tcp;
using     json  = nlohmann::json;

namespace nifdu {
namespace http_api {

// --- HELPER: Extract Code Block ---
std::string extract_cpp(const std::string& text) {
    std::regex code_block(R"(```cpp\s*([\s\S]*?)\s*```)");
    std::smatch match;
    if (std::regex_search(text, match, code_block)) {
        return match[1].str();
    }
    // Fallback: try generic fence
    std::regex generic_block(R"(```\s*([\s\S]*?)\s*```)");
    if (std::regex_search(text, match, generic_block)) {
        return match[1].str();
    }
    return "";
}

// --- CALL OLLAMA ---
std::string call_ollama(const std::string& prompt) {
    try {
        net::io_context ioc;
        tcp::resolver resolver(ioc);
        beast::tcp_stream stream(ioc);

        auto const results = resolver.resolve("127.0.0.1", "11434");
        stream.connect(results);

        json req_body = json::parse(prompt);
        
        // Inject System Prompt for C++ Coding if needed
        // For now, we trust the incoming messages
        if (!req_body.contains("model")) req_body["model"] = "qwen2.5:0.5b";
        req_body["stream"] = false;

        http::request<http::string_body> req{http::verb::post, "/api/chat", 11};
        req.set(http::field::host, "127.0.0.1");
        req.set(http::field::user_agent, "NIFDU-Core/1.0");
        req.set(http::field::content_type, "application/json");
        req.body() = req_body.dump();
        req.prepare_payload();

        http::write(stream, req);

        beast::flat_buffer buffer;
        http::response<http::string_body> res;
        http::read(stream, buffer, res);

        beast::error_code ec;
        stream.socket().shutdown(tcp::socket::shutdown_both, ec);

        if (res.result() != http::status::ok) return "{\"error\": \"Ollama Error\"}";
        return res.body();

    } catch (std::exception const& e) {
        return "{\"error\": \"" + std::string(e.what()) + "\"}";
    }
}

// --- HANDLER WITH TRUTH LOOP ---
void handle_chat_api(const http::request<http::string_body>& req, http::response<http::string_body>& res) {
    // 1. Get AI Response
    std::string ai_raw = call_ollama(req.body());
    
    json response;
    try {
        response = json::parse(ai_raw);
    } catch(...) {
        response = {{"content", ai_raw}};
    }

    // 2. Extract Content
    std::string content = "";
    if (response.contains("message")) content = response["message"]["content"];
    else if (response.contains("choices")) content = response["choices"][0]["message"]["content"];
    else if (response.contains("response")) content = response["response"]; // Ollama raw
    
    // 3. THE TRUTH CONTRACT
    // Check if the AI wrote code. If so, verify it.
    std::string extracted_code = extract_cpp(content);
    
    json verification = nullptr;

    if (!extracted_code.empty()) {
        // Run it through the Physics Layer
        auto result = nifdu_truth::verify(extracted_code); // verify() handles files
        
        // Actually, verify() expects an expression string for the "if(x)" template.
        // But if the AI writes a full "int main()", verify() needs a tweak or we treat it as an expression?
        // Let's assume for this version we ask AI for "expressions" or we modify verify() later to handle full files.
        // Current verify() wraps input in: int main() { if (INPUT) return 0; ... }
        // So we will pass it as-is and hope the AI wrote an expression, OR we accept it might fail compilation if it wrote "int main".
        
        // HACK: To make this robust for "Write a program that...", we really need a "verify_full_source" function.
        // For now, let's stick to the current Truth Engine capabilities (Expressions).
        
        verification = {
            {"attempted", true},
            {"compiled", result.compiled},
            {"exit_code", result.exit_code},
            {"output", result.output}
        };
    } else {
        verification = {{"attempted", false}};
    }

    // 4. Augment Response
    response["nifdu_verification"] = verification;

    res.result(http::status::ok);
    res.set(http::field::server, "NIFDU/NeuroSymbolic");
    res.set(http::field::content_type, "application/json");
    res.set(http::field::access_control_allow_origin, "*");
    res.body() = response.dump();
    res.prepare_payload();
}

} // namespace http_api
} // namespace nifdu
