#include "nifdu/agent3.hpp"

#include <algorithm>
#include <atomic>
#include <chrono>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <sstream>
#include <system_error>

namespace nifdu {

namespace {

namespace fs = std::filesystem;

std::string make_id(const std::string& prefix) {
    static std::atomic<unsigned long long> counter{0};
    const auto now = std::chrono::high_resolution_clock::now().time_since_epoch().count();
    return prefix + "_" + std::to_string(now) + "_" + std::to_string(counter++);
}

std::string current_timestamp() {
    const auto now = std::chrono::system_clock::now();
    const std::time_t value = std::chrono::system_clock::to_time_t(now);
    std::tm local{};
#if defined(_WIN32)
    localtime_s(&local, &value);
#else
    localtime_r(&value, &local);
#endif
    std::ostringstream output;
    output << std::put_time(&local, "%Y-%m-%dT%H:%M:%S");
    return output.str();
}

std::string read_text_file(const fs::path& path) {
    std::ifstream input(path, std::ios::binary);
    if (!input) {
        return {};
    }
    std::ostringstream output;
    output << input.rdbuf();
    return output.str();
}

bool write_text_file(const fs::path& path, const std::string& content) {
    std::error_code error;
    if (path.has_parent_path()) {
        fs::create_directories(path.parent_path(), error);
        if (error) {
            return false;
        }
    }
    std::ofstream output(path, std::ios::binary | std::ios::trunc);
    if (!output) {
        return false;
    }
    output << content;
    return static_cast<bool>(output);
}

json step_to_json(const PlanStep& step) {
    return {
        {"id", step.id},
        {"description", step.description},
        {"action", step.action},
        {"target", step.target},
        {"completed", step.completed}
    };
}

} // namespace

Agent3Engine::Agent3Engine() = default;

AgentPlan Agent3Engine::create_plan(const std::string& session_id, const std::string& prompt) {
    AgentPlan plan;
    plan.session_id = session_id.empty() ? make_id("session") : session_id;
    plan.prompt = prompt;
    plan.steps.push_back({1, "Analyse the requested task", "read", ".", false});
    plan.steps.push_back({2, "Prepare a safe implementation plan", "plan", plan.session_id, false});
    plan.steps.push_back({3, "Verify the completed operation", "verify", plan.session_id, false});

    active_plans_[plan.session_id] = plan;
    session_events_[plan.session_id].push_back({
        {"type", "plan_created"},
        {"session_id", plan.session_id},
        {"prompt", prompt},
        {"step_count", plan.steps.size()},
        {"timestamp", current_timestamp()}
    });
    return plan;
}

json Agent3Engine::execute_step(const std::string& session_id, int step_id) {
    const auto plan_it = active_plans_.find(session_id);
    if (plan_it == active_plans_.end()) {
        return {{"success", false}, {"error", "session_not_found"}, {"session_id", session_id}};
    }

    AgentPlan& plan = plan_it->second;
    auto step_it = std::find_if(plan.steps.begin(), plan.steps.end(), [step_id](const PlanStep& step) {
        return step.id == step_id;
    });
    if (step_it == plan.steps.end()) {
        return {{"success", false}, {"error", "step_not_found"}, {"session_id", session_id}, {"step_id", step_id}};
    }

    step_it->completed = true;
    while (plan.current_step_index < static_cast<int>(plan.steps.size()) &&
           plan.steps[static_cast<std::size_t>(plan.current_step_index)].completed) {
        ++plan.current_step_index;
    }
    plan.completed = plan.current_step_index >= static_cast<int>(plan.steps.size());

    json event = {
        {"type", "step_completed"},
        {"session_id", session_id},
        {"step", step_to_json(*step_it)},
        {"plan_completed", plan.completed},
        {"timestamp", current_timestamp()}
    };
    session_events_[session_id].push_back(event);

    return {{"success", true}, {"session_id", session_id}, {"step", step_to_json(*step_it)}, {"plan_completed", plan.completed}};
}

json Agent3Engine::get_events(const std::string& session_id) {
    const auto event_it = session_events_.find(session_id);
    if (event_it == session_events_.end()) {
        return {{"success", true}, {"session_id", session_id}, {"events", json::array()}};
    }
    return {{"success", true}, {"session_id", session_id}, {"events", event_it->second}};
}

DiffPreview Agent3Engine::preview_diff(const std::string& filepath, const std::string& new_content) {
    DiffPreview preview;
    preview.target_file = filepath;
    preview.old_content = read_text_file(filepath);
    preview.new_content = new_content;

    std::ostringstream patch;
    patch << "--- " << filepath << "\n";
    patch << "+++ " << filepath << "\n";
    patch << "@@ -1 +1 @@\n";

    if (!preview.old_content.empty()) {
        std::istringstream old_stream(preview.old_content);
        std::string line;
        while (std::getline(old_stream, line)) {
            patch << "-" << line << "\n";
        }
    }

    std::istringstream new_stream(new_content);
    std::string line;
    while (std::getline(new_stream, line)) {
        patch << "+" << line << "\n";
    }

    preview.diff_patch = patch.str();
    return preview;
}

std::string Agent3Engine::create_snapshot(const std::vector<std::string>& filepaths) {
    UndoSnapshot snapshot;
    snapshot.snapshot_id = make_id("snapshot");
    snapshot.timestamp = current_timestamp();
    for (const std::string& filepath : filepaths) {
        snapshot.file_states[filepath] = read_text_file(filepath);
    }
    snapshots_[snapshot.snapshot_id] = snapshot;
    return snapshot.snapshot_id;
}

bool Agent3Engine::revert_snapshot(const std::string& snapshot_id) {
    const auto snapshot_it = snapshots_.find(snapshot_id);
    if (snapshot_it == snapshots_.end()) {
        return false;
    }

    bool success = true;
    for (const auto& [filepath, content] : snapshot_it->second.file_states) {
        if (!write_text_file(filepath, content)) {
            success = false;
        }
    }
    return success;
}

std::string Agent3Engine::start_process(const std::string& command, const std::string& cwd) {
    const std::string process_id = make_id("process");
    session_events_[process_id].push_back({
        {"type", "process_registered"},
        {"process_id", process_id},
        {"command", command},
        {"cwd", cwd},
        {"status", "not_started"},
        {"message", "Direct process execution is disabled in the safe core"},
        {"timestamp", current_timestamp()}
    });
    return process_id;
}

json Agent3Engine::poll_process(const std::string& process_id) {
    const auto process_it = session_events_.find(process_id);
    if (process_it == session_events_.end()) {
        return {{"success", false}, {"error", "process_not_found"}, {"process_id", process_id}};
    }
    return {
        {"success", true},
        {"process_id", process_id},
        {"status", "not_started"},
        {"running", false},
        {"exit_code", nullptr},
        {"message", "Direct process execution is disabled in the safe core"}
    };
}

bool Agent3Engine::stop_process(const std::string& process_id) {
    const auto process_it = session_events_.find(process_id);
    if (process_it == session_events_.end()) {
        return false;
    }
    process_it->second.push_back({
        {"type", "process_stopped"},
        {"process_id", process_id},
        {"timestamp", current_timestamp()}
    });
    return true;
}

} // namespace nifdu
