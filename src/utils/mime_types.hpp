#pragma once

// NIFDU temporary mime_types.hpp stub.
// This mirrors the classic Boost.Beast helper: mime_type(path).

#include <boost/beast/core/string.hpp>

namespace nifdu {
namespace utils {

    inline boost::beast::string_view mime_type(boost::beast::string_view path)
    {
        // SUPER SIMPLE stub: everything = application/octet-stream.
        // You can later paste in your full real implementation.
        return "application/octet-stream";
    }

} // namespace utils
} // namespace nifdu
