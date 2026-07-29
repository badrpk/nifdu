#include "nifdu/telemetry.hpp"
#include <cmath>
#include <sstream>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

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

    constexpr double R = 6371000.0;
    double dLat = (p2.lat - p1.lat) * M_PI / 180.0;
    double dLng = (p2.lng - p1.lng) * M_PI / 180.0;

    double a = std::sin(dLat / 2.0) * std::sin(dLat / 2.0) +
               std::cos(p1.lat * M_PI / 180.0) * std::cos(p2.lat * M_PI / 180.0) *
               std::sin(dLng / 2.0) * std::sin(dLng / 2.0);

    double c = 2.0 * std::atan2(std::sqrt(a), std::sqrt(1.0 - a));
    seg.distance_m = R * c;

    seg.speed_kmh = (p1.speed_kmh + p2.speed_kmh) / 2.0;
    seg.mode = classify_mode(seg.speed_kmh, (p1.alt_m + p2.alt_m) / 2.0);

    return seg;
}

json TelemetryEngine::build_geojson_edges(const std::vector<MapSegment>& segments, int min_samples) {
    json feature_collection;
    feature_collection["type"] = "FeatureCollection";

    json features = json::array();
    for (const auto& seg : segments) {
        json feature;
        feature["type"] = "Feature";

        json geometry;
        geometry["type"] = "LineString";
        geometry["coordinates"] = json::array({
            json::array({seg.p1.lng, seg.p1.lat}),
            json::array({seg.p2.lng, seg.p2.lat})
        });

        json properties;
        properties["distance_m"] = seg.distance_m;
        properties["speed_kmh"] = seg.speed_kmh;
        properties["mode"] = seg.mode;
        properties["samples"] = min_samples;

        feature["geometry"] = geometry;
        feature["properties"] = properties;

        features.push_back(feature);
    }

    feature_collection["features"] = features;
    return feature_collection;
}

} // namespace nifdu
