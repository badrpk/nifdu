#pragma once
#include <string>

namespace nifdu {
namespace os {

struct BootConfig {
    std::string efi_path;
    std::string kernel_label;
};

class KernelBootPlanner {
public:
    void set_config(const BootConfig& cfg) { cfg_ = cfg; }
    const BootConfig& config() const noexcept { return cfg_; }

    // In future: write EFI entries / boot shims.
    void plan() const;

private:
    BootConfig cfg_;
};

} // namespace os
} // namespace nifdu
