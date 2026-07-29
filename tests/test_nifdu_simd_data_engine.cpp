#include "nifdu/simd_data_engine.hpp"
#include <iostream>
#include <chrono>
#include <vector>
#include <limits>

int main() {
    std::cout << "=== NIFDU Native C++ SIMD Vector Data Engine Benchmark ===" << std::endl;

    std::vector<double> dataset = {10.0, 20.0, std::numeric_limits<double>::quiet_NaN(), 40.0, 50.0, 60.0, 70.0, 80.0, 90.0, 100.0};
    
    // Warmup
    auto res_warmup = nifdu::SimdDataEngine::process_array(dataset);

    auto t0 = std::chrono::high_resolution_clock::now();
    
    // Run NIFDU SIMD Native Execution Loop 10,000 times to measure microsecond-level precision
    for (int i = 0; i < 10000; i++) {
        auto res = nifdu::SimdDataEngine::process_array(dataset);
    }
    
    auto t1 = std::chrono::high_resolution_clock::now();
    double total_us = std::chrono::duration<double, std::micro>(t1 - t0).count();
    double avg_us = total_us / 10000.0;
    double avg_ms = avg_us / 1000.0;

    std::cout << "NIFDU 10,000 Iterations Total Time: " << total_us << " us (" << total_us / 1000.0 << " ms)" << std::endl;
    std::cout << "NIFDU Average Latency Per Task: " << avg_us << " us (" << avg_ms << " ms)" << std::endl;
    std::cout << "Result Mean: " << res_warmup.mean << " | Valid Count: " << res_warmup.valid_count << std::endl;

    return 0;
}
