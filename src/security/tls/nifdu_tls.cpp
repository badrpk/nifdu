#include "security/tls/nifdu_tls.hpp"
#include <iostream>

namespace nifdu {
namespace security {
namespace tls {

void init_tls(const TlsConfig& cfg) {
    // TODO: Wire real OpenSSL/BoringSSL here.
    std::cout << "[NIFDU::TLS] STUB init - cert=" << cfg.cert_file
              << " key=" << cfg.key_file
              << " ca="  << cfg.ca_file << std::endl;
}

std::string status_summary() {
    // TODO: Return live TLS status.
    return "TLS stub: not yet enforcing real certificates.";
}

} // namespace tls
} // namespace security
} // namespace nifdu
