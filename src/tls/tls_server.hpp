#pragma once
#include <string>
#include <map>
#include <boost/asio.hpp>
#include <boost/asio/ssl.hpp>

namespace nifdu_tls {

struct TLSHost {
    std::string host;
    std::string cert;
    std::string key;
};

void run_tls_server(unsigned short port,
                    const std::vector<TLSHost>& hosts,
                    unsigned short backend_port = 80);

} // namespace nifdu_tls
