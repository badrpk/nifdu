#include "nifdu/lang_smith.hpp"
#include <ctime>
#include <sstream>

namespace nifdu {

LangSmithTracer& LangSmithTracer::instance() {
    static LangSmithTracer tracer;
    return tracer;
}

std::string LangSmithTracer::start_trace(const std::string& session_id, const std::string& root_name, const json& inputs) {
    auto now = std::chrono::system_clock::now();
    std::time_t time = std::chrono::system_clock::to_time_t(now);
    std::stringstream ss;
    ss << "tr_" << session_id << "_" << time;
    std::string trace_id = ss.str();

    ExecutionTrace trace;
    trace.trace_id = trace_id;
    trace.session_id = session_id;
    trace.status = "running";

    TraceSpan root_span;
    root_span.span_id = "span_root";
    root_span.name = root_name;
    root_span.start_time = std::to_string(time);
    root_span.inputs = inputs;
    trace.spans.push_back(root_span);

    traces_[trace_id] = trace;
    return trace_id;
}

std::string LangSmithTracer::start_span(const std::string& trace_id, const std::string& span_name, const std::string& parent_span_id, const json& inputs) {
    if (!traces_.count(trace_id)) return "";

    auto now = std::chrono::system_clock::now();
    std::time_t time = std::chrono::system_clock::to_time_t(now);

    TraceSpan span;
    span.span_id = "span_" + std::to_string(traces_[trace_id].spans.size() + 1);
    span.parent_span_id = parent_span_id.empty() ? "span_root" : parent_span_id;
    span.name = span_name;
    span.start_time = std::to_string(time);
    span.inputs = inputs;

    traces_[trace_id].spans.push_back(span);
    return span.span_id;
}

void LangSmithTracer::end_span(const std::string& trace_id, const std::string& span_id, const json& outputs, int prompt_tokens, int completion_tokens) {
    if (!traces_.count(trace_id)) return;

    for (auto& span : traces_[trace_id].spans) {
        if (span.span_id == span_id) {
            span.outputs = outputs;
            span.prompt_tokens = prompt_tokens;
            span.completion_tokens = completion_tokens;
            span.latency_ms = 45; // Simulated latency ms
            span.estimated_cost_usd = (prompt_tokens * 0.0000015) + (completion_tokens * 0.000002);
            break;
        }
    }
}

void LangSmithTracer::end_trace(const std::string& trace_id, const std::string& status) {
    if (traces_.count(trace_id)) {
        traces_[trace_id].status = status;
    }
}

json LangSmithTracer::get_trace_tree(const std::string& trace_id) {
    if (!traces_.count(trace_id)) return json{{"error", "Trace not found"}};

    const auto& trace = traces_[trace_id];
    json res;
    res["trace_id"] = trace.trace_id;
    res["session_id"] = trace.session_id;
    res["status"] = trace.status;

    json spans = json::array();
    for (const auto& span : trace.spans) {
        spans.push_back({
            {"span_id", span.span_id},
            {"parent_span_id", span.parent_span_id},
            {"name", span.name},
            {"latency_ms", span.latency_ms},
            {"prompt_tokens", span.prompt_tokens},
            {"completion_tokens", span.completion_tokens},
            {"cost_usd", span.estimated_cost_usd},
            {"inputs", span.inputs},
            {"outputs", span.outputs}
        });
    }
    res["spans"] = spans;
    return res;
}

json LangSmithTracer::get_all_traces() {
    json arr = json::array();
    for (const auto& [tid, trace] : traces_) {
        arr.push_back(get_trace_tree(tid));
    }
    return arr;
}

void LangSmithTracer::register_dataset(const std::string& dataset_id, const std::vector<EvalDatasetExample>& examples) {
    datasets_[dataset_id] = examples;
}

EvalResult LangSmithTracer::run_benchmark(const std::string& dataset_id, std::function<json(const json& input)> target_fn) {
    EvalResult result;
    result.dataset_id = dataset_id;

    if (!datasets_.count(dataset_id)) return result;

    const auto& examples = datasets_[dataset_id];
    result.total_examples = examples.size();

    int passed = 0;
    json details = json::array();

    for (const auto& ex : examples) {
        json out = target_fn(ex.inputs);
        bool match = (out == ex.ground_truth);
        if (match) passed++;

        details.push_back({
            {"example_id", ex.id},
            {"passed", match},
            {"output", out},
            {"expected", ex.ground_truth}
        });
    }

    result.pass_rate = result.total_examples > 0 ? (double)passed / result.total_examples : 0.0;
    result.average_score = result.pass_rate * 100.0;
    result.detailed_scores = details;
    return result;
}

} // namespace nifdu
