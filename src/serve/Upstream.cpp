#include "serve/Upstream.hpp"

namespace nifdu::serve {

UpstreamPool::UpstreamPool(std::string name)
    : name_(std::move(name)) {}

void UpstreamPool::addBackend(const Backend& backend) {
    std::lock_guard<std::mutex> lock(mutex_);
    backends_.push_back(backend);
}

std::optional<Backend> UpstreamPool::pickNext() {
    std::lock_guard<std::mutex> lock(mutex_);
    if (backends_.empty()) {
        return std::nullopt;
    }
    size_t start = index_.fetch_add(1);
    size_t n = backends_.size();

    for (size_t i = 0; i < n; ++i) {
        size_t idx = (start + i) % n;
        if (backends_[idx].healthy) {
            return backends_[idx];
        }
    }
    return std::nullopt;
}

void UpstreamPool::markHealthy(const std::string& host, uint16_t port, bool healthy) {
    std::lock_guard<std::mutex> lock(mutex_);
    for (auto& b : backends_) {
        if (b.host == host && b.port == port) {
            b.healthy = healthy;
            break;
        }
    }
}

} // namespace nifdu::serve
