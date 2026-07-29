#pragma once

#include <string>

namespace nifdu {
namespace security {
namespace tls {

struct TlsConfig {
    std::string cert_file;
    std::string key_file;
    std::string ca_file;
    bool        require_client_cert = false;
};

void init_tls(const TlsConfig& cfg);
std::string status_summary();

} // namespace tls
} // namespace security
} // namespace nifdu
