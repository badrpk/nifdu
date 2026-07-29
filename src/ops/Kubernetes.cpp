#include "ops/Kubernetes.hpp"
#include <iostream>

namespace nifdu::ops {

namespace {
class NullK8sClient : public IKubernetesClient {
public:
    bool applyDeployment(const K8sDeployment& d) override {
        std::cerr << "[NIFDU] NullK8sClient applyDeployment name="
                  << d.name << " ns=" << d.namespace_ << std::endl;
        return true;
    }

    std::optional<K8sDeployment> getDeployment(const std::string& ns,
                                               const std::string& name) override {
        std::cerr << "[NIFDU] NullK8sClient getDeployment ns="
                  << ns << " name=" << name << std::endl;
        return std::nullopt;
    }
};
} // namespace

std::unique_ptr<IKubernetesClient> createK8sClientFromEnv() {
    // TODO: implement real K8s client using REST / kubeconfig
    return std::make_unique<NullK8sClient>();
}

} // namespace nifdu::ops
