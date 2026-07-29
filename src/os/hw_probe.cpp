#include "os/hw_probe.hpp"

namespace nifdu {
namespace os {

HardwareSnapshot HardwareProbe::probe() const {
    HardwareSnapshot s;
    s.cpu  = "stub-cpu";
    s.ram  = "stub-ram";
    s.gpu  = "stub-gpu";
    s.bios = "stub-bios";
    return s;
}

} // namespace os
} // namespace nifdu
