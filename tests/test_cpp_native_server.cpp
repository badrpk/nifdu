#include "nifdu/http_server.hpp"
#include <curl/curl.h>
#include <iostream>
#include <thread>
#include <chrono>

static size_t WriteCallback(void* contents, size_t size, size_t nmemb, void* userp) {
    reinterpret_cast<std::string*>(userp)->append(reinterpret_cast<char*>(contents), size * nmemb);
    return size * nmemb;
}

std::string http_get(const std::string& url) {
    CURL* curl = curl_easy_init();
    std::string response;
    if (curl) {
        curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
        curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, WriteCallback);
        curl_easy_setopt(curl, CURLOPT_WRITEDATA, &response);
        curl_easy_perform(curl);
        curl_easy_cleanup(curl);
    }
    return response;
}

std::string http_post(const std::string& url, const std::string& json_payload, const std::vector<std::string>& headers = {}) {
    CURL* curl = curl_easy_init();
    std::string response;
    if (curl) {
        struct curl_slist* header_list = nullptr;
        header_list = curl_slist_append(header_list, "Content-Type: application/json");
        for (const auto& h : headers) {
            header_list = curl_slist_append(header_list, h.c_str());
        }

        curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
        curl_easy_setopt(curl, CURLOPT_POSTFIELDS, json_payload.c_str());
        curl_easy_setopt(curl, CURLOPT_HTTPHEADER, header_list);
        curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, WriteCallback);
        curl_easy_setopt(curl, CURLOPT_WRITEDATA, &response);
        
        curl_easy_perform(curl);
        curl_slist_free_all(header_list);
        curl_easy_cleanup(curl);
    }
    return response;
}

int main() {
    std::cout << "====================================================\n";
    std::cout << "🚀 NIFDU 100% NATIVE C++ HTTP & SERVER HARNESS TEST\n";
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

    // 1. Start Native C++ Server on Port 8011
    nifdu::NativeHttpServer server(8011);
    server.start();
    std::this_thread::sleep_for(std::chrono::milliseconds(200));

    // 2. Health Check Route
    std::cout << "TEST 1: Native C++ Socket /api/health\n";
    std::string health_res = http_get("http://127.0.0.1:8011/api/health");
    assert_test(health_res.find("nifdu-cpp-native-core") != std::string::npos, "Native C++ HTTP server returned healthy status");

    // 3. Agent-3 Plan Creation
    std::cout << "\nTEST 2: Native C++ /api/agent/plan\n";
    std::string plan_res = http_post("http://127.0.0.1:8011/api/agent/plan", "{\"session_id\":\"sess_native_01\", \"prompt\":\"Refactor server to 100% pure C++\"}");
    assert_test(plan_res.find("sess_native_01") != std::string::npos, "Native C++ Agent-3 plan created via HTTP socket");

    // 4. Telemetry Ingestion
    std::cout << "\nTEST 3: Native C++ Signed /api/telemetry\n";
    std::string telem_req = "{\"points\":[{\"lat\":33.7,\"lng\":73.06,\"alt_m\":500,\"speed_kmh\":60},{\"lat\":33.71,\"lng\":73.07,\"alt_m\":500,\"speed_kmh\":65}]}";
    std::string telem_res = http_post("http://127.0.0.1:8011/api/telemetry", telem_req, {"x-nifdu-deviceid: dev_cpp_99", "x-nifdu-signature: sig_cpp_99"});
    assert_test(telem_res.find("\"success\":true") != std::string::npos, "Native C++ Telemetry points processed");

    // 5. GeoJSON Map Edges Output
    std::cout << "\nTEST 4: Native C++ /api/map/edges GeoJSON Output\n";
    std::string map_res = http_get("http://127.0.0.1:8011/api/map/edges?min_samples=1");
    assert_test(map_res.find("FeatureCollection") != std::string::npos, "Native C++ GeoJSON FeatureCollection generated");

    // 6. Device Key Provisioning
    std::cout << "\nTEST 5: Native C++ /api/auth/key Device Secret\n";
    std::string key_res = http_post("http://127.0.0.1:8011/api/auth/key", "{\"deviceId\":\"dev_cpp_99\"}");
    assert_test(key_res.find("secret_dev_cpp_99_key") != std::string::npos, "Native C++ HMAC secret provisioned");

    // 7. Universal Model LLM Invoke
    std::cout << "\nTEST 6: Native C++ /api/llm/invoke\n";
    std::string llm_res = http_post("http://127.0.0.1:8011/api/llm/invoke", "{\"provider\":\"ollama\",\"prompt\":\"Convert all modules to C++\"}");
    assert_test(llm_res.find("Processed via Native C++ LLM Adapter") != std::string::npos, "Native C++ LLM invocation executed");

    // Stop Server
    server.stop();

    // Summary
    std::cout << "\n====================================================\n";
    std::cout << "📊 NATIVE C++ HARNESS SUMMARY: " << passed << " PASSED, " << failed << " FAILED\n";
    std::cout << "====================================================\n\n";

    return (failed == 0) ? 0 : 1;
}
