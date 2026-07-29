#include "pkg/nifdu_package_manager.hpp"
#include <iostream>

namespace nifdu {
namespace pkg {

void init_package_manager(const std::string& root) {
    std::cout << "[NIFDU::Pkg] STUB init at " << root << std::endl;
}

bool install_package(const std::string& name) {
    std::cout << "[NIFDU::Pkg] STUB install " << name << std::endl;
    return true;
}

std::vector<PackageInfo> list_installed() {
    std::cout << "[NIFDU::Pkg] STUB list installed packages." << std::endl;
    return {};
}

} // namespace pkg
} // namespace nifdu
