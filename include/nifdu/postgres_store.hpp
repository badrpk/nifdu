#ifndef NIFDU_POSTGRES_STORE_HPP
#define NIFDU_POSTGRES_STORE_HPP

#include <nlohmann/json.hpp>
#include <string>
#include <vector>
#include <mutex>
#include <thread>
#include <queue>
#include <atomic>
#include <chrono>

namespace nifdu {

using json = nlohmann::json;

struct TraceSpan {
    std::string span_id;
    std::string parent_id;
    std::string run_id;
    std::string name;
    std::string span_type; // "chain", "llm", "tool", "agent"
    std::string input_json;
    std::string output_json;
    double latency_ms = 0.0;
    int prompt_tokens = 0;
    int completion_tokens = 0;
    std::string timestamp;
};

struct GraphCheckpoint {
    std::string checkpoint_id;
    std::string session_id;
    int step_index = 0;
    std::string state_json;
    std::string timestamp;
};

class PostgresStore {
public:
    PostgresStore(std::string conn_info = "host=127.0.0.1 port=5432 dbname=nifdu user=postgres password=postgres");
    ~PostgresStore();

    bool initialize_schema();
    
    // LangSmith Superior Trace Logging API
    void log_span(const TraceSpan& span);
    
    // LangGraph Superior Checkpoint Persistence API
    bool save_checkpoint(const std::string& session_id, int step_index, const json& state);
    json get_checkpoint(const std::string& session_id, int step_index);

    // Metrics & Performance Accessors
    size_t pending_spans_count();
    double get_avg_write_latency_ms() const { return avg_write_latency_ms_; }

private:
    void flush_loop();
    
    std::string conn_info_;
    std::atomic<bool> running_{true};
    std::thread flush_thread_;
    
    std::mutex queue_mutex_;
    std::queue<TraceSpan> span_queue_;
    
    std::mutex checkpoint_mutex_;
    std::map<std::string, std::vector<GraphCheckpoint>> in_memory_checkpoints_;

    double avg_write_latency_ms_ = 0.025; // Sub-millisecond target
};

} // namespace nifdu

#endif // NIFDU_POSTGRES_STORE_HPP
