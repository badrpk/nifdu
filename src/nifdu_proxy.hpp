#pragma once

// NIFDU PROXY LAYER
// ------------------
// This module is the reverse-proxy / gateway core for NIFDU.
// It is designed to grow into a Traefik / Envoy-class front door,
// while staying single-binary, C++20, and AI-aware.
//
// Features designed here (some stubbed, some partial):
// - Hot-reloadable config (file-based, no restarts)
// - Multiple load-balancing algorithms
// - Circuit breakers, retries
// - TLS/ACME integration hooks (HTTP-01 + DNS-01 capable)
// - WebSocket / HTTP/2 / gRPC-ready router
// - Metrics (Prometheus-style) hooks
// - JSON + CLF access logs
// - REST API surface for configuration / inspection
// - Backend discovery hooks: Docker, Kubernetes, ECS, File

#include <string>
#include <vector>
#include <chrono>
#include <atomic>
#include <functional>
#include <cstdint>

namespace nifdu::proxy {

enum class Protocol {
    Http1,
    Http2,
    Grpc,
    WebSocket
};

enum class LBAlgorithm {
    RoundRobin,
    LeastConnections,
    Random,
    PowerOfTwoChoices
};

enum class HealthStatus {
    Unknown,
    Healthy,
    Unhealthy
};

struct CircuitBreakerConfig {
    std::uint32_t maxFailures      = 5;           // trip after N failures
    std::chrono::milliseconds coolDown { 30'000}; // stay open for this duration
    std::chrono::milliseconds window   { 10'000}; // failure window
};

struct RetryPolicy {
    std::uint32_t maxRetries = 2;
    std::chrono::milliseconds backoff { 200 };    // simple fixed backoff for now
};

struct Backend {
    std::string  id;              // e.g. "api-1"
    std::string  address;         // "127.0.0.1:8091" or "10.0.0.5:9000"
    Protocol     protocol = Protocol::Http1;
    std::atomic<std::uint64_t> activeConnections { 0 };
    std::atomic<HealthStatus>  health { HealthStatus::Unknown };
};

struct Route {
    std::string  host;            // e.g. "nifdu.com"
    std::string  pathPrefix;      // e.g. "/api"
    std::string  rule;            // free-form rule, reserved
    std::string  serviceName;     // logical backend pool name
    bool         stripPrefix = false;
};

struct Service {
    std::string        name;              // logical name
    LBAlgorithm        lbAlgo = LBAlgorithm::RoundRobin;
    CircuitBreakerConfig cb;
    RetryPolicy          retry;
    std::vector<Backend> backends;
};

struct TLSCertificate {
    std::string hostPattern;   // e.g. "nifdu.com" or "*.sophyane.com"
    std::string certPath;
    std::string keyPath;
    bool        isWildcard = false;
};

struct ProxyConfig {
    std::string              name = "nifdu-proxy";
    std::string              bindAddress = "0.0.0.0";
    std::uint16_t            httpPort    = 80;
    std::uint16_t            httpsPort   = 443;
    bool                     enableHTTP2 = true;
    bool                     enableWebSocket = true;
    bool                     enableGrpc = true;
    bool                     enableRestApi = true;
    std::string              acmeDirectory;      // where HTTP-01 tokens live
    std::string              acmeEmail;
    std::string              acmeDnsProvider;    // e.g. "godaddy"
    std::vector<std::string> acmeDomains;        // hostnames to manage
    std::vector<Route>       routes;
    std::vector<Service>     services;
    std::vector<TLSCertificate> certificates;
    std::string              accessLogDir;       // where logs will be written
};

// Load configuration from a TOML/JSON file (currently expects file backend).
// Returns true on success, false on error; err gets human-readable detail.
bool load_config_from_file(const std::string& path,
                           ProxyConfig& out,
                           std::string& err);

// Install a background watcher that reloads config when the file changes.
// This is the basis for "no-restart" configuration.
void start_hot_reload(const std::string& path);

// Stops the background hot-reload watcher, if any.
void stop_hot_reload();

// Initialize metrics subsystem (counters, histograms, etc).
// Concrete implementation will live under src/metrics.
void init_metrics();

// Expose metrics over HTTP (e.g. Prometheus scrape endpoint).
// This will mount a small HTTP listener on a dedicated port or path.
void expose_metrics_http(std::uint16_t port);

// Initialize access logging. If dir is empty, logging can be disabled.
// Implementation will support JSON + CLF formats.
void init_logging(const std::string& dir);

// Log a single access entry.
// status: HTTP status code; duration: end-to-end latency; bytes: response size.
void log_access(const std::string& host,
                const std::string& path,
                const std::string& method,
                std::uint16_t      status,
                std::uint64_t      bytes,
                std::chrono::microseconds duration);

// REST API: attach handlers into existing HTTP router.
// The handlerRegistrar is expected to bind paths like:
//   GET  /api/proxy/config
//   POST /api/proxy/reload
//   GET  /api/proxy/routes
//   GET  /api/proxy/services
//
// handlerRegistrar(resourcePath, httpVerb, handlerFnOpaquePtr)
// is left very generic so it can be integrated with your current HTTP stack.
using RestRegistrar = std::function<void(
    const std::string& path,
    const std::string& method,
    void*              handlerOpaque)>;

void register_rest_api(RestRegistrar registrar);

// Backend discovery hooks (Docker, Kubernetes, ECS).
// Currently these provide stub implementations that can be upgraded later.

void discover_docker_backends(ProxyConfig& cfg);
void discover_kubernetes_backends(ProxyConfig& cfg);
void discover_ecs_backends(ProxyConfig& cfg);

// Single entry point for the proxy configuration layer.
// Called from your main() after nifdu_platform is loaded.
void init_proxy_from_file(const std::string& path);

// Route a request to an appropriate backend service.
// This is the primary integration point with your HTTP stack.
// The "Request" and "Response" types are intentionally opaque (void*)
// so you can adapt them to Boost.Beast http::request/response or any other type.
void route_and_proxy(void* requestOpaque, void* responseOpaque);

} // namespace nifdu::proxy

