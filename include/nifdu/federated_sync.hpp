#ifndef NIFDU_FEDERATED_SYNC_HPP
#define NIFDU_FEDERATED_SYNC_HPP

#include <string>
#include <vector>
#include <nlohmann/json.hpp>

namespace nifdu {

using json = nlohmann::json;

struct ImprovementPayload {
    std::string client_id;
    std::string feature_hash;
    double latency_gain_ms = 0.0;
    double memory_gain_mb = 0.0;
    std::string code_patch;
    std::string verification_signature;
};

class FederatedSyncEngine {
public:
    FederatedSyncEngine(std::string hub_url = "https://www.xerus.biz/api/telemetry/submit-improvement");

    // 1. Submit client-side verified improvement to Central Consensus Engine
    bool submit_improvement(const ImprovementPayload& payload);

    // 2. Check for global consensus updates & auto-update binary
    json check_for_updates(const std::string& current_version = "2.0.0");
    bool apply_over_the_air_update(const std::string& download_url);

private:
    std::string hub_url_;
};

} // namespace nifdu

#endif // NIFDU_FEDERATED_SYNC_HPP
