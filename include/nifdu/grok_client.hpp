#ifndef NIFDU_GROK_CLIENT_HPP
#define NIFDU_GROK_CLIENT_HPP

#include <string>
#include <vector>
#include <functional>
#include <nlohmann/json.hpp>

namespace nifdu {

using json = nlohmann::json;

struct GrokMessage {
    std::string role; // "system", "user", "assistant"
    std::string content;
};

class GrokClient {
public:
    GrokClient(std::string api_key = "", std::string model = "grok-2-vision-1212");

    // Native xAI Grok API Integration
    std::string invoke(const std::string& prompt);
    bool invoke_stream(const std::string& prompt, std::function<void(const std::string& chunk)> on_chunk);

    // X (Twitter) Real-Time Data Stream Integration
    json search_x_realtime(const std::string& query, int max_results = 10);

private:
    std::string api_key_;
    std::string model_;
    std::string api_url_ = "https://api.x.ai/v1/chat/completions";
};

} // namespace nifdu

#endif // NIFDU_GROK_CLIENT_HPP
