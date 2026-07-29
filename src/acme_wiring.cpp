#include "tls_sni.hpp"
#include "acme_client.hpp"
#include <iostream>

extern SniManager mgr;  // defined in server_tls.cpp

void nifdu_init_acme()
{
    using nifdu::acme::AcmeClient;
    auto& acme = AcmeClient::Instance();

    acme.AttachSniManager(&mgr);
    acme.SetCertRoot("C:/nifdu/certs");
    acme.StartRenewalThread();

    std::cout << "[NIFDU] On-demand ACME/TLS initialized (skeleton)" << std::endl;
}
