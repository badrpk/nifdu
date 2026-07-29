#include "tls_sni.hpp"

#include <fstream>
#include <iostream>
#include <algorithm>

#include <openssl/err.h>
#include <openssl/x509.h>

#include "nlohmann/json.hpp"

using json = nlohmann::json;

namespace nifdu::tls {

namespace {

SSL_CTX* create_ctx_from_files(const std::string& fullchain,
                               const std::string& key)
{
    const SSL_METHOD* method = TLS_server_method();
    SSL_CTX* ctx = SSL_CTX_new(method);
    if (!ctx) {
        std::cerr << "[tls] SSL_CTX_new failed" << std::endl;
        return nullptr;
    }

    SSL_CTX_set_min_proto_version(ctx, TLS1_2_VERSION);

    if (SSL_CTX_use_certificate_chain_file(ctx, fullchain.c_str()) != 1) {
        std::cerr << "[tls] Failed to load cert chain from: " << fullchain << std::endl;
        ERR_print_errors_fp(stderr);
        SSL_CTX_free(ctx);
        return nullptr;
    }

    if (SSL_CTX_use_PrivateKey_file(ctx, key.c_str(), SSL_FILETYPE_PEM) != 1) {
        std::cerr << "[tls] Failed to load key from: " << key << std::endl;
        ERR_print_errors_fp(stderr);
        SSL_CTX_free(ctx);
        return nullptr;
    }

    if (SSL_CTX_check_private_key(ctx) != 1) {
        std::cerr << "[tls] Private key does not match certificate for: " << fullchain << std::endl;
        ERR_print_errors_fp(stderr);
        SSL_CTX_free(ctx);
        return nullptr;
    }

    return ctx;
}

std::string to_lower(const std::string& s) {
    std::string out = s;
    std::transform(out.begin(), out.end(), out.begin(),
                   [](unsigned char c){ return static_cast<char>(std::tolower(c)); });
    return out;
}

} // namespace

std::shared_ptr<TlsRegistry> load_tls_registry(const std::string& json_path)
{
    std::ifstream in(json_path);
    if (!in) {
        std::cerr << "[tls] Cannot open TLS map: " << json_path << std::endl;
        return nullptr;
    }

    json j;
    try {
        in >> j;
    } catch (const std::exception& ex) {
        std::cerr << "[tls] Failed to parse TLS map JSON: " << ex.what() << std::endl;
        return nullptr;
    }

    if (!j.contains("hosts") || !j["hosts"].is_object()) {
        std::cerr << "[tls] TLS map missing 'hosts' object" << std::endl;
        return nullptr;
    }

    auto reg = std::make_shared<TlsRegistry>();

    for (auto it = j["hosts"].begin(); it != j["hosts"].end(); ++it) {
        const std::string host_raw = it.key();
        const std::string host     = to_lower(host_raw);

        const auto& h = it.value();
        const std::string fullchain = h.value("fullchain", "");
        const std::string key       = h.value("key", "");

        if (fullchain.empty() || key.empty()) {
            std::cerr << "[tls] Skipping host '" << host
                      << "' due to missing fullchain/key in TLS map" << std::endl;
            continue;
        }

        SSL_CTX* ctx = create_ctx_from_files(fullchain, key);
        if (!ctx) {
            std::cerr << "[tls] Skipping host '" << host
                      << "' due to SSL_CTX creation failure" << std::endl;
            continue;
        }

        TlsCert cert;
        cert.fullchain = fullchain;
        cert.key       = key;
        cert.ctx       = ctx;

        reg->hosts.emplace(host, std::move(cert));
    }

    if (reg->hosts.empty()) {
        std::cerr << "[tls] No valid hosts loaded from TLS map" << std::endl;
        return nullptr;
    }

    auto it = reg->hosts.find("nifdu.com");
    if (it != reg->hosts.end()) {
        reg->default_ctx = it->second.ctx;
    } else {
        reg->default_ctx = reg->hosts.begin()->second.ctx;
    }

    std::cerr << "[tls] Loaded " << reg->hosts.size()
              << " TLS hosts, default=" << (reg->default_ctx ? "OK" : "NULL")
              << std::endl;

    return reg;
}

int sni_callback(SSL* ssl, int* /*ad*/, void* arg)
{
    auto* reg = static_cast<TlsRegistry*>(arg);
    if (!reg) {
        return SSL_TLSEXT_ERR_NOACK;
    }

    const char* servername = SSL_get_servername(ssl, TLSEXT_NAMETYPE_host_name);
    if (!servername) {
        if (reg->default_ctx) {
            SSL_set_SSL_CTX(ssl, reg->default_ctx);
            return SSL_TLSEXT_ERR_OK;
        }
        return SSL_TLSEXT_ERR_NOACK;
    }

    std::string host = to_lower(servername);

    auto it = reg->hosts.find(host);
    if (it != reg->hosts.end() && it->second.ctx) {
        SSL_set_SSL_CTX(ssl, it->second.ctx);
        return SSL_TLSEXT_ERR_OK;
    }

    if (reg->default_ctx) {
        SSL_set_SSL_CTX(ssl, reg->default_ctx);
        return SSL_TLSEXT_ERR_OK;
    }

    return SSL_TLSEXT_ERR_NOACK;
}

} // namespace nifdu::tls
