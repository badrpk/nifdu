#include <boost/beast/http.hpp>
#include <iostream>
#include <string>

namespace beast = boost::beast;
namespace http = beast::http;

namespace nifdu {
namespace http_api {

    // This matches the signature expected by the linker
    void handle_lead_api(
        http::request<http::string_body> const& req,
        http::response<http::string_body>& res) 
    {
        std::cout << "[LEAD API] Received Data: " << req.body() << std::endl;

        // Construct a simple success JSON response
        res.result(http::status::ok);
        res.set(http::field::server, "Nifdu Server");
        res.set(http::field::content_type, "application/json");
        res.body() = R"({"status":"success", "message":"Lead captured successfully"})";
        res.prepare_payload();
    }

} // namespace http_api
} // namespace nifdu
