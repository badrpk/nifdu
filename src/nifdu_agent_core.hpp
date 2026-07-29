#pragma once
#include <string>
#include <vector>
#include <fstream>
#include <iostream>
#include <array>
#include <memory>
#include <cstdio>
#include <nlohmann/json.hpp>

using json = nlohmann::json;

namespace nifdu_agent {
    // TOOL: Execute System Command
    inline std::string exec_system_cmd(const std::string& cmd) {
        std::array<char, 128> buffer;
        std::string result;
        std::string full_cmd = cmd + " 2>&1"; 
        std::unique_ptr<FILE, decltype(&_pclose)> pipe(_popen(full_cmd.c_str(), "r"), _pclose);
        if (!pipe) return "Error: Failed to open pipe.";
        while (fgets(buffer.data(), buffer.size(), pipe.get()) != nullptr) {
            result += buffer.data();
        }
        return result;
    }

    // MEMORY: JSON File
    inline void save_memory(const json& history) {
        std::ofstream file("C:\\nifdu\\conversation_history.json");
        if (file.is_open()) file << history.dump(4);
    }

    inline json load_memory() {
        std::ifstream file("C:\\nifdu\\conversation_history.json");
        if (!file.is_open()) return json::array();
        try { return json::parse(file); } catch (...) { return json::array(); }
    }

    inline void append_interaction(const std::string& user, const std::string& ai) {
        json hist = load_memory();
        if (hist.size() > 20) hist.erase(0); 
        hist.push_back({ {"role", "user"}, {"content", user} });
        hist.push_back({ {"role", "assistant"}, {"content", ai} });
        save_memory(hist);
    }
}
