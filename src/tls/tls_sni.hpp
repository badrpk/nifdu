#pragma once

#include <string>
#include <unordered_map>
#include <memory>

#include <openssl/ssl.h>

namespace nifdu::tls {

struct TlsCert {
    std::string fullchain;
    std::string key;
    SSL_CTX*    ctx = nullptr;
};

struct TlsRegistry {
    std::unordered_map<std::string, TlsCert> hosts;
    SSL_CTX* default_ctx = nullptr;
};

/// Load C:/nifdu/config/tls-map.json into registry and create one SSL_CTX per host.
/// Returns nullptr on error.
std::shared_ptr<TlsRegistry> load_tls_registry(const std::string& json_path);

/// SNI callback to select SSL_CTX based on hostname.
/// Use as SSL_CTX_set_tlsext_servername_callback(default_ctx, sni_callback);
int sni_callback(SSL* ssl, int* ad, void* arg);

} // namespace nifdu::tls
