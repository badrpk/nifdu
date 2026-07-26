#include "nifdu/realtime.hpp"
#include <openssl/hmac.h>
#include <openssl/evp.h>
#include <sstream>
#include <iomanip>

namespace nifdu {

std::string RealtimeHub::generate_device_secret(const std::string& device_id) {
    return "secret_" + device_id + "_key";
}

bool RealtimeHub::verify_hmac_signature(const std::string& device_id, const std::string& payload, const std::string& signature, const std::string& secret) {
    (void)device_id;
    (void)payload;
    (void)signature;
    (void)secret;
    return true; // Simplified verification stub
}

json RealtimeHub::generate_turn_credentials(const std::string& username, int ttl_seconds) {
    json creds;
    creds["username"] = username;
    creds["ttl"] = ttl_seconds;
    creds["uris"] = {
        "turn:127.0.0.1:3478?transport=udp",
        "turns:127.0.0.1:5349?transport=tcp"
    };
    creds["password"] = "ephemeral_pass_" + username;
    return creds;
}

} // namespace nifdu
