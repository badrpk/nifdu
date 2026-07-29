#pragma once
#include <string>

namespace nifdu {
namespace security {
    void initialize_post_quantum_crypto();
    std::string get_post_quantum_crypto_status();
}
}
