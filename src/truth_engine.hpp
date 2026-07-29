#pragma once
#include <string>
#include <cstdlib>
#include <fstream>
#include <filesystem>
#include <windows.h>
#include <atomic>
#include <chrono>
#include <iostream>

namespace nifdu_truth {

struct TruthResult {
    bool compiled = false;
    int exit_code = -1;
    std::string output;
    std::string command_line;
};

inline std::string get_unique_id() {
    static std::atomic<unsigned long long> counter{0};
    auto now = std::chrono::high_resolution_clock::now().time_since_epoch().count();
    return std::to_string(now) + "_" + std::to_string(counter++);
}

inline std::string write_temp_cpp(const std::string& input, std::string& out_exe) {
    std::filesystem::create_directories("C:/nifdu/temp");
    std::string id = get_unique_id();
    std::string base = "C:/nifdu/temp/truth_" + id;
    std::string src = base + ".cpp";
    out_exe = base + ".exe";

    std::ofstream ofs(src);
    
    // --- INTELLIGENT WRAPPER ---
    // If input contains "int main", assume it's a full program.
    // Otherwise, treat it as a boolean expression to verify.
    if (input.find("int main") != std::string::npos) {
        ofs << input; 
    } else {
        // Expression Mode: Return 0 (True) if expression is true, 99 if false.
        ofs << "#include <iostream>\n"
            << "#include <cmath>\n"
            << "#include <string>\n"
            << "#include <vector>\n"
            << "int main(){ if(" << input << ") return 0; return 99; }\n";
    }
    
    return src;
}

TruthResult verify(const std::string& expression);

} // namespace nifdu_truth
