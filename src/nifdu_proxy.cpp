#include "nifdu_proxy.hpp"

#include <mutex>
#include <fstream>
#include <sstream>
#include <iostream>
#include <thread>
#include <filesystem>
#include <random>

namespace fs = std::filesystem;

namespace nifdu::proxy {

namespace {

// Global proxy configuration + synchronization.
ProxyConfig       g_config;
std::mutex        g_configMutex;
std::atomic<bool> g_hotReloadRunning { false };
std::thread       g_hotReloadThread;

// Simple helper: read entire file into string.
std::string load_file_to_string(const std::string& path)
{
    std::ifstream in(path, std::ios::binary);
    if (!in) return {};
    std::ostringstream ss;
    ss << in.rdbuf();
    return ss.str();
}

// Placeholder parser.
// For now we treat the config file as a very small custom INI-like source.
// Later it can be upgraded to full TOML/JSON without changing the public API.
bool parse_config_text(const std::string& text, ProxyConfig& cfg, std::string& err)
{
    // Extremely small placeholder: we only look for a few keys.
    // Anything more complex can be delegated to a dedicated parser later.
    cfg = ProxyConfig{};
    std::istringstream iss(text);
    std::string line;
    while (std::getline(iss, line)) {
        if (line.empty() || line[0] == '#')
            continue;
        auto pos = line.find('=');
        if (pos == std::string::npos)
            continue;
        std::string key = line.substr(0, pos);
        std::string val = line.substr(pos + 1);
        if (key == "name") {
            cfg.name = val;
        } else if (key == "bind") {
            cfg.bindAddress = val;
        } else if (key == "http_port") {
            cfg.httpPort = static_cast<std::uint16_t>(std::stoi(val));
        } else if (key == "https_port") {
            cfg.httpsPort = static_cast<std::uint16_t>(std::stoi(val));
        } else if (key == "access_log_dir") {
            cfg.accessLogDir = val;
        }
        // Routes, services, certificates, etc. intentionally omitted here.
        // They will be parsed from proper TOML/JSON in a later iteration.
    }

    if (cfg.bindAddress.empty()) {
        err = "bind address not specified in proxy config";
        return false;
    }
    return true;
}

// Simple random engine for LB choices.
std::mt19937& rng()
{
    static thread_local std::mt19937 eng{ std::random_device{}() };
    return eng;
}

// LB: pick backend index using specified algorithm.
int choose_backend_index(const Service& svc)
{
    const auto n = svc.backends.size();
    if (n == 0) return -1;
    switch (svc.lbAlgo) {
        case LBAlgorithm::RoundRobin: {
            static std::atomic<std::uint64_t> rrCounter { 0 };
            auto idx = rrCounter.fetch_add(1, std::memory_order_relaxed);
            return static_cast<int>(idx % n);
        }
        case LBAlgorithm::LeastConnections: {
            std::size_t best = 0;
            std::uint64_t bestVal = svc.backends[0].activeConnections.load(std::memory_order_relaxed);
            for (std::size_t i = 1; i < n; ++i) {
                auto v = svc.backends[i].activeConnections.load(std::memory_order_relaxed);
                if (v < bestVal) {
                    bestVal = v;
                    best = i;
                }
            }
            return static_cast<int>(best);
        }
        case LBAlgorithm::Random: {
            std::uniform_int_distribution<int> dist(0, static_cast<int>(n - 1));
            return dist(rng());
        }
        case LBAlgorithm::PowerOfTwoChoices: {
            if (n == 1) return 0;
            std::uniform_int_distribution<int> dist(0, static_cast<int>(n - 1));
            int i1 = dist(rng());
            int i2 = dist(rng());
            auto c1 = svc.backends[i1].activeConnections.load(std::memory_order_relaxed);
            auto c2 = svc.backends[i2].activeConnections.load(std::memory_order_relaxed);
            return (c1 <= c2) ? i1 : i2;
        }
    }
    return 0;
}

} // anonymous namespace

// ================== Public API ==================

bool load_config_from_file(const std::string& path,
                           ProxyConfig& out,
                           std::string& err)
{
    auto text = load_file_to_string(path);
    if (text.empty()) {
        err = "unable to read proxy config file: " + path;
        return false;
    }
    return parse_config_text(text, out, err);
}

void start_hot_reload(const std::string& path)
{
    stop_hot_reload(); // ensure only one watcher

    g_hotReloadRunning.store(true, std::memory_order_release);
    g_hotReloadThread = std::thread([path]() {
        std::cout << "[nifdu-proxy] hot-reload watching: " << path << "\n";
        std::error_code ec;
        auto last = fs::last_write_time(path, ec);
        if (ec) {
            std::cerr << "[nifdu-proxy] cannot stat config: " << ec.message() << "\n";
        }

        while (g_hotReloadRunning.load(std::memory_order_acquire)) {
            std::this_thread::sleep_for(std::chrono::seconds(2));
            std::error_code ecLoop;
            auto now = fs::last_write_time(path, ecLoop);
            if (ecLoop) continue;
            if (now != last) {
                last = now;
                ProxyConfig newCfg;
                std::string err;
                if (load_config_from_file(path, newCfg, err)) {
                    std::lock_guard<std::mutex> lock(g_configMutex);
                    g_config = std::move(newCfg);
                    std::cout << "[nifdu-proxy] config reloaded from " << path << "\n";
                } else {
                    std::cerr << "[nifdu-proxy] config reload failed: " << err << "\n";
                }
            }
        }
        std::cout << "[nifdu-proxy] hot-reload thread exiting.\n";
    });
}

void stop_hot_reload()
{
    if (!g_hotReloadRunning.exchange(false, std::memory_order_acq_rel)) {
        return;
    }
    if (g_hotReloadThread.joinable()) {
        g_hotReloadThread.join();
    }
}

void init_metrics()
{
    // Stub: in future this will integrate with src/metrics and export counters like:
    // - http_requests_total{host,method,code}
    // - http_request_duration_seconds_bucket
    // - backend_up{service,backend}
    std::cout << "[nifdu-proxy] metrics subsystem initialized (stub)\n";
}

void expose_metrics_http(std::uint16_t port)
{
    // Stub: this will spin up a tiny HTTP server on /metrics.
    std::cout << "[nifdu-proxy] metrics HTTP endpoint planned on port " << port << " (stub)\n";
}

void init_logging(const std::string& dir)
{
    std::lock_guard<std::mutex> lock(g_configMutex);
    g_config.accessLogDir = dir;
    if (dir.empty()) {
        std::cout << "[nifdu-proxy] access logging disabled (empty dir)\n";
    } else {
        std::cout << "[nifdu-proxy] access logging will use directory: " << dir << "\n";
    }
}

void log_access(const std::string& host,
                const std::string& path,
                const std::string& method,
                std::uint16_t      status,
                std::uint64_t      bytes,
                std::chrono::microseconds duration)
{
    std::string dir;
    {
        std::lock_guard<std::mutex> lock(g_configMutex);
        dir = g_config.accessLogDir;
    }
    if (dir.empty()) {
        // Minimal stdout JSON log as a default.
        std::cout << "{\"host\":\"" << host
                  << "\",\"path\":\"" << path
                  << "\",\"method\":\"" << method
                  << "\",\"status\":" << status
                  << ",\"bytes\":" << bytes
                  << ",\"duration_us\":" << duration.count()
                  << "}\n";
        return;
    }

    try {
        fs::create_directories(dir);
        auto logPath = fs::path(dir) / "access.log";
        std::ofstream out(logPath, std::ios::app);
        if (!out) {
            std::cerr << "[nifdu-proxy] cannot open access log: " << logPath << "\n";
            return;
        }
        out << "{\"host\":\"" << host
            << "\",\"path\":\"" << path
            << "\",\"method\":\"" << method
            << "\",\"status\":" << status
            << ",\"bytes\":" << bytes
            << ",\"duration_us\":" << duration.count()
            << "}\n";
    } catch (...) {
        // Swallow logging exceptions to avoid breaking the main flow.
    }
}

void register_rest_api(RestRegistrar registrar)
{
    if (!registrar) return;

    // Handlers are opaque; integration code will adapt your HTTP stack.
    registrar("/api/proxy/config", "GET",   nullptr);
    registrar("/api/proxy/routes", "GET",   nullptr);
    registrar("/api/proxy/services", "GET", nullptr);
    registrar("/api/proxy/reload", "POST",  nullptr);

    std::cout << "[nifdu-proxy] REST API endpoints registered (handlers stubbed)\n";
}

void discover_docker_backends(ProxyConfig& cfg)
{
    // Stub: future implementation will talk to Docker API on /var/run/docker.sock (Unix)
    // or named pipe on Windows, and populate cfg.services[].backends based on labels.
    (void)cfg;
    std::cout << "[nifdu-proxy] Docker discovery not yet implemented (stub)\n";
}

void discover_kubernetes_backends(ProxyConfig& cfg)
{
    // Stub: will use Kubernetes API (watch) to map Ingress/Service/Endpoint
    // objects into cfg.routes and cfg.services.
    (void)cfg;
    std::cout << "[nifdu-proxy] Kubernetes discovery not yet implemented (stub)\n";
}

void discover_ecs_backends(ProxyConfig& cfg)
{
    // Stub: will use AWS ECS APIs for task discovery and map to backends.
    (void)cfg;
    std::cout << "[nifdu-proxy] ECS discovery not yet implemented (stub)\n";
}

void init_proxy_from_file(const std::string& path)
{
    ProxyConfig newCfg;
    std::string err;
    if (!load_config_from_file(path, newCfg, err)) {
        std::cerr << "[nifdu-proxy] initial config load failed: " << err << "\n";
        return;
    }

    // Here we could also call discovery hooks to enrich the config:
    discover_docker_backends(newCfg);
    discover_kubernetes_backends(newCfg);
    discover_ecs_backends(newCfg);

    {
        std::lock_guard<std::mutex> lock(g_configMutex);
        g_config = std::move(newCfg);
    }

    std::cout << "[nifdu-proxy] initial config loaded from " << path << "\n";
}

void route_and_proxy(void* requestOpaque, void* responseOpaque)
{
    // This is the main glue point between the proxy and the HTTP stack.
    // In your Boost.Beast server, you can:
    //
    // - Wrap http::request<http::string_body>& in an opaque pointer
    // - Wrap http::response<http::string_body>& in an opaque pointer
    // - Inside this function, reinterpret_cast them back and perform:
    //   - host/path matching against g_config.routes
    //   - choose backend using choose_backend_index()
    //   - apply retry/circuit-breaker policy
    //   - proxy the bytes (future work)
    //
    // For now we only emit a trace message so this file is safe to compile
    // and publish, even before full proxying is wired in.

    (void)requestOpaque;
    (void)responseOpaque;

    std::cout << "[nifdu-proxy] route_and_proxy() invoked (stub; integrate with HTTP stack later)\n";
}

} // namespace nifdu::proxy
