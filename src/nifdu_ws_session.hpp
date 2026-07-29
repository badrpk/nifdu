#pragma once
#include <boost/beast.hpp>
#include <boost/asio.hpp>
#include <memory>
#include <string>

namespace nifdu {

namespace beast     = boost::beast;
namespace http      = beast::http;
namespace websocket = beast::websocket;
namespace asio      = boost::asio;
using tcp           = asio::ip::tcp;

class ws_session : public std::enable_shared_from_this<ws_session> {
public:
    explicit ws_session(tcp::socket&& socket)
        : ws_(std::move(socket)) {}

    void run(http::request<http::string_body>&& req) {
        ws_.set_option(websocket::stream_base::timeout::suggested(beast::role_type::server));
        ws_.set_option(websocket::stream_base::decorator([](websocket::response_type& res) {
            res.set(http::field::server, "NIFDU-http80");
        }));

        ws_.async_accept(req,
            beast::bind_front_handler(&ws_session::on_accept, shared_from_this()));
    }

private:
    websocket::stream<tcp::socket> ws_;
    beast::flat_buffer buffer_;

    void on_accept(beast::error_code ec) {
        if (ec) return;
        do_read();
    }

    void do_read() {
        ws_.async_read(buffer_,
            beast::bind_front_handler(&ws_session::on_read, shared_from_this()));
    }

    void on_read(beast::error_code ec, std::size_t) {
        if (ec == websocket::error::closed) return;
        if (ec) return;

        ws_.text(ws_.got_text());
        ws_.async_write(buffer_.data(),
            beast::bind_front_handler(&ws_session::on_write, shared_from_this()));
    }

    void on_write(beast::error_code ec, std::size_t) {
        if (ec) return;
        buffer_.consume(buffer_.size());
        do_read();
    }
};

} // namespace nifdu