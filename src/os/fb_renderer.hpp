#pragma once
#include <string>

namespace nifdu {
namespace os {

class FramebufferRenderer {
public:
    void draw_text(int x, int y, const std::string& text);
};

} // namespace os
} // namespace nifdu
