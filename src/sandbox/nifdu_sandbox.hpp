#pragma once

#include <string>

namespace nifdu {
namespace sandbox {

struct ExecResult {
    int exit_code = 0;
    std::string stdout_text;
    std::string stderr_text;
};

void init_sandbox();
ExecResult run_snippet(const std::string& code);

} // namespace sandbox
} // namespace nifdu
