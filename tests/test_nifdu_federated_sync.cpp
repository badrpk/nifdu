#include "nifdu/federated_sync.hpp"
#include <iostream>

int main() {
    std::cout << "=== NIFDU Global Federated Self-Improvement & Continuous Delivery Test ===" << std::endl;

    nifdu::FederatedSyncEngine sync_hub;

    nifdu::ImprovementPayload payload;
    payload.client_id = "client_node_89412";
    payload.feature_hash = "simd_vector_opt_0x99a";
    payload.latency_gain_ms = 0.497;
    payload.memory_gain_mb = 3.2;
    payload.code_patch = "// SIMD Auto-Vectorization Patch";
    payload.verification_signature = "sig_ecc_verified_pass";

    bool submitted = sync_hub.submit_improvement(payload);
    std::cout << "Submitted to Consensus Server: " << (submitted ? "SUCCESS" : "FAILED") << std::endl;

    auto updates = sync_hub.check_for_updates("2.0.0");
    std::cout << "Global Update Check: " << updates.dump(2) << std::endl;

    return 0;
}
