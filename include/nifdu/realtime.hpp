#ifndef NIFDU_REALTIME_HPP
#define NIFDU_REALTIME_HPP

#include <nlohmann/json.hpp>
#include <string>

namespace nifdu {

using json = nlohmann::json;

class RealtimeHub {
public:
    static std::string generate_device_secret(const std::string& device_id);
    static bool verify_hmac_signature(const std::string& device_id, const std::string& payload, const std::string& signature, const std::string& secret);
    static json generate_turn_credentials(const std::string& username, int ttl_seconds = 86400);
};

} // namespace nifdu

#endif // NIFDU_REALTIME_HPP
