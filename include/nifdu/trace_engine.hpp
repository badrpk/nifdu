#ifndef NIFDU_TRACE_ENGINE_HPP
#define NIFDU_TRACE_ENGINE_HPP

#include <nlohmann/json.hpp>
#include <string>
#include <vector>
#include <map>

namespace nifdu {

using json = nlohmann::json;

struct TraceSpan {
    std::string span_id;
    std::string parent_span_id;
    std::string name; // "llm", "tool", "chain", "retriever"
    std::string start_time;
    std::string end_time;
    long latency_ms = 0;
    int prompt_tokens = 0;
    int completion_tokens = 0;
    double estimated_cost_usd = 0.0;
    json inputs;
    json outputs;
    json metadata;
};

struct ExecutionTrace {
    std::string trace_id;
    std::string session_id;
    std::vector<TraceSpan> spans;
    std::string status; // "running", "completed", "error"
};

struct EvalDatasetExample {
    std::string id;
    json inputs;
    json ground_truth;
};

struct EvalResult {
    std::string dataset_id;
    int total_examples = 0;
    double pass_rate = 0.0;
    double average_score = 0.0;
    json detailed_scores;
};

class NifduTraceEngine {
public:
    static NifduTraceEngine& instance();

    std::string start_trace(const std::string& session_id, const std::string& root_name, const json& inputs);
    std::string start_span(const std::string& trace_id, const std::string& span_name, const std::string& parent_span_id = "", const json& inputs = {});
    void end_span(const std::string& trace_id, const std::string& span_id, const json& outputs, int prompt_tokens = 0, int completion_tokens = 0);
    void end_trace(const std::string& trace_id, const std::string& status = "completed");

    json get_trace_tree(const std::string& trace_id);
    json get_all_traces();

    // Evaluation & Benchmarking
    void register_dataset(const std::string& dataset_id, const std::vector<EvalDatasetExample>& examples);
    EvalResult run_benchmark(const std::string& dataset_id, std::function<json(const json& input)> target_fn);

private:
    NifduTraceEngine() = default;
    std::map<std::string, ExecutionTrace> traces_;
    std::map<std::string, std::vector<EvalDatasetExample>> datasets_;
};

} // namespace nifdu

#endif // NIFDU_TRACE_ENGINE_HPP
