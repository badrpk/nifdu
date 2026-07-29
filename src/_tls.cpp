#include "tls_sni.hpp"
#include <iostream>

// Single global instance used by the rest of the code.
SniManager mgr;

// Stub implementation: in the real system this would populate mgr
// with certificates and keys for SNI. For now we just log once.
void load_all_certs() {
    std::cerr << "[TLS] load_all_certs() stub called; real TLS/SNI loading disabled.\n";
}
