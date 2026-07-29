#include "nifdu_platform.hpp"
#include "nifdu_routes.hpp"

#include <toml++/toml.hpp>
#include <iostream>
#include "tls/tls_sni.hpp"

namespace nifdu::platform {

namespace {

PlatformConfig g_cfg;

PlatformConfig makeDefaults()
{
    PlatformConfig cfg;
    cfg.http.bind = "0.0.0.0";
    cfg.http.port = 80;
    cfg.http.acme_webroot = "C:/nifdu/acme-challenge";
    cfg.http.sites_index  = "C:/nifdu/certs/nifdu_certs.toml";

    cfg.ai.chat_url    = "http://127.0.0.1:8096";
    cfg.ai.embed_url   = "http://127.0.0.1:8092";
    cfg.ai.model       = "qwen2.5-1.5b-instruct";
    cfg.ai.embed_model = "bge-small-en-v1.5";

    cfg.db.dsn = "";
    cfg.db.vector_extension = "vector";

    return cfg;
}

} // namespace

bool loadPlatformConfig(const std::string& path, PlatformConfig& out)
{
    PlatformConfig cfg = makeDefaults();

    try {
        auto tbl = toml::parse_file(path);

        if (auto http = tbl["http"].as_table()) {
            if (auto v = (*http)["bind"].value<std::string>())
                cfg.http.bind = *v;
            if (auto v = (*http)["port"].value<int64_t>())
                cfg.http.port = static_cast<unsigned short>(*v);
            if (auto v = (*http)["acme_webroot"].value<std::string>())
                cfg.http.acme_webroot = *v;
            if (auto v = (*http)["sites_index"].value<std::string>())
                cfg.http.sites_index = *v;
        }

        if (auto ai = tbl["ai"].as_table()) {
            if (auto v = (*ai)["chat_url"].value<std::string>())
                cfg.ai.chat_url = *v;
            if (auto v = (*ai)["embed_url"].value<std::string>())
                cfg.ai.embed_url = *v;
            if (auto v = (*ai)["model"].value<std::string>())
                cfg.ai.model = *v;
            if (auto v = (*ai)["embed_model"].value<std::string>())
                cfg.ai.embed_model = *v;
        }

        if (auto db = tbl["db"].as_table()) {
            if (auto v = (*db)["dsn"].value<std::string>())
                cfg.db.dsn = *v;
            if (auto v = (*db)["vector_extension"].value<std::string>())
                cfg.db.vector_extension = *v;
        }

        if (auto tenants = tbl["tenant"].as_table()) {
            for (auto&& [key, value] : *tenants) {
                auto t = value.as_table();
                if (!t) continue;

                TenantConfig tc;
                tc.name = key.str();

                if (auto v = (*t)["subdomain"].value<std::string>())
                    tc.subdomain = *v;
                if (auto v = (*t)["host"].value<std::string>())
                    tc.host = *v;
                if (auto v = (*t)["docroot"].value<std::string>())
                    tc.docroot = *v;
                if (auto v = (*t)["ai_space"].value<std::string>())
                    tc.ai_space = *v;

                if (!tc.host.empty() && !tc.docroot.empty()) {
                    cfg.tenants.push_back(std::move(tc));
                }
            }
        }

        out = std::move(cfg);
        return true;
    }
    catch (const std::exception& e) {
        std::cerr << "[nifdu-platform] Failed to parse TOML '"
                  << path << "': " << e.what() << std::endl;
        out = std::move(cfg); // defaults
        return false;
    }
}

const PlatformConfig& getConfig()
{
    return g_cfg;
}

void initFromFile(const std::string& path)
{
    PlatformConfig cfg;
    bool ok = loadPlatformConfig(path, cfg);

    if (!ok) {
        std::cerr << "[nifdu-platform] Using defaults (missing or invalid "
                  << path << ")" << std::endl;
    } else {
        std::cout << "[nifdu-platform] Loaded config from " << path << std::endl;
    }

    g_cfg = cfg;

    // Register tenant sites into router
    for (const auto& t : g_cfg.tenants) {
        if (!t.host.empty() && !t.docroot.empty()) {
            registerTenantSite(t.host, t.docroot);
            std::cout << "[nifdu-platform] Tenant host registered: "
                      << t.host << " -> " << t.docroot << std::endl;
        }
    }
}

std::string acmeChallengeDir()
{
    std::string base = g_cfg.http.acme_webroot;
    if (base.empty())
        base = "C:/nifdu/acme-challenge";
    if (!base.empty() && (base.back() == '/' || base.back() == '\\'))
        base.pop_back();
    return base + "/.well-known/acme-challenge";
}

} // namespace nifdu::platform

