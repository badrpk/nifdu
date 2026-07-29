#include "tls_server.hpp"
#include <iostream>
#include <thread>
#include <boost/asio/ssl.hpp>

using boost::asio::ip::tcp;

namespace nifdu_tls {

static std::map<std::string, std::shared_ptr<boost::asio::ssl::context>> g_contexts;

// Pick certificate by SNI
static boost::asio::ssl::context& get_context(const std::string& sni) {
    auto it = g_contexts.find(sni);
    if (it != g_contexts.end()) return *it->second;

    // fallback: first certificate
    return *g_contexts.begin()->second;
}

void run_tls_server(unsigned short port,
                    const std::vector<TLSHost>& hosts,
                    unsigned short backend_port)
{
    try {
        boost::asio::io_context ioc;

        // ---- Load certificates into contexts ----
        for (auto& h : hosts) {
            auto ctx = std::make_shared<boost::asio::ssl::context>(boost::asio::ssl::context::tls_server);
            ctx->set_options(boost::asio::ssl::context::default_workarounds |
                             boost::asio::ssl::context::no_sslv2 |
                             boost::asio::ssl::context::no_sslv3 |
                             boost::asio::ssl::context::single_dh_use);

            ctx->use_certificate_chain_file(h.cert);
            ctx->use_private_key_file(h.key, boost::asio::ssl::context::pem);

            g_contexts[h.host] = ctx;
        }

        // ---- Acceptor ----
        tcp::acceptor acceptor(ioc, tcp::endpoint(tcp::v4(), port));
        std::cout << "[TLS] Listening on 0.0.0.0:" << port << " (SNI enabled)" << std::endl;

        // ---- Main loop ----
        std::thread([&] {
            for (;;) {
                tcp::socket socket(ioc);

                acceptor.accept(socket);

                std::thread([s=std::move(socket), backend_port]() mutable {

                    try {
                        // Receive ClientHello → Extract SNI
                        std::array<char, 4096> bufx{};
                        s.receive(boost::asio::buffer(bufx));

                        std::string clientHello(bufx.begin(), bufx.end());
                        std::string host;

                        // Naive SNI extractor — works for Chrome/Firefox/Edge
                        size_t p = clientHello.find("server_name");
                        if (p != std::string::npos) {
                            size_t hstart = clientHello.find_last_of(0x00, p);
                            size_t hend = clientHello.find('\0', hstart + 1);
                            host = clientHello.substr(hstart + 1, hend - hstart - 1);
                        }

                        if (host.empty()) host = g_contexts.begin()->first;

                        auto& ctx = get_context(host);

                        // ---- TLS handshake ----
                        boost::asio::ssl::stream<tcp::socket> tls_stream(std::move(s), ctx);

                        tls_stream.handshake(boost::asio::ssl::stream_base::server);

                        // ---- Connect to backend ----
                        boost::asio::io_context b_ioc;
                        tcp::resolver resolver(b_ioc);
                        auto endpoints = resolver.resolve("127.0.0.1", std::to_string(backend_port));
                        tcp::socket backend(b_ioc);
                        boost::asio::connect(backend, endpoints);

                        // pipe TLS -> backend
                        std::thread([&]{
                            try {
                                std::array<char, 8192> buf;
                                for(;;){
                                    size_t n = tls_stream.read_some(boost::asio::buffer(buf));
                                    boost::asio::write(backend, boost::asio::buffer(buf,n));
                                }
                            } catch(...) {}
                        }).detach();

                        // pipe backend -> TLS
                        std::array<char, 8192> buf2;
                        for(;;){
                            size_t n = backend.read_some(boost::asio::buffer(buf2));
                            boost::asio::write(tls_stream, boost::asio::buffer(buf2,n));
                        }

                    } catch (std::exception &e) {
                        std::cerr << "[TLS ERROR] " << e.what() << std::endl;
                    }

                }).detach();
            }
        }).detach();

        ioc.run();

    } catch (std::exception &e) {
        std::cerr << "[TLS FATAL] " << e.what() << std::endl;
    }
}

} // namespace nifdu_tls
