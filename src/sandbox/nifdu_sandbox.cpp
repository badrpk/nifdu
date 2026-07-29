#include "sandbox/nifdu_sandbox.hpp"
#include <iostream>

namespace nifdu {
namespace sandbox {

void init_sandbox() {
    std::cout << "[NIFDU::Sandbox] STUB init (no isolation yet)." << std::endl;
}

ExecResult run_snippet(const std::string& code) {
    std::cout << "[NIFDU::Sandbox] STUB run snippet: " << code << std::endl;
    ExecResult r;
    r.exit_code   = 0;
    r.stdout_text = "sandbox stub: no execution.";
    r.stderr_text = "";
    return r;
}

} // namespace sandbox
} // namespace nifdu
