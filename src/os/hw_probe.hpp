#pragma once
#include <string>

namespace nifdu {
namespace os {

struct HardwareSnapshot {
    std::string cpu;
    std::string ram;
    std::string gpu;
    std::string bios;
};

class HardwareProbe {
public:
    HardwareSnapshot probe() const;
};

} // namespace os
} // namespace nifdu
