#include "ops/Cloud.hpp"
#include <iostream>

namespace nifdu::ops {

namespace {

class NullCloud : public ICloudProvider {
public:
    explicit NullCloud(CloudProvider cp) : cp_(cp) {}

    bool createBucket(const std::string& name) override {
        std::cerr << "[NIFDU] NullCloud(" << static_cast<int>(cp_)
                  << ") createBucket " << name << std::endl;
        return true;
    }

    bool createVm(const std::string& name, const std::string& size) override {
        std::cerr << "[NIFDU] NullCloud(" << static_cast<int>(cp_)
                  << ") createVm " << name << " size=" << size << std::endl;
        return true;
    }

    bool createDnsRecord(const std::string& zone,
                         const std::string& host,
                         const std::string& ip) override {
        std::cerr << "[NIFDU] NullCloud(" << static_cast<int>(cp_)
                  << ") createDnsRecord " << host << "." << zone
                  << " -> " << ip << std::endl;
        return true;
    }

private:
    CloudProvider cp_;
};

} // namespace

std::unique_ptr<ICloudProvider> createCloudProvider(CloudProvider cp) {
    // TODO: real AWS / Azure SDK bindings
    return std::make_unique<NullCloud>(cp);
}

} // namespace nifdu::ops
