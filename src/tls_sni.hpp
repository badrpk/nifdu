#ifndef NIFDU_TLS_SNI_HPP
#define NIFDU_TLS_SNI_HPP
#include <memory>
#include <string>
namespace boost::asio::ssl { class context; }
struct SniManager {
    void add_or_update(const std::string&, const std::string&, const std::string&) {}
};
extern SniManager mgr;
extern void load_all_certs();
std::shared_ptr<boost::asio::ssl::context> build_ssl_ctx_with_sni(SniManager&);
#endif
