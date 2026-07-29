#pragma once
#include <string>
#include <optional>
#include <memory>

namespace nifdu::ops {

struct K8sDeployment {
    std::string name;
    std::string namespace_;
    int         replicas = 1;
    std::string image;
};

class IKubernetesClient {
public:
    virtual ~IKubernetesClient() = default;

    virtual bool applyDeployment(const K8sDeployment& d) = 0;
    virtual std::optional<K8sDeployment> getDeployment(const std::string& ns,
                                                       const std::string& name) = 0;
};

std::unique_ptr<IKubernetesClient> createK8sClientFromEnv();

} // namespace nifdu::ops
