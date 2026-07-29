#include "os/desktop/nifdu_desktop.hpp"
#include <iostream>

namespace nifdu {
namespace os {
namespace desktop {

void init_desktop_shell() {
    std::cout << "[NIFDU::Desktop] STUB init (no real windows yet)." << std::endl;
}

void run_main_loop() {
    std::cout << "[NIFDU::Desktop] STUB main loop — no events." << std::endl;
}

bool is_supported() {
    return false; // TODO: flip when first prototype exists.
}

} // namespace desktop
} // namespace os
} // namespace nifdu
