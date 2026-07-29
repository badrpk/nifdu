#pragma once
#include <string>

namespace nifdu_ai {

    // Returns true if the AI client is “configured” (API key present, etc.)
    bool is_ready();

    // Calls the configured AI backend and returns the assistant text.
    // Throws std::runtime_error on hard failures.
    std::string call_qwen_completion(const std::string& prompt);

} // namespace nifdu_ai
