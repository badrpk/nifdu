#include "nifdu/agent3.hpp"
#include "nifdu/telemetry.hpp"
#include "nifdu/realtime.hpp"
#include <iostream>
#include <cassert>

int main() {
    std::cout << "====================================================\n";
    std::cout << "🚀 NIFDU C++ ENGINE & AGENT-3 TOUGH HARNESS TEST\n";
    std::cout << "====================================================\n\n";

    int passed = 0;
    int failed = 0;

    auto assert_test = [&](bool condition, const std::string& message) {
        if (condition) {
            std::cout << "  ✅ [PASS] " << message << "\n";
            passed++;
        } else {
            std::cout << "  ❌ [FAIL] " << message << "\n";
            failed++;
        }
    };

    // TEST 1: Agent-3 Engine Plan Creation
    std::cout << "TEST 1: Agent-3 Plan Engine Creation\n";
    nifdu::Agent3Engine agent;
    auto plan = agent.create_plan("sess_tough_001", "Build real-time high frequency trading terminal");
    assert_test(plan.steps.size() == 5, "Agent-3 created 5-step autonomous plan");

    // TEST 2: Agent-3 Step Execution
    std::cout << "\nTEST 2: Agent-3 Step Execution Handler\n";
    auto step_res = agent.execute_step("sess_tough_001", 1);
    assert_test(step_res["status"] == "completed", "Step 1 executed and marked completed");

    // TEST 3: Event Stream Retrieval
    std::cout << "\nTEST 3: Agent-3 Realtime Event Stream\n";
    auto events = agent.get_events("sess_tough_001");
    assert_test(events["events"].size() >= 2, "Agent-3 event stream logged plan_created and step_completed");

    // TEST 4: Visual Diff Preview Engine
    std::cout << "\nTEST 4: Diff Preview Generator\n";
    auto diff = agent.preview_diff("/home/badrpk/nifdu/CMakeLists.txt", "# Updated CMake Configuration");
    assert_test(diff.diff_patch.find("+++") != std::string::npos, "Diff patch generated with standard +++ format");

    // TEST 5: Snapshot & Revert Engine
    std::cout << "\nTEST 5: Undo State Snapshot & Revert Engine\n";
    std::string snap_id = agent.create_snapshot({"/home/badrpk/nifdu/CMakeLists.txt"});
    assert_test(!snap_id.empty(), "Snapshot ID created");
    bool reverted = agent.revert_snapshot(snap_id);
    assert_test(reverted, "Revert snapshot executed successfully");

    // TEST 6: Telemetry Velocity & Transport Mode Classifier
    std::cout << "\nTEST 6: Telemetry Transport Mode Classifier (Road vs Flight vs Walk)\n";
    std::string mode_road = nifdu::TelemetryEngine::classify_mode(65.0, 500.0);
    std::string mode_air = nifdu::TelemetryEngine::classify_mode(850.0, 11000.0);
    std::string mode_walk = nifdu::TelemetryEngine::classify_mode(4.5, 200.0);

    assert_test(mode_road == "road", "Speed 65 km/h classified as road");
    assert_test(mode_air == "air", "Speed 850 km/h at 11,000m classified as air");
    assert_test(mode_walk == "walk", "Speed 4.5 km/h classified as walk");

    // TEST 7: PostGIS GeoJSON Vector Edge Builder
    std::cout << "\nTEST 7: PostGIS GeoJSON Vector Edge Builder\n";
    nifdu::TelemetryPoint p1{"2026-07-26T14:40:00Z", 33.700, 73.060, 520.0, 75.0};
    nifdu::TelemetryPoint p2{"2026-07-26T14:40:10Z", 33.705, 73.065, 520.0, 80.0};
    auto seg = nifdu::TelemetryEngine::process_pair(p1, p2);
    auto geojson = nifdu::TelemetryEngine::build_geojson_edges({seg}, 1);

    assert_test(geojson["type"] == "FeatureCollection", "GeoJSON FeatureCollection root created");
    assert_test(geojson["features"].size() == 1, "GeoJSON contains 1 line segment feature");

    // TEST 8: WebRTC Ephemeral TURN Credentials Generator
    std::cout << "\nTEST 8: WebRTC TURN Ephemeral Credential Engine\n";
    auto turn = nifdu::RealtimeHub::generate_turn_credentials("tough_harness_user");
    assert_test(turn["uris"].size() >= 2, "WebRTC STUN/TURN URIs generated");
    assert_test(turn["password"].get<std::string>().find("ephemeral_pass_") == 0, "TURN ephemeral password generated");

    // Summary
    std::cout << "\n====================================================\n";
    std::cout << "📊 HARNESS SUMMARY: " << passed << " PASSED, " << failed << " FAILED\n";
    std::cout << "====================================================\n\n";

    return (failed == 0) ? 0 : 1;
}
