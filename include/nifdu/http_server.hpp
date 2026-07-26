#ifndef NIFDU_HTTP_SERVER_HPP
#define NIFDU_HTTP_SERVER_HPP

#include "nifdu/agent3.hpp"
#include "nifdu/telemetry.hpp"
#include "nifdu/realtime.hpp"
#include "nifdu/lang_adapter.hpp"
#include "nifdu/lang_graph.hpp"
#include "nifdu/lang_smith.hpp"
#include "nifdu/pakistan_payments.hpp"

#include <nlohmann/json.hpp>
#include <string>
#include <vector>
#include <map>
#include <functional>
#include <atomic>
#include <thread>
#include <mutex>

namespace nifdu {

using json = nlohmann::json;

struct HttpRequest {
    std::string method;
    std::string path;
    std::map<std::string, std::string> query;
    std::map<std::string, std::string> headers;
    std::string body;
    json json_body;
};

struct HttpResponse {
    int status_code = 200;
    std::string content_type = "application/json";
    std::map<std::string, std::string> headers;
    std::string body;
};

using HttpHandler = std::function<HttpResponse(const HttpRequest& request)>;

class NativeHttpServer {
public:
    explicit NativeHttpServer(int port = 8009);
    ~NativeHttpServer();

    void register_route(const std::string& method, const std::string& path, HttpHandler handler);
    void start();
    void stop();

    // Telemetry and Realtime Store Accessors
    std::vector<MapSegment>& get_segments() { return in_memory_segments_; }

private:
    void setup_routes();
    void serve_loop();
    void handle_client(int client_fd);
    HttpResponse dispatch_request(const HttpRequest& request);
    
    // WebSocket Handshake & Frame Helpers
    bool is_websocket_request(const HttpRequest& req);
    HttpResponse handle_websocket_handshake(const HttpRequest& req);

    int port_;
    std::atomic<bool> running_{false};
    std::thread server_thread_;
    
    std::mutex routes_mutex_;
    std::map<std::string, HttpHandler> routes_;

    // Core Native Subsystems
    Agent3Engine agent_engine_;
    UniversalLlmAdapter model_adapter_;
    GraphWorkflow graph_workflow_;
    PakistanPaymentEngine payment_engine_;

    std::vector<MapSegment> in_memory_segments_;
    std::map<std::string, std::string> device_keys_;
};

} // namespace nifdu

#endif // NIFDU_HTTP_SERVER_HPP
