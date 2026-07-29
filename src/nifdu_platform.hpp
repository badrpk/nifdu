#pragma once
#include <string>
#include <vector>

namespace nifdu::platform {

struct HttpConfig {
    std::string bind;          // "0.0.0.0"
    unsigned short port = 80;  // 80
    std::string acme_webroot;  // "C:/nifdu/acme-challenge"
    std::string sites_index;   // "C:/nifdu/certs/nifdu_certs.toml" (future TLS)
};

struct AiConfig {
    std::string chat_url;      // "http://127.0.0.1:8096"
    std::string embed_url;     // "http://127.0.0.1:8092"
    std::string model;         // "qwen2.5-1.5b-instruct"
    std::string embed_model;   // "bge-small-en-v1.5"
};

struct DbConfig {
    std::string dsn;               // pg DSN
    std::string vector_extension;  // "vector"
};

struct TenantConfig {
    std::string name;      // "snacks"
    std::string subdomain; // "snacks"
    std::string host;      // "snacks.nifdu.com"
    std::string docroot;   // "C:/webroot/nifdu.com/www/tenants/snacks"
    std::string ai_space;  // "tenant:snacks"
};

struct PlatformConfig {
    HttpConfig http;
    AiConfig   ai;
    DbConfig   db;
    std::vector<TenantConfig> tenants;
};

// Parse TOML file into PlatformConfig (returns false on failure, but does not throw).
bool loadPlatformConfig(const std::string& path, PlatformConfig& out);

// Global accessor after initFromFile() is called.
const PlatformConfig& getConfig();

// Initialize from TOML path; uses sane defaults if missing/error.
// Also registers tenant hosts into the router.
void initFromFile(const std::string& path);

// Helper: ACME challenge directory (http.acme_webroot + "/.well-known/acme-challenge").
std::string acmeChallengeDir();

} // namespace nifdu::platform
