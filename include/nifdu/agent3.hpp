#ifndef NIFDU_AGENT3_HPP
#define NIFDU_AGENT3_HPP

#include <nlohmann/json.hpp>
#include <string>
#include <vector>
#include <map>
#include <memory>
#include <chrono>

namespace nifdu {

using json = nlohmann::json;

struct PlanStep {
    int id = 0;
    std::string description;
    std::string action; // "read", "write", "mkdir", "rm", "run", "git"
    std::string target;
    bool completed = false;
};

struct AgentPlan {
    std::string session_id;
    std::string prompt;
    std::vector<PlanStep> steps;
    int current_step_index = 0;
    bool completed = false;
};

struct DiffPreview {
    std::string target_file;
    std::string old_content;
    std::string new_content;
    std::string diff_patch;
};

struct UndoSnapshot {
    std::string snapshot_id;
    std::string timestamp;
    std::map<std::string, std::string> file_states; // path -> content
};

class Agent3Engine {
public:
    Agent3Engine();
    
    // Plan APIs
    AgentPlan create_plan(const std::string& session_id, const std::string& prompt);
    json execute_step(const std::string& session_id, int step_id);
    json get_events(const std::string& session_id);
    
    // Diff & Undo APIs
    DiffPreview preview_diff(const std::string& filepath, const std::string& new_content);
    std::string create_snapshot(const std::vector<std::string>& filepaths);
    bool revert_snapshot(const std::string& snapshot_id);
    
    // Process Execution APIs
    std::string start_process(const std::string& command, const std::string& cwd);
    json poll_process(const std::string& process_id);
    bool stop_process(const std::string& process_id);

private:
    std::map<std::string, AgentPlan> active_plans_;
    std::map<std::string, std::vector<json>> session_events_;
    std::map<std::string, UndoSnapshot> snapshots_;
};

} // namespace nifdu

#endif // NIFDU_AGENT3_HPP
