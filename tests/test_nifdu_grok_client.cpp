#include "nifdu/grok_client.hpp"
#include <iostream>

int main() {
    std::cout << "=== NIFDU Native xAI Grok & Real-Time X Search Test ===" << std::endl;
    
    nifdu::GrokClient grok("xai-test-key", "grok-2-vision-1212");
    
    std::cout << "[GrokClient] Invoking Grok Model Pipeline..." << std::endl;
    std::string response = grok.invoke("Analyze intrinsic value of Mughal Steel (MUGHAL.PSX)");
    std::cout << "Response: " << response << std::endl;

    std::cout << "\n[GrokClient] Searching Real-Time X (Twitter) Stream for #NIFDU..." << std::endl;
    auto tweets = grok.search_x_realtime("NIFDU", 3);
    std::cout << "X Real-Time Tweets:\n" << tweets.dump(2) << std::endl;

    return 0;
}
