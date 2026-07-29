#pragma once

#include <string>
#include <vector>

namespace nifdu {
namespace pkg {

struct PackageInfo {
    std::string name;
    std::string version;
};

void init_package_manager(const std::string& root);
bool install_package(const std::string& name);
std::vector<PackageInfo> list_installed();

} // namespace pkg
} // namespace nifdu
