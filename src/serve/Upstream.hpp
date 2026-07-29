#pragma once
#include <string>
#include <vector>
#include <atomic>
#include <mutex>
#include <optional>

namespace nifdu::serve {

struct Backend {
    std::string host;
    uint16_t    port = 0;
    int         weight = 1;
    bool        healthy = true;
};

class UpstreamPool {
public:
    explicit UpstreamPool(std::string name);

    void addBackend(const Backend& backend);
    std::optional<Backend> pickNext();  // simple round-robin for now
    void markHealthy(const std::string& host, uint16_t port, bool healthy);

    const std::string& name() const { return name_; }

private:
    std::string name_;
    std::vector<Backend> backends_;
    std::atomic<size_t> index_{0};
    mutable std::mutex mutex_;
};

} // namespace nifdu::serve
