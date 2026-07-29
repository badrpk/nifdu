#pragma once

#include <string>
#include <unordered_map>
#include <mutex>
#include <optional>

namespace nifdu::acme {

class ChallengeRegistry {
public:
    static ChallengeRegistry& Instance() {
        static ChallengeRegistry inst;
        return inst;
    }

    // token -> value
    void SetToken(const std::string& token, const std::string& value) {
        std::lock_guard<std::mutex> lock(mutex_);
        tokens_[token] = value;
    }

    void ClearToken(const std::string& token) {
        std::lock_guard<std::mutex> lock(mutex_);
        tokens_.erase(token);
    }

    std::optional<std::string> GetToken(const std::string& token) const {
        std::lock_guard<std::mutex> lock(mutex_);
        auto it = tokens_.find(token);
        if (it == tokens_.end()) return std::nullopt;
        return it->second;
    }

    // Convenience helper for HTTP router:
    // If target == "/.well-known/acme-challenge/<token>",
    // returns the token value (if present).
    std::optional<std::string> TryResolveFromPath(const std::string& target) const {
        static const std::string prefix = "/.well-known/acme-challenge/";
        if (target.rfind(prefix, 0) != 0) { // not starting with prefix
            return std::nullopt;
        }
        std::string token = target.substr(prefix.size());
        return GetToken(token);
    }

private:
    mutable std::mutex mutex_;
    std::unordered_map<std::string, std::string> tokens_;
};

} // namespace nifdu::acme
