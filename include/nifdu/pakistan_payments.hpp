#pragma once

#include <string>
#include <vector>
#include <map>

namespace nifdu {

struct PaymentResult {
    bool success;
    std::string transaction_id;
    std::string gateway;
    double amount_pkr;
    double amount_usd;
    std::string msisdn;
    std::string status_code;
    std::string response_message;
    std::string raw_response;
};

class PakistanPaymentEngine {
public:
    PakistanPaymentEngine();

    // JazzCash Merchant API
    PaymentResult initiate_jazzcash_payment(const std::string& msisdn, double amount_pkr, const std::string& ref_id);

    // Easypaisa Merchant API
    PaymentResult initiate_easypaisa_payment(const std::string& msisdn, double amount_pkr, const std::string& ref_id);

    // UPaisa Merchant API
    PaymentResult initiate_upaisa_payment(const std::string& msisdn, double amount_pkr, const std::string& ref_id);

    // SBP Raast Instant Payment Gateway (MSISDN Alias)
    PaymentResult initiate_raast_payment(const std::string& msisdn_alias, double amount_pkr, const std::string& iban);

    // Credit / Debit Card Processing (VISA / Mastercard)
    PaymentResult process_card_payment(const std::string& card_number, const std::string& exp_month_year, const std::string& cvv, double amount_usd);

    // Config & Secrets Vault Link
    void load_vault_config(const std::string& vault_path);

private:
    std::string m_jazzcash_merchant_id;
    std::string m_jazzcash_password;
    std::string m_jazzcash_hash_key;
    std::string m_easypaisa_store_id;
    std::string m_easypaisa_hash_key;
    std::string m_raast_participant_id;
};

} // namespace nifdu
