#pragma once
#include <boost/beast.hpp>
#include <string>

namespace nifdu {
namespace beast = boost::beast;
namespace http  = beast::http;

inline http::response<http::string_body>
socket_http_stub(const http::request<http::string_body>& req) {
    http::response<http::string_body> res{http::status::ok, req.version()};
    res.set(http::field::server, "NIFDU-http80");
    res.set(http::field::content_type, "application/json; charset=utf-8");
    res.keep_alive(req.keep_alive());
    res.body() =
        "{"
          "\"status\":\"ok\","
          "\"route\":\"/socket\","
          "\"mode\":\"http_stub\","
          "\"hint\":\"Send WebSocket Upgrade headers to switch to ws\""
        "}";
    res.prepare_payload();
    return res;
}

} // namespace nifdu