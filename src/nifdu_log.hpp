#pragma once
#include <vector>
#include <string>
#include <mutex>

namespace nifdu_log {

    static std::vector<std::string> log_buffer;
    static std::mutex log_mutex;

    inline void push(const std::string& s) {
        std::lock_guard<std::mutex> lock(log_mutex);
        log_buffer.push_back(s);
        if (log_buffer.size() > 2000)
            log_buffer.erase(log_buffer.begin());
    }

    inline std::vector<std::string> get() {
        std::lock_guard<std::mutex> lock(log_mutex);
        return log_buffer;
    }

} // namespace nifdu_log
