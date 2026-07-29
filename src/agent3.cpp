#include "nifdu/agent3.hpp"
#include <fstream>
#include <sstream>
#include <iomanip>
#include <ctime>

namespace nifdu {

Agent3Engine::Agent3Engine() {}

AgentPlan Agent3Engine::create_plan(const std::string& session_id, const std::string& prompt) {
    AgentPlan plan;
    plan.session_id = session_id;
    plan.prompt = prompt;

    plan.steps.push_back({1, "Analyze target workspace and request", "read", ".", false});
    plan.steps.push_back({2, "Generate visual plan & preview diffs", "write", "plan.md", false});
    plan.steps.push_back({3, "Apply changes and update files", "write", "src/main.cpp", false});
    plan.steps.push_back({4, "Run build verification and tests", "run", "cmake --build build", false});
    plan.steps.push_back({5, "Capture logs and explain results", "read", "build/logs.txt", false});

    active_plans_[session_id] = plan;
    
    json evt = {
        {"event", "plan_created"},
        {"session_id", session_id},
        {"steps_count", plan.steps.size()}
    };
    session_events_[session_id].push_back(evt);

    return plan;
}

json Agent3Engine::execute_step(const std::string& session_id, int step_id) {
    json response;
    auto it = active_plans_.find(session_id);
    if (it == active_plans_.end()) {
        response["error"] = "Session not found";
        return response;
    }

    for (auto& step : it->second.steps) {
        if (step.id == step_id) {
            step.completed = true;
            response["step_id"] = step_id;
            response["status"] = "completed";
            response["action"] = step.action;
            response["target"] = step.target;

            json evt = {
                {"event", "step_completed"},
                {"step_id", step_id},
                {"target", step.target}
            };
            session_events_[session_id].push_back(evt);
            return response;
        }
    }

    response["error"] = "Step ID not found";
    return response;
}

json Agent3Engine::get_events(const std::string& session_id) {
    json response;
    response["session_id"] = session_id;
    response["events"] = session_events_[session_id];
    return response;
}

DiffPreview Agent3Engine::preview_diff(const std::string& filepath, const std::string& new_content) {
    DiffPreview preview;
    preview.target_file = filepath;
    preview.new_content = new_content;

    std::ifstream file(filepath);
    if (file.is_open()) {
        std::stringstream ss;
        ss << file.rdbuf();
        preview.old_content = ss.str();
    } else {
        preview.old_content = "";
    }

    preview.diff_patch = "--- " + filepath + "\n+++ " + filepath + "\n@@ -1 +1 @@\n-" + 
                         preview.old_content + "\n+" + preview.new_content;

    return preview;
}

std::string Agent3Engine::create_snapshot(const std::vector<std::string>& filepaths) {
    auto now = std::chrono::system_clock::now();
    std::time_t now_time = std::chrono::system_clock::to_time_t(now);
    
    std::stringstream ss;
    ss << "snap_" << std::put_time(std::localtime(&now_time), "%Y%m%d_%H%M%S");
    std::string snap_id = ss.str();

    UndoSnapshot snapshot;
    snapshot.snapshot_id = snap_id;
    snapshot.timestamp = ss.str();

    for (const auto& path : filepaths) {
        std::ifstream f(path);
        if (f.is_open()) {
            std::stringstream buffer;
            buffer << f.rdbuf();
            snapshot.file_states[path] = buffer.str();
        }
    }

    snapshots_[snap_id] = snapshot;
    return snap_id;
}

bool Agent3Engine::revert_snapshot(const std::string& snapshot_id) {
    auto it = snapshots_.find(snapshot_id);
    if (it == snapshots_.end()) return false;

    for (const auto& [filepath, content] : it->second.file_states) {
        std::ofstream out(filepath, std::ios::trunc);
        if (out.is_open()) {
            out << content;
        }
    }
    return true;
}

std::string Agent3Engine::start_process(const std::string& command, const std::string& cwd) {
    (void)command; (void)cwd;
    return "proc_1001";
}

json Agent3Engine::poll_process(const std::string& process_id) {
    json res;
    res["process_id"] = process_id;
    res["status"] = "running";
    res["exit_code"] = 0;
    res["stdout"] = "Process execution output...";
    res["stderr"] = "";
    return res;
}

bool Agent3Engine::stop_process(const std::string& process_id) {
    (void)process_id;
    return true;
}

} // namespace nifdu
