#ifndef NIFDU_LANG_ADAPTER_HPP
#define NIFDU_LANG_ADAPTER_HPP

#include <nlohmann/json.hpp>
#include <string>
#include <vector>
#include <memory>
#include <functional>

namespace nifdu {

using json = nlohmann::json;

// 1. Universal Model Adapter
enum class LlmProvider {
    OpenAI,
    Ollama,
    LlamaCpp,
    Gemini
};

struct LlmConfig {
    LlmProvider provider = LlmProvider::Ollama;
    std::string model_name = "llama3.1:latest";
    std::string api_key;
    std::string endpoint = "http://127.0.0.1:11434/v1/chat/completions";
    double temperature = 0.7;
    int max_tokens = 2048;
};

class UniversalLlmAdapter {
public:
    explicit UniversalLlmAdapter(LlmConfig config);
    std::string invoke(const std::string& prompt);
    void stream(const std::string& prompt, std::function<void(const std::string& chunk)> callback);
    
    // Fallback chain (OpenAI -> Ollama -> LlamaCpp)
    std::string invoke_with_fallback(const std::string& prompt, const std::vector<LlmConfig>& fallback_chain);

private:
    LlmConfig config_;
};

// 2. Structured Output Parser
class StructuredParser {
public:
    static json parse_and_validate(const std::string& raw_output, const json& schema, UniversalLlmAdapter& adapter, int max_retries = 3);
};

// 3. Document Loader, Text Splitter & RAG Vector Engine
struct DocumentChunk {
    std::string doc_id;
    std::string text;
    std::vector<float> embedding;
    json metadata;
};

class RagEngine {
public:
    static std::vector<std::string> chunk_text(const std::string& text, std::size_t chunk_size = 500, std::size_t overlap = 50);
    void add_document(const std::string& doc_id, const std::string& content, const json& metadata = {});
    std::vector<DocumentChunk> similarity_search(const std::string& query, std::size_t top_k = 3);

private:
    std::vector<DocumentChunk> vector_store_;
};

} // namespace nifdu

#endif // NIFDU_LANG_ADAPTER_HPP
