#include <iostream>
#include <thread>
#include <chrono>
#include "ai/av_trigger.hpp"

int main() {
    std::cout << "=== NIFDU C++ BINARY RUNNING ===" << std::endl;
    const char* jobs[] = {
        "slide the cat from left to right",
        "the cat spins into the void",
        "cat vibrates at 50Hz"
    };
    
    for (const auto& p : jobs) {
        std::cout << "[C++] Sending Job: " << p << std::endl;
        trigger_av_render(p);
        std::cout << "[C++] Waiting 5s for render..." << std::endl;
        std::this_thread::sleep_for(std::chrono::seconds(5));
    }
    return 0;
}
