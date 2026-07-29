// acme_client.hpp
#pragma once

#include <string>
#include <memory>

class SniManager;

namespace nifdu::acme {

class AcmeClient {
public:
    static AcmeClient& Instance();

    void AttachSniManager(SniManager* mgr);
    void SetCertRoot(const std::string& path);
    void StartRenewalThread();
    bool EnsureCertificate(const std::string& domain);   // <-- this line was missing

    AcmeClient();
    ~AcmeClient();
    AcmeClient(const AcmeClient&) = delete;
    AcmeClient& operator=(const AcmeClient&) = delete;

private:
    struct Impl;
    std::unique_ptr<Impl> pimpl;
};

} // namespace nifdu::acme