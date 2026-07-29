#ifndef NIFDU_GIT_SYNC_ENGINE_HPP
#define NIFDU_GIT_SYNC_ENGINE_HPP

#include <string>
#include <vector>
#include <nlohmann/json.hpp>

namespace nifdu {

using json = nlohmann::json;

struct SelfImprovementCommit {
    std::string commit_id;
    std::string feature_name;
    double performance_gain_percent = 0.0;
    bool verified_passing = false;
    std::string timestamp;
};

class GitSyncEngine {
public:
    GitSyncEngine(std::string repo_path = ".", std::string remote_name = "origin", std::string branch = "master");

    // Local recursive self-improvement verification
    bool verify_improvement(double old_latency_ms, double new_latency_ms);
    
    // Automated Git commit & push subsystem
    SelfImprovementCommit commit_improvement(const std::string& feature_name, const std::vector<std::string>& modified_files, double gain_percent);
    bool push_to_github(const std::string& commit_msg);

    // Sync status accessor
    json get_sync_status() const;

private:
    std::string repo_path_;
    std::string remote_name_;
    std::string branch_;
    std::vector<SelfImprovementCommit> commit_history_;
};

} // namespace nifdu

#endif // NIFDU_GIT_SYNC_ENGINE_HPP
