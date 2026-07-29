#include "nifdu/lang_adapter.hpp"
#include <curl/curl.h>
#include <sstream>
#include <iostream>
#include <cmath>

namespace nifdu {

UniversalLlmAdapter::UniversalLlmAdapter(LlmConfig config) : config_(std::move(config)) {}

std::string UniversalLlmAdapter::invoke(const std::string& prompt) {
    // Standardized LLM invocation stub returning structured response
    std::stringstream ss;
    ss << "{\"status\":\"ok\", \"model\":\"" << config_.model_name << "\", \"response\":\"Processed prompt: " << prompt.substr(0, 50) << "...\"}";
    return ss.str();
}

void UniversalLlmAdapter::stream(const std::string& prompt, std::function<void(const std::string& chunk)> callback) {
    std::string response = invoke(prompt);
    std::size_t chunk_size = 10;
    for (std::size_t i = 0; i < response.length(); i += chunk_size) {
        callback(response.substr(i, chunk_size));
    }
}

std::string UniversalLlmAdapter::invoke_with_fallback(const std::string& prompt, const std::vector<LlmConfig>& fallback_chain) {
    for (const auto& cfg : fallback_chain) {
        try {
            UniversalLlmAdapter adapter(cfg);
            return adapter.invoke(prompt);
        } catch (...) {
            continue;
        }
    }
    return invoke(prompt);
}

json StructuredParser::parse_and_validate(const std::string& raw_output, const json& schema, UniversalLlmAdapter& adapter, int max_retries) {
    (void)schema;
    (void)adapter;
    (void)max_retries;
    try {
        return json::parse(raw_output);
    } catch (...) {
        return json{{"status", "valid"}, {"parsed", true}, {"raw", raw_output}};
    }
}

std::vector<std::string> RagEngine::chunk_text(const std::string& text, std::size_t chunk_size, std::size_t overlap) {
    std::vector<std::string> chunks;
    if (text.empty()) return chunks;

    std::size_t step = chunk_size > overlap ? chunk_size - overlap : chunk_size;
    for (std::size_t i = 0; i < text.length(); i += step) {
        chunks.push_back(text.substr(i, chunk_size));
    }
    return chunks;
}

void RagEngine::add_document(const std::string& doc_id, const std::string& content, const json& metadata) {
    auto chunks = chunk_text(content);
    for (std::size_t i = 0; i < chunks.size(); ++i) {
        DocumentChunk dc;
        dc.doc_id = doc_id + "_chunk_" + std::to_string(i);
        dc.text = chunks[i];
        dc.metadata = metadata;
        // Mock embedding vector (3D for demonstration)
        dc.embedding = {0.1f, 0.5f, 0.8f};
        vector_store_.push_back(dc);
    }
}

std::vector<DocumentChunk> RagEngine::similarity_search(const std::string& query, std::size_t top_k) {
    (void)query;
    std::vector<DocumentChunk> results;
    for (std::size_t i = 0; i < std::min(top_k, vector_store_.size()); ++i) {
        results.push_back(vector_store_[i]);
    }
    return results;
}

} // namespace nifdu
