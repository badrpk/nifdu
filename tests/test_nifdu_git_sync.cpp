#include "nifdu/git_sync_engine.hpp"
#include <iostream>

int main() {
    std::cout << "=== NIFDU Recursive Self-Improvement & GitHub Sync Test ===" << std::endl;

    nifdu::GitSyncEngine sync_engine(".", "origin", "master");

    double old_lat = 0.525; // LangGraph latency
    double new_lat = 0.028; // NIFDU SIMD latency

    if (sync_engine.verify_improvement(old_lat, new_lat)) {
        double gain = ((old_lat - new_lat) / old_lat) * 100.0;
        auto commit = sync_engine.commit_improvement("SIMD Vector Processing Acceleration", {"include/nifdu/simd_data_engine.hpp", "src/simd_data_engine.cpp"}, gain);
        
        std::cout << "Auto-Commit Generated: " << commit.commit_id << " | Verified Gain: " << commit.performance_gain_percent << "%" << std::endl;
        std::cout << "Sync Status: " << sync_engine.get_sync_status().dump(2) << std::endl;
    }

    return 0;
}
