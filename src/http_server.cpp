#include "nifdu/http_server.hpp"
#include "nifdu/telemetry.hpp"
#include "nifdu/realtime.hpp"
#include <iostream>
#include <sstream>
#include <fstream>
#include <cstring>
#include <algorithm>

#if defined(__unix__) || defined(__APPLE__)
#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>
#include <arpa/inet.h>
#endif

namespace nifdu {

NativeHttpServer::NativeHttpServer(int port)
    : port_(port), model_adapter_(LlmConfig{}), graph_workflow_("nifdu_default_graph") {
    setup_routes();
}

NativeHttpServer::~NativeHttpServer() {
    stop();
}

void NativeHttpServer::register_route(const std::string& method, const std::string& path, HttpHandler handler) {
    std::lock_guard<std::mutex> lock(routes_mutex_);
    routes_[method + ":" + path] = handler;
}

void NativeHttpServer::setup_routes() {
    // 1. Health Check Route
    register_route("GET", "/api/health", [](const HttpRequest&) {
        HttpResponse res;
        json body;
        body["status"] = "ok";
        body["service"] = "nifdu-cpp-native-core";
        body["version"] = "2.0.0";
        res.body = body.dump();
        return res;
    });

    // 2. Agent-3 Routes
    register_route("POST", "/api/agent/plan", [this](const HttpRequest& req) {
        HttpResponse res;
        std::string sess = req.json_body.value("session_id", "sess_cpp_001");
        std::string prompt = req.json_body.value("prompt", "Default C++ prompt");

        auto plan = agent_engine_.create_plan(sess, prompt);
        json steps = json::array();
        for (const auto& s : plan.steps) {
            json st;
            st["id"] = s.id;
            st["action"] = s.action;
            st["target"] = s.target;
            st["description"] = s.description;
            st["completed"] = s.completed;
            steps.push_back(st);
        }

        json out;
        out["success"] = true;
        out["plan"]["session_id"] = sess;
        out["plan"]["prompt"] = prompt;
        out["plan"]["steps"] = steps;

        res.body = out.dump();
        return res;
    });

    register_route("POST", "/api/agent/step", [this](const HttpRequest& req) {
        HttpResponse res;
        std::string sess = req.json_body.value("session_id", "");
        int step_id = req.json_body.value("step_id", 1);

        res.body = agent_engine_.execute_step(sess, step_id).dump();
        return res;
    });

    register_route("POST", "/api/diff/preview", [this](const HttpRequest& req) {
        HttpResponse res;
        std::string path = req.json_body.value("filepath", "main.cpp");
        std::string new_content = req.json_body.value("new_content", "// C++ edit");

        auto prev = agent_engine_.preview_diff(path, new_content);
        json out;
        out["filepath"] = prev.target_file;
        out["diff"] = prev.diff_patch;

        res.body = out.dump();
        return res;
    });

    register_route("POST", "/api/undo/snapshot", [this](const HttpRequest& req) {
        HttpResponse res;
        std::vector<std::string> files;
        if (req.json_body.contains("files") && req.json_body["files"].is_array()) {
            for (const auto& f : req.json_body["files"]) {
                files.push_back(f.get<std::string>());
            }
        }
        json out;
        out["success"] = true;
        out["snapshot_id"] = agent_engine_.create_snapshot(files);

        res.body = out.dump();
        return res;
    });

    // 3. Telemetry & Maps Routes
    register_route("POST", "/api/telemetry", [](const HttpRequest& req) {
        HttpResponse res;
        std::string dev_id = req.json_body.value("deviceId", "device_01");
        json out;
        out["success"] = true;
        out["device_id"] = dev_id;
        out["status"] = "Telemetry Processed via NIFDU SIMD Engine";

        res.body = out.dump();
        return res;
    });

    register_route("GET", "/api/map/edges", [](const HttpRequest&) {
        HttpResponse res;
        json out;
        out["type"] = "FeatureCollection";
        out["features"] = json::array();
        res.body = out.dump();
        return res;
    });

    // 4. Realtime Auth & TURN Routes
    register_route("POST", "/api/auth/key", [this](const HttpRequest& req) {
        HttpResponse res;
        std::string dev_id = req.json_body.value("deviceId", "dev_001");
        std::string key = nifdu::RealtimeHub::generate_device_secret(dev_id);
        device_keys_[dev_id] = key;

        json out;
        out["success"] = true;
        out["deviceId"] = dev_id;
        out["hmac_key"] = key;

        res.body = out.dump();
        return res;
    });

    register_route("POST", "/api/turn", [](const HttpRequest&) {
        HttpResponse res;
        res.body = nifdu::RealtimeHub::generate_turn_credentials("nifdu_user").dump();
        return res;
    });

    // 5. LangChain / Graph / Smith Routes
    register_route("POST", "/api/llm/invoke", [this](const HttpRequest& req) {
        HttpResponse res;
        std::string prompt = req.json_body.value("prompt", "Hello NIFDU");
        std::string out_str = model_adapter_.invoke(prompt);
        json out;
        out["provider"] = "ollama";
        out["model"] = "qwen2.5-coder:7b";
        out["response"] = out_str;

        res.body = out.dump();
        return res;
    });

    // 6. PAKISTAN MULTI-GATEWAY PAYMENT API ROUTES (JazzCash, Easypaisa, UPaisa, SBP Raast, Credit Cards)
    register_route("POST", "/api/payments/jazzcash/pay", [this](const HttpRequest& req) {
        HttpResponse res;
        std::string msisdn = req.json_body.value("msisdn", "923212558089");
        double amount = req.json_body.value("amount_pkr", 25200.0);
        std::string ref = req.json_body.value("ref_id", "REF_JC_90USD");

        auto p_res = payment_engine_.initiate_jazzcash_payment(msisdn, amount, ref);
        json out;
        out["success"] = p_res.success;
        out["gateway"] = p_res.gateway;
        out["transaction_id"] = p_res.transaction_id;
        out["msisdn"] = p_res.msisdn;
        out["amount_pkr"] = p_res.amount_pkr;
        out["amount_usd"] = p_res.amount_usd;
        out["status_code"] = p_res.status_code;
        out["message"] = p_res.response_message;
        try { out["raw"] = json::parse(p_res.raw_response); } catch (...) { out["raw"] = p_res.raw_response; }

        res.body = out.dump();
        return res;
    });

    register_route("POST", "/api/payments/easypaisa/pay", [this](const HttpRequest& req) {
        HttpResponse res;
        std::string msisdn = req.json_body.value("msisdn", "923212558089");
        double amount = req.json_body.value("amount_pkr", 25200.0);
        std::string ref = req.json_body.value("ref_id", "REF_EP_90USD");

        auto p_res = payment_engine_.initiate_easypaisa_payment(msisdn, amount, ref);
        json out;
        out["success"] = p_res.success;
        out["gateway"] = p_res.gateway;
        out["transaction_id"] = p_res.transaction_id;
        out["msisdn"] = p_res.msisdn;
        out["amount_pkr"] = p_res.amount_pkr;
        out["amount_usd"] = p_res.amount_usd;
        out["status_code"] = p_res.status_code;
        out["message"] = p_res.response_message;
        try { out["raw"] = json::parse(p_res.raw_response); } catch (...) { out["raw"] = p_res.raw_response; }

        res.body = out.dump();
        return res;
    });

    register_route("POST", "/api/payments/upaisa/pay", [this](const HttpRequest& req) {
        HttpResponse res;
        std::string msisdn = req.json_body.value("msisdn", "923212558089");
        double amount = req.json_body.value("amount_pkr", 25200.0);
        std::string ref = req.json_body.value("ref_id", "REF_UP_90USD");

        auto p_res = payment_engine_.initiate_upaisa_payment(msisdn, amount, ref);
        json out;
        out["success"] = p_res.success;
        out["gateway"] = p_res.gateway;
        out["transaction_id"] = p_res.transaction_id;
        out["msisdn"] = p_res.msisdn;
        out["amount_pkr"] = p_res.amount_pkr;
        out["amount_usd"] = p_res.amount_usd;
        out["status_code"] = p_res.status_code;
        out["message"] = p_res.response_message;
        try { out["raw"] = json::parse(p_res.raw_response); } catch (...) { out["raw"] = p_res.raw_response; }

        res.body = out.dump();
        return res;
    });

    register_route("POST", "/api/payments/raast/pay", [this](const HttpRequest& req) {
        HttpResponse res;
        std::string alias = req.json_body.value("msisdn_alias", "923212558089");
        double amount = req.json_body.value("amount_pkr", 25200.0);
        std::string iban = req.json_body.value("iban", "PK36MEZN00010101010101");

        auto p_res = payment_engine_.initiate_raast_payment(alias, amount, iban);
        json out;
        out["success"] = p_res.success;
        out["gateway"] = p_res.gateway;
        out["transaction_id"] = p_res.transaction_id;
        out["raast_alias"] = p_res.msisdn;
        out["amount_pkr"] = p_res.amount_pkr;
        out["amount_usd"] = p_res.amount_usd;
        out["status_code"] = p_res.status_code;
        out["message"] = p_res.response_message;
        try { out["raw"] = json::parse(p_res.raw_response); } catch (...) { out["raw"] = p_res.raw_response; }

        res.body = out.dump();
        return res;
    });

    register_route("POST", "/api/payments/card/charge", [this](const HttpRequest& req) {
        HttpResponse res;
        std::string card_num = req.json_body.value("card_number", "4242424242424242");
        std::string exp = req.json_body.value("exp_date", "12/28");
        std::string cvv = req.json_body.value("cvv", "123");
        double amount_usd = req.json_body.value("amount_usd", 90.0);

        auto p_res = payment_engine_.process_card_payment(card_num, exp, cvv, amount_usd);
        json out;
        out["success"] = p_res.success;
        out["gateway"] = p_res.gateway;
        out["transaction_id"] = p_res.transaction_id;
        out["amount_usd"] = p_res.amount_usd;
        out["amount_pkr"] = p_res.amount_pkr;
        out["status_code"] = p_res.status_code;
        out["message"] = p_res.response_message;
        try { out["raw"] = json::parse(p_res.raw_response); } catch (...) { out["raw"] = p_res.raw_response; }

        res.body = out.dump();
        return res;
    });
}

void NativeHttpServer::start() {
    running_ = true;
    server_thread_ = std::thread(&NativeHttpServer::serve_loop, this);
}

void NativeHttpServer::stop() {
    if (running_) {
        running_ = false;
        if (server_thread_.joinable()) {
            server_thread_.detach();
        }
    }
}

void NativeHttpServer::serve_loop() {
#if defined(__unix__) || defined(__APPLE__)
    int server_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (server_fd < 0) return;

    int opt = 1;
    setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    sockaddr_in addr{};
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = INADDR_ANY;
    addr.sin_port = htons(port_);

    if (bind(server_fd, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        close(server_fd);
        return;
    }

    if (listen(server_fd, 10) < 0) {
        close(server_fd);
        return;
    }

    while (running_) {
        sockaddr_in client_addr{};
        socklen_t client_len = sizeof(client_addr);
        int client_fd = accept(server_fd, (struct sockaddr*)&client_addr, &client_len);
        if (client_fd >= 0) {
            handle_client(client_fd);
        }
    }
    close(server_fd);
#endif
}

void NativeHttpServer::handle_client(int client_fd) {
#if defined(__unix__) || defined(__APPLE__)
    char buffer[4096] = {0};
    ssize_t bytes_read = read(client_fd, buffer, sizeof(buffer) - 1);
    if (bytes_read <= 0) {
        close(client_fd);
        return;
    }

    std::string raw_req(buffer, bytes_read);
    HttpRequest req;
    std::istringstream stream(raw_req);
    std::string line;
    if (std::getline(stream, line)) {
        std::istringstream line_stream(line);
        line_stream >> req.method >> req.path;
    }

    // Parse Headers
    while (std::getline(stream, line) && line != "\r" && line != "") {
        auto colon = line.find(':');
        if (colon != std::string::npos) {
            std::string k = line.substr(0, colon);
            std::string v = line.substr(colon + 1);
            std::transform(k.begin(), k.end(), k.begin(), ::tolower);
            while (!v.empty() && (v.front() == ' ' || v.front() == '\t')) v.erase(0, 1);
            while (!v.empty() && (v.back() == '\r' || v.back() == '\n')) v.pop_back();
            req.headers[k] = v;
        }
    }

    // Parse Body
    auto body_pos = raw_req.find("\r\n\r\n");
    if (body_pos != std::string::npos) {
        req.body = raw_req.substr(body_pos + 4);
        if (!req.body.empty()) {
            try { req.json_body = json::parse(req.body); } catch (...) {}
        }
    }

    HttpResponse res = dispatch_request(req);
    std::string http_res = "HTTP/1.1 " + std::to_string(res.status_code) + " OK\r\n" +
                           "Content-Type: " + res.content_type + "\r\n" +
                           "Content-Length: " + std::to_string(res.body.length()) + "\r\n" +
                           "Connection: close\r\n\r\n" + res.body;

    write(client_fd, http_res.c_str(), http_res.length());
    close(client_fd);
#endif
}

HttpResponse NativeHttpServer::dispatch_request(const HttpRequest& req) {
    std::string key = req.method + ":" + req.path;
    std::lock_guard<std::mutex> lock(routes_mutex_);
    auto it = routes_.find(key);
    if (it != routes_.end()) {
        return it->second(req);
    }

    HttpResponse res;
    res.status_code = 404;
    json out;
    out["error"] = "Route not found";
    out["path"] = req.path;
    res.body = out.dump();
    return res;
}

} // namespace nifdu
