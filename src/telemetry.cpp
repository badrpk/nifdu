#include "nifdu/telemetry.hpp"
#include <cmath>
#include <sstream>

namespace nifdu {

std::string TelemetryEngine::classify_mode(double speed_kmh, double alt_m) {
    if (speed_kmh >= 800.0 || alt_m >= 3000.0) {
        return "air";
    }
    if (speed_kmh >= 250.0 && speed_kmh <= 400.0) {
        return "fast_rail";
    }
    if (speed_kmh >= 10.0 && speed_kmh <= 200.0) {
        return "road";
    }
    if (speed_kmh < 10.0) {
        return "walk";
    }
    return "unknown";
}

MapSegment TelemetryEngine::process_pair(const TelemetryPoint& p1, const TelemetryPoint& p2) {
    MapSegment seg;
    seg.p1 = p1;
    seg.p2 = p2;

    // Approximate Haversine distance in meters
    constexpr double R = 6371000.0; // Earth radius in meters
    double dLat = (p2.lat - p1.lat) * M_PI / 180.0;
    double dLng = (p2.lng - p1.lng) * M_PI / 180.0;

    double a = std::sin(dLat / 2) * std::sin(dLat / 2) +
               std::cos(p1.lat * M_PI / 180.0) * std::cos(p2.lat * M_PI / 180.0) *
               std::sin(dLng / 2) * std::sin(dLng / 2);

    double c = 2 * std::atan2(std::sqrt(a), std::sqrt(1 - a));
    seg.distance_m = R * c;

    seg.speed_kmh = p2.speed_kmh > 0 ? p2.speed_kmh : (seg.distance_m / 1000.0) * 3600.0;
    seg.mode = classify_mode(seg.speed_kmh, p2.alt_m);

    return seg;
}

json TelemetryEngine::build_geojson_edges(const std::vector<MapSegment>& segments, int min_samples) {
    json geojson;
    geojson["type"] = "FeatureCollection";
    json features = json::array();

    for (const auto& seg : segments) {
        json feature;
        feature["type"] = "Feature";
        feature["properties"] = {
            {"mode", seg.mode},
            {"speed_kmh", seg.speed_kmh},
            {"samples", min_samples}
        };

        feature["geometry"] = {
            {"type", "LineString"},
            {"coordinates", {
                {seg.p1.lng, seg.p1.lat},
                {seg.p2.lng, seg.p2.lat}
            }}
        };
        features.push_back(feature);
    }

    geojson["features"] = features;
    return geojson;
}

} // namespace nifdu
