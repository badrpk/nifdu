#include "nifdu/workflow_graph.hpp"
#include <ctime>
#include <sstream>
#include <iomanip>

namespace nifdu {

GraphWorkflow::GraphWorkflow(std::string name) : name_(std::move(name)) {}

void GraphWorkflow::add_node(const std::string& name, NodeHandler handler, bool interrupt_before) {
    nodes_[name] = std::move(handler);
    interrupt_nodes_[name] = interrupt_before;
}

void GraphWorkflow::add_edge(const std::string& from_node, const std::string& to_node) {
    direct_edges_[from_node] = to_node;
}

void GraphWorkflow::add_conditional_edges(const std::string& from_node, EdgeCondition condition, const std::map<std::string, std::string>& path_map) {
    conditional_edges_[from_node] = {std::move(condition), path_map};
}

void GraphWorkflow::set_entry_point(const std::string& node_name) {
    entry_point_ = node_name;
}

json GraphWorkflow::run(const std::string& thread_id, const GraphState& initial_state) {
    GraphState current_state = initial_state;
    std::string current_node = entry_point_.empty() ? (nodes_.empty() ? "" : nodes_.begin()->first) : entry_point_;

    int step = 0;
    while (!current_node.empty() && step < 10) {
        step++;

        auto now = std::chrono::system_clock::now();
        std::time_t time = std::chrono::system_clock::to_time_t(now);
        std::stringstream ss;
        ss << "chk_" << thread_id << "_" << step << "_" << time;

        GraphCheckpoint chk;
        chk.checkpoint_id = ss.str();
        chk.thread_id = thread_id;
        chk.step_index = step;
        chk.current_node = current_node;
        chk.state = current_state;
        chk.timestamp = ss.str();

        thread_checkpoints_[thread_id].push_back(chk);

        // HITL Interrupt Check
        if (interrupt_nodes_[current_node]) {
            active_interrupts_[thread_id] = chk;
            json res;
            res["status"] = "interrupted";
            res["thread_id"] = thread_id;
            res["checkpoint_id"] = chk.checkpoint_id;
            res["interrupted_at_node"] = current_node;
            res["current_state"] = current_state;
            return res;
        }

        // Execute node handler
        if (nodes_.count(current_node)) {
            current_state = nodes_[current_node](current_state);
        }

        // Transition to next node
        if (conditional_edges_.count(current_node)) {
            const auto& [cond_fn, path_map] = conditional_edges_[current_node];
            std::string branch_key = cond_fn(current_state);
            current_node = path_map.count(branch_key) ? path_map.at(branch_key) : "";
        } else if (direct_edges_.count(current_node)) {
            current_node = direct_edges_[current_node];
        } else {
            break;
        }
    }

    json result;
    result["status"] = "completed";
    result["thread_id"] = thread_id;
    result["final_state"] = current_state;
    result["total_steps"] = step;
    return result;
}

json GraphWorkflow::approve_and_continue(const std::string& thread_id, const GraphState& updated_state) {
    if (!active_interrupts_.count(thread_id)) {
        return json{{"error", "No active interrupt for thread_id"}};
    }

    auto chk = active_interrupts_[thread_id];
    active_interrupts_.erase(thread_id);

    GraphState state = updated_state.empty() ? chk.state : updated_state;
    // Execute target node with approval
    if (nodes_.count(chk.current_node)) {
        state = nodes_[chk.current_node](state);
    }

    std::string next_node = direct_edges_.count(chk.current_node) ? direct_edges_[chk.current_node] : "";

    json result;
    result["status"] = "completed";
    result["thread_id"] = thread_id;
    result["final_state"] = state;
    result["completed_at_node"] = chk.current_node;
    return result;
}

GraphCheckpoint GraphWorkflow::get_checkpoint(const std::string& checkpoint_id) {
    for (const auto& [tid, list] : thread_checkpoints_) {
        for (const auto& chk : list) {
            if (chk.checkpoint_id == checkpoint_id) return chk;
        }
    }
    return {};
}

json GraphWorkflow::rewind_to_checkpoint(const std::string& checkpoint_id) {
    auto chk = get_checkpoint(checkpoint_id);
    if (chk.checkpoint_id.empty()) {
        return json{{"error", "Checkpoint not found"}};
    }
    json result;
    result["status"] = "rewound";
    result["checkpoint_id"] = checkpoint_id;
    result["thread_id"] = chk.thread_id;
    result["restored_state"] = chk.state;
    return result;
}

} // namespace nifdu
