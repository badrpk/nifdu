#pragma once
#include <string>
#include <vector>
#include <unordered_map>

enum class RouteMode {
    Static,  // serve file from docroot
    Ssg,     // pre-generated static (same as Static at runtime)
    Ssr,     // per-request C++ render (stubbed for now)
    Api      // JSON API route
};

struct RouteConfig {
    std::string pattern;          // e.g. "/", "/blog/[id]", "/api/ping"
    RouteMode   mode;
    std::string file;             // relative file for Static/Ssg/Ssr
    int         revalidateSeconds;
};

struct RouteMatch {
    const RouteConfig* route = nullptr;
    std::unordered_map<std::string, std::string> params;
};

struct SiteConfig {
    std::string host;     // e.g. "nifdu.com"
    std::string docRoot;  // e.g. "C:/webroot/nifdu.com/www"
};

// All sites NIFDU knows about.
const std::vector<SiteConfig>& getSites();

// Routes for a specific host (can be empty → pure static).
const std::vector<RouteConfig>& getRoutesForHost(const std::string& host);

// Try to match a path ("/", "/blog/foo") against route patterns.
bool matchRoute(const std::string& path,
                const std::vector<RouteConfig>& routes,
                RouteMatch& outMatch);

// Register a tenant site from platform config (e.g. snacks.nifdu.com).
void registerTenantSite(const std::string& host, const std::string& docRoot);
