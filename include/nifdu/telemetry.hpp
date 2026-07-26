#ifndef NIFDU_TELEMETRY_HPP
#define NIFDU_TELEMETRY_HPP

#include <nlohmann/json.hpp>
#include <string>
#include <vector>

namespace nifdu {

using json = nlohmann::json;

struct TelemetryPoint {
    std::string at;
    double lat = 0.0;
    double lng = 0.0;
    double alt_m = 0.0;
    double speed_kmh = 0.0;
};

struct MapSegment {
    TelemetryPoint p1;
    TelemetryPoint p2;
    double distance_m = 0.0;
    double speed_kmh = 0.0;
    std::string mode; // "air", "fast_rail", "road", "walk", "unknown"
};

class TelemetryEngine {
public:
    static std::string classify_mode(double speed_kmh, double alt_m);
    static MapSegment process_pair(const TelemetryPoint& p1, const TelemetryPoint& p2);
    static json build_geojson_edges(const std::vector<MapSegment>& segments, int min_samples = 5);
};

} // namespace nifdu

#endif // NIFDU_TELEMETRY_HPP
