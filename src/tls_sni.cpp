#include "tls_sni.hpp"
#include <iostream>
#include <memory>
namespace boost::asio::ssl { class context; }

SniManager mgr;
void load_all_certs() {
    std::cerr << "[STUB] load_all_certs() called.\n";
}
std::shared_ptr<boost::asio::ssl::context> build_ssl_ctx_with_sni(SniManager&) {
    std::cerr << "[STUB] build_ssl_ctx_with_sni() called. Returning null.\n";
    return nullptr;
}
