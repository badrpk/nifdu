#include "truth_engine.hpp"
#include <iostream>

namespace nifdu_truth {

TruthResult verify(const std::string& expression) {
    TruthResult r;
    std::string exe_path;
    std::string src_path = write_temp_cpp(expression, exe_path);

    // Compile quietly; /Fe sets exe, /Fo sets obj path
    std::string obj_path = src_path + ".obj";
    std::string cmd =
        "cl /nologo /EHsc \"" + src_path + "\" "
        "/Fe\"" + exe_path + "\" "
        "/Fo\"" + obj_path + "\" "
        "> NUL 2>&1";

    r.command_line = cmd;

    int comp = std::system(cmd.c_str());
    if (comp != 0) {
        r.compiled = false;
        r.exit_code = comp;
        r.output = "Compilation Failed";

        std::filesystem::remove(src_path);
        std::filesystem::remove(obj_path);
        return r;
    }

    // Run compiled test program
    int run = std::system(exe_path.c_str());
    r.compiled  = true;
    r.exit_code = run;
    r.output    = (run == 0)
        ? "TRUE"
        : "FALSE (Exit " + std::to_string(run) + ")";

    // Cleanup
    std::filesystem::remove(src_path);
    std::filesystem::remove(obj_path);
    std::filesystem::remove(exe_path);

    return r;
}

} // namespace nifdu_truth
