// src/render/context.hpp
#pragma once

#include <string>

namespace nifdu::render {

struct RenderContext {
    std::string clientIp;
    std::string userAgent;
    std::string host;
    std::string path;
};

} // namespace nifdu::render
