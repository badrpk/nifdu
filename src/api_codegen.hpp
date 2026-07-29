#pragma once

#include "httplib.h"

// Very small API for now: just a registration helper.
namespace nifdu::codegen {

    // Attach GET/POST routes for /api/codegen to the given HTTP80 server.
    void register_routes(httplib::Server& svr);

} // namespace nifdu::codegen
