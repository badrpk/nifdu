#pragma once
#include <string>
#include <cstdlib>
#include <fstream>
#include <filesystem>
#include <windows.h>
#include <atomic>
#include <chrono>

namespace nifdu_truth {

struct TruthResult {
    bool compiled = false;
    int exit_code = -1;
    std::string output;
    std::string command_line;
};

// Thread-safe unique ID generator
inline std::string get_unique_id() {
    static std::atomic<unsigned long long> counter{0};
    auto now = std::chrono::high_resolution_clock::now().time_since_epoch().count();
    return std::to_string(now) + "_" + std::to_string(counter++);
}

inline std::string write_temp_cpp(const std::string& expr, std::string& out_exe) {
    std::filesystem::create_directories("C:/nifdu/temp");

    std::string id   = get_unique_id();
    std::string base = "C:/nifdu/temp/truth_" + id;
    std::string src  = base + ".cpp";
    out_exe          = base + ".exe";

    std::ofstream ofs(src);
    ofs << "#include <iostream>\n"
           "int main(){ if(" << expr << ") return 0; return 99; }\n";
    return src;
}

TruthResult verify(const std::string& expression);

} // namespace nifdu_truth
