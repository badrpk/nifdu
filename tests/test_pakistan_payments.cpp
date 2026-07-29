#include "nifdu/http_server.hpp"
#include <curl/curl.h>
#include <iostream>
#include <cassert>

static size_t WriteCb(void* contents, size_t size, size_t nmemb, void* userp) {
    reinterpret_cast<std::string*>(userp)->append(reinterpret_cast<char*>(contents), size * nmemb);
    return size * nmemb;
}

std::string post_json(const std::string& url, const std::string& payload) {
    CURL* curl = curl_easy_init();
    std::string response;
    if (curl) {
        struct curl_slist* headers = nullptr;
        headers = curl_slist_append(headers, "Content-Type: application/json");
        curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
        curl_easy_setopt(curl, CURLOPT_POSTFIELDS, payload.c_str());
        curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
        curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, WriteCb);
        curl_easy_setopt(curl, CURLOPT_WRITEDATA, &response);
        curl_easy_perform(curl);
        curl_slist_free_all(headers);
        curl_easy_cleanup(curl);
    }
    return response;
}

int main() {
    std::cout << "====================================================\n";
    std::cout << "🇵🇰 TESTING PAKISTAN MULTI-GATEWAY PAYMENT ENGINE REST API\n";
    std::cout << "====================================================\n\n";

    nifdu::NativeHttpServer server(8019);
    server.start();
    std::this_thread::sleep_for(std::chrono::milliseconds(200));

    // Test 1: JazzCash
    std::cout << "1. Testing JazzCash Mobile Wallet API (/api/payments/jazzcash/pay)...\n";
    std::string jc_res = post_json("http://127.0.0.1:8019/api/payments/jazzcash/pay", "{\"msisdn\":\"923212558089\", \"amount_pkr\":25200.0}");
    std::cout << "   Response: " << jc_res << "\n\n";
    assert(jc_res.find("JazzCash") != std::string::npos);

    // Test 2: Easypaisa
    std::cout << "2. Testing Easypaisa OTC / Wallet API (/api/payments/easypaisa/pay)...\n";
    std::string ep_res = post_json("http://127.0.0.1:8019/api/payments/easypaisa/pay", "{\"msisdn\":\"923212558089\", \"amount_pkr\":25200.0}");
    std::cout << "   Response: " << ep_res << "\n\n";
    assert(ep_res.find("Easypaisa") != std::string::npos);

    // Test 3: UPaisa
    std::cout << "3. Testing UPaisa Wallet API (/api/payments/upaisa/pay)...\n";
    std::string up_res = post_json("http://127.0.0.1:8019/api/payments/upaisa/pay", "{\"msisdn\":\"923212558089\", \"amount_pkr\":25200.0}");
    std::cout << "   Response: " << up_res << "\n\n";
    assert(up_res.find("UPaisa") != std::string::npos);

    // Test 4: SBP Raast Instant Gateway
    std::cout << "4. Testing State Bank of Pakistan Raast API (/api/payments/raast/pay)...\n";
    std::string raast_res = post_json("http://127.0.0.1:8019/api/payments/raast/pay", "{\"msisdn_alias\":\"923212558089\", \"amount_pkr\":25200.0}");
    std::cout << "   Response: " << raast_res << "\n\n";
    assert(raast_res.find("Raast") != std::string::npos);

    // Test 5: Credit/Debit Card Charge
    std::cout << "5. Testing Credit/Debit Card Gateway (/api/payments/card/charge)...\n";
    std::string card_res = post_json("http://127.0.0.1:8019/api/payments/card/charge", "{\"card_number\":\"4242424242424242\", \"amount_usd\":90.0}");
    std::cout << "   Response: " << card_res << "\n\n";
    assert(card_res.find("Credit") != std::string::npos);

    server.stop();

    std::cout << "====================================================\n";
    std::cout << "✅ ALL 5 PAKISTAN PAYMENT GATEWAYS PASSED!\n";
    std::cout << "====================================================\n";

    return 0;
}
