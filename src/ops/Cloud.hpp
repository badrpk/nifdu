#pragma once
#include <string>
#include <memory>

namespace nifdu::ops {

enum class CloudProvider {
    AWS,
    Azure
};

class ICloudProvider {
public:
    virtual ~ICloudProvider() = default;

    virtual bool createBucket(const std::string& name) = 0;
    virtual bool createVm(const std::string& name, const std::string& size) = 0;
    virtual bool createDnsRecord(const std::string& zone,
                                 const std::string& host,
                                 const std::string& ip) = 0;
};

std::unique_ptr<ICloudProvider> createCloudProvider(CloudProvider cp);

} // namespace nifdu::ops
